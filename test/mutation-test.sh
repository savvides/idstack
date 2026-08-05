#!/usr/bin/env bash
# Mutation test: reintroduce each bug fixed in v3.3.0.0 into a throwaway copy
# of the repo and confirm the guarding test FAILS. A test that still passes
# with its bug reintroduced is not guarding anything — that is exactly how the
# v3.3.0.0 defects survived (the version-classifier suite tested a local copy
# of the classifier, and gen-skills counted a missing-placeholder template as
# neither generated nor failed).
#
# Slower than the gate suites (it copies the repo and runs smoke-test once per
# mutation), so it is NOT wired into smoke-test.sh. Run it after touching a
# test, a guard, or bin/lib/. CI runs it as a separate job.
#
# Usage: test/mutation-test.sh [path-to-repo]   (defaults to this checkout)
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
expect_fail() { # <name> <cmd...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  NOT-GUARDED: $name (test still passed with the bug reintroduced)"
    fail=$((fail+1))
  else
    echo "  GUARDED: $name (test failed as it should)"
    pass=$((pass+1))
  fi
}

fresh() {
  rm -rf "$WORK/r"
  mkdir -p "$WORK/r"
  # Copy only what the suites need; skip .git and any nested worktrees.
  for item in bin skills templates test evidence docs .claude-plugin \
              VERSION CHANGELOG.md README.md TODOS.md AGENTS.md setup dist; do
    [ -e "$SRC/$item" ] && cp -R "$SRC/$item" "$WORK/r/"
  done
  return 0
}

# 1. f-string bug in the preamble -> test-preamble-python must fail
fresh
python3 - "$WORK/r/templates/preamble.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("print('SKILLS_COMPLETED: ' + ','.join(sorted(completed)))",
              "print(f'SKILLS_COMPLETED: {','.join(sorted(completed))}')")
open(p,'w').write(s)
PY
expect_fail "preamble f-string regression" "$WORK/r/test/test-preamble-python.sh"

# 2. course-import dropped from SUGGESTED_NEXT -> test-preamble-python must fail
fresh
python3 - "$WORK/r/templates/preamble.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("    ('course-import', 'learning-objectives'),\n", "")
open(p,'w').write(s)
PY
expect_fail "course-import suggestion regression" "$WORK/r/test/test-preamble-python.sh"

# 3. non-canonical manifest section name returns -> smoke-test must fail
fresh
sed -i.bak 's/manifest `assessments` section/manifest `assessment_design` section/' \
  "$WORK/r/skills/assessment-design/SKILL.md.tmpl"
expect_fail "non-canonical section name regression" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 4. bare /skill reference returns -> smoke-test must fail
fresh
sed -i.bak 's|`/idstack:learning-objectives`|`/learning-objectives`|' \
  "$WORK/r/skills/needs-analysis/SKILL.md.tmpl"
expect_fail "bare /skill reference regression" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 5. pipeline unnamespaced Skill invocation returns -> smoke-test must fail
fresh
sed -i.bak 's|skill: "idstack:needs-analysis"|skill: "needs-analysis"|' \
  "$WORK/r/skills/pipeline/SKILL.md.tmpl"
expect_fail "pipeline namespace regression" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 6. hand-rolled _IDSTACK with the legacy path returns -> smoke-test must fail
fresh
python3 - "$WORK/r/skills/learn/SKILL.md.tmpl" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("{{IDSTACK_RESOLVE}}",
  'for _p in "$CLAUDE_PLUGIN_ROOT" "$HOME/.claude/plugins/idstack"; do [ -d "$_p" ] && _IDSTACK="$_p" && break; done', 1)
open(p,'w').write(s)
PY
expect_fail "hand-rolled _IDSTACK regression" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 7. plugin-status fixed-window regression -> test-plugin-status must fail
fresh
python3 - "$WORK/r/bin/lib/plugin-status.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('''plugin_entry_window() {
  awk -v id="$1" '
    index($0, id) && !f { f = 1; print; next }
    f {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /[A-Za-z0-9._-]+@[A-Za-z0-9._-]+/) { f = 0 }
      else { print }
    }'
}''', '''plugin_entry_window() {
  grep -A4 "$1"
}''')
open(p,'w').write(s)
PY
expect_fail "plugin-status fixed-window regression" "$WORK/r/test/test-plugin-status.sh"

# 8. version disagreement -> smoke-test must fail
fresh
printf '9.9.9.9\n' > "$WORK/r/VERSION"
expect_fail "VERSION/plugin.json disagreement" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 9. stale generated file -> smoke-test must fail (gen-skills dry-run gate)
fresh
echo 'drift' >> "$WORK/r/skills/red-team/SKILL.md"
expect_fail "stale generated SKILL.md" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 10. missing Top recommendations -> smoke-test must fail
fresh
sed -i.bak '/\*\*Top recommendations:\*\*/d' "$WORK/r/skills/learning-objectives/SKILL.md.tmpl"
expect_fail "missing Top recommendations" "$WORK/r/test/smoke-test.sh" "$WORK/r"

echo ""
echo "guarded: $pass   NOT guarded: $fail"
[ "$fail" -eq 0 ]
