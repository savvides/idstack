#!/usr/bin/env bash
# Behavioral tests for bin/idstack-status.
#
# --readiness (bin/idstack-status:193-294) is the pre-export gate: it decides
# whether a course is fit to ship. It had no coverage at all.
#
# Verdict-state tests alone are not enough here. A fixture that sits below
# every threshold at once still passes when a single threshold constant is
# wrong, because some other unmet condition keeps the verdict NOT-READY. So
# each threshold is probed at its own boundary with the other two held
# passing, and the WCAG Level-A override — which forces NOT-READY regardless
# of the overall accessibility score — is exercised separately.

set -e

. "$(dirname "$0")/test-helper.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
STATUS="$REPO_ROOT/bin/idstack-status"

if ! command -v python3 >/dev/null 2>&1; then
  echo "test-status: python3 not available, skipping"
  exit 0
fi
if [ ! -x "$STATUS" ]; then
  echo "test-status: $STATUS missing or not executable" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "idstack-status tests"
echo ""

# --- dashboard ---
check "no timeline shows the empty state" \
  "$STATUS | grep -q 'No course data yet'"

mkdir -p .idstack
printf '%s\n' '{"project_name": "Test Course 123"}' > .idstack/project.json
printf '%s\n' '{"skill":"needs-analysis","event":"completed","training_justified":true}' > .idstack/timeline.jsonl

check "project name comes from the manifest" \
  "$STATUS | grep -q 'Project: Test Course 123'"

cat > .idstack/timeline.jsonl <<'JSON'
{"skill":"needs-analysis","event":"completed","training_justified":true}
{"skill":"course-quality-review","event":"completed","score":65,"dimensions":{"teaching_presence":7,"social_presence":3,"cognitive_presence":5}}
{"skill":"course-quality-review","event":"completed","score":85,"dimensions":{"teaching_presence":8,"social_presence":7,"cognitive_presence":8}}
JSON

# Namespaced forms — v3.3.0.0 banned the bare /skill spelling because it
# resolves in neither CLI. A test asserting the bare form would re-admit it.
check "completed skills render as namespaced checkboxes" \
  "$STATUS | grep -q '\[x\] /idstack:needs-analysis'"

check "quality trend shows the progression" \
  "$STATUS | grep -q 'Quality trend: 65 -> 85'"

check "next step is suggested, namespaced" \
  "$STATUS | grep -q 'Suggested next: /idstack:learning-objectives'"

cat > .idstack/learnings.jsonl <<'JSON'
{"skill":"needs-analysis","type":"operational","insight":"Learned X"}
{"skill":"needs-analysis","type":"pattern","insight":"Learned Y"}
JSON
check "learnings are counted" \
  "$STATUS | grep -q 'Learnings: 2 discoveries stored'"

mkdir -p .idstack/exports/test-course-123
touch .idstack/exports/test-course-123/index.html
touch .idstack/exports/test-course-123/other-report.html
check "reports section is present" \
  "$STATUS | grep -q 'Reports'"
check "dashboard index.html is listed" \
  "$STATUS | grep -q 'test-course-123/index.html'"
check "per-skill report is listed" \
  "$STATUS | grep -q 'test-course-123/other-report.html'"

echo ""

# --- readiness gate ---
# Helper: write a manifest with explicit scores. $4 is optional extra JSON for
# the accessibility section (used for the WCAG override case).
write_manifest() {
  cat > .idstack/project.json <<JSON
{
  "project_name": "Test Course 123",
  "quality_review": {"overall_score": $1},
  "red_team_audit": {"findings_summary": {"critical": $2}},
  "accessibility_review": {"score": {"overall": $3}${4:+, $4}}
}
JSON
}

# Only needs-analysis and course-quality-review have run so far.
check "missing reviews give INCOMPLETE, not a score verdict" \
  "$STATUS --readiness | grep -q 'INCOMPLETE'"

check "INCOMPLETE names the skills still to run" \
  "$STATUS --readiness | grep -q '/idstack:red-team'"

cat >> .idstack/timeline.jsonl <<'JSON'
{"skill":"red-team","event":"completed"}
{"skill":"accessibility-review","event":"completed"}
JSON

# All three reviews have now run, so verdicts turn on the scores alone.
write_manifest 80 0 90
check "all thresholds met gives READY TO EXPORT" \
  "$STATUS --readiness | grep -q 'READY TO EXPORT'"

# --- threshold boundaries, one at a time ---
# Each case holds the other two dimensions passing, so the verdict can only
# flip because of the constant under test.

write_manifest 70 0 90
check "quality exactly at the threshold (70) is READY" \
  "$STATUS --readiness | grep -q 'READY TO EXPORT'"

write_manifest 69 0 90
check "quality one below the threshold (69) is NOT-READY" \
  "$STATUS --readiness | grep -q 'NOT-READY'"
check "quality failure is itemized with both numbers" \
  "$STATUS --readiness | grep -q 'quality score 69 < 70'"

write_manifest 80 0 80
check "accessibility exactly at the threshold (80) is READY" \
  "$STATUS --readiness | grep -q 'READY TO EXPORT'"

write_manifest 80 0 79
check "accessibility one below the threshold (79) is NOT-READY" \
  "$STATUS --readiness | grep -q 'accessibility score 79 < 80'"

write_manifest 80 1 90
check "a single critical red-team finding is NOT-READY" \
  "$STATUS --readiness | grep -q '1 critical red-team finding'"

# --- WCAG Level-A override ---
# A Level-A violation forces NOT-READY even when the overall score passes;
# nothing exercised this path, so the score check could have swallowed it.
#
# The override is implemented TWICE — once in access_tier() for the per-skill
# row and once in verdict() for the overall line. Removing either one alone
# leaves the other still reporting, so both are asserted; a single assertion
# here would let half the override rot silently.
write_manifest 80 0 95 '"wcag_violations": [{"level": "A", "criterion": "1.1.1"}]'
check "a Level-A violation overrides a passing accessibility score" \
  "$STATUS --readiness | grep -q '1 WCAG Level-A violation'"
check "Level-A violation forces NOT-READY overall" \
  "$STATUS --readiness | grep -q 'NOT-READY'"
check "Level-A violation also marks the accessibility row NEEDS-WORK" \
  "$STATUS --readiness | grep -qE 'Accessibility Review: +NEEDS-WORK'"

# Level-AA is not the override; it must not block export on its own.
write_manifest 80 0 95 '"wcag_violations": [{"level": "AA", "criterion": "1.4.3"}]'
check "a Level-AA violation alone does not block export" \
  "$STATUS --readiness | grep -q 'READY TO EXPORT'"

echo ""
echo "idstack-status: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
