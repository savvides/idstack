#!/usr/bin/env bash
# Shared counters and assertion helper for the idstack test suites.
# Sourced, never executed: `. "$(dirname "$0")/test-helper.sh"`.
#
# Nine suites each carried their own PASS/FAIL/TOTAL and their own copy of this
# function. They had already drifted: some printed failure diagnostics, some
# swallowed them with 2>/dev/null, and two spelled the helper `assert` instead
# of `check`. A suite that prints nothing on failure is the worst version —
# CI tells you something broke and not what.
#
# Suites with a genuinely different assertion shape keep their own wrapper and
# use only the counters from here: test-version-classifier.sh compares a
# version string to an expected classification rather than running a command.

PASS=0
FAIL=0
TOTAL=0

# check <description> <command> [expected_exit] [expected_output_regex]
#
# Runs <command> through eval with stderr folded into stdout. With no optional
# arguments this is the plain "command must succeed" form every suite already
# used. Pass expected_exit to assert a specific non-zero code (exit codes are
# part of the contract for bin/idstack-manifest-merge and bin/idstack-doctor),
# and expected_output_regex to also require matching output — an ERE, matched
# with grep -qE.
#
# On failure the first 5 lines of output are printed, indented. Never silence
# this; a bare FAIL is the thing this helper exists to stop.
check() {
  TOTAL=$((TOTAL + 1))
  local _desc="$1" _cmd="$2" _want_exit="${3:-0}" _want_out="${4:-}"
  local _out _code=0

  _out=$(eval "$_cmd" 2>&1) || _code=$?

  if [ "$_code" -ne "$_want_exit" ]; then
    FAIL=$((FAIL + 1))
    echo "  FAIL: $_desc (expected exit $_want_exit, got $_code)"
    [ -n "$_out" ] && printf '%s\n' "$_out" | head -5 | sed 's/^/        | /'
    return 0
  fi

  if [ -n "$_want_out" ] && ! printf '%s\n' "$_out" | grep -qE "$_want_out"; then
    FAIL=$((FAIL + 1))
    echo "  FAIL: $_desc (exit $_code correct, output missing /$_want_out/)"
    [ -n "$_out" ] && printf '%s\n' "$_out" | head -5 | sed 's/^/        | /'
    return 0
  fi

  PASS=$((PASS + 1))
  echo "  PASS: $_desc"
  return 0
}
