# Plugin-status parsing for `claude plugin list` output — the single definition
# used by bin/idstack-doctor. Source this file; do not inline the awk program
# (an inlined copy cannot be unit-tested, and the version-classifier drifted
# three times for exactly that reason).
#
# plugin_entry_window <plugin-id> reads `claude plugin list` output on stdin and
# prints only the entry for <plugin-id>: the matching line plus its indented
# continuation lines, stopping at a blank line or the next `name@marketplace`
# id. Scoping matters — a fixed-size window (the old `grep -A4`) reads a
# neighboring plugin's status line and reports a disabled plugin as enabled
# whenever the next entry starts within the window.
plugin_entry_window() {
  awk -v id="$1" '
    index($0, id) && !f { f = 1; print; next }
    f {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /[A-Za-z0-9._-]+@[A-Za-z0-9._-]+/) { f = 0 }
      else { print }
    }'
}

# plugin_is_enabled <plugin-id> — stdin is `claude plugin list` output.
# Returns 0 when that plugin's own entry reports enabled, 1 otherwise.
plugin_is_enabled() {
  plugin_entry_window "$1" | grep -qi "enabled"
}
