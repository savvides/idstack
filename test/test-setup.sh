#!/usr/bin/env bash
# Behavioral tests for ./setup — flag parsing, scope selection, and legacy
# cleanup. Everything runs against a COPY of the repo with a fake $HOME and a
# stub `claude` on $PATH, so the real install and the real working tree are
# never touched.
#
# Why this exists: setup is the primary deliverable (it is what a new user
# runs first) and had no test coverage at all, while the smoke test spent 14
# assertions on landing-page CSS. The v3.3.0.0 audit found four defects in it,
# including --keep-legacy being honored in only one of three deletion paths.
#
# Usage: test/test-setup.sh [path-to-repo]
set -u

PASS=0
FAIL=0
TOTAL=0

SRC="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

check() {
  TOTAL=$((TOTAL + 1))
  local name="$1" cmd="$2" _out
  if _out=$(eval "$cmd" 2>&1); then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    [ -n "$_out" ] && printf '%s\n' "$_out" | head -5 | sed 's/^/        | /'
    FAIL=$((FAIL + 1))
  fi
}

# Build an isolated environment: repo copy + fake HOME + stub claude/codex that
# log their arguments instead of touching the real install.
setup_env() {
  rm -rf "$WORK/env"
  mkdir -p "$WORK/env/home" "$WORK/env/bin" "$WORK/env/idstack"
  for item in bin skills templates evidence docs .claude-plugin \
              VERSION setup dist AGENTS.md; do
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

# run_setup <flags...> — runs setup with the fake HOME and stub PATH.
run_setup() {
  ( export HOME="$WORK/env/home" \
           PATH="$WORK/env/bin:$PATH" \
           CLAUDE_STUB_LOG="$WORK/env/claude.log" \
           CLAUDE_STUB_EXIT="${STUB_EXIT:-0}"
    cd "$WORK/env/idstack" && ./setup --no-codex "$@" ) >"$WORK/env/out.log" 2>&1
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
check "--help exits 0 and documents --keep-legacy" \
  "raw_setup --help 2>/dev/null | grep -q -- '--keep-legacy'"

# --- scope selection ---
setup_env
run_setup
check "default install uses user scope" \
  "grep -q 'plugin install idstack@idstack --scope user' '$WORK/env/claude.log'"

setup_env
run_setup --local
check "--local installs at project scope" \
  "grep -q 'plugin install idstack@idstack --scope project' '$WORK/env/claude.log'"

# --- legacy cleanup: v2.0 dispatcher symlink ---
setup_env
mkdir -p "$WORK/env/home/.claude/skills"
ln -s "$WORK/env/idstack" "$WORK/env/home/.claude/skills/idstack"
run_setup
check "legacy dispatcher symlink is removed by default" \
  "[ ! -e '$WORK/env/home/.claude/skills/idstack' ]"

setup_env
mkdir -p "$WORK/env/home/.claude/skills"
ln -s "$WORK/env/idstack" "$WORK/env/home/.claude/skills/idstack"
run_setup --keep-legacy
check "--keep-legacy KEEPS the dispatcher symlink" \
  "[ -L '$WORK/env/home/.claude/skills/idstack' ]"

# --- legacy cleanup: pre-v2 per-skill symlinks ---
setup_env
mkdir -p "$WORK/env/home/.claude/skills"
ln -s "$WORK/env/idstack/skills/needs-analysis" "$WORK/env/home/.claude/skills/needs-analysis"
run_setup
check "pre-v2 per-skill symlink is removed by default" \
  "[ ! -e '$WORK/env/home/.claude/skills/needs-analysis' ]"

setup_env
mkdir -p "$WORK/env/home/.claude/skills"
ln -s "$WORK/env/idstack/skills/needs-analysis" "$WORK/env/home/.claude/skills/needs-analysis"
run_setup --keep-legacy
check "--keep-legacy KEEPS pre-v2 per-skill symlinks" \
  "[ -L '$WORK/env/home/.claude/skills/needs-analysis' ]"

# --- legacy cleanup: pre-v2.0.1.0 dispatcher DIRECTORY ---
setup_env
mkdir -p "$WORK/env/home/.claude/skills/idstack"
printf 'name: idstack\n' > "$WORK/env/home/.claude/skills/idstack/SKILL.md"
run_setup
check "pre-v2.0.1.0 dispatcher dir is removed by default" \
  "[ ! -d '$WORK/env/home/.claude/skills/idstack' ]"

setup_env
mkdir -p "$WORK/env/home/.claude/skills/idstack"
printf 'name: idstack\n' > "$WORK/env/home/.claude/skills/idstack/SKILL.md"
run_setup --keep-legacy
check "--keep-legacy KEEPS the dispatcher dir" \
  "[ -d '$WORK/env/home/.claude/skills/idstack' ]"

# An unrecognized directory is never auto-removed.
setup_env
mkdir -p "$WORK/env/home/.claude/skills/idstack"
printf 'someone else stuff\n' > "$WORK/env/home/.claude/skills/idstack/README.md"
run_setup
check "unrecognized dir at the legacy path is left alone" \
  "[ -d '$WORK/env/home/.claude/skills/idstack' ]"

# --- vestigial symlink scope: --local must not touch \$HOME ---
setup_env
mkdir -p "$WORK/env/home/.claude/plugins"
ln -s "$WORK/env/idstack" "$WORK/env/home/.claude/plugins/idstack"
run_setup --local
check "--local leaves the \$HOME vestigial symlink alone" \
  "[ -L '$WORK/env/home/.claude/plugins/idstack' ]"

setup_env
mkdir -p "$WORK/env/home/.claude/plugins"
ln -s "$WORK/env/idstack" "$WORK/env/home/.claude/plugins/idstack"
run_setup
check "default scope removes the \$HOME vestigial symlink" \
  "[ ! -e '$WORK/env/home/.claude/plugins/idstack' ]"

# --- failure handling: a nonzero `claude` must fail loudly, not silently ---
setup_env
check "a failing 'claude' call makes setup exit nonzero" \
  "! STUB_EXIT=1 raw_setup --no-codex >/dev/null 2>&1"

setup_env
STUB_EXIT=1 run_setup
check "a failing 'claude' call prints manual-recovery steps" \
  "grep -q 'marketplace add' '$WORK/env/out.log'"

# --- regeneration invariant ---
# The fixture is copied from a tree the smoke test already gates as fresh, so
# asserting freshness after a plain run proves nothing. Dirty a generated file
# first: only an actual regeneration during setup can make the dry-run pass.
setup_env
echo 'drift' >> "$WORK/env/idstack/skills/red-team/SKILL.md"
check "fixture is genuinely stale before setup runs" \
  "! '$WORK/env/idstack/bin/idstack-gen-skills' --dry-run"
run_setup
check "setup regenerates stale generated files" \
  "'$WORK/env/idstack/bin/idstack-gen-skills' --dry-run"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
