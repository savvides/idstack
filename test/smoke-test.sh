#!/usr/bin/env bash
# idstack smoke test — verifies installation is correct
set -e

PASS=0
FAIL=0
TOTAL=0

SKILLS_DIR="${1:-$HOME/.claude/skills}"

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" 2>/dev/null; then
    echo "  PASS: $1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
  fi
}

echo "idstack smoke test"
echo "  skills dir: $SKILLS_DIR"
echo ""

# Check symlinks exist
check "idstack symlink exists" "[ -L '$SKILLS_DIR/idstack' ]"
check "needs-analysis symlink exists" "[ -L '$SKILLS_DIR/needs-analysis' ]"
check "learning-objectives symlink exists" "[ -L '$SKILLS_DIR/learning-objectives' ]"
check "course-quality-review symlink exists" "[ -L '$SKILLS_DIR/course-quality-review' ]"

# Check SKILL.md files are reachable through symlinks
check "needs-analysis/SKILL.md reachable" "[ -f '$SKILLS_DIR/needs-analysis/SKILL.md' ]"
check "learning-objectives/SKILL.md reachable" "[ -f '$SKILLS_DIR/learning-objectives/SKILL.md' ]"
check "course-quality-review/SKILL.md reachable" "[ -f '$SKILLS_DIR/course-quality-review/SKILL.md' ]"

# Check YAML frontmatter has required fields
for skill in needs-analysis learning-objectives course-quality-review; do
  check "$skill has name: field" "grep -q '^name:' '$SKILLS_DIR/$skill/SKILL.md'"
  check "$skill has description: field" "grep -q '^description:' '$SKILLS_DIR/$skill/SKILL.md'"
  check "$skill has allowed-tools: field" "grep -q '^allowed-tools:' '$SKILLS_DIR/$skill/SKILL.md'"
done

# Check evidence file exists
check "evidence/references.md exists" "[ -f '$SKILLS_DIR/idstack/evidence/references.md' ]"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
