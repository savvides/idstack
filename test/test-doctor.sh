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
#   1. doctor sources bin/lib/plugin-status.sh, so the fixture copies the
#      whole bin/ tree. Copying just the one script gives a "No such file" on
#      the source line and every assertion below fails for the wrong reason.
#
#   2. PATH is replaced, not prepended. The "claude not found" case is only
#      meaningful if `claude` is genuinely unreachable — with the real PATH
#      still appended, that test passes on CI (no claude) and fails on any
#      developer machine that has Claude Code installed.

set -e

. "$(dirname "$0")/test-helper.sh"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

# Fixture repo — whole bin/ tree, so the sourced libs resolve.
MOCK_IDSTACK_DIR="$TEST_ROOT/idstack"
mkdir -p "$MOCK_IDSTACK_DIR/bin"
cp -R "$REPO_DIR/bin/." "$MOCK_IDSTACK_DIR/bin/"
DOCTOR_CMD="$MOCK_IDSTACK_DIR/bin/idstack-doctor"

# The writing-standard check runs bin/idstack-ste-check from the real repo
# (the mock repo has no templates/ word list), with the python3 found here.
PYTHON="$(command -v python3)"

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
pipeline learn start"

setup_happy_path() {
  rm -rf "$MOCK_IDSTACK_DIR/.claude-plugin" "$MOCK_IDSTACK_DIR/skills" "$HOME/.claude"
  mkdir -p "$MOCK_IDSTACK_DIR/.claude-plugin"
  # Version must parse as JSON — with python3, doctor reads it with json.load (grep is the no-python3 fallback).
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

# With python3, doctor parses plugin.json as JSON (grep is the no-python3 fallback) — malformed must be caught.
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

# --- python3 ---
# Every skill saves its results through python3, so its absence is a PROBLEM.
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_BIN/python3"
check "missing python3 is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack needs python3 3.9"
"$DOCTOR_CMD" > "$TEST_ROOT/no-python.txt" 2>&1 || true
ln -sf "$PYTHON" "$MOCK_BIN/python3"

setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
check "python3 3.9 or later is found" "'$DOCTOR_CMD'" 0 "found python3 3\\.(9|[1-9][0-9])"

# --- --quick: one machine-readable code for /idstack:start ---
# The order is the point. A working python3 wins over a failing xcode-select,
# because a python.org install leaves the Command Line Tools absent. A stub
# check that ran first would block that user every time.
# The OK checks compare the whole output: the full report also ends with an
# OK line, so a regex would pass even if --quick were ignored.
# Fakes REPLACE the file in MOCK_BIN. Remove it first: MOCK_BIN/python3 is a
# symlink to the real interpreter, and a redirect would write through it.
fake_cmd() { # fake_cmd <name> <shell body>
  rm -f "$MOCK_BIN/$1"
  printf '#!/bin/sh\n%s\n' "$2" > "$MOCK_BIN/$1"
  chmod +x "$MOCK_BIN/$1"
}
restore_quick_cmds() {
  rm -f "$MOCK_BIN/uname" "$MOCK_BIN/xcode-select" "$MOCK_BIN/python3"
  ln -sf "$PYTHON" "$MOCK_BIN/python3"
}

setup_happy_path
check "--quick prints only OK when python3 is 3.9 or later" "[ \"\$('$DOCTOR_CMD' --quick 2>&1)\" = OK ]"

fake_cmd uname 'echo Darwin'
fake_cmd xcode-select 'exit 2'
check "--quick prints only OK on a Mac with python.org python3 and no developer tools" "[ \"\$('$DOCTOR_CMD' --quick 2>&1)\" = OK ]"

fake_cmd python3 'exit 1'
check "--quick prints PYTHON_STUB for the macOS python3 stub" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_STUB$"

fake_cmd uname 'echo Linux'
check "--quick prints PYTHON_OLD for an old python3 that is not the macOS stub" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_OLD$"
restore_quick_cmds

rm "$MOCK_BIN/python3"
check "--quick prints PYTHON_MISSING without python3" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_MISSING$"
restore_quick_cmds

check "an unknown argument exits 2" "'$DOCTOR_CMD' --bogus" 2 "ERROR: unknown argument: --bogus"
"$DOCTOR_CMD" --bogus > "$TEST_ROOT/bad-arg.txt" 2>&1 || true

# --- writing standard (ASD-STE100) ---
# A person reads every line that doctor prints. Send a healthy run and the
# problem runs, which print all of the explanation lines, through the checker.
STE_OUT="$TEST_ROOT/ste-out"
mkdir -p "$STE_OUT"
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
"$DOCTOR_CMD" > "$STE_OUT/healthy.txt" 2>&1 || true

setup_happy_path
mock_claude_output "idstack@idstack
status: disabled"
rm "$MOCK_IDSTACK_DIR/.claude-plugin/plugin.json" "$MOCK_IDSTACK_DIR/.claude-plugin/marketplace.json"
rm "$MOCK_IDSTACK_DIR/skills/learn/SKILL.md"
"$DOCTOR_CMD" > "$STE_OUT/manifests.txt" 2>&1 || true

setup_happy_path
mock_claude_output "some-other-plugin
status: enabled"
echo 'not json at all' > "$MOCK_IDSTACK_DIR/.claude-plugin/plugin.json"
"$DOCTOR_CMD" > "$STE_OUT/not-installed.txt" 2>&1 || true

setup_happy_path
remove_mock_claude
"$DOCTOR_CMD" > "$STE_OUT/no-claude.txt" 2>&1 || true
cp "$TEST_ROOT/no-python.txt" "$STE_OUT/no-python.txt"
cp "$TEST_ROOT/bad-arg.txt" "$STE_OUT/bad-arg.txt"

check "doctor output obeys the writing standard (healthy and problem runs)" \
  "'$PYTHON' '$REPO_DIR/bin/idstack-ste-check' --format text '$STE_OUT'/*.txt"

echo ""
echo "  $PASS/$TOTAL passed"
[ "$FAIL" = "0" ] || exit 1
