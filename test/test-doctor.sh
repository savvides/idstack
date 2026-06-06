#!/usr/bin/env bash
# Unit tests for bin/idstack-doctor

set -e

PASS=0
FAIL=0
TOTAL=0

# Keep tests isolated
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# Mock home directory
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

# Mock project root
MOCK_IDSTACK_DIR="$TEST_ROOT/idstack"
mkdir -p "$MOCK_IDSTACK_DIR/bin"
# Copy the doctor script to the mock bin directory
cp "$(cd "$(dirname "$0")/.." && pwd -P)/bin/idstack-doctor" "$MOCK_IDSTACK_DIR/bin/idstack-doctor"

# The doctor script resolves its path using `dirname $0`/..
# We'll execute it via its path in the mock directory.
DOCTOR_CMD="$MOCK_IDSTACK_DIR/bin/idstack-doctor"

SKILLS="needs-analysis learning-objectives course-quality-review course-import \
assessment-design course-builder course-export accessibility-review red-team \
pipeline learn"

# Setup happy path
setup_happy_path() {
  # Clean up previous state
  rm -rf "$MOCK_IDSTACK_DIR/.claude-plugin" "$MOCK_IDSTACK_DIR/skills" "$HOME/.claude"

  # 1. Plugin + marketplace manifests
  mkdir -p "$MOCK_IDSTACK_DIR/.claude-plugin"
  echo '{"version": "1.0.0"}' > "$MOCK_IDSTACK_DIR/.claude-plugin/plugin.json"
  touch "$MOCK_IDSTACK_DIR/.claude-plugin/marketplace.json"

  # 2. Skill files
  for skill in $SKILLS; do
    mkdir -p "$MOCK_IDSTACK_DIR/skills/$skill"
    touch "$MOCK_IDSTACK_DIR/skills/$skill/SKILL.md"
  done
}

# Setup mock claude command
MOCK_BIN="$TEST_ROOT/bin"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"

mock_claude_output() {
  cat > "$MOCK_BIN/claude" << 'EOF'
#!/bin/sh
if [ "$1 $2" = "plugin list" ]; then
EOF
  echo "  cat << 'INNER_EOF'" >> "$MOCK_BIN/claude"
  echo "$1" >> "$MOCK_BIN/claude"
  echo "INNER_EOF" >> "$MOCK_BIN/claude"
  echo "fi" >> "$MOCK_BIN/claude"
  chmod +x "$MOCK_BIN/claude"
}

remove_mock_claude() {
  rm -f "$MOCK_BIN/claude"
}

check() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"
  local cmd="$2"
  local expected_exit="${3:-0}"
  local expected_grep="${4:-}"

  local out
  local exit_code=0
  out=$(eval "$cmd" 2>&1) || exit_code=$?

  if [ "$exit_code" -eq "$expected_exit" ]; then
    if [ -n "$expected_grep" ] && ! echo "$out" | grep -q "$expected_grep"; then
      FAIL=$((FAIL + 1))
      echo "  FAIL: $desc (exit code correct, but output missing: $expected_grep)"
      echo "    Output was:"
      echo "$out" | sed 's/^/      /'
    else
      PASS=$((PASS + 1))
      echo "  PASS: $desc"
    fi
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (expected exit $expected_exit, got $exit_code)"
    echo "    Output was:"
    echo "$out" | sed 's/^/      /'
  fi
}

echo "test-doctor"
echo ""

# -----------------------------------------------------------------------------
# Test Cases
# -----------------------------------------------------------------------------

# 1. Happy path
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
check "happy path (all good)" "'$DOCTOR_CMD'" 0 "OK"

# 2. Missing plugin manifest
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_IDSTACK_DIR/.claude-plugin/plugin.json"
check "missing plugin.json" "'$DOCTOR_CMD'" 1 "PROBLEM: missing.*plugin.json"

# 3. Missing marketplace manifest
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_IDSTACK_DIR/.claude-plugin/marketplace.json"
check "missing marketplace.json" "'$DOCTOR_CMD'" 1 "PROBLEM: missing.*marketplace.json"

# 4. Missing SKILL files
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_IDSTACK_DIR/skills/needs-analysis/SKILL.md"
check "missing SKILL.md file" "'$DOCTOR_CMD'" 1 "PROBLEM:.*SKILL.md file(s) missing"

# 5. claude not found
setup_happy_path
remove_mock_claude
check "claude not found on PATH" "'$DOCTOR_CMD'" 0 "WARNING: 'claude' not found on PATH"

# 6. plugin not enabled
setup_happy_path
mock_claude_output "idstack@idstack
status: disabled"
check "plugin not enabled" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is installed but not enabled"

# 7. plugin not installed
setup_happy_path
mock_claude_output "some-other-plugin
status: enabled"
check "plugin not installed" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is not installed"

# 8. Legacy symlink conflict
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
mkdir -p "$HOME/.claude/skills"
ln -s "/tmp/dummy" "$HOME/.claude/skills/idstack"
check "legacy symlink conflict" "'$DOCTOR_CMD'" 1 "PROBLEM: legacy symlink at"

# 9. Legacy directory conflict (VERSION)
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm -rf "$HOME/.claude/skills/idstack"
mkdir -p "$HOME/.claude/skills/idstack"
echo "2.0.0" > "$HOME/.claude/skills/idstack/VERSION"
check "legacy directory conflict (VERSION)" "'$DOCTOR_CMD'" 1 "PROBLEM: pre-v2.0.1.0 install at"

# 10. Legacy individual skill symlink
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm -rf "$HOME/.claude/skills/idstack"
mkdir -p "$HOME/.claude/skills"
ln -s "/tmp/dummy-idstack/some-skill" "$HOME/.claude/skills/needs-analysis"
check "legacy individual skill symlink" "'$DOCTOR_CMD'" 1 "PROBLEM: pre-v2 skill symlink"

echo ""
echo "  $PASS/$TOTAL passed"
[ "$FAIL" = "0" ] || exit 1
