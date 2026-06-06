#!/usr/bin/env bash
# Unit tests for bin/idstack-status.
# Run from the repo root (or sourced by smoke-test.sh).

set -e

PASS=0
FAIL=0
TOTAL=0

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS="$REPO_ROOT/bin/idstack-status"

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
  echo "test-status: python3 not available, skipping"
  exit 0
fi

if [ ! -x "$STATUS" ]; then
  echo "test-status: $STATUS missing or not executable"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# idstack-status looks for files relative to current working directory
cd "$WORK"

echo "test-status"
echo ""

# --- Test 1: No state ---
assert "no timeline shows empty state message" "$STATUS | grep -q 'No course data yet'"

# --- Test 2: Project name from manifest ---
mkdir -p .idstack
cat > .idstack/project.json <<'JSON'
{
  "project_name": "Test Course 123"
}
JSON
cat > .idstack/timeline.jsonl <<'JSON'
{"skill":"needs-analysis","event":"completed","training_justified":true}
JSON
assert "project name from manifest" "$STATUS | grep -q 'Project: Test Course 123'"

# --- Test 3: Timeline parsing ---
cat > .idstack/timeline.jsonl <<'JSON'
{"skill":"needs-analysis","event":"completed","training_justified":true}
{"skill":"course-quality-review","event":"completed","score":65,"dimensions":{"teaching_presence":7,"social_presence":3,"cognitive_presence":5}}
{"skill":"course-quality-review","event":"completed","score":85,"dimensions":{"teaching_presence":8,"social_presence":7,"cognitive_presence":8}}
JSON
assert "shows skills completed checkboxes" "$STATUS | grep -q '\[x\] /needs-analysis'"
assert "shows quality trend" "$STATUS | grep -q 'Quality trend: 65 -> 85'"
assert "suggests next skill" "$STATUS | grep -q 'Suggested next: /learning-objectives'"

# --- Test 4: Learnings log ---
cat > .idstack/learnings.jsonl <<'JSON'
{"skill":"needs-analysis","type":"operational","insight":"Learned X"}
{"skill":"needs-analysis","type":"pattern","insight":"Learned Y"}
JSON
assert "shows learnings count" "$STATUS | grep -q 'Learnings: 2 discoveries stored'"

# --- Test 5: Exports directory ---
mkdir -p .idstack/exports/test-course-123
touch .idstack/exports/test-course-123/index.html
touch .idstack/exports/test-course-123/other-report.html
assert "reports section present" "$STATUS | grep -q 'Reports (open in a browser for the human view)'"
assert "index.html listed" "$STATUS | grep -q 'test-course-123/index.html'"
assert "other report listed" "$STATUS | grep -q 'test-course-123/other-report.html'"

# --- Test 6: Readiness flag - INCOMPLETE ---
# Using readiness should show incomplete when missing skills
assert "readiness incomplete due to missing reviews" "$STATUS --readiness | grep -q 'INCOMPLETE'"

# --- Test 7: Readiness flag - NOT-READY ---
# Complete the timeline for readiness
cat >> .idstack/timeline.jsonl <<'JSON'
{"skill":"red-team","event":"completed"}
{"skill":"accessibility-review","event":"completed"}
JSON

# Default manifest with poor scores
cat > .idstack/project.json <<'JSON'
{
  "project_name": "Test Course 123",
  "quality_review": {"overall_score": 60},
  "red_team_audit": {"findings_summary": {"critical": 2}},
  "accessibility_review": {"score": {"overall": 70}}
}
JSON
assert "readiness not-ready due to low scores" "$STATUS --readiness | grep -q 'NOT-READY'"

# --- Test 8: Readiness flag - READY TO EXPORT ---
cat > .idstack/project.json <<'JSON'
{
  "project_name": "Test Course 123",
  "quality_review": {"overall_score": 80},
  "red_team_audit": {"findings_summary": {"critical": 0}},
  "accessibility_review": {"score": {"overall": 90}}
}
JSON
assert "readiness ready to export" "$STATUS --readiness | grep -q 'READY TO EXPORT'"

echo ""
echo "test-status: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
