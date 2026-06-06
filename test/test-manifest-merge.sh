#!/usr/bin/env bash
# Unit tests for bin/idstack-manifest-merge.
# Run from the repo root (or sourced by smoke-test.sh).

set -e

. "$(dirname "$0")/test_helper.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$REPO_ROOT/bin/idstack-manifest-merge"

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
check "section replaced" \
  "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"red_team_audit\"]=={\"confidence_score\": 75}'"

# --- Test 2: foreign sections preserved ---
check "context preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"context\"]=={\"modality\": \"online\"}'"
check "needs_analysis preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"needs_analysis\"]=={\"existing\": \"data\"}'"

# --- Test 3: top-level fields preserved (project_name, created) ---
check "project_name preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"project_name\"]==\"test-project\"'"
check "created preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"created\"]==\"2026-01-01T00:00:00Z\"'"
check "version preserved" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"version\"]==\"1.4\"'"

# --- Test 4: updated timestamp bumped (not equal to seeded value) ---
check "updated timestamp bumped" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"updated\"]!=\"2026-01-01T00:00:00Z\"'"

# --- Test 5: stdin payload ---
seed_manifest
echo '{"score": 99}' | "$MERGE" --section quality_review --payload - --manifest "$WORK/project.json" --quiet
check "stdin payload accepted" "python3 -c 'import json; d=json.load(open(\"$WORK/project.json\")); assert d[\"quality_review\"]=={\"score\": 99}'"

# --- Test 6: unknown section rejected with exit 3 ---
seed_manifest
set +e
"$MERGE" --section bogus_section --payload "$WORK/payload.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "unknown section exits 3" "[ $EC -eq 3 ]"

# --- Test 7: malformed payload rejected with exit 1 ---
seed_manifest
echo 'not json' > "$WORK/bad.json"
set +e
"$MERGE" --section red_team_audit --payload "$WORK/bad.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "malformed payload exits 1" "[ $EC -eq 1 ]"

# --- Test 8: malformed manifest rejected with exit 2 ---
echo 'not json' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "malformed manifest exits 2" "[ $EC -eq 2 ]"

# --- Test 9: missing manifest rejected with exit 4 ---
rm -f "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "missing manifest exits 4" "[ $EC -eq 4 ]"

# --- Test 10: missing payload file rejected with exit 5 ---
seed_manifest
set +e
"$MERGE" --section red_team_audit --payload "$WORK/nonexistent.json" --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "missing payload file exits 5" "[ $EC -eq 5 ]"

# --- Test 11: manifest with non-dict root (list) rejected with exit 2 ---
echo '[]' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "manifest with list root exits 2" "[ $EC -eq 2 ]"

# --- Test 12: manifest with non-dict root (string) rejected with exit 2 ---
echo '"a string"' > "$WORK/project.json"
set +e
echo '{}' | "$MERGE" --section red_team_audit --payload - --manifest "$WORK/project.json" --quiet 2>/dev/null
EC=$?
set -e
check "manifest with string root exits 2" "[ $EC -eq 2 ]"

echo ""
echo "manifest-merge: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
