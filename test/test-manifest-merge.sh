#!/usr/bin/env bash
# (see idstack-migrate --init coverage at the end of this file)
# Unit tests for bin/idstack-manifest-merge.
# Run from the repo root (or sourced by smoke-test.sh).

set -e

PASS=0
FAIL=0
TOTAL=0

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$REPO_ROOT/bin/idstack-manifest-merge"

assert() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    echo "  PASS: $1"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1"
  fi
}

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
assert "section replaced" \
  "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"red_team_audit\"]=={\"confidence_score\": 75}'"

# --- Test 2: foreign sections preserved ---
assert "context preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"context\"]=={\"modality\": \"online\"}'"
assert "needs_analysis preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"needs_analysis\"]=={\"existing\": \"data\"}'"

# --- Test 3: top-level fields preserved (project_name, created) ---
assert "project_name preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"project_name\"]==\"test-project\"'"
assert "created preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"created\"]==\"2026-01-01T00:00:00Z\"'"
assert "version preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"version\"]==\"1.4\"'"

# --- Test 4: updated timestamp bumped (not equal to seeded value) ---
assert "updated timestamp bumped" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"updated\"]!=\"2026-01-01T00:00:00Z\"'"

# --- Test 5: stdin payload ---
seed_manifest
echo '{"score": 99}' | "$MERGE" --section quality_review --payload - --manifest "$WORK/project.json" --quiet
assert "stdin payload accepted" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"quality_review\"]=={\"score\": 99}'"

# --- Test 6: unknown section rejected with exit 3 ---
seed_manifest
set +e
"$MERGE" --section bogus_section --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "unknown section exits 3" "[ $EC -eq 3 ]"

# --- Test 7: malformed payload rejected with exit 1 ---
seed_manifest
echo 'not json' > "$WORK/bad.json"
set +e
"$MERGE" --section red_team_audit --payload "$WORK/bad.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "malformed payload exits 1" "[ $EC -eq 1 ]"

# --- Test 8: malformed manifest rejected with exit 2 ---
echo 'not json' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "malformed manifest exits 2" "[ $EC -eq 2 ]"

# --- Test 9: missing manifest rejected with exit 4 ---
rm -f "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "missing manifest exits 4" "[ $EC -eq 4 ]"

# --- Test 10: missing payload file rejected with exit 5 ---
seed_manifest
set +e
"$MERGE" --section red_team_audit --payload "$WORK/nonexistent.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "missing payload file exits 5" "[ $EC -eq 5 ]"

# --- Test 11: manifest with non-dict root (list) rejected with exit 2 ---
echo '[]' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "manifest with list root exits 2" "[ $EC -eq 2 ]"

# --- Test 12: manifest with non-dict root (string) rejected with exit 2 ---
echo '"a string"' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "manifest with string root exits 2" "[ $EC -eq 2 ]"

# --- idstack-migrate --init: the manifest bootstrap the merge tool depends on ---
# Skills running standalone create the manifest with --init before merging;
# without it the merge exits 4 and standalone results are never persisted.
MIGRATE="$(cd "$(dirname "$0")/.." && pwd -P)/bin/idstack-migrate"

INIT_DIR="$WORK/initcase"
mkdir -p "$INIT_DIR/.idstack"
( cd "$INIT_DIR" && "$MIGRATE" --init .idstack/project.json >/dev/null 2>&1 )
assert "--init creates a manifest" "[ -f '$INIT_DIR/.idstack/project.json' ]"
assert "--init manifest is at the latest schema version" \
  "python3 -c \"import json; assert json.load(open('$INIT_DIR/.idstack/project.json'))['version']=='1.4'\""

# Every section the merge tool accepts must exist in a freshly initialized
# manifest — otherwise a standalone skill's first merge lands in a document
# missing the sections downstream skills read.
assert "--init manifest carries every mergeable section" \
  "python3 -c \"
import json, re, sys
d = json.load(open('$INIT_DIR/.idstack/project.json'))
src = open('$MERGE').read()
allowed = set(re.findall(r'\\\"([a-z_]+)\\\",?\\s*(?:#|\\n)', src.split('ALLOWED_SECTIONS')[1].split(']')[0]))
missing = sorted(s for s in allowed if s not in d)
assert not missing, 'missing from --init manifest: ' + repr(missing)
\""

# A merge into a freshly initialized manifest must succeed.
( cd "$INIT_DIR" && echo '{"overall_score": 77}' | "$MERGE" --section quality_review --payload - --quiet >/dev/null 2>&1 )
assert "merge into an --init manifest succeeds" \
  "python3 -c \"import json; assert json.load(open('$INIT_DIR/.idstack/project.json'))['quality_review']['overall_score']==77\""

# --init must never clobber an existing manifest.
( cd "$INIT_DIR" && "$MIGRATE" --init .idstack/project.json >/dev/null 2>&1 )
assert "--init preserves an existing manifest" \
  "python3 -c \"import json; assert json.load(open('$INIT_DIR/.idstack/project.json'))['quality_review']['overall_score']==77\""

# Without --init the old behavior holds: silent no-op on a missing file.
NOINIT_DIR="$WORK/noinit"
mkdir -p "$NOINIT_DIR/.idstack"
( cd "$NOINIT_DIR" && "$MIGRATE" .idstack/project.json >/dev/null 2>&1 )
assert "plain migrate does not create a manifest" "[ ! -f '$NOINIT_DIR/.idstack/project.json' ]"

echo ""

# --- Test 13: payload with non-dict root (list) rejected with exit 1 ---
seed_manifest
echo '[]' > "$WORK/payload.json"
set +e
"$MERGE" --section red_team_audit --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "payload with list root exits 1" "[ $EC -eq 1 ]"

# --- Test 14: payload with non-dict root (string) rejected with exit 1 ---
seed_manifest
echo '"a string"' > "$WORK/payload.json"
set +e
"$MERGE" --section red_team_audit --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
assert "payload with string root exits 1" "[ $EC -eq 1 ]"

echo ""
echo "manifest-merge: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
