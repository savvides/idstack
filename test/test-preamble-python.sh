#!/usr/bin/env bash
# Executes preamble bash blocks that run Python, on THIS machine's python3.
# Context Recovery runs scripts/idstack-status --context. The Preferences block
# runs an inline python3 -c. Both swallow errors (`2>/dev/null` and, in the
# preferences block, `except Exception: pass`), so a failure surfaces as empty output
# rather than a crash — the positive assertions below are what catch it.
# (A same-type-quote f-string once broke Context Recovery on every Python < 3.12
# and no test noticed; this suite exists so that class of failure can't ship.)
#
# Run from the repo root or via smoke-test.sh; CI runs it on Python 3.9 and 3.12.
set -e

. "$(dirname "$0")/test-helper.sh"

IDSTACK_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"

echo "test-preamble-python"
echo "  python3: $(python3 --version 2>&1 || echo 'not found')"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not available — the preamble degrades without it by design."
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Extract the Context Recovery bash fence from the preamble source. Generated
# SKILL.md files embed this block (gen-skills splices it), so testing the source
# covers every generated SKILL.md. Expand {{IDSTACK_RESOLVE}} with the snippet (gen-skills
# also leaves out its comment lines, which does not change what runs), and write this repo in place of ${CLAUDE_PLUGIN_ROOT} the way Claude Code does.
awk -v snippet="$IDSTACK_DIR/templates/snippets/idstack-resolve.sh" '
  /^## Preamble: Context Recovery/{s=1}
  s && /^```bash$/{f=1; next}
  f && /^```$/{exit}
  f && /\{\{IDSTACK_RESOLVE\}\}/{while ((getline l < snippet) > 0) print l; close(snippet); next}
  f' "$IDSTACK_DIR/templates/preamble.md" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$IDSTACK_DIR|g" > "$WORK/block.sh"

check "extracted a non-empty context-recovery block" "[ -s '$WORK/block.sh' ]"
check "block runs idstack-status --context" "grep -q 'idstack-status\" --context' '$WORK/block.sh'"

mkdir -p "$WORK/proj/.idstack"
cat > "$WORK/proj/.idstack/timeline.jsonl" <<'EOF'
{"ts":"2026-08-04T00:00:00Z","skill":"needs-analysis","event":"completed"}
{"ts":"2026-08-04T00:01:00Z","skill":"course-import","event":"completed"}
EOF

OUT=$(cd "$WORK/proj" && bash "$WORK/block.sh" 2>&1 || true)

check "SKILLS_COMPLETED lists both skills" \
  "echo \"\$OUT\" | grep -qF 'SKILLS_COMPLETED: course-import,needs-analysis'"
check "LAST_SKILL reported" \
  "echo \"\$OUT\" | grep -q 'LAST_SKILL: course-import'"
check "SUGGESTED_NEXT after needs-analysis is learning-objectives" \
  "echo \"\$OUT\" | grep -qF 'SUGGESTED_NEXT: learning-objectives'"

# Import-first project: course-import is the alternative pipeline entry, and it
# alone must still yield a suggestion.
mkdir -p "$WORK/proj2/.idstack"
cat > "$WORK/proj2/.idstack/timeline.jsonl" <<'EOF'
{"ts":"2026-08-04T00:01:00Z","skill":"course-import","event":"completed"}
EOF

OUT2=$(cd "$WORK/proj2" && bash "$WORK/block.sh" 2>&1 || true)

check "import-first project gets SUGGESTED_NEXT: learning-objectives" \
  "echo \"\$OUT2\" | grep -qF 'SUGGESTED_NEXT: learning-objectives'"

# Preferences: open() with no encoding uses the locale. LC_ALL=C and
# PYTHONUTF8=0 make that encoding ASCII. A UTF-8 course name then raises
# UnicodeDecodeError, and the block hides it (except Exception: pass, 2>/dev/null),
# so the known preference lines never print.
awk '
  /^## Preamble: Preferences/{s=1}
  s && /^```bash$/{f=1; next}
  f && /^```$/{exit}
  f' "$IDSTACK_DIR/templates/preamble.md" > "$WORK/prefs-block.sh"
check "extracted a non-empty preferences block" "[ -s '$WORK/prefs-block.sh' ]"

mkdir -p "$WORK/prefs/.idstack"
python3 - "$WORK/prefs/.idstack/project.json" <<'PY'
import sys
open(sys.argv[1], "wb").write(
    '{"project_name":"Caf\u00e9","preferences":{"verbosity":"concise","export_format":"scorm","preferred_lms":"moodle","auto_advance_pipeline":true}}'.encode("utf-8"))
PY

OUTP=$(cd "$WORK/prefs" && LC_ALL=C PYTHONUTF8=0 bash "$WORK/prefs-block.sh" 2>&1 || true)
OUTP=$(printf '%s\n' "$OUTP" | tr -d '\r')

check "preferences survive a non-ASCII manifest when the locale is ASCII" \
  "printf '%s\n' \"\$OUTP\" | grep -qx 'VERBOSITY:concise'"
check "export format survives a non-ASCII manifest when the locale is ASCII" \
  "printf '%s\n' \"\$OUTP\" | grep -qx 'EXPORT_FORMAT:scorm'"
check "preferred LMS survives a non-ASCII manifest when the locale is ASCII" \
  "printf '%s\n' \"\$OUTP\" | grep -qx 'PREFERRED_LMS:moodle'"
check "auto-advance survives a non-ASCII manifest when the locale is ASCII" \
  "printf '%s\n' \"\$OUTP\" | grep -qx 'AUTO_ADVANCE:true'"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
