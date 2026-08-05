# Legacy-VERSION classifier — the single definition shared by setup,
# bin/idstack-doctor, and test/test-version-classifier.sh. Source this file;
# do not copy the case statement (copies drifted three times across
# PR #15 / #19 / #20 / #21 before it was extracted here).
#
# classify_version <version> prints one of:
#   skip    — modern install (v2.0.1.0+), leave alone
#   legacy  — pre-v2.0.1.0 install, flag for cleanup
#   unknown — unparseable, leave alone and warn
#
# Patterns are bash globs, not regex. Two arms: explicitly skip modern/future
# versions first, then flag the legacy ones. Patterns avoid literal dots and
# single-digit ranges so multi-digit components (2.0.10.0, 2.10.0.0, 20.x,
# 100.0.0, 200.0.0) classify correctly. Pinned by test/test-version-classifier.sh.
classify_version() {
  case "$1" in
    2.0.[1-9]*|2.[1-9]*|[3-9]*|[1-9][0-9]*) echo "skip" ;;
    0.*|1.*|2.0.0.*|2.0.0) echo "legacy" ;;
    *) echo "unknown" ;;
  esac
}
