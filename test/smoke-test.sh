#!/usr/bin/env bash
# idstack smoke test — verifies installation is correct
set -e

PASS=0
FAIL=0
TOTAL=0

SKILLS_DIR="${1:-$HOME/.claude/skills}"
IDSTACK_DIR="$SKILLS_DIR/idstack"

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
echo "  idstack dir: $IDSTACK_DIR"
echo ""

# Check single symlink exists
check "idstack symlink exists" "[ -L '$SKILLS_DIR/idstack' ]"
check "idstack symlink is directory" "[ -d '$SKILLS_DIR/idstack' ]"

# Check dispatcher SKILL.md at root
check "dispatcher SKILL.md exists" "[ -f '$IDSTACK_DIR/SKILL.md' ]"
check "dispatcher has name: idstack" "grep -q '^name: idstack$' '$IDSTACK_DIR/SKILL.md'"

# Check all sub-skill SKILL.md files are reachable
SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team pipeline learn"
for skill in $SKILLS; do
  check "$skill/SKILL.md reachable" "[ -f '$IDSTACK_DIR/$skill/SKILL.md' ]"
done

# Check YAML frontmatter has required fields with idstack- prefix
for skill in $SKILLS; do
  check "$skill has name: idstack-$skill" "grep -q '^name: idstack-$skill' '$IDSTACK_DIR/$skill/SKILL.md'"
  check "$skill has description: field" "grep -q '^description:' '$IDSTACK_DIR/$skill/SKILL.md'"
  check "$skill has allowed-tools: field" "grep -q '^allowed-tools:' '$IDSTACK_DIR/$skill/SKILL.md'"
done

# Check evidence file exists
check "evidence/references.md exists" "[ -f '$IDSTACK_DIR/evidence/references.md' ]"

# Check bin scripts exist and are executable
for script in idstack-migrate idstack-timeline-log idstack-learnings-log idstack-learnings-search idstack-learnings-delete idstack-learnings-promote idstack-status idstack-gen-skills; do
  check "bin/$script exists" "[ -f '$IDSTACK_DIR/bin/$script' ]"
  check "bin/$script is executable" "[ -x '$IDSTACK_DIR/bin/$script' ]"
done

# Check template system
check "templates/preamble.md exists" "[ -f '$IDSTACK_DIR/templates/preamble.md' ]"
TMPL_SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team pipeline learn"
for skill in $TMPL_SKILLS; do
  check "$skill has SKILL.md.tmpl" "[ -f '$IDSTACK_DIR/$skill/SKILL.md.tmpl' ]"
done

# Check generated files have auto-generated header (only for preamble-based skills)
PREAMBLE_SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team pipeline learn"
for skill in $PREAMBLE_SKILLS; do
  check "$skill SKILL.md has auto-generated header" "grep -q 'AUTO-GENERATED from SKILL.md.tmpl' '$IDSTACK_DIR/$skill/SKILL.md'"
done

# Check all preamble-based skills have context recovery
for skill in $PREAMBLE_SKILLS; do
  check "$skill has context recovery" "grep -q 'Context Recovery' '$IDSTACK_DIR/$skill/SKILL.md'"
done

# Check pipeline-originated skills have timeline logging
TIMELINE_SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team"
for skill in $TIMELINE_SKILLS; do
  check "$skill has timeline logging" "grep -q 'idstack-timeline-log' '$IDSTACK_DIR/$skill/SKILL.md'"
done

# Check preamble uses IDSTACK_HOME
check "preamble uses IDSTACK_HOME" "grep -q 'IDSTACK_HOME' '$IDSTACK_DIR/templates/preamble.md'"

# Migration tests (v1.0 → v1.3, v1.1 → v1.3, v1.2 → v1.3)
FIXTURE_DIR="$IDSTACK_DIR/test/fixtures"
if [ -d "$FIXTURE_DIR" ] && command -v python3 &>/dev/null; then
  # Test v1.0 → v1.3 chained migration
  TMPDIR_MIG=$(mktemp -d)
  cp "$FIXTURE_DIR/manifest-v1.0.json" "$TMPDIR_MIG/project.json"
  "$IDSTACK_DIR/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
  check "v1.0→v1.3: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.3'\""
  check "v1.0→v1.3: has red_team_audit" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'red_team_audit' in d\""
  check "v1.0→v1.3: has accessibility_review" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'accessibility_review' in d\""
  check "v1.0→v1.3: has readiness_check" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'readiness_check' in d.get('export_metadata',{})\""
  check "v1.0→v1.3: has quick_wins" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'quick_wins' in d.get('quality_review',{})\""
  check "v1.0→v1.3: has preferences" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'preferences' in d\""
  check "v1.0→v1.3: preserves project_name" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['project_name']=='Test Course v1.0'\""
  rm -rf "$TMPDIR_MIG"

  # Test v1.1 → v1.3 chained migration
  TMPDIR_MIG=$(mktemp -d)
  cp "$FIXTURE_DIR/manifest-v1.1.json" "$TMPDIR_MIG/project.json"
  "$IDSTACK_DIR/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
  check "v1.1→v1.3: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.3'\""
  check "v1.1→v1.3: has red_team_audit" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'red_team_audit' in d\""
  check "v1.1→v1.3: has accessibility_review" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'accessibility_review' in d\""
  check "v1.1→v1.3: has preferences" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['preferences']['verbosity']=='normal'\""
  check "v1.1→v1.3: preserves review_history" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert len(d['quality_review']['review_history'])==1\""
  check "v1.1→v1.3: preserves existing data" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['import_metadata']['items_imported']['modules']==6\""
  rm -rf "$TMPDIR_MIG"

  # Test v1.2 → v1.3 migration
  TMPDIR_MIG=$(mktemp -d)
  cp "$FIXTURE_DIR/manifest-v1.2.json" "$TMPDIR_MIG/project.json"
  "$IDSTACK_DIR/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
  check "v1.2→v1.3: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.3'\""
  check "v1.2→v1.3: has preferences" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['preferences']['verbosity']=='normal'\""
  check "v1.2→v1.3: has auto_advance" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['preferences']['auto_advance_pipeline']==False\""
  check "v1.2→v1.3: preserves project_name" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['project_name']=='Test Course v1.2'\""
  check "v1.2→v1.3: preserves quality_score" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['quality_review']['overall_score']==72\""
  check "v1.2→v1.3: idempotent" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.3'\" && '$IDSTACK_DIR/bin/idstack-migrate' '$TMPDIR_MIG/project.json' >/dev/null 2>&1 && python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.3'\""
  rm -rf "$TMPDIR_MIG"
fi

# Template freshness check
check "generated SKILL.md files are up to date" "'$IDSTACK_DIR/bin/idstack-gen-skills' --dry-run"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
