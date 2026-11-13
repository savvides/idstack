#!/usr/bin/env bash
# Behavioral tests for ./setup — flag parsing, scope selection, failure
# handling and regeneration. Everything runs against a COPY of the repo with a fake $HOME and a
# stub `claude` on $PATH, so the real install and the real working tree are
# never touched.
#
# Why this exists: setup is the primary deliverable (it is what a new user
# runs first) and had no test coverage at all, while the smoke test spent 14
# assertions on landing-page CSS. The v3.3.0.0 audit found four defects in it.
#
# Usage: test/test-setup.sh [path-to-repo]
set -u

. "$(dirname "$0")/test-helper.sh"

SRC="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Build an isolated environment: repo copy + fake HOME + a stub `claude` that
# logs its arguments instead of touching the real install.
setup_env() {
  rm -rf "$WORK/env"
  mkdir -p "$WORK/env/home" "$WORK/env/bin" "$WORK/env/idstack"
  for item in scripts skills templates evidence docs extension .claude-plugin \
              VERSION setup; do
    [ -e "$SRC/$item" ] && cp -R "$SRC/$item" "$WORK/env/idstack/"
  done
  cat > "$WORK/env/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "claude $*" >> "$CLAUDE_STUB_LOG"
exit "${CLAUDE_STUB_EXIT:-0}"
EOF
  chmod +x "$WORK/env/bin/claude"
  : > "$WORK/env/claude.log"
  return 0
}

# run_setup <flags...> — runs setup with the fake HOME and stub PATH. Each
# run's output is also added to $WORK/ste-runs.txt for the writing-standard
# check at the end of this suite.
run_setup() {
  local _rc=0
  ( export HOME="$WORK/env/home" \
           PATH="$WORK/env/bin:$PATH" \
           CLAUDE_STUB_LOG="$WORK/env/claude.log" \
           CLAUDE_STUB_EXIT="${STUB_EXIT:-0}"
    cd "$WORK/env/idstack" && ./setup "$@" ) >"$WORK/env/out.log" 2>&1 || _rc=$?
  cat "$WORK/env/out.log" >> "$WORK/ste-runs.txt"
  return "$_rc"
}

echo "test-setup"
echo ""

# raw_setup <flags...> — like run_setup but returns setup's exit status and
# leaves stdout on the caller's stdout (for flag-parsing assertions).
raw_setup() {
  ( export HOME="$WORK/env/home" \
           PATH="$WORK/env/bin:$PATH" \
           CLAUDE_STUB_LOG="$WORK/env/claude.log" \
           CLAUDE_STUB_EXIT="${STUB_EXIT:-0}"
    cd "$WORK/env/idstack" && ./setup "$@" )
}

# --- flag parsing ---
setup_env
check "unknown flag exits 2" \
  "raw_setup --bogus >/dev/null 2>&1; [ \$? -eq 2 ]"

setup_env
check "--help exits 0 and documents --local" \
  "raw_setup --help 2>/dev/null | grep -q -- '--local'"

setup_env
check "--help text obeys the writing standard (ASD-STE100)" \
  "( set -o pipefail; raw_setup --help 2>&1 | python3 '$SRC/scripts/idstack-ste-check' --format text - )"

# --- scope selection ---
setup_env
run_setup
check "default install uses user scope" \
  "grep -q 'plugin install idstack@idstack --scope user' '$WORK/env/claude.log'"

setup_env
run_setup --local
check "--local installs at project scope" \
  "grep -q 'plugin install idstack@idstack --scope project' '$WORK/env/claude.log'"

# --- failure handling: a nonzero `claude` must fail loudly, not silently ---
setup_env
check "a failing 'claude' call makes setup exit nonzero" \
  "! STUB_EXIT=1 raw_setup >/dev/null 2>&1"

setup_env
STUB_EXIT=1 run_setup
check "a failing 'claude' call prints manual-recovery steps" \
  "grep -q 'marketplace add' '$WORK/env/out.log'"

# --- missing prerequisites: no banner, nonzero exit (#184) ---
# Hide the real `claude`: a PATH of only the system dirs, with python3 from the real PATH.
setup_env
_bin="$WORK/env/nobin"; mkdir -p "$_bin"
for d in /usr/bin /bin; do for f in "$d"/*; do ln -sf "$f" "$_bin/$(basename "$f")"; done; done
rm -f "$_bin/claude"; ln -sf "$(command -v python3)" "$_bin/python3"
check "no 'claude' on PATH: exit 1 and no banner" \
  "( export HOME='$WORK/env/home' PATH='$_bin'; cd '$WORK/env/idstack' && ./setup ) >'$WORK/env/out.log' 2>&1; [ \$? -eq 1 ] && grep -q 'claude' '$WORK/env/out.log' && ! grep -q 'To use a skill' '$WORK/env/out.log'"
cat "$WORK/env/out.log" >> "$WORK/ste-runs.txt"

setup_env
printf '#!/bin/sh\nexit 1\n' > "$WORK/env/bin/python3"; chmod +x "$WORK/env/bin/python3"
check "python3 too old or missing: nonzero exit and no banner" \
  "raw_setup >'$WORK/env/out.log' 2>&1; [ \$? -ne 0 ] && ! grep -q 'To use a skill' '$WORK/env/out.log'"
cat "$WORK/env/out.log" >> "$WORK/ste-runs.txt"

setup_env
check "happy path exits 0 and shows the banner" \
  "raw_setup >'$WORK/env/out.log' 2>&1 && grep -q 'To use a skill' '$WORK/env/out.log'"

# --- regeneration invariant ---
# The fixture is copied from a tree the smoke test already gates as fresh, so
# asserting freshness after a plain run proves nothing. Dirty a generated file
# first: only an actual regeneration during setup can make the dry-run pass.
setup_env
echo 'drift' >> "$WORK/env/idstack/skills/red-team/SKILL.md"
check "fixture is genuinely stale before setup runs" \
  "! '$WORK/env/idstack/scripts/idstack-gen-skills' --dry-run"
run_setup
check "setup regenerates stale generated files" \
  "'$WORK/env/idstack/scripts/idstack-gen-skills' --dry-run"

# --- writing standard (ASD-STE100) ---
# Every run_setup above: a normal install, --local, a failed 'claude' call and
# a regeneration.
check "setup output obeys the writing standard in every run of this suite" \
  "python3 '$SRC/scripts/idstack-ste-check' --format text '$WORK/ste-runs.txt'"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
