#!/usr/bin/env bash
# Unit tests for scripts/lib/plugin-status.sh — the `claude plugin list` parsing
# that scripts/idstack-doctor uses to decide whether idstack is enabled.
#
# Why this test exists: the original implementation used `grep -A4`, a fixed
# window that spills into the NEXT plugin's entry. With two plugins listed
# close together, a disabled idstack was reported as "installed and enabled"
# and the doctor gave a clean bill of health for a broken install. The cases
# below pin the scoping rule: an entry ends at a blank line or the next
# name@marketplace id, whichever comes first.
#
# Run from the repo root or via smoke-test.sh.
set -e

. "$(dirname "$0")/test-helper.sh"

IDSTACK_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$IDSTACK_DIR/scripts/lib/plugin-status.sh"

# Domain-specific shape: feeds a `claude plugin list` listing to
# plugin_is_enabled and compares the result. Takes only the counters from
# test-helper.sh, and is named check_listing so it cannot shadow check().
# check_listing <name> <expected: enabled|disabled> <listing>
check_listing() {
  TOTAL=$((TOTAL + 1))
  local name="$1" expected="$2" listing="$3" got
  if printf '%s\n' "$listing" | plugin_is_enabled "idstack@idstack"; then
    got="enabled"
  else
    got="disabled"
  fi
  if [ "$got" = "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $name -> $got"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $name -> $got (expected $expected)"
  fi
}

echo "test-plugin-status"
echo ""

check_listing "enabled, only plugin installed" enabled \
'idstack@idstack
  Status: enabled
  Version: 3.3.0.0'

check_listing "disabled, only plugin installed" disabled \
'idstack@idstack
  Status: disabled
  Version: 3.3.0.0'

# The regression the fixed window caused: the neighbour's "enabled" was inside
# the -A4 window, so a disabled idstack read as enabled.
check_listing "disabled, next plugin enabled two lines later" disabled \
'idstack@idstack
  Status: disabled
superpowers@marketplace
  Status: enabled'

check_listing "disabled, next plugin enabled after a blank line" disabled \
'idstack@idstack
  Status: disabled
  Version: 3.3.0.0

superpowers@marketplace
  Status: enabled'

check_listing "disabled, a PRECEDING plugin is enabled" disabled \
'superpowers@marketplace
  Status: enabled

idstack@idstack
  Status: disabled'

check_listing "enabled, listed between two disabled plugins" enabled \
'airtable@marketplace
  Status: disabled

idstack@idstack
  Status: enabled

superpowers@marketplace
  Status: disabled'

# Single-line listing formats.
check_listing "single-line format, enabled" enabled 'idstack@idstack (enabled)'
check_listing "single-line format, disabled with enabled neighbour" disabled \
'idstack@idstack (disabled)
superpowers@marketplace (enabled)'

# Not installed at all — doctor gates on a separate grep, but the parser must
# not invent an enabled verdict from someone else's entry.
check_listing "idstack absent, another plugin enabled" disabled \
'superpowers@marketplace
  Status: enabled'

# plugin_one_folder_scope: real `claude plugin list` entries (Claude Code 2.1.323).
# check_scope <name> <expected scope or empty> <listing>
check_scope() {
  TOTAL=$((TOTAL + 1))
  local got
  got=$(printf '%s\n' "$3" | plugin_one_folder_scope "idstack@idstack")
  if [ "$got" = "$2" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $1 -> '$got'"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1 -> '$got' (expected '$2')"
  fi
}
_e() { printf '  ❯ idstack@idstack\n    Version: 9.9.9.9\n    Scope: %s\n    Status: ✘ disabled\n' "$1"; }
check_scope "project scope" project "$(_e project)"
check_scope "local scope" local "$(_e local)"
check_scope "user scope" "" "$(_e user)"
check_scope "no scope line" "" 'idstack@idstack
  Status: disabled'
check_scope "project and user entries" "" "$(_e project)

$(_e user)"
check_scope "a neighbour's project scope is not idstack's" "" "$(_e user)

  ❯ other@market
    Scope: project"

echo ""
echo "  $PASS/$TOTAL passed"
[ "$FAIL" = "0" ] || exit 1
