#!/usr/bin/env bash
# (see idstack-migrate --init coverage after Test 12 in this file)
# Unit tests for scripts/idstack-manifest-merge.
# Run from the repo root, or through smoke-test.sh, which runs it.

set -e

. "$(dirname "$0")/test-helper.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$REPO_ROOT/scripts/idstack-manifest-merge"

# Skip the suite if python3 is missing (the tool requires python3).
if ! command -v python3 >/dev/null 2>&1; then
  echo "test-manifest-merge: python3 not available, skipping"
  exit 0
fi

if [ ! -x "$MERGE" ]; then
  echo "test-manifest-merge: $MERGE missing or not executable"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
# Windows: the python3 -c checks name these paths in their code, where Git Bash does not convert /tmp/... (C:/... works in both).
case "$(uname -s)" in MINGW*|MSYS*) ON_WINDOWS=1; WORK=$(cygpath -m "$WORK"); MERGE=$(cygpath -m "$MERGE") ;; esac
# NTFS has no POSIX file modes or read-only folders, Git Bash's ln -s makes a copy and ulimit -f fails:
# these checks run on macOS and Linux only.
posix_check() { if [ -n "${ON_WINDOWS:-}" ]; then echo "  SKIP: $1 (Windows)"; else check "$@"; fi; }

# Fresh manifest used by each test (rewritten between cases).
seed_manifest() {
  cat > "$WORK/project.json" <<'EOF'
{
  "version": "1.4",
  "project_name": "test-project",
  "created": "2026-01-01T00:00:00Z",
  "updated": "2026-01-01T00:00:00Z",
  "context": {"modality": "online"},
  "needs_analysis": {"existing": "data"},
  "red_team_audit": {"old": "value"}
}
EOF
}

echo "test-manifest-merge"
echo ""

# --- Test 1: simple replace ---
seed_manifest
echo '{"confidence_score": 75}' > "$WORK/payload.json"
"$MERGE" --section red_team_audit --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet
check "section replaced" \
  "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"red_team_audit\"]=={\"confidence_score\": 75}'"

# --- Test 2: foreign sections preserved ---
check "context preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"context\"]=={\"modality\": \"online\"}'"
check "needs_analysis preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"needs_analysis\"]=={\"existing\": \"data\"}'"

# --- Test 3: top-level fields preserved (project_name, created) ---
check "project_name preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"project_name\"]==\"test-project\"'"
check "created preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"created\"]==\"2026-01-01T00:00:00Z\"'"
check "version preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"version\"]==\"1.4\"'"

# --- Test 4: updated timestamp bumped (not equal to seeded value) ---
check "updated timestamp bumped" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"updated\"]!=\"2026-01-01T00:00:00Z\"'"

# --- Test 5: stdin payload ---
seed_manifest
echo '{"score": 99}' | "$MERGE" --section quality_review --payload - --manifest "$WORK/project.json" --quiet
check "stdin payload accepted" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"quality_review\"]=={\"score\": 99}'"

# --- Test 6: unknown section rejected with exit 3 ---
seed_manifest
set +e
"$MERGE" --section bogus_section --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "unknown section exits 3" "[ $EC -eq 3 ]"

# --- Test 7: malformed payload rejected with exit 1 ---
seed_manifest
echo 'not json' > "$WORK/bad.json"
set +e
"$MERGE" --section red_team_audit --payload "$WORK/bad.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "malformed payload exits 1" "[ $EC -eq 1 ]"

# --- Test 8: malformed manifest rejected with exit 2 ---
echo 'not json' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "malformed manifest exits 2" "[ $EC -eq 2 ]"

# --- Test 9: missing manifest rejected with exit 4 ---
rm -f "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "missing manifest exits 4" "[ $EC -eq 4 ]"

# --- Test 10: missing payload file rejected with exit 5 ---
seed_manifest
set +e
"$MERGE" --section red_team_audit --payload "$WORK/nonexistent.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "missing payload file exits 5" "[ $EC -eq 5 ]"

# --- Test 11: manifest with non-dict root (list) rejected with exit 2 ---
echo '[]' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "manifest with list root exits 2" "[ $EC -eq 2 ]"

# --- Test 12: manifest with non-dict root (string) rejected with exit 2 ---
echo '"a string"' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "manifest with string root exits 2" "[ $EC -eq 2 ]"

# --- idstack-migrate --init: the manifest bootstrap the merge tool depends on ---
# Skills pass --create to the merge, which runs idstack-migrate --init when
# no manifest exists; without --create the merge exits 4 and standalone results are never saved.
MIGRATE="$(cd "$(dirname "$0")/.." && pwd -P)/scripts/idstack-migrate"

INIT_DIR="$WORK/initcase"
mkdir -p "$INIT_DIR/.idstack"
( cd "$INIT_DIR" && "$MIGRATE" --init .idstack/project.json >/dev/null 2>&1 )
check "--init creates a manifest" "[ -f '$INIT_DIR/.idstack/project.json' ]"
check "--init manifest is at the latest schema version" \
  "python3 -c \"import json; assert json.load(open('$INIT_DIR/.idstack/project.json'))['version']=='1.4'\""

# Every section the merge tool accepts must exist in a freshly initialized
# manifest — otherwise a standalone skill's first merge lands in a document
# missing the sections downstream skills read.
check "--init manifest carries every mergeable section" \
  "python3 -c \"
import json
d = json.load(open('$INIT_DIR/.idstack/project.json'))
ns = {'__name__': 'merge', '__file__': '$MERGE'}
exec(open('$MERGE').read(), ns)
allowed = ns['ALLOWED_SECTIONS']
missing = sorted(s for s in allowed if s not in d)
assert not missing, 'missing from --init manifest: ' + repr(missing)
\""

# A merge into a freshly initialized manifest must succeed.
( cd "$INIT_DIR" && echo '{"overall_score": 77}' | "$MERGE" --section quality_review --payload - --quiet >/dev/null 2>&1 )
check "merge into an --init manifest succeeds" \
  "python3 -c \"import json; assert json.load(open('$INIT_DIR/.idstack/project.json'))['quality_review']['overall_score']==77\""

# --init must never clobber an existing manifest.
( cd "$INIT_DIR" && "$MIGRATE" --init .idstack/project.json >/dev/null 2>&1 )
check "--init preserves an existing manifest" \
  "python3 -c \"import json; assert json.load(open('$INIT_DIR/.idstack/project.json'))['quality_review']['overall_score']==77\""

# Without --init the old behavior holds: silent no-op on a missing file.
NOINIT_DIR="$WORK/noinit"
mkdir -p "$NOINIT_DIR/.idstack"
( cd "$NOINIT_DIR" && "$MIGRATE" .idstack/project.json >/dev/null 2>&1 )
check "plain migrate does not create a manifest" "[ ! -f '$NOINIT_DIR/.idstack/project.json' ]"

# migrate once wrote the manifest in place and turned a failed write into exit 0,
# which left a cut-off manifest. A 20 KB manifest cannot be written under a
# 4-block file size limit.
FAILMIG="$WORK/failmig"
mkdir -p "$FAILMIG"
python3 -c "import json, sys; json.dump({'version': '1.3', 'project_name': 'x', 'pad': 'p' * 20000}, open(sys.argv[1], 'w'))" "$FAILMIG/project.json"
cp "$FAILMIG/project.json" "$FAILMIG/before.json"
set +e
MIG_OUT=$( ulimit -f 4; "$MIGRATE" "$FAILMIG/project.json" 2>/dev/null )
MIG_EC=$?
set -e
posix_check "migrate that cannot write exits non-zero, prints nothing and keeps the manifest" \
  "[ $MIG_EC -ne 0 ] && [ -z \"\$MIG_OUT\" ] && cmp -s '$FAILMIG/project.json' '$FAILMIG/before.json' && [ -z \"\$(ls -A '$FAILMIG' | grep -v -e '^project.json\$' -e '^before.json\$')\" ]"

# migrate once pasted the path into its python source, so a quote broke it.
QUOTEMIG="$WORK/o'neil course"
mkdir -p "$QUOTEMIG"
echo '{"version": "1.3", "project_name": "q"}' > "$QUOTEMIG/project.json"
chmod 640 "$QUOTEMIG/project.json"
check "migrate works at a path with a quote" \
  "\"\$MIGRATE\" \"\$QUOTEMIG/project.json\" >/dev/null 2>&1 && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))[\"version\"] == \"1.4\"' \"\$QUOTEMIG/project.json\""
posix_check "migrate keeps the file mode at a path with a quote" \
  "python3 -c 'import os, sys; p = sys.argv[1]; assert os.stat(p).st_mode & 0o777 == 0o640, oct(os.stat(p).st_mode)' \"\$QUOTEMIG/project.json\""

# migrate once replaced a symlinked manifest with a plain file and left the target at the old version.
LINKMIG="$WORK/linkmig"
mkdir -p "$LINKMIG/real"
echo '{"version": "1.0", "project_name": "l"}' > "$LINKMIG/real/project.json"
ln -s "$LINKMIG/real/project.json" "$LINKMIG/project.json"
"$MIGRATE" "$LINKMIG/project.json" >/dev/null 2>&1 || true
posix_check "migrate writes through a symlinked manifest" \
  "[ -L '$LINKMIG/project.json' ] && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))[\"version\"] == \"1.4\"' '$LINKMIG/real/project.json'"

# migrate once gave a python traceback when it could not make its tempfile.
if [ "$(id -u)" -ne 0 ]; then
  ROMIG="$WORK/romig"
  mkdir -p "$ROMIG"
  echo '{"version": "1.3", "project_name": "r"}' > "$ROMIG/project.json"
  cp "$ROMIG/project.json" "$ROMIG/before.json"
  chmod 555 "$ROMIG"
  set +e
  RO_ERR=$( "$MIGRATE" "$ROMIG/project.json" 2>&1 >/dev/null )
  RO_EC=$?
  set -e
  chmod 755 "$ROMIG"
  posix_check "migrate in a read-only folder exits 1 with a clear message and keeps the manifest" \
    "[ $RO_EC -eq 1 ] && printf '%s' \"\$RO_ERR\" | grep -q 'The manifest did not change' && ! printf '%s' \"\$RO_ERR\" | grep -q Traceback && cmp -s '$ROMIG/project.json' '$ROMIG/before.json'"
fi

echo ""

# --- Test 13: payload with non-dict root (list) rejected with exit 1 ---
seed_manifest
echo '[]' > "$WORK/payload.json"
set +e
"$MERGE" --section red_team_audit --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "payload with list root exits 1" "[ $EC -eq 1 ]"

# --- Test 14: payload with non-dict root (string) rejected with exit 1 ---
seed_manifest
echo '"a string"' > "$WORK/payload.json"
set +e
"$MERGE" --section red_team_audit --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "payload with string root exits 1" "[ $EC -eq 1 ]"

# --- Test 15: --create makes a canonical manifest, then merges into it ---
rm -f "$WORK/project.json"
echo '{"overall_score": 81}' | "$MERGE" --create --section quality_review --payload - --manifest "$WORK/project.json" --quiet
check "--create makes a missing manifest" "[ -f '$WORK/project.json' ]"
check "--create manifest is canonical and carries the section" \
  "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"version\"]==\"1.4\" and \"red_team_audit\" in d and d[\"quality_review\"]=={\"overall_score\": 81}'"

# --- Test 16: --create never replaces an existing manifest ---
seed_manifest
echo '{}' | "$MERGE" --create --section quality_review --payload - --manifest "$WORK/project.json" --quiet
check "--create keeps an existing manifest" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"needs_analysis\"]=={\"existing\": \"data\"}'"

# --- Test 17: several sections and --set in one write ---
seed_manifest
echo '{"a": 1}' > "$WORK/p1.json"
echo '{"b": 2}' | "$MERGE" --set project_name="New Name" --section assessments --payload "$WORK/p1.json" \
  --section learning_objectives --payload - --manifest "$WORK/project.json" --quiet
check "multi-section write replaces each section" \
  "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"assessments\"]=={\"a\": 1} and d[\"learning_objectives\"]=={\"b\": 2}'"
check "--set writes project_name" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"project_name\"]==\"New Name\"'"

# --- Test 18: a bad second payload writes nothing; a bad payload with --create makes no manifest ---
seed_manifest
cp "$WORK/project.json" "$WORK/before.json"
echo 'not json' > "$WORK/bad.json"
set +e
"$MERGE" --section assessments --payload "$WORK/p1.json" --section learning_objectives --payload "$WORK/bad.json" \
  --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "bad second payload exits 1" "[ $EC -eq 1 ]"
check "bad second payload leaves the manifest unchanged" "cmp -s '$WORK/project.json' '$WORK/before.json'"
rm -f "$WORK/project.json"
set +e
"$MERGE" --create --section assessments --payload "$WORK/bad.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
set -e
check "bad payload with --create makes no manifest" "[ ! -f '$WORK/project.json' ]"

# --- Test 19: --set takes only known keys; pairs must match ---
seed_manifest
set +e
echo '{}' | "$MERGE" --set version=9 --section quality_review --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
"$MERGE" --section assessments --section quality_review --payload "$WORK/p1.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC2=$?
set -e
check "--set with an unknown key exits 3" "[ $EC -eq 3 ]"
check "a --section with no --payload is refused" "[ $EC2 -ne 0 ]"

# --- Test 20: the merge keeps the manifest's file mode (mkstemp makes 0600) ---
seed_manifest
chmod 644 "$WORK/project.json"
echo '{}' | "$MERGE" --section quality_review --payload - --manifest "$WORK/project.json" --quiet
posix_check "merge keeps the manifest mode 644" \
  "python3 -c 'import os, sys; m = os.stat(sys.argv[1]).st_mode & 0o777; assert m == 0o644, oct(m)' '$WORK/project.json'"

# --- Test 21: a symlinked manifest stays a link, and its target gets the write (#168) ---
mkdir -p "$WORK/linkmerge/real"
seed_manifest
cp "$WORK/project.json" "$WORK/linkmerge/real/project.json"
ln -s "$WORK/linkmerge/real/project.json" "$WORK/linkmerge/project.json"
echo '{"x": 1}' | "$MERGE" --section quality_review --payload - --manifest "$WORK/linkmerge/project.json" --quiet || true
posix_check "merge writes through a symlinked manifest" \
  "[ -L '$WORK/linkmerge/project.json' ] && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))[\"quality_review\"] == {\"x\": 1}' '$WORK/linkmerge/real/project.json'"

# --- Test 22: a read-only folder gives exit 6 and a clear message, not a traceback ---
if [ "$(id -u)" -ne 0 ]; then
  mkdir -p "$WORK/romerge"
  seed_manifest
  cp "$WORK/project.json" "$WORK/romerge/project.json"
  chmod 555 "$WORK/romerge"
  set +e
  RO_ERR=$(echo '{}' | "$MERGE" --section quality_review --payload - --manifest "$WORK/romerge/project.json" 2>&1 >/dev/null)
  RO_EC=$?
  set -e
  chmod 755 "$WORK/romerge"
  posix_check "merge in a read-only folder exits 6 with no traceback" \
    "[ $RO_EC -eq 6 ] && ! printf '%s' \"\$RO_ERR\" | grep -q Traceback && cmp -s '$WORK/romerge/project.json' '$WORK/project.json'"
fi

# --- Test 23: a manifest from a newer idstack is not written (exit 7) ---
seed_manifest
python3 -c 'import json, sys; p = sys.argv[1]; d = json.load(open(p)); d["version"] = "1.10"; json.dump(d, open(p, "w"))' "$WORK/project.json"
cp "$WORK/project.json" "$WORK/newer-before.json"
set +e
NEW_ERR=$(echo '{}' | "$MERGE" --section quality_review --payload - --manifest "$WORK/project.json" 2>&1 >/dev/null)
NEW_EC=$?
set -e
check "merge refuses a manifest from a newer idstack (exit 7, unchanged)" \
  "[ $NEW_EC -eq 7 ] && printf '%s' \"\$NEW_ERR\" | grep -q 'newer' && cmp -s '$WORK/project.json' '$WORK/newer-before.json'"

# --- Test 24: migrate reports a newer schema and leaves the file unchanged ---
set +e
MIG_ERR=$("$REPO_ROOT/scripts/idstack-migrate" "$WORK/project.json" 2>&1 >/dev/null)
set -e
check "migrate prints NEWER_SCHEMA for a manifest from a newer idstack" \
  "printf '%s' \"\$MIG_ERR\" | grep -qx 'NEWER_SCHEMA 1.10' && cmp -s '$WORK/project.json' '$WORK/newer-before.json'"

# --- Test 25: migrate treats a null section as absent instead of crashing ---
echo '{"version": "1.0", "project_name": "n", "quality_review": null, "import_metadata": null}' > "$WORK/nullmig.json"
check "migrate fills a null section with its defaults" \
  "\"$REPO_ROOT/scripts/idstack-migrate\" '$WORK/nullmig.json' >/dev/null 2>&1 && python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d[\"version\"] == \"1.4\" and isinstance(d[\"quality_review\"], dict) and isinstance(d[\"import_metadata\"], dict)' '$WORK/nullmig.json'"

# --- Test 26: migrate --init writes its seed atomically (no stray tempfile, valid JSON) ---
mkdir -p "$WORK/initmig"
"$REPO_ROOT/scripts/idstack-migrate" --init "$WORK/initmig/project.json" >/dev/null 2>&1
check "migrate --init leaves one valid manifest and no tempfile" \
  "[ \"\$(ls -A '$WORK/initmig')\" = project.json ] && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))[\"version\"] == \"1.4\"' '$WORK/initmig/project.json'"

# --- Test 27: file mode (#190). A new manifest has the umask mode, and a merge keeps the mode ---
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
mkdir -p "$WORK/mode"
echo '{}' > "$WORK/mode/p.json"
check "a new manifest has mode 644 under umask 022, and a merge keeps it" \
  "( umask 022; cd '$WORK/mode' && '$MERGE' --create --section context --payload p.json --quiet && [ \"\$(mode_of .idstack/project.json)\" = 644 ] && '$MERGE' --section context --payload p.json --quiet && [ \"\$(mode_of .idstack/project.json)\" = 644 ] )"
chmod 640 "$WORK/mode/.idstack/project.json"
posix_check "a merge keeps mode 640 of an existing manifest" \
  "( umask 022; cd '$WORK/mode' && '$MERGE' --section context --payload p.json --quiet && [ \"\$(mode_of .idstack/project.json)\" = 640 ] )"

# --- Test 28: the home folder (#178). Merge and migrate --init write nothing there ---
mkdir -p "$WORK/home"
set +e
HOME_ERR=$(cd "$WORK/home" && HOME="$WORK/home" "$MERGE" --create --section context --payload ../mode/p.json 2>&1 >/dev/null)
HOME_EC=$?
HOME_MIG_ERR=$(cd "$WORK/home" && HOME="$WORK/home" "$REPO_ROOT/scripts/idstack-migrate" --init 2>&1 >/dev/null)
HOME_MIG_EC=$?
set -e
check "merge in the home folder exits 9 and writes nothing" \
  "[ $HOME_EC -eq 9 ] && printf '%s' \"\$HOME_ERR\" | grep -q 'home folder' && [ ! -e '$WORK/home/.idstack' ]"
check "migrate --init in the home folder exits 9 and writes nothing" \
  "[ $HOME_MIG_EC -eq 9 ] && printf '%s' \"\$HOME_MIG_ERR\" | grep -q 'home folder' && [ ! -e '$WORK/home/.idstack' ]"
posix_check "a symlink to the home folder is also refused" \
  "ln -s '$WORK/home' '$WORK/homelink' && cd '$WORK/homelink' && HOME='$WORK/home' '$MERGE' --create --section context --payload ../mode/p.json --quiet; [ \$? -eq 9 ]"

# --- Test 29: the lock (#179). Two writers at the same time lose no update ---
mkdir -p "$WORK/lock/.idstack"
(
  cd "$WORK/lock"
  echo '{}' | "$MERGE" --create --section context --payload - --quiet
  ( for i in $(seq 1 40); do echo "{\"n\":$i}" | "$MERGE" --section quality_review --payload - --quiet; done ) &
  ( for i in $(seq 1 40); do echo "{\"n\":$i}" | "$MERGE" --section red_team_audit --payload - --quiet; done ) &
  wait
)
check "two concurrent merges lose no update" \
  "python3 -c 'import json; d=json.load(open(\"$WORK/lock/.idstack/project.json\")); assert d[\"quality_review\"][\"n\"]==40 and d[\"red_team_audit\"][\"n\"]==40, d'"

# The lock, without timing (#203): hold .manifest.lock, start a merge, and make
# sure that it waits. Test 29 alone passes with no lock when the writes do not overlap.
mkdir -p "$WORK/held/.idstack"
( cd "$WORK/held" && echo '{}' | "$MERGE" --create --section context --payload - --quiet )
check "a merge waits while another process holds the lock" \
  "python3 - '$MERGE' '$WORK/held' <<'PY'
import json, os, subprocess, sys
merge, d = sys.argv[1], sys.argv[2]
manifest = d + '/.idstack/project.json'
lock = open(d + '/.idstack/.manifest.lock', 'a')
try:
    import fcntl
    fcntl.flock(lock, fcntl.LOCK_EX)
except ImportError:  # Windows: the merge locks byte 0 with msvcrt
    import msvcrt
    lock.seek(0)
    msvcrt.locking(lock.fileno(), msvcrt.LK_LOCK, 1)
cmd = [sys.executable, merge] if os.name == 'nt' else [merge]  # Windows runs no shebang
p = subprocess.Popen(cmd + ['--section', 'quality_review', '--payload', '-', '--quiet'], cwd=d, stdin=subprocess.PIPE)
p.stdin.write(b'{\"n\": 1}'); p.stdin.close()
try:
    p.wait(timeout=5)
    sys.exit('the merge did not wait for the lock')
except subprocess.TimeoutExpired:
    pass
assert json.load(open(manifest)).get('quality_review') != {'n': 1}
lock.close()
assert p.wait(timeout=30) == 0
assert json.load(open(manifest))['quality_review'] == {'n': 1}
PY"

# --- Test 30: --expect-updated (#179). A stale read writes nothing ---
seed_manifest
cp "$WORK/project.json" "$WORK/expect-before.json"
echo '{"x": 1}' > "$WORK/payload.json"
set +e
EXP_ERR=$("$MERGE" --section quality_review --payload "$WORK/payload.json" --manifest "$WORK/project.json" --expect-updated "2025-12-31T00:00:00Z" 2>&1 >/dev/null)
EXP_EC=$?
set -e
check "a stale --expect-updated exits 8 and leaves the manifest unchanged" \
  "[ $EXP_EC -eq 8 ] && printf '%s' \"\$EXP_ERR\" | grep -q 'changed after you read' && cmp -s '$WORK/project.json' '$WORK/expect-before.json'"
check "a matching --expect-updated writes" \
  "'$MERGE' --section quality_review --payload '$WORK/payload.json' --manifest '$WORK/project.json' --expect-updated 2026-01-01T00:00:00Z --quiet && python3 -c 'import json; assert json.load(open(\"$WORK/project.json\"))[\"quality_review\"]=={\"x\": 1}'"
check "a second merge with the first read time is stale" \
  "'$MERGE' --section quality_review --payload '$WORK/payload.json' --manifest '$WORK/project.json' --expect-updated 2026-01-01T00:00:00Z --quiet" 8

# The lock file must be git-ignored, once, even when .gitignore lacks a final newline.
GI="$WORK/gi"; mkdir -p "$GI"; seed_manifest; cp "$WORK/project.json" "$GI/project.json"; printf 'canvas.env' > "$GI/.gitignore"
echo '{"x": 1}' > "$WORK/payload.json"
"$MERGE" --section quality_review --payload "$WORK/payload.json" --manifest "$GI/project.json" --quiet
"$MERGE" --section quality_review --payload "$WORK/payload.json" --manifest "$GI/project.json" --quiet
check "the merge git-ignores .manifest.lock once and keeps old lines" \
  "[ \$(grep -cx '.manifest.lock' '$GI/.gitignore') -eq 1 ] && grep -qx 'canvas.env' '$GI/.gitignore'"
GW="$WORK/gw"; mkdir -p "$GW/.gitignore"; cp "$WORK/project.json" "$GW/project.json"
GW_ERR=$("$MERGE" --section quality_review --payload "$WORK/payload.json" --manifest "$GW/project.json" --quiet 2>&1 >/dev/null)
check "a .gitignore that cannot be written warns on stderr and the merge still writes" \
  "printf '%s' \"\$GW_ERR\" | grep -q 'gitignore' && python3 -c 'import json; assert json.load(open(\"$GW/project.json\"))[\"quality_review\"]=={\"x\": 1}'"

# Non-ASCII text through stdin, a payload file and the slug (#136). A Windows python3 reads a pipe in
# the ANSI code page; PYTHONIOENCODING=cp1252 makes that pipe on every OS. The bytes are UTF-8: "Café — é".
mkdir -p "$WORK/utf8/.idstack"
printf '{"n": "Caf\303\251 \342\200\224 \303\251"}' > "$WORK/utf8/p.json"
printf '{"project_name": "Caf\303\251 \342\200\224 Bio 101"}' > "$WORK/utf8/name.json"
cat > "$WORK/utf8/check.py" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["quality_review"] == {"n": "Caf\u00e9 \u2014 \u00e9"}, d["quality_review"]
assert d["red_team_audit"] == {"n": "Caf\u00e9 \u2014 \u00e9"}, d["red_team_audit"]
PY
check "non-ASCII text in a payload from a cp1252 stdin and from a file stays UTF-8" \
  "cd '$WORK/utf8' && PYTHONIOENCODING=cp1252 '$MERGE' --create --section quality_review --payload - --quiet < p.json && '$MERGE' --section red_team_audit --payload p.json --quiet && python3 check.py .idstack/project.json"
check "the slug of a non-ASCII project name" \
  "[ \"\$('$REPO_ROOT/scripts/idstack-slugify' --from-manifest '$WORK/utf8/name.json')\" = cafe-bio-101 ]"

# A write used to keep the same updated value for a whole second. A second
# merge with the first read then replaced the section.
mkdir -p "$WORK/samesec"
check "a second merge in the same second keeps the first section" \
  "python3 - '$MERGE' '$WORK/samesec' <<'PY'
import datetime, json, os, subprocess, sys
from datetime import timezone
merge, work = sys.argv[1], sys.argv[2]
manifest = os.path.join(work, 'project.json')
cmd = [sys.executable, merge] if os.name == 'nt' else [merge]
lost = []
for i in range(12):
    now = datetime.datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    with open(manifest, 'w', encoding='utf-8') as handle:
        json.dump({'version': '1.4', 'project_name': 't', 'created': now, 'updated': now, 'context': {'keep': 1}}, handle)
    first = os.path.join(work, 'a.json')
    second = os.path.join(work, 'b.json')
    with open(first, 'w', encoding='utf-8') as handle:
        json.dump({'n': 1}, handle)
    with open(second, 'w', encoding='utf-8') as handle:
        json.dump({'n': 2}, handle)
    one = subprocess.run(cmd + ['--section', 'quality_review', '--payload', first, '--manifest', manifest, '--expect-updated', now, '--quiet'])
    if one.returncode != 0:
        lost.append('first write %d exited %d' % (i, one.returncode))
        break
    two = subprocess.run(cmd + ['--section', 'quality_review', '--payload', second, '--manifest', manifest, '--expect-updated', now, '--quiet'], stderr=subprocess.DEVNULL)
    data = json.load(open(manifest, encoding='utf-8'))
    if two.returncode != 8 or data.get('quality_review') != {'n': 1}:
        lost.append('i=%d rc=%d section=%s updated=%s seed=%s' % (i, two.returncode, data.get('quality_review'), data.get('updated'), now))
if lost:
    sys.stderr.write('\n'.join(lost) + '\n')
    sys.exit(1)
PY"

# Two writes in one microsecond must still change updated.
check "a same-microsecond stamp moves forward" \
  "python3 - '$MERGE' <<'PY'
import sys
from datetime import datetime, timezone
merge = sys.argv[1]
ns = {'__name__': 'merge_under_test', '__file__': merge}
exec(open(merge, encoding='utf-8').read(), ns)
class Frozen(datetime):
    @classmethod
    def now(cls, tz=None):
        return cls(2026, 1, 1, 0, 0, 0, 5, tzinfo=timezone.utc)
ns['datetime'] = Frozen
got = ns['fresh_updated']('2026-01-01T00:00:00.000005Z')
assert got == '2026-01-01T00:00:00.000006Z', got
other = ns['fresh_updated']('2020-01-01T00:00:00Z')
assert other == '2026-01-01T00:00:00.000005Z', other
ahead = ns['fresh_updated']('2026-01-01T00:00:01.000000Z')
assert ahead == '2026-01-01T00:00:01.000001Z', ahead
for bad in ('', None, 'not a stamp', 5):
    got = ns['fresh_updated'](bad)
    assert got == '2026-01-01T00:00:00.000005Z', (bad, got)
PY"

# --create must not leave a manifest when --expect-updated refuses the write.
mkdir -p "$WORK/create-stale"
echo '{}' > "$WORK/create-stale/p.json"
set +e
CS_ERR=$("$MERGE" --create --expect-updated "1999-01-01T00:00:00Z" --section context --payload "$WORK/create-stale/p.json" --manifest "$WORK/create-stale/.idstack/project.json" 2>&1 >/dev/null)
CS_EC=$?
set -e
check "--create with a stale --expect-updated exits 8 and makes no manifest" \
  "[ $CS_EC -eq 8 ] && printf '%s' \"\$CS_ERR\" | grep -q 'changed after you read' && [ ! -e '$WORK/create-stale/.idstack' ]"

# An explicit 0 is a real count. The old summary must not replace it.
cat > "$WORK/zeros.json" <<'EOF'
{
  "version": "1.3",
  "project_name": "z",
  "red_team_audit": {
    "summary": {"critical_count": 4, "warning_count": 2, "info_count": 1},
    "findings_summary": {"critical": 0, "warning": 7, "info": 0}
  }
}
EOF
check "migrate keeps an explicit zero in findings_summary" \
  "\"$REPO_ROOT/scripts/idstack-migrate\" '$WORK/zeros.json' >/dev/null && python3 -c 'import json; d=json.load(open(\"$WORK/zeros.json\")); fs=d[\"red_team_audit\"][\"findings_summary\"]; assert fs=={\"critical\": 0, \"warning\": 7, \"info\": 0}, fs; assert \"summary\" not in d[\"red_team_audit\"]'"

# An all-zero findings_summary is the v1.2 seed. The old summary replaces it.
cat > "$WORK/seedzeros.json" <<'EOF'
{
  "version": "1.3",
  "project_name": "z",
  "red_team_audit": {
    "summary": {"critical_count": 4, "warning_count": 2, "info_count": 1},
    "findings_summary": {"critical": 0, "warning": 0, "info": 0}
  }
}
EOF
check "migrate replaces an all-zero findings_summary with the old counts" \
  "\"$REPO_ROOT/scripts/idstack-migrate\" '$WORK/seedzeros.json' >/dev/null && python3 -c 'import json; d=json.load(open(\"$WORK/seedzeros.json\")); fs=d[\"red_team_audit\"][\"findings_summary\"]; assert fs=={\"critical\": 4, \"warning\": 2, \"info\": 1}, fs'"

# A course .idstack that points at the home profile is the home folder (#178).
# Git Bash ln -s copies, so this block runs on macOS and Linux only.
if [ -z "${ON_WINDOWS:-}" ]; then
  mkdir -p "$WORK/homeprof/.idstack" "$WORK/courselink"
  ln -s "$WORK/homeprof/.idstack" "$WORK/courselink/.idstack"
  echo '{}' > "$WORK/courselink/p.json"
  set +e
  LINK_ERR=$(cd "$WORK/courselink" && HOME="$WORK/homeprof" "$MERGE" --create --section context --payload p.json 2>&1 >/dev/null)
  LINK_EC=$?
  LINK_MIG_ERR=$(cd "$WORK/courselink" && HOME="$WORK/homeprof" "$REPO_ROOT/scripts/idstack-migrate" --init 2>&1 >/dev/null)
  LINK_MIG_EC=$?
  set -e
  check "merge through a symlinked .idstack into the home profile exits 9 and writes nothing" \
    "[ $LINK_EC -eq 9 ] && printf '%s' \"\$LINK_ERR\" | grep -q 'home folder' && [ ! -f '$WORK/homeprof/.idstack/project.json' ] && [ ! -e '$WORK/homeprof/.idstack/.manifest.lock' ]"
  check "migrate --init through a symlinked .idstack into the home profile exits 9 and writes nothing" \
    "[ $LINK_MIG_EC -eq 9 ] && printf '%s' \"\$LINK_MIG_ERR\" | grep -q 'home folder' && [ ! -f '$WORK/homeprof/.idstack/project.json' ]"
fi

# The lock has to sit on the real file. A merge through the symlink and a
# merge through the target then wait for each other.
mkdir -p "$WORK/linklock"
posix_check "a merge through a symlinked manifest waits for the lock on the real file" \
  "python3 - '$MERGE' '$WORK/linklock' <<'PY'
import json, os, subprocess, sys
merge, d = sys.argv[1], sys.argv[2]
real = os.path.join(d, 'real')
os.makedirs(real)
manifest_real = os.path.join(real, 'project.json')
with open(manifest_real, 'w', encoding='utf-8') as handle:
    json.dump({'version': '1.4', 'project_name': 's', 'updated': '2020-01-01T00:00:00Z', 'context': {'v': 1}}, handle)
link_dir = os.path.join(d, 'via')
os.makedirs(link_dir)
link = os.path.join(link_dir, 'project.json')
os.symlink(manifest_real, link)
lock = open(os.path.join(real, '.manifest.lock'), 'a')
import fcntl
fcntl.flock(lock, fcntl.LOCK_EX)
cmd = [sys.executable, merge] if os.name == 'nt' else [merge]
proc = subprocess.Popen(cmd + ['--section', 'quality_review', '--payload', '-', '--manifest', link, '--quiet'], stdin=subprocess.PIPE)
proc.stdin.write(b'{\"n\": 1}')
proc.stdin.close()
try:
    proc.wait(timeout=2)
    sys.exit('the merge did not wait for the lock on the real file')
except subprocess.TimeoutExpired:
    pass
lock.close()
rc = proc.wait(timeout=30)
data = json.load(open(manifest_real, encoding='utf-8'))
if rc != 0 or data.get('quality_review') != {'n': 1}:
    sys.exit('after the lock, rc=%s section=%s' % (rc, data.get('quality_review')))
if not os.path.islink(link):
    sys.exit('the manifest symlink was replaced')
PY"

echo ""
echo "manifest-merge: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
