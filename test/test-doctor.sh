#!/usr/bin/env bash
# Unit tests for bin/idstack-doctor.
#
# doctor's whole job is to tell a user why /idstack:<skill> isn't working, so
# every branch it can print is a branch someone will act on. Before this suite
# it had no execution coverage at all — smoke-test only checked the file exists
# and parses.
#
# Two things this harness has to get right, both of which are easy to get
# wrong:
#
#   1. doctor sources bin/lib/version-classify.sh and bin/lib/plugin-status.sh
#      (see bin/idstack-doctor:21-23), so the fixture copies the whole bin/
#      tree. Copying just the one script gives a "No such file" on the source
#      line and every assertion below fails for the wrong reason.
#
#   2. PATH is replaced, not prepended. The "claude not found" case is only
#      meaningful if `claude` is genuinely unreachable — with the real PATH
#      still appended, that test passes on CI (no claude) and fails on any
#      developer machine that has Claude Code installed.

set -e

. "$(dirname "$0")/test-helper.sh"

REPO_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

# Fixture repo — whole bin/ tree, so the sourced libs resolve.
MOCK_IDSTACK_DIR="$TEST_ROOT/idstack"
mkdir -p "$MOCK_IDSTACK_DIR/bin"
cp -R "$REPO_DIR/bin/." "$MOCK_IDSTACK_DIR/bin/"
DOCTOR_CMD="$MOCK_IDSTACK_DIR/bin/idstack-doctor"

# Pinned PATH: only what doctor and its libs actually invoke, plus whatever
# mock we drop in. `claude` is absent unless a test installs it.
MOCK_BIN="$TEST_ROOT/bin"
mkdir -p "$MOCK_BIN"
for _c in bash sh env command dirname echo grep head python3 readlink sed tr awk cat ls rm mkdir ln chmod mktemp printf sort wc basename find touch cp cut; do
  _p=$(command -v "$_c" 2>/dev/null) && ln -sf "$_p" "$MOCK_BIN/$_c"
done
export PATH="$MOCK_BIN"

SKILLS="needs-analysis learning-objectives course-quality-review course-import \
assessment-design course-builder course-export accessibility-review red-team \
pipeline learn"

setup_happy_path() {
  rm -rf "$MOCK_IDSTACK_DIR/.claude-plugin" "$MOCK_IDSTACK_DIR/skills" "$HOME/.claude"
  mkdir -p "$MOCK_IDSTACK_DIR/.claude-plugin"
  # Version must parse as JSON — doctor reads it with python3, not a regex.
  echo '{"name": "idstack", "version": "9.9.9.9"}' > "$MOCK_IDSTACK_DIR/.claude-plugin/plugin.json"
  echo '{"name": "idstack"}' > "$MOCK_IDSTACK_DIR/.claude-plugin/marketplace.json"
  for skill in $SKILLS; do
    mkdir -p "$MOCK_IDSTACK_DIR/skills/$skill"
    touch "$MOCK_IDSTACK_DIR/skills/$skill/SKILL.md"
  done
}

# Stub `claude` whose `plugin list` prints $1 verbatim.
mock_claude_output() {
  {
    echo '#!/bin/sh'
    echo 'if [ "$1 $2" = "plugin list" ]; then'
    echo "cat << 'INNER_EOF'"
    echo "$1"
    echo 'INNER_EOF'
    echo 'fi'
  } > "$MOCK_BIN/claude"
  chmod +x "$MOCK_BIN/claude"
}

remove_mock_claude() { rm -f "$MOCK_BIN/claude"; }

echo "idstack doctor tests"
echo ""

# --- healthy install ---
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
check "healthy install reports OK and exits 0" "'$DOCTOR_CMD'" 0 "OK"

# --- manifest problems ---
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_IDSTACK_DIR/.claude-plugin/plugin.json"
check "missing plugin.json is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: missing.*plugin\.json"

setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_IDSTACK_DIR/.claude-plugin/marketplace.json"
check "missing marketplace.json is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: missing.*marketplace\.json"

# plugin.json is parsed as JSON, not grepped — malformed must be caught.
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
echo 'not json at all' > "$MOCK_IDSTACK_DIR/.claude-plugin/plugin.json"
check "unparseable plugin.json is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: could not parse version"

setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_IDSTACK_DIR/skills/needs-analysis/SKILL.md"
check "missing SKILL.md is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: 1 SKILL\.md file"

# --- claude install state ---
setup_happy_path
remove_mock_claude
check "absent claude is a WARNING, not a failure" "'$DOCTOR_CMD'" 0 "WARNING: 'claude' not found on PATH"

setup_happy_path
mock_claude_output "idstack@idstack
status: disabled"
check "installed but disabled is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is installed but not enabled"

setup_happy_path
mock_claude_output "some-other-plugin
status: enabled"
check "not installed is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is not installed"

# The v3.3.0.0 regression: a neighbouring plugin's "enabled" line was read as
# idstack's, so a disabled idstack was diagnosed healthy. Pinned here too, at
# the doctor level rather than only in test-plugin-status.sh.
setup_happy_path
mock_claude_output "idstack@idstack
status: disabled
other-plugin@other
status: enabled"
check "neighbour's enabled line is not attributed to idstack" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is installed but not enabled"

# --- legacy install conflicts ---
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
mkdir -p "$HOME/.claude/skills"
ln -s "$TEST_ROOT/dummy" "$HOME/.claude/skills/idstack"
check "legacy dispatcher symlink is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: legacy symlink at"

setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
mkdir -p "$HOME/.claude/skills/idstack"
echo "2.0.0" > "$HOME/.claude/skills/idstack/VERSION"
check "pre-v2.0.1.0 install dir is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: pre-v2\.0\.1\.0 install at"

setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
mkdir -p "$HOME/.claude/skills"
ln -s "$TEST_ROOT/dummy-idstack/some-skill" "$HOME/.claude/skills/needs-analysis"
check "pre-v2 per-skill symlink is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: pre-v2 skill symlink"

# An unrelated directory must not be claimed as a broken idstack install.
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
mkdir -p "$HOME/.claude/skills/idstack"
echo "someone else's thing" > "$HOME/.claude/skills/idstack/README.md"
check "unrecognized dir warns rather than claiming ownership" "'$DOCTOR_CMD'" 0 "WARNING: directory at"

echo ""
echo "  $PASS/$TOTAL passed"
[ "$FAIL" = "0" ] || exit 1
