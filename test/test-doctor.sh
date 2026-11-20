#!/usr/bin/env bash
# Unit tests for scripts/idstack-doctor.
#
# doctor's whole job is to tell a user why /idstack:<skill> isn't working, so
# every branch it can print is a branch someone will act on. Before this suite
# it had no execution coverage at all — smoke-test only checked the file exists
# and parses.
#
# Two things this harness has to get right, both of which are easy to get
# wrong:
#
#   1. doctor sources scripts/lib/plugin-status.sh, so the fixture copies the
#      whole scripts/ tree. Copying just the one script gives a "No such file" on
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

# Fixture repo — whole scripts/ tree, so the sourced libs resolve.
MOCK_IDSTACK_DIR="$TEST_ROOT/idstack"
mkdir -p "$MOCK_IDSTACK_DIR/scripts"
cp -R "$REPO_DIR/scripts/." "$MOCK_IDSTACK_DIR/scripts/"
DOCTOR_CMD="$MOCK_IDSTACK_DIR/scripts/idstack-doctor"

# The writing-standard check runs scripts/idstack-ste-check from the real repo
# (the mock repo has no templates/ word list), with the python3 found here.
PYTHON="$(command -v python3)"

# Pinned PATH: the commands that doctor, its libs and this harness run, plus
# any mock that a test adds. `claude` is absent unless a test installs it.
MOCK_BIN="$TEST_ROOT/bin"
mkdir -p "$MOCK_BIN"
for _c in bash sh env command dirname echo grep head python3 readlink sed tr awk cat ls rm mkdir ln chmod mktemp printf sort wc basename find touch cp cut; do
  _p=$(command -v "$_c" 2>/dev/null) && ln -sf "$_p" "$MOCK_BIN/$_c"
done
export PATH="$MOCK_BIN"

SKILLS="needs-analysis learning-objectives course-quality-review course-import \
assessment-design course-builder course-export accessibility-review red-team \
pipeline learn start quick-check storyboard question-bank evaluation-plan"

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
check "installed but disabled gives the enable command" "'$DOCTOR_CMD'" 1 "Fix: claude plugin enable idstack@idstack"

# A project- or local-scope install is disabled when `claude plugin list` runs in
# another folder, or after a disable in its own folder (#201, #206). The fixtures are
# real output (Claude Code 2.1.323).
setup_happy_path
mock_claude_output "Installed plugins:

  ❯ idstack@idstack
    Version: 9.9.9.9
    Scope: project
    Status: ✘ disabled"
check "a project-scope install seen from a different folder names the scope" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is installed for one folder only \(scope: project\)"
check "a project-scope install gives the user-scope install command" "'$DOCTOR_CMD'" 1 "claude plugin install idstack@idstack --scope user"
check "a project-scope install gives the enable command for its own folder" "'$DOCTOR_CMD' | grep -A1 'in the folder where you installed idstack'" 0 "^    claude plugin enable idstack@idstack$"
check "a project-scope install does not send the user to the folder they are in" "'$DOCTOR_CMD' | grep -c 'from the project folder'" 1 "^0$"
"$DOCTOR_CMD" > "$TEST_ROOT/project-scope.txt" 2>&1 || true

mock_claude_output "Installed plugins:

  ❯ idstack@idstack
    Version: 9.9.9.9
    Scope: local
    Status: ✘ disabled"
check "a local-scope install names the scope" "'$DOCTOR_CMD'" 1 "installed for one folder only \(scope: local\)"
check "a local-scope install gives the enable command" "'$DOCTOR_CMD'" 1 "^    claude plugin enable idstack@idstack$"
check "a local-scope install gives the user-scope install command" "'$DOCTOR_CMD'" 1 "claude plugin install idstack@idstack --scope user"

# A disabled user-scope entry: enable fixes it in every folder, also next to a
# disabled project entry.
mock_claude_output "Installed plugins:

  ❯ idstack@idstack
    Version: 9.9.9.9
    Scope: user
    Status: ✘ disabled"
check "a disabled user-scope install gives the enable command" "'$DOCTOR_CMD'" 1 "Fix: claude plugin enable idstack@idstack"
mock_claude_output "Installed plugins:

  ❯ idstack@idstack
    Version: 9.9.9.9
    Scope: project
    Status: ✘ disabled

  ❯ idstack@idstack
    Version: 9.9.9.9
    Scope: user
    Status: ✘ disabled"
check "a project-scope and a user-scope install, both disabled, give the enable command" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is installed but not enabled"

mock_claude_output "Installed plugins:

  ❯ idstack@idstack
    Version: 9.9.9.9
    Scope: project
    Status: ✘ disabled

  ❯ idstack@idstack
    Version: 9.9.9.9
    Scope: user
    Status: ✔ enabled"
check "a project-scope and a user-scope install together are OK" "'$DOCTOR_CMD'" 0 "installed and enabled"

setup_happy_path
mock_claude_output "some-other-plugin
status: enabled"
check "not installed is a PROBLEM" "'$DOCTOR_CMD'" 1 "PROBLEM: idstack@idstack is not installed"
check "from a clone, the fix gives the path of the clone" "'$DOCTOR_CMD'" 1 "claude plugin marketplace add '/[^']*/idstack'$"

# A desktop user has no clone: the doctor runs from the Claude Code plugin
# cache. The cache is not a marketplace source, so the fix gives GitHub (#186).
CACHE_IDSTACK_DIR="$HOME/.claude/plugins/cache/idstack/idstack/9.9.9.9"
mkdir -p "$CACHE_IDSTACK_DIR"
cp -R "$MOCK_IDSTACK_DIR/." "$CACHE_IDSTACK_DIR/"
CACHE_DOCTOR="$CACHE_IDSTACK_DIR/scripts/idstack-doctor"
check "in the plugin cache, the fix gives the GitHub marketplace" "'$CACHE_DOCTOR'" 1 "claude plugin marketplace add https://github.com/savvides/idstack.git"
# #205: add does not refresh a marketplace added earlier, so install got the old version.
check "in the plugin cache, the fix updates the marketplace before the install" \
  "'$CACHE_DOCTOR' | grep -A1 'marketplace add https' | grep -q 'claude plugin marketplace update idstack'"
check "in the plugin cache, the fix does not give a local path" "'$CACHE_DOCTOR' | grep -c \"marketplace add '/\"" 1 "^0$"
check "in the plugin cache, the fix does not tell the user to run ./setup" "'$CACHE_DOCTOR' | grep -c 'run ./setup'" 1 "^0$"
"$CACHE_DOCTOR" > "$TEST_ROOT/cache-not-installed.txt" 2>&1 || true

# Two more lines tell the user to run ./setup, and a desktop user has no clone
# and no ./setup: the WARNING for a missing claude command, and the PROBLEM for a
# missing marketplace.json. In the plugin cache they tell the user to install
# idstack again. From a clone they keep ./setup (#186).
remove_mock_claude
check "from a clone, with claude absent, the WARNING tells the user to run ./setup" "'$DOCTOR_CMD'" 0 "Then run ./setup from the repo"
check "in the plugin cache, with claude absent, the WARNING does not mention ./setup" "'$CACHE_DOCTOR' | grep -cF './setup'" 1 "^0$"
check "in the plugin cache, with claude absent, the WARNING sends the user to the desktop app" "'$CACHE_DOCTOR'" 0 "install idstack again from the Claude desktop app"
check "in the plugin cache, with claude absent, the WARNING does not promise install commands" "'$CACHE_DOCTOR' | grep -c 'It prints the install commands'" 1 "^0$"
"$CACHE_DOCTOR" > "$TEST_ROOT/cache-no-claude.txt" 2>&1 || true

mock_claude_output "idstack@idstack
status: enabled"
rm "$MOCK_IDSTACK_DIR/.claude-plugin/marketplace.json" "$CACHE_IDSTACK_DIR/.claude-plugin/marketplace.json"
check "from a clone, a missing marketplace.json says that ./setup cannot install the plugin" "'$DOCTOR_CMD'" 1 "Without this file, ./setup cannot install the plugin"
check "in the plugin cache, a missing marketplace.json is a PROBLEM" "'$CACHE_DOCTOR'" 1 "PROBLEM: missing.*marketplace\.json"
check "in the plugin cache, a missing marketplace.json does not mention ./setup" "'$CACHE_DOCTOR' | grep -cF './setup'" 1 "^0$"
check "in the plugin cache, a missing marketplace.json says to install idstack again" "'$CACHE_DOCTOR'" 1 "Install idstack again"
check "in the plugin cache, a missing marketplace.json gives the README address" "'$CACHE_DOCTOR'" 1 "https://github.com/savvides/idstack#"
"$CACHE_DOCTOR" > "$TEST_ROOT/cache-no-marketplace.txt" 2>&1 || true

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
fake_cmd() { # fake_cmd <name> <shell body> [folder, default MOCK_BIN]
  local _dir="${3:-$MOCK_BIN}"
  rm -f "$_dir/$1"
  printf '#!/bin/sh\n%s\n' "$2" > "$_dir/$1"
  chmod +x "$_dir/$1"
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

# A python3 that does not run gives one PROBLEM, not a second one from the
# plugin.json check (#201). That check reads the version with grep instead.
setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
fake_cmd python3 'exit 1'
check "a python3 that does not run gives one PROBLEM" "'$DOCTOR_CMD' | grep -c 'PROBLEM'" 0 "^1$"
check "a python3 that does not run still shows the plugin.json version" "'$DOCTOR_CMD'" 1 "found plugin.json \\(version 9\\.9\\.9\\.9\\)"
restore_quick_cmds

# --- the Microsoft Store shortcut on Windows (#185) ---
# Windows has a python3 shortcut that opens the Microsoft Store. It fails when it
# runs, and it lives in a WindowsApps folder. A python3 that works in that folder
# is a real Store install of Python, so it must give OK. WIN_BIN stands in for
# ...\AppData\Local\Microsoft\WindowsApps and comes first on the PATH. WIN_BIN_BS
# is a folder whose name has backslashes, as a Windows path does.
WIN_BIN="$TEST_ROOT/c/Users/test/AppData/Local/Microsoft/WindowsApps"
WIN_BIN_BS="$TEST_ROOT/Local\\WindowsApps\\bin"
mkdir -p "$WIN_BIN" "$WIN_BIN_BS"
WIN_PATH="$WIN_BIN:$MOCK_BIN"

setup_happy_path
mock_claude_output "idstack@idstack
status: enabled"
fake_cmd uname 'echo MINGW64_NT-10.0-19045'
fake_cmd python3 'exit 1' "$WIN_BIN"
check "--quick prints PYTHON_WINSTUB for the Microsoft Store stub" "PATH='$WIN_PATH' '$DOCTOR_CMD' --quick" 1 "^PYTHON_WINSTUB$"
check "the full run reports the Microsoft Store stub" "PATH='$WIN_PATH' '$DOCTOR_CMD'" 1 "PROBLEM: .*Microsoft Store"
check "the Microsoft Store stub gives one PROBLEM" "PATH='$WIN_PATH' '$DOCTOR_CMD' | grep -c 'PROBLEM'" 0 "^1$"
check "the full run sends the user to the Microsoft Store for the stub" "PATH='$WIN_PATH' '$DOCTOR_CMD'" 1 "Fix: open the Microsoft Store app.*Python Software Foundation"
check "the full run tells the user to run the doctor again after the install" "PATH='$WIN_PATH' '$DOCTOR_CMD'" 1 "Install the newest version.*run idstack-doctor again"
# The python.org installer gives no python3 command, so the shortcut stays first on PATH and the doctor says the same again.
check "the full run does not send the Windows user to the python.org installer" "PATH='$WIN_PATH' '$DOCTOR_CMD' | grep -c -E 'python\\.org|Add python\\.exe'" 1 "^0$"
PATH="$WIN_PATH" "$DOCTOR_CMD" > "$TEST_ROOT/winstub.txt" 2>&1 || true

fake_cmd python3 'exit 1' "$WIN_BIN_BS"
check "--quick prints PYTHON_WINSTUB when the folder path has backslashes" "PATH='$WIN_BIN_BS':'$MOCK_BIN' '$DOCTOR_CMD' --quick" 1 "^PYTHON_WINSTUB$"

rm -f "$WIN_BIN/python3"
ln -sf "$PYTHON" "$WIN_BIN/python3"
check "--quick prints only OK for a python3 that works in a WindowsApps folder" "[ \"\$(PATH='$WIN_PATH' '$DOCTOR_CMD' --quick 2>&1)\" = OK ]"
check "the full run finds a python3 that works in a WindowsApps folder" "PATH='$WIN_PATH' '$DOCTOR_CMD'" 0 "found python3 3\\.(9|[1-9][0-9])"

fake_cmd python3 'exit 1'
check "--quick prints PYTHON_OLD for a python3 that fails outside WindowsApps on Windows" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_OLD$"
rm -f "$WIN_BIN/python3" "$WIN_BIN_BS/python3"
restore_quick_cmds

rm "$MOCK_BIN/python3"
check "--quick prints PYTHON_MISSING without python3" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_MISSING$"
restore_quick_cmds

check "an unknown argument exits 2" "'$DOCTOR_CMD' --bogus" 2 "ERROR: unknown argument: --bogus"
"$DOCTOR_CMD" --bogus > "$TEST_ROOT/bad-arg.txt" 2>&1 || true
check "an unknown argument shows the command" "'$DOCTOR_CMD' --bogus" 2 "^Command: idstack-doctor"
check "an unknown argument prints no diagnosis" "'$DOCTOR_CMD' --bogus 2>/dev/null | wc -c | tr -d ' '" 0 "^0$"

# --- --help (#170) ---
# --help once exited 2 as an unknown argument. It must print the usage and run no check.
check "--help prints the usage and exits 0" "'$DOCTOR_CMD' --help" 0 "idstack-doctor --quick"
check "-h exits 0" "'$DOCTOR_CMD' -h" 0
check "--help prints no diagnosis" "'$DOCTOR_CMD' --help | grep -c '^idstack doctor$'" 1 "^0$"
check "--quick --help prints the usage, not a code" "'$DOCTOR_CMD' --quick --help | grep -cxE 'OK|PYTHON_[A-Z]+'" 1 "^0$"
check "--help before an unknown argument prints the usage" "'$DOCTOR_CMD' --help --bogus" 0 "idstack-doctor --quick"
check "--help after an unknown argument prints the usage" "'$DOCTOR_CMD' --bogus --help" 0 "idstack-doctor --quick"
rm "$MOCK_BIN/python3"
check "--help works without python3" "'$DOCTOR_CMD' --help" 0 "idstack-doctor --quick"
restore_quick_cmds
"$DOCTOR_CMD" --help > "$TEST_ROOT/help.txt" 2>&1 || true

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
cp "$TEST_ROOT/project-scope.txt" "$STE_OUT/project-scope.txt"
cp "$TEST_ROOT/no-python.txt" "$STE_OUT/no-python.txt"
cp "$TEST_ROOT/winstub.txt" "$STE_OUT/winstub.txt"
cp "$TEST_ROOT/bad-arg.txt" "$STE_OUT/bad-arg.txt"
cp "$TEST_ROOT/help.txt" "$STE_OUT/help.txt"
cp "$TEST_ROOT/cache-not-installed.txt" "$STE_OUT/cache-not-installed.txt"
cp "$TEST_ROOT/cache-no-claude.txt" "$STE_OUT/cache-no-claude.txt"
cp "$TEST_ROOT/cache-no-marketplace.txt" "$STE_OUT/cache-no-marketplace.txt"

check "doctor output obeys the writing standard (healthy and problem runs)" \
  "'$PYTHON' '$REPO_DIR/scripts/idstack-ste-check' --format text '$STE_OUT'/*.txt"

echo ""
echo "  $PASS/$TOTAL passed"
[ "$FAIL" = "0" ] || exit 1
