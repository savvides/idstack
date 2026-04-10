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
check "course-import symlink exists" "[ -L '$SKILLS_DIR/course-import' ]"
check "assessment-design symlink exists" "[ -L '$SKILLS_DIR/assessment-design' ]"
check "course-builder symlink exists" "[ -L '$SKILLS_DIR/course-builder' ]"
check "course-export symlink exists" "[ -L '$SKILLS_DIR/course-export' ]"
check "accessibility-review symlink exists" "[ -L '$SKILLS_DIR/accessibility-review' ]"
check "red-team symlink exists" "[ -L '$SKILLS_DIR/red-team' ]"

# Check SKILL.md files are reachable through symlinks
check "needs-analysis/SKILL.md reachable" "[ -f '$SKILLS_DIR/needs-analysis/SKILL.md' ]"
check "learning-objectives/SKILL.md reachable" "[ -f '$SKILLS_DIR/learning-objectives/SKILL.md' ]"
check "course-quality-review/SKILL.md reachable" "[ -f '$SKILLS_DIR/course-quality-review/SKILL.md' ]"
check "course-import/SKILL.md reachable" "[ -f '$SKILLS_DIR/course-import/SKILL.md' ]"
check "assessment-design/SKILL.md reachable" "[ -f '$SKILLS_DIR/assessment-design/SKILL.md' ]"
check "course-builder/SKILL.md reachable" "[ -f '$SKILLS_DIR/course-builder/SKILL.md' ]"
check "course-export/SKILL.md reachable" "[ -f '$SKILLS_DIR/course-export/SKILL.md' ]"
check "accessibility-review/SKILL.md reachable" "[ -f '$SKILLS_DIR/accessibility-review/SKILL.md' ]"
check "red-team/SKILL.md reachable" "[ -f '$SKILLS_DIR/red-team/SKILL.md' ]"

# Check YAML frontmatter has required fields
for skill in needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team; do
  check "$skill has name: field" "grep -q '^name:' '$SKILLS_DIR/$skill/SKILL.md'"
  check "$skill has description: field" "grep -q '^description:' '$SKILLS_DIR/$skill/SKILL.md'"
  check "$skill has allowed-tools: field" "grep -q '^allowed-tools:' '$SKILLS_DIR/$skill/SKILL.md'"
done

# Check evidence file exists
check "evidence/references.md exists" "[ -f '$SKILLS_DIR/idstack/evidence/references.md' ]"

# Check migration script exists and is executable
check "bin/idstack-migrate exists" "[ -f '$SKILLS_DIR/idstack/bin/idstack-migrate' ]"
check "bin/idstack-migrate is executable" "[ -x '$SKILLS_DIR/idstack/bin/idstack-migrate' ]"

# Check all skills reference idstack-migrate in preamble
for skill in needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team; do
  check "$skill preamble calls idstack-migrate" "grep -q 'idstack-migrate' '$SKILLS_DIR/$skill/SKILL.md'"
done

# Check new bin scripts exist and are executable
check "bin/idstack-timeline-log exists" "[ -f '$SKILLS_DIR/idstack/bin/idstack-timeline-log' ]"
check "bin/idstack-timeline-log is executable" "[ -x '$SKILLS_DIR/idstack/bin/idstack-timeline-log' ]"
check "bin/idstack-learnings-log exists" "[ -f '$SKILLS_DIR/idstack/bin/idstack-learnings-log' ]"
check "bin/idstack-learnings-log is executable" "[ -x '$SKILLS_DIR/idstack/bin/idstack-learnings-log' ]"
check "bin/idstack-learnings-search exists" "[ -f '$SKILLS_DIR/idstack/bin/idstack-learnings-search' ]"
check "bin/idstack-learnings-search is executable" "[ -x '$SKILLS_DIR/idstack/bin/idstack-learnings-search' ]"
check "bin/idstack-status exists" "[ -f '$SKILLS_DIR/idstack/bin/idstack-status' ]"
check "bin/idstack-status is executable" "[ -x '$SKILLS_DIR/idstack/bin/idstack-status' ]"
check "bin/idstack-gen-skills exists" "[ -f '$SKILLS_DIR/idstack/bin/idstack-gen-skills' ]"
check "bin/idstack-gen-skills is executable" "[ -x '$SKILLS_DIR/idstack/bin/idstack-gen-skills' ]"

# Check template system
check "templates/preamble.md exists" "[ -f '$SKILLS_DIR/idstack/templates/preamble.md' ]"
for skill in needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team; do
  check "$skill has SKILL.md.tmpl" "[ -f '$SKILLS_DIR/idstack/$skill/SKILL.md.tmpl' ]"
done

# Check generated files have auto-generated header
for skill in needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team; do
  check "$skill SKILL.md has auto-generated header" "grep -q 'AUTO-GENERATED from SKILL.md.tmpl' '$SKILLS_DIR/$skill/SKILL.md'"
done

# Check all skills have context recovery preamble
for skill in needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team; do
  check "$skill has context recovery" "grep -q 'Context Recovery' '$SKILLS_DIR/$skill/SKILL.md'"
done

# Check all skills have timeline logging
for skill in needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team; do
  check "$skill has timeline logging" "grep -q 'idstack-timeline-log' '$SKILLS_DIR/$skill/SKILL.md'"
done

# Migration tests (v1.0 → v1.2 and v1.1 → v1.2)
FIXTURE_DIR="$SKILLS_DIR/idstack/test/fixtures"
if [ -d "$FIXTURE_DIR" ] && command -v python3 &>/dev/null; then
  # Test v1.0 → v1.2 chained migration
  TMPDIR_MIG=$(mktemp -d)
  cp "$FIXTURE_DIR/manifest-v1.0.json" "$TMPDIR_MIG/project.json"
  "$SKILLS_DIR/idstack/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
  check "v1.0→v1.2: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.2'\""
  check "v1.0→v1.2: has red_team_audit" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'red_team_audit' in d\""
  check "v1.0→v1.2: has accessibility_review" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'accessibility_review' in d\""
  check "v1.0→v1.2: has readiness_check" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'readiness_check' in d.get('export_metadata',{})\""
  check "v1.0→v1.2: has quick_wins" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'quick_wins' in d.get('quality_review',{})\""
  check "v1.0→v1.2: preserves project_name" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['project_name']=='Test Course v1.0'\""
  rm -rf "$TMPDIR_MIG"

  # Test v1.1 → v1.2 migration
  TMPDIR_MIG=$(mktemp -d)
  cp "$FIXTURE_DIR/manifest-v1.1.json" "$TMPDIR_MIG/project.json"
  "$SKILLS_DIR/idstack/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
  check "v1.1→v1.2: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.2'\""
  check "v1.1→v1.2: has red_team_audit" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'red_team_audit' in d\""
  check "v1.1→v1.2: has accessibility_review" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'accessibility_review' in d\""
  check "v1.1→v1.2: preserves review_history" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert len(d['quality_review']['review_history'])==1\""
  check "v1.1→v1.2: preserves existing data" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['import_metadata']['items_imported']['modules']==6\""
  rm -rf "$TMPDIR_MIG"
fi

# Template freshness check
check "generated SKILL.md files are up to date" "'$SKILLS_DIR/idstack/bin/idstack-gen-skills' --dry-run"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
