#!/usr/bin/env bash
# Unit tests for bin/idstack-migrate.
# Run from the repo root (or sourced by smoke-test.sh).

set -e

PASS=0
FAIL=0
TOTAL=0

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIGRATE="$REPO_ROOT/bin/idstack-migrate"
FIXTURE_DIR="$REPO_ROOT/test/fixtures"

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
  echo "test-migrate: python3 not available, skipping"
  exit 0
fi

if [ ! -x "$MIGRATE" ]; then
  echo "test-migrate: $MIGRATE missing or not executable"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "test-migrate"
echo ""

# --- Test: v1.0 → v1.4 chained migration ---
cp "$FIXTURE_DIR/manifest-v1.0.json" "$WORK/project.json"
"$MIGRATE" "$WORK/project.json" >/dev/null 2>&1
assert "v1.0→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert d['version']=='1.4'\""
assert "v1.0→v1.4: has preferences" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert 'preferences' in d\""
assert "v1.0→v1.4: preserves project_name" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert d['project_name']=='Test Course v1.0'\""

# --- Test: v1.2 → v1.4 migration ---
cp "$FIXTURE_DIR/manifest-v1.2.json" "$WORK/project.json"
"$MIGRATE" "$WORK/project.json" >/dev/null 2>&1
assert "v1.2→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert d['version']=='1.4'\""
assert "v1.2→v1.4: has preferences" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert d['preferences']['verbosity']=='normal'\""

# --- Test: idempotent ---
assert "v1.2→v1.4: idempotent" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert d['version']=='1.4'\" && '$MIGRATE' '$WORK/project.json' >/dev/null 2>&1 && python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert d['version']=='1.4'\""

# --- Test: v1.3-drifted → v1.4 cleanup migration ---
if [ -f "$FIXTURE_DIR/manifest-v1.3-drifted.json" ]; then
  cp "$FIXTURE_DIR/manifest-v1.3-drifted.json" "$WORK/project.json"
  "$MIGRATE" "$WORK/project.json" >/dev/null 2>&1
  assert "v1.3-drifted→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert d['version']=='1.4'\""
  assert "v1.3-drifted→v1.4: red_team summary renamed to findings_summary" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); rt=d['red_team_audit']; assert 'summary' not in rt; assert rt['findings_summary']=={'critical': 3, 'warning': 5, 'info': 2}\""
  assert "v1.3-drifted→v1.4: _import_quality_flags moved into import_metadata" "python3 -c \"import json; d=json.load(open('$WORK/project.json')); assert '_import_quality_flags' not in d; details=d['import_metadata']['quality_flag_details']; assert len(details)==2 and details[0]['key']=='orphan_module_8'\""
fi

# --- Test: file does not exist ---
rm -f "$WORK/project.json"
"$MIGRATE" "$WORK/project.json" >/dev/null 2>&1
EC=$?
assert "missing manifest exits 0" "[ $EC -eq 0 ]"

# --- Test: malformed json gracefully degraded (fallback to cat, exits 0) ---
echo "invalid json" > "$WORK/project.json"
# capture output to check fallback mechanism
OUT=$("$MIGRATE" "$WORK/project.json" 2>/dev/null)
EC=$?
assert "malformed manifest exits 0" "[ $EC -eq 0 ]"
assert "malformed manifest outputs original" "[ \"\$OUT\" = 'invalid json' ]"

echo ""
echo "migrate: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
