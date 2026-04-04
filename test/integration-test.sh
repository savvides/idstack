#!/usr/bin/env bash
# idstack integration tests — behavioral tests for bin scripts
set -e

PASS=0
FAIL=0
TOTAL=0

IDSTACK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

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

echo "idstack integration tests"
echo "  test dir: $TEST_DIR"
echo ""

cd "$TEST_DIR"

# --- idstack-timeline-log ---
echo "## idstack-timeline-log"

check "creates .idstack/ and timeline.jsonl" \
  "$IDSTACK_DIR/bin/idstack-timeline-log '{\"skill\":\"test\",\"event\":\"completed\",\"score\":72}' && [ -f .idstack/timeline.jsonl ]"

check "appends valid JSON with ts field" \
  "python3 -c \"import json; d=json.loads(open('.idstack/timeline.jsonl').readline()); assert 'ts' in d and d['skill']=='test'\""

check "handles empty arg without error" \
  "$IDSTACK_DIR/bin/idstack-timeline-log ''"

check "handles no arg without error" \
  "$IDSTACK_DIR/bin/idstack-timeline-log"

check "multiple appends create multiple lines" \
  "$IDSTACK_DIR/bin/idstack-timeline-log '{\"skill\":\"second\",\"event\":\"completed\"}' && [ \$(wc -l < .idstack/timeline.jsonl | tr -d ' ') -eq 2 ]"

echo ""

# --- idstack-learnings-log ---
echo "## idstack-learnings-log"

check "creates learnings.jsonl" \
  "$IDSTACK_DIR/bin/idstack-learnings-log '{\"skill\":\"import\",\"type\":\"operational\",\"key\":\"test\",\"insight\":\"test insight\",\"confidence\":8}' && [ -f .idstack/learnings.jsonl ]"

check "appends valid JSON with ts field" \
  "python3 -c \"import json; d=json.loads(open('.idstack/learnings.jsonl').readline()); assert 'ts' in d and d['type']=='operational'\""

check "handles empty arg without error" \
  "$IDSTACK_DIR/bin/idstack-learnings-log ''"

echo ""

# --- idstack-learnings-search ---
echo "## idstack-learnings-search"

# Add a second learning of different type
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"review","type":"pattern","key":"test2","insight":"pattern insight","confidence":7}'

check "returns results with --limit" \
  "[ \$($IDSTACK_DIR/bin/idstack-learnings-search --limit 1 | wc -l | tr -d ' ') -eq 1 ]"

check "returns all when limit exceeds count" \
  "[ \$($IDSTACK_DIR/bin/idstack-learnings-search --limit 99 | wc -l | tr -d ' ') -eq 2 ]"

check "filters by --type" \
  "$IDSTACK_DIR/bin/idstack-learnings-search --limit 10 --type operational | python3 -c \"import json,sys; d=json.loads(sys.stdin.readline()); assert d['type']=='operational'\""

check "no file returns empty" \
  "rm -f .idstack/learnings.jsonl && [ -z \"\$($IDSTACK_DIR/bin/idstack-learnings-search --limit 3)\" ]"

echo ""

# --- idstack-status ---
echo "## idstack-status"

check "no timeline shows empty state message" \
  "rm -f .idstack/timeline.jsonl && $IDSTACK_DIR/bin/idstack-status | grep -q 'No course data yet'"

# Rebuild timeline for status tests
$IDSTACK_DIR/bin/idstack-timeline-log '{"skill":"needs-analysis","event":"completed","training_justified":true}'
$IDSTACK_DIR/bin/idstack-timeline-log '{"skill":"course-quality-review","event":"completed","score":65,"dimensions":{"teaching_presence":7,"social_presence":3,"cognitive_presence":5}}'

check "shows skills completed checkboxes" \
  "$IDSTACK_DIR/bin/idstack-status | grep -q '\[x\] /needs-analysis'"

check "shows quality trend" \
  "$IDSTACK_DIR/bin/idstack-status | grep -q 'Quality trend: 65'"

check "suggests next skill" \
  "$IDSTACK_DIR/bin/idstack-status | grep -q 'Suggested next'"

echo ""

# --- idstack-gen-skills ---
echo "## idstack-gen-skills"

check "dry-run passes when fresh" \
  "$IDSTACK_DIR/bin/idstack-gen-skills --dry-run"

check "dry-run detects stale SKILL.md" \
  "echo 'stale content' >> $IDSTACK_DIR/needs-analysis/SKILL.md && ! $IDSTACK_DIR/bin/idstack-gen-skills --dry-run"

check "regenerate fixes staleness" \
  "$IDSTACK_DIR/bin/idstack-gen-skills && $IDSTACK_DIR/bin/idstack-gen-skills --dry-run"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
