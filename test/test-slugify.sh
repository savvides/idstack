#!/usr/bin/env bash
# Unit tests for bin/idstack-slugify.
# Run from the repo root (or sourced by smoke-test.sh).

set -e

PASS=0
FAIL=0
TOTAL=0

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUGIFY="$REPO_ROOT/bin/idstack-slugify"

assert() {
  TOTAL=$((TOTAL + 1))
  local description="$1"
  local command="$2"
  local expected="$3"

  local got
  # Run the command, safely capturing output.
  if got=$(eval "$command" 2>/dev/null); then
    if [ "$got" = "$expected" ]; then
      PASS=$((PASS + 1))
      echo "  PASS: $description -> $got"
    else
      FAIL=$((FAIL + 1))
      echo "  FAIL: $description -> $got (expected: $expected)"
    fi
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $description (command failed unexpectedly)"
  fi
}

assert_exit_code() {
  TOTAL=$((TOTAL + 1))
  local description="$1"
  local command="$2"
  local expected_code="$3"

  set +e
  eval "$command" >/dev/null 2>&1
  local code=$?
  set -e

  if [ "$code" -eq "$expected_code" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $description -> exit code $code"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $description -> exit code $code (expected: $expected_code)"
  fi
}


if [ ! -x "$SLUGIFY" ]; then
  echo "test-slugify: $SLUGIFY missing or not executable"
  exit 1
fi

echo "test-slugify"
echo ""

# --- Happy path: standard strings ---
assert "standard string" "'$SLUGIFY' 'Introduction to Biology 101'" "introduction-to-biology-101"
assert "lowercase stays lowercase" "'$SLUGIFY' 'hello world'" "hello-world"
assert "uppercase becomes lowercase" "'$SLUGIFY' 'HELLO WORLD'" "hello-world"

# --- Edge cases: special characters and hyphens ---
assert "multiple spaces become single hyphen" "'$SLUGIFY' 'hello   world'" "hello-world"
assert "special characters become hyphens" "'$SLUGIFY' 'hello!@#world'" "hello-world"
assert "leading hyphens are stripped" "'$SLUGIFY' '---hello'" "hello"
assert "trailing hyphens are stripped" "'$SLUGIFY' 'world---'" "world"
assert "mixed hyphens and spaces" "'$SLUGIFY' '  -hello-  world- '" "hello-world"
assert "all special characters" "'$SLUGIFY' '!@#$%^&*()'" "untitled-course"
assert "only hyphens" "'$SLUGIFY' '---'" "untitled-course"
assert "only spaces" "'$SLUGIFY' '   '" "untitled-course"

# --- Edge case: empty input ---
assert "empty string" "'$SLUGIFY' ''" "untitled-course"

# --- Unicode and accents (NFKD folding) ---
assert "unicode folding (é, I)" "'$SLUGIFY' 'Géographie I'" "geographie-i"
assert "unicode characters" "'$SLUGIFY' 'Über den Wolken'" "uber-den-wolken"
assert "non-ascii stripped" "'$SLUGIFY' 'Hello 🌍 World'" "hello-world"

# --- Input methods ---
assert "stdin implicitly" "echo 'Pipe Test' | '$SLUGIFY'" "pipe-test"
assert "stdin explicitly with hyphen" "echo 'Explicit Pipe' | '$SLUGIFY' -" "explicit-pipe"

# --- Error cases ---
# Test exit code 3 when no argument and no stdin
# The tool checks [ -t 0 ] to detect if it's connected to a terminal.
# We simulate a terminal using python's pty module.
if command -v python3 >/dev/null 2>&1; then
  assert_exit_code "no input given (exit 3)" "python3 -c 'import sys, os, pty, subprocess; pid, fd = pty.fork(); sys.exit(subprocess.call([\"$SLUGIFY\"])) if pid == 0 else sys.exit(os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1]))'" 3
else
  echo "  SKIP: no input given (exit 3) — python3 required for pty simulation"
fi

echo ""
echo "slugify: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
