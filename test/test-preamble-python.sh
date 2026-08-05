#!/usr/bin/env bash
# Executes the Context Recovery bash block from templates/preamble.md against a
# fixture timeline, on THIS machine's python3. The block swallows errors with
# `2>/dev/null || true`, so an embedded-Python SyntaxError surfaces as empty
# output rather than a crash — the positive assertions below are what catch it.
# (A same-type-quote f-string once broke the whole block on every Python < 3.12
# and no test noticed; this suite exists so that class of failure can't ship.)
#
# Run from the repo root or via smoke-test.sh; CI runs it on Python 3.9 and 3.12.
set -e

PASS=0
FAIL=0
TOTAL=0

IDSTACK_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"

check() {
  TOTAL=$((TOTAL + 1))
  local _out
  if _out=$(eval "$2" 2>&1); then
    echo "  PASS: $1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"
    if [ -n "$_out" ]; then
      printf '%s\n' "$_out" | head -5 | sed 's/^/        | /'
    fi
    FAIL=$((FAIL + 1))
  fi
}

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
# SKILL.md files embed this block byte-for-byte (gen-skills splices it), so
# testing the source covers all 22 outputs.
awk '/^## Preamble: Context Recovery/{s=1} s && /^```bash$/{f=1; next} f && /^```$/{exit} f' \
  "$IDSTACK_DIR/templates/preamble.md" > "$WORK/block.sh"

check "extracted a non-empty context-recovery block" "[ -s '$WORK/block.sh' ]"
check "block reads the timeline" "grep -q 'timeline.jsonl' '$WORK/block.sh'"

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

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
