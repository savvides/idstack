#!/usr/bin/env bash
# Behavioral tests for scripts/idstack-status.
#
# --readiness (the "Readiness table" block in scripts/idstack-status) is the pre-export gate: it decides
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
STATUS="$REPO_ROOT/scripts/idstack-status"

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

# A person reads the dashboard, and course-export reads --readiness. The
# outputs of each state go to $STE_OUT, and the ASD-STE100 checker reads them
# at the end of this suite.
STE_CHECK="$REPO_ROOT/scripts/idstack-ste-check"
STE_OUT="$WORK/ste-out"
mkdir -p "$STE_OUT"
ste_capture() { # <state name>
  "$STATUS" > "$STE_OUT/dashboard-$1.txt" 2>&1
  "$STATUS" --readiness > "$STE_OUT/readiness-$1.txt" 2>&1
}

echo "idstack-status tests"
echo ""

# --- dashboard ---
check "no timeline shows the empty state" \
  "$STATUS | grep -q 'There is no course data'"
ste_capture empty

# A first skill writes the timeline only when it completes. Its report, still in
# progress, must show before that.
mkdir -p .idstack/exports/first-course
printf '%s\n' '# Draft' '' '**Status:** in progress. A section with a draft mark waits for your approval.' \
  > .idstack/exports/first-course/needs-analysis.md
check "no timeline still lists a report in progress" \
  "$STATUS | grep -qx '  .idstack/exports/first-course/needs-analysis.md (in progress)'"
rm -rf .idstack

mkdir -p .idstack
printf '%s\n' '{"project_name": "Test Course 123"}' > .idstack/project.json
printf '%s\n' '{"skill":"needs-analysis","event":"completed","training_justified":true}' > .idstack/timeline.jsonl

check "project name comes from the manifest" \
  "$STATUS | grep -q 'Project: Test Course 123'"

# #172: the dashboard once read only the last 200 timeline lines, so an early
# skill in a long project showed as not completed.
python3 -c 'print("\n".join(["{\"skill\":\"quick-check\",\"event\":\"completed\"}"] * 250))' >> .idstack/timeline.jsonl
check "a skill before the last 200 timeline lines still counts as completed" \
  "$STATUS --context | grep 'SKILLS_COMPLETED' | grep -q needs-analysis"

# idstack-migrate --init writes an empty project_name; fall back as idstack-slugify does.
printf '%s\n' '{"project_name": "", "needs_analysis": {"project_name": "Fallback Course"}}' > .idstack/project.json
check "an empty project name falls back to needs_analysis.project_name" \
  "$STATUS | grep -q 'Project: Fallback Course'"
printf '%s\n' '{"project_name": "", "needs_analysis": []}' > .idstack/project.json
check "an empty project name with no fallback shows unknown" \
  "$STATUS | grep -q 'Project: unknown'"
printf '%s\n' '{"project_name": "Test Course 123"}' > .idstack/project.json

cat > .idstack/timeline.jsonl <<'JSON'
{"skill":"needs-analysis","event":"completed","training_justified":true}
{"skill":"course-quality-review","event":"completed","score":65,"dimensions":{"teaching_presence":7,"social_presence":3,"cognitive_presence":5}}
{"skill":"course-quality-review","event":"completed","score":85,"dimensions":{"teaching_presence":8,"social_presence":7,"cognitive_presence":8}}
JSON

# Namespaced forms — v3.3.0.0 banned the bare /skill spelling because it
# does not resolve in Claude Code. A test asserting the bare form would re-admit it.
check "completed skills render as namespaced checkboxes" \
  "$STATUS | grep -q '\[x\] /idstack:needs-analysis'"

check "quality trend shows the progression" \
  "$STATUS | grep -q 'Quality trend: 65 -> 85'"

check "next step is recommended, namespaced" \
  "$STATUS | grep -q 'Recommended next: /idstack:learning-objectives'"

cat > .idstack/learnings.jsonl <<'JSON'
{"skill":"needs-analysis","type":"operational","insight":"Learned X"}
{"skill":"needs-analysis","type":"pattern","insight":"Learned Y"}
JSON
check "learnings are counted" \
  "$STATUS | grep -q 'Learnings: 2 entries'"

mkdir -p .idstack/exports/test-course-123
touch .idstack/exports/test-course-123/index.md
touch .idstack/exports/test-course-123/other-report.md
check "reports section is present" \
  "$STATUS | grep -q 'Reports'"
check "dashboard index.md is listed" \
  "$STATUS | grep -q 'test-course-123/index.md'"
check "per-skill report is listed" \
  "$STATUS | grep -q 'test-course-123/other-report.md'"
check "a finished report has no in-progress mark" \
  "$STATUS | grep -qx '  .idstack/exports/test-course-123/other-report.md'"
printf '%s\n' '# Draft' '' '**Status:** in progress. A section with a draft mark waits for your approval.' '' \
  > .idstack/exports/test-course-123/draft-report.md
check "a report with the status line is marked in progress" \
  "$STATUS | grep -qx '  .idstack/exports/test-course-123/draft-report.md (in progress)'"
ste_capture partial

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
ste_capture ready

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

# A red-team section with no critical count must not pass the gate as 0 findings.
printf '%s\n' '{"quality_review": {"overall_score": 80}, "accessibility_review": {"score": {"overall": 90}}, "red_team_audit": {"confidence_score": 20}}' > .idstack/project.json
check "a red-team section with no critical count is NOT-READY" \
  "$STATUS --readiness | grep -q 'NOT-READY (no red-team critical count)'"
check "a missing critical count marks the red-team row NEEDS-WORK, not 0" \
  "$STATUS --readiness | grep -qE 'Red Team Audit: +NEEDS-WORK +Critical: none'"
ste_capture no-red-count

# A completed review whose manifest write failed leaves a 0 or missing score.
write_manifest 0 0 0
check "a completed review with a 0 score in the manifest says it has no score" \
  "$STATUS --readiness | grep -q 'quality review has no score in the manifest, accessibility review has no score in the manifest'"
printf '%s\n' '{"red_team_audit": {"findings_summary": {"critical": 0}}}' > .idstack/project.json
check "a completed review with no score section is NEEDS-WORK" \
  "$STATUS --readiness | grep -qE 'Quality Review: +NEEDS-WORK'"

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

# --- writing standard (ASD-STE100) ---
# NOT-READY with all four reasons, so the reason list is in the text too.
write_manifest 60 2 70 '"wcag_violations": [{"level": "A", "criterion": "1.1.1"}, {"level": "A", "criterion": "2.1.1"}]'
ste_capture not-ready
printf 'not json\n' > .idstack/timeline.jsonl
ste_capture unreadable-timeline
check "the dashboard text obeys the writing standard in each state" \
  "python3 '$STE_CHECK' --format text '$STE_OUT'/dashboard-*.txt"
check "the --readiness text obeys the writing standard in each state" \
  "python3 '$STE_CHECK' --format text '$STE_OUT'/readiness-*.txt"

echo ""
echo "idstack-status: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
