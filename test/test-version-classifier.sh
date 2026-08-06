#!/usr/bin/env bash
# Unit tests for the legacy-VERSION classifier shared by setup and
# bin/idstack-doctor. The classifier decides whether a VERSION file under the
# legacy install path means "modern install — leave alone" (skip) or
# "pre-v2.0.1.0 install — flag for cleanup" (legacy).
#
# Why this test exists: Gemini Code Assist has flagged this case statement
# three times (PR #15 → PR #19 → PR #20 → PR #21). The patterns are subtle
# (bash globs, not regex) and an off-by-one in a character class silently
# flips classifications for multi-digit components. This test pins the
# contract so it can't drift again. Cases that once silently fell through
# to "unknown" — notably 20.x and 200.x — are now pinned here explicitly.
#
# The single definition lives in bin/lib/version-classify.sh and is sourced
# here, so this suite exercises the exact code setup and doctor run — a local
# mirror of the case statement once passed green while the real call sites
# could drift.
#
# Run from the repo root or via smoke-test.sh.

set -e

. "$(dirname "$0")/test-helper.sh"

IDSTACK_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$IDSTACK_DIR/bin/lib/version-classify.sh"

# Domain-specific shape: this compares a version string to an expected
# classification rather than running a command, so it takes only the counters
# from test-helper.sh. Named check_version so it cannot shadow the shared
# check() — a same-named local wrapper is how the two would drift apart again.
check_version() {
  TOTAL=$((TOTAL + 1))
  local version="$1"
  local expected="$2"
  local got
  got="$(classify_version "$version")"
  if [ "$got" = "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $version -> $got"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $version -> $got (expected $expected)"
  fi
}

echo "test-version-classifier"
echo ""

# Legacy versions that ever shipped.
check_version "0.1.0"     legacy
check_version "0.5.0"     legacy
check_version "1.0.0"     legacy
check_version "1.9.0"     legacy
check_version "2.0.0"     legacy
check_version "2.0.0.0"   legacy
check_version "2.0.0.1"   legacy

# Modern versions — including multi-digit components that broke the
# previous patterns.
check_version "2.0.1.0"   skip
check_version "2.0.1.5"   skip
check_version "2.0.10.0"  skip
check_version "2.0.99.0"  skip
check_version "2.1.0.0"   skip
check_version "2.4.0.0"   skip
check_version "2.10.0.0"  skip
check_version "2.99.0.0"  skip
check_version "3.0.0.0"   skip
check_version "9.0.0.0"   skip
check_version "10.0.0.0"  skip
check_version "19.0.0.0"  skip
check_version "100.0.0.0" skip

# Future major versions where the major itself is multi-digit but does not
# start with 1. Caught by Gemini on PR #21 — the previous 1[0-9]* arm
# missed these and silently fell through to "unknown". Now classified by
# [1-9][0-9]*.
check_version "20.0.0.0"  skip
check_version "21.5.0"    skip
check_version "25.99.0"   skip
check_version "29.0.0"    skip
check_version "30.0.0"    skip
check_version "200.0.0"   skip
check_version "999.0.0"   skip

echo ""
echo "  $PASS/$TOTAL passed"
[ "$FAIL" = "0" ] || exit 1
