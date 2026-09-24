#!/usr/bin/env bash
# Mutation test: reintroduce each fixed defect into a throwaway copy
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

pass=0; fail=0; skip=0
expect_fail() { # <name> <cmd...>
  local name="$1"; shift
  # A mutation that edits nothing proves nothing, whatever the suite then does.
  # Cases 16 and 17 went stale twice this way: their anchor stopped matching,
  # python's assert exited nonzero, nothing checked it, and both kept reporting
  # GUARDED. *.bak is excluded because sed -i.bak writes one even on no match.
  local d=0
  diff -rq -x '*.bak' "$WORK/base" "$WORK/r" >/dev/null 2>&1 || d=$?
  if [ "$d" -ne 1 ]; then
    echo "  ERROR: $name: the mutation did not change the copy (diff exit $d; stale anchor?) — fix the case; no result is trustworthy until then" >&2
    exit 1
  fi
  if "$@" >/dev/null 2>&1; then
    echo "  NOT-GUARDED: $name (test still passed with the bug reintroduced)"
    fail=$((fail+1))
  else
    echo "  GUARDED: $name (test failed as it should)"
    pass=$((pass+1))
  fi
}

skip_case() { # <name> <why>
  echo "  SKIPPED: $1 ($2)"
  skip=$((skip+1))
}

# Some defects only manifest on specific interpreters. PEP 701 (Python 3.12)
# legalized reusing a quote character inside an f-string replacement field, so
# the preamble f-string bug is a SyntaxError on 3.9-3.11 and valid code on
# 3.12+. Mutating it under 3.12 would report a false NOT-GUARDED.
PY_LT_312=$(python3 -c 'import sys; print(1 if sys.version_info < (3,12) else 0)' 2>/dev/null || echo 0)

# Every case starts from one pristine snapshot, taken once. It is the tree the
# baseline below vouches for and the tree expect_fail diffs each mutation
# against, so all three agree by construction even if $SRC is edited mid-run.
# Copy only what the suites need; skip .git and any nested worktrees.
mkdir -p "$WORK/base"
for item in bin skills templates test evidence docs extension .claude-plugin \
            VERSION CHANGELOG.md README.md TODOS.md CONTRIBUTING.md \
            DESIGN.md ROADMAP.md CLAUDE.md setup; do
  [ -e "$SRC/$item" ] && cp -R "$SRC/$item" "$WORK/base/"
done

fresh() {
  rm -rf "$WORK/r"
  cp -R "$WORK/base" "$WORK/r"
}

# Regenerate after mutating a .tmpl or a spliced template. Without this, the
# generated files go stale and smoke-test's `gen-skills --dry-run` gate fires —
# which means the mutation is caught by the staleness check rather than by the
# assertion it is meant to exercise, and GUARDED proves nothing about that
# assertion. Regenerating makes the specific guard the only thing that can fail.
# Failure is fatal, not swallowed. A `|| true` here is how the --target
# removal could have silently no-opped every regeneration: the mutation then
# trips the staleness gate instead of its own assertion, and GUARDED means
# nothing. No mutation in this file is supposed to break generation.
regen() {
  if ! "$WORK/r/bin/idstack-gen-skills" >/dev/null 2>&1; then
    echo "  ERROR: regen failed — a mutation broke generation; the GUARDED results below are meaningless" >&2
    exit 1
  fi
}

# Baseline: the unmutated copy must pass, or every expect_fail below reports
# GUARDED for the wrong reason. fresh() once omitted extension/, so smoke-test
# failed on every copy and each smoke-guarded case "passed" while guarding
# nothing. smoke-test runs every other guarding suite, so one run covers them.
fresh
if ! "$WORK/r/test/smoke-test.sh" "$WORK/r" >"$WORK/baseline.log" 2>&1; then
  echo "  ERROR: the unmutated copy fails smoke-test; every GUARDED result would be meaningless" >&2
  grep -A5 'FAIL:' "$WORK/baseline.log" >&2
  exit 1
fi

# 0. expect_fail must refuse a mutation that changed nothing. Run in a subshell
# so its exit is observable; bash does not run the parent's EXIT trap there.
fresh
if ( expect_fail "no-op mutation" false ) >/dev/null 2>&1; then
  echo "  ERROR: a mutation that changed nothing was counted as GUARDED" >&2
  exit 1
fi

# 1. f-string bug in the preamble -> test-preamble-python must fail.
# Only meaningful on Python < 3.12; see PY_LT_312 above.
if [ "$PY_LT_312" = "1" ]; then
  fresh
  python3 - "$WORK/r/templates/preamble.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("print('SKILLS_COMPLETED: ' + ','.join(sorted(completed)))",
              "print(f'SKILLS_COMPLETED: {','.join(sorted(completed))}')")
open(p,'w').write(s)
PY
  regen
  expect_fail "preamble f-string regression" "$WORK/r/test/test-preamble-python.sh"
else
  skip_case "preamble f-string regression" \
    "needs python < 3.12; PEP 701 makes the mutated form valid on $(python3 -V 2>&1)"
fi

# 2. course-import dropped from SUGGESTED_NEXT -> test-preamble-python must fail
fresh
python3 - "$WORK/r/templates/preamble.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("    ('course-import', 'learning-objectives'),\n", "")
open(p,'w').write(s)
PY
regen
expect_fail "course-import suggestion regression" "$WORK/r/test/test-preamble-python.sh"

# 3. non-canonical manifest section name returns -> smoke-test must fail
fresh
sed -i.bak 's/manifest `assessments` section/manifest `assessment_design` section/' \
  "$WORK/r/skills/assessment-design/SKILL.md.tmpl"
regen
expect_fail "non-canonical section name regression" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 4. bare /skill reference returns -> smoke-test must fail
fresh
sed -i.bak 's|`/idstack:learning-objectives`|`/learning-objectives`|' \
  "$WORK/r/skills/needs-analysis/SKILL.md.tmpl"
regen
expect_fail "bare /skill reference regression" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 4b. UNBACKTICKED bare /skill in the preamble returns -> smoke-test must fail.
# The guard above matched only backticked refs until v3.3.0.1, so three plain-prose
# examples sat in the preamble's context-recovery section telling the model to say
# "/assessment-design is the natural next step" — a command that does nothing. The
# preamble is spliced into all 22 skill files, so this reached every user.
fresh
sed -i.bak 's|/idstack:assessment-design is the natural next step|/assessment-design is the natural next step|' \
  "$WORK/r/templates/preamble.md"
regen
expect_fail "unbackticked bare /skill in preamble regression" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 5. pipeline unnamespaced Skill invocation returns -> smoke-test must fail
fresh
sed -i.bak 's|skill: "idstack:needs-analysis"|skill: "needs-analysis"|' \
  "$WORK/r/skills/pipeline/SKILL.md.tmpl"
regen
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
regen
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

# 7b. doctor stops flagging a disabled install -> test-doctor must fail.
# doctor exists to explain why /idstack:<skill> is missing; a branch that stops
# reporting turns it into a script that always says everything is fine.
fresh
sed -i.bak 's|echo "  PROBLEM: idstack@idstack is installed but not enabled."|echo "  OK: installed"|' \
  "$WORK/r/bin/idstack-doctor"
expect_fail "doctor silently passes a disabled install" "$WORK/r/test/test-doctor.sh"

# 7c. readiness threshold drifts by one -> test-status must fail.
# A fixture failing every threshold at once cannot catch this: some other
# unmet condition keeps the verdict NOT-READY either way. The boundary cases
# in test-status.sh hold the other two dimensions passing so the constant is
# the only thing that can flip the verdict.
fresh
sed -i.bak 's|^READY_QUALITY_MIN=70|READY_QUALITY_MIN=69|' "$WORK/r/bin/idstack-status"
expect_fail "readiness quality threshold off by one" "$WORK/r/test/test-status.sh"

# 7d. WCAG Level-A override removed from the verdict -> test-status must fail.
# The override exists in access_tier() and again in verdict(); deleting either
# alone leaves the other reporting, so both are pinned.
fresh
python3 - "$WORK/r/bin/idstack-status" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("    if level_a_violations:\n        issues.append(f'{len(level_a_violations)} WCAG Level-A violation(s)')\n", "")
open(p, 'w').write(s)
PY
expect_fail "WCAG Level-A override dropped from verdict" "$WORK/r/test/test-status.sh"

# 7e. a suite regrows its own counters -> smoke-test must fail.
# This is how the nine copies of check() drifted apart in the first place: each
# suite kept a private PASS=0 and its own body, and one of them ended up
# swallowing failure output entirely.
fresh
python3 - "$WORK/r/test/test-doctor.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('. "$(dirname "$0")/test-helper.sh"',
              'PASS=0\nFAIL=0\nTOTAL=0\ncheck() { TOTAL=$((TOTAL+1)); eval "$2" >/dev/null 2>&1 && PASS=$((PASS+1)) || FAIL=$((FAIL+1)); }', 1)
open(p, 'w').write(s)
PY
expect_fail "suite regrows private test counters" "$WORK/r/test/smoke-test.sh" "$WORK/r"

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
regen
expect_fail "missing Top recommendations" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 11. --keep-legacy ignored by the per-skill symlink loop -> test-setup must fail
fresh
python3 - "$WORK/r/setup" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('''      if [ "$KEEP_LEGACY" = "1" ]; then
        echo "  KEEPING legacy symlink: $legacy (--keep-legacy)"
      else
        rm "$legacy"
        echo "  cleaned up legacy: $legacy"
      fi''', '''      rm "$legacy"
      echo "  cleaned up legacy: $legacy"''')
open(p,'w').write(s)
PY
expect_fail "--keep-legacy ignored by per-skill loop" "$WORK/r/test/test-setup.sh" "$WORK/r"

# 12. --local scope leaking into $HOME -> test-setup must fail
fresh
python3 - "$WORK/r/setup" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('''if [ "$SCOPE" = "local" ]; then
  vestigial="$(pwd)/.claude/plugins/idstack"
else
  vestigial="$HOME/.claude/plugins/idstack"
fi
if [ -L "$vestigial" ]; then
  rm "$vestigial"
  echo "  removed vestigial symlink: $vestigial (pre-marketplace install method)"
fi''', '''for plugins_base in "$HOME/.claude/plugins" "$(pwd)/.claude/plugins"; do
  vestigial="$plugins_base/idstack"
  if [ -L "$vestigial" ]; then
    rm "$vestigial"
    echo "  removed vestigial symlink: $vestigial"
  fi
done''')
open(p,'w').write(s)
PY
expect_fail "--local leaking into \$HOME" "$WORK/r/test/test-setup.sh" "$WORK/r"

# 13. silent failure when `claude` exits nonzero -> test-setup must fail
fresh
python3 - "$WORK/r/setup" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
s = re.sub(r'  if ! claude plugin marketplace add "\$IDSTACK_DIR"; then\n(?:.*\n)*?  fi\n',
           '  claude plugin marketplace add "$IDSTACK_DIR" || true\n', s, count=1)
s = re.sub(r'  if ! claude plugin install idstack@idstack --scope "\$CLAUDE_SCOPE"; then\n(?:.*\n)*?  fi\n',
           '  claude plugin install idstack@idstack --scope "$CLAUDE_SCOPE" || true\n', s, count=1)
open(p,'w').write(s)
PY
expect_fail "silent 'claude' failure" "$WORK/r/test/test-setup.sh" "$WORK/r"

# 14. a retired-CLI reference creeps back into a doc -> smoke-test must fail.
# This is the mutation that matters for the v3.4.0.0 removal: the 47 assertions
# that used to name the second target are gone, so a green suite proves nothing
# unless the repo-wide sweep that replaced them actually bites. Mutating README
# rather than a code file also proves the sweep is not narrowed to bin/.
fresh
python3 - "$WORK/r/README.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("**Requirement:** [Claude Code](https://claude.ai/code)",
              "**Requirement:** [Claude Code](https://claude.ai/code) or OpenAI Codex CLI", 1)  # IDSTACK_CLI_LEAK_ALLOW
open(p,'w').write(s)
PY
expect_fail "retired-CLI reference back in README" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 15. the second-CLI output bundle returns -> smoke-test must fail.
# A directory, not a string: the sweep greps file *contents*, so an empty
# bundle directory would slip past it. The explicit -e check is what catches it.
fresh
mkdir -p "$WORK/r/dist/skills"
expect_fail "second-CLI dist/ bundle returns" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 16. an untagged reference inside a file that legitimately carries tagged lines
# -> smoke-test must fail. docs/index.html holds two IDSTACK_CLI_LEAK_ALLOW
# release-note lines. The tag has to exempt those *lines* and nothing else; the
# obvious "simplification" is to exclude the whole file, which would silently
# reopen the landing page — the single most user-visible surface — to stale
# capability claims. This is the mutation that catches that rewrite.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '<h2 id="install-title">'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, '<p>Also runs in OpenAI Codex CLI.</p>\n        ' + old, 1)  # IDSTACK_CLI_LEAK_ALLOW
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "untagged reference in a file with tagged lines" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 17. a capability claim that happens to contain the PR-review bot's name ->
# smoke-test must fail. The first draft of the sweep filtered the bot's name as
# a bare string across the whole repo, so this exact line passed: it names the
# retired CLI, it is untagged, and it sat on the landing page. The exemption is
# a line tag now, and this mutation is what keeps it from regressing to a
# string filter.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '<h2 id="install-title">'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, '<p>Reviewed by Gemini Code Assist. Also runs in Codex CLI.</p>\n        ' + old, 1)  # IDSTACK_CLI_LEAK_ALLOW
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "claim carrying the bot's name is not exempt" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 18. an evidence card overstates its domain's tier strength -> smoke-test must
# fail. Three cards had drifted this way before v3.4.0.1, two of them claiming
# T2 for domains whose strongest reference is T3. idstack's whole claim is that
# it labels evidence honestly, so a card advertising better evidence than the
# repo holds is the most expensive inaccuracy it can ship. Mutating toward
# OVERSTATES rather than a harmless typo pins the direction that matters.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import io, sys
p = sys.argv[1]; s = io.open(p, encoding='utf-8').read()
old = '<span class="meta-tier">T3</span>'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
io.open(p, 'w', encoding='utf-8').write(s.replace(old, '<span class="meta-tier">T1–T5</span>'))
PY
expect_fail "evidence card overstates its tier range" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 19. a domain's study count drifts from the reference file -> smoke-test must
# fail. The count and the tier range are separate assertions; a checker that
# only compared tiers would let "108 peer-reviewed studies" rot silently.
fresh
python3 - "$WORK/r/evidence/references.md" <<'PY'
import io, sys
p = sys.argv[1]; s = io.open(p, encoding='utf-8').read()
lines = s.split('\n')
for i, line in enumerate(lines):
    if line.startswith('## Domain 3: '):
        # Drop the first citation line under this heading.
        for j in range(i + 1, len(lines)):
            if '[Needs-' in lines[j]:
                del lines[j]
                break
        break
io.open(p, 'w', encoding='utf-8').write('\n'.join(lines))
PY
expect_fail "domain study count drifts from the cards" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 20. version string in README mutated -> smoke-test must fail
fresh
python3 - "$WORK/r" <<'PY'
import sys, os
root = sys.argv[1]
with open(os.path.join(root, "VERSION")) as vf:
    v = vf.read().strip()
p = os.path.join(root, "README.md")
s = open(p).read()
s = s.replace(f"v{v}", "v9.9.9.9")
open(p, 'w').write(s)
PY
expect_fail "version string in README mutated" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 21. non-existent binary reference in README -> smoke-test must fail
fresh
python3 - "$WORK/r/README.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("bin/idstack-doctor", "bin/idstack-fake-binary", 1)
open(p,'w').write(s)
PY
expect_fail "non-existent binary reference in README" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 22. dateModified reintroduced into the landing page -> smoke-test must fail.
# The field was deleted rather than corrected (spec D2); this proves the
# absence assertion in check-doc-accuracy.py actually guards that decision.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('"datePublished": "2026-04-20",',
              '"datePublished": "2026-04-20",\n    "dateModified": "2026-08-06",', 1)
open(p, 'w').write(s)
PY
expect_fail "dateModified reintroduced into docs/index.html" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 23. an untagged claim in a committed doc under docs/superpowers/ -> smoke-test
# must fail. 2b36bea added --exclude-dir=superpowers to the sweep to hide the
# extension's design docs; grep matches that name at any depth, so it exempted
# every committed spec and plan under docs/superpowers/ and superpowers/.
fresh
printf 'idstack also runs in OpenAI Codex CLI.\n' > "$WORK/r/docs/superpowers/leak.md"  # IDSTACK_CLI_LEAK_ALLOW
expect_fail "committed docs/superpowers is not sweep-exempt" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 24a/24b/24f. The extension suite must exercise the SHIPPED files. Every
# extension test used to load a hand-maintained .cjs twin, so a bug planted in
# the .js that Chrome actually runs stayed green.

# 24a. shipped renderer stops escaping '<' -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/renderer-helper.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "    .replace(/</g, '&lt;')\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "shipped renderer stops escaping '<'" "$WORK/r/test/test-extension.sh"

# 24b. the course-root detector the side panel imports treats every course page
# as the root -> test-extension must fail. The old suite tested extractor.js's
# copy (via a .cjs twin); sidepanel.js imports content/extractor-core.js.
fresh
python3 - "$WORK/r/extension/content/extractor-core.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "isCourseRoot: !!match,"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "isCourseRoot: !!anyCourseMatch,", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "side panel course-root detector matches every course page" "$WORK/r/test/test-extension.sh"

# 24f. a hand-copied .cjs twin comes back -> test-extension must fail.
fresh
cp "$WORK/r/extension/sidepanel/renderer-helper.js" "$WORK/r/extension/sidepanel/renderer-helper.cjs"
expect_fail "hand-copied .cjs twin back in extension/" "$WORK/r/test/test-extension.sh"

# 24c/24d/24e. service-worker.js, storage.js and sidepanel.js never ran under
# the old suite (no chrome or DOM stub), so a bug planted in any of them stayed
# green. Each case now trips a test that executes the shipped module.

# 24c. RUN_AUDIT stops holding the reply channel open -> test-extension must
# fail. Without `return true` Chrome closes the port and the panel gets undefined.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "      return true; // async reply\n    }\n\n    if (request.action === 'CRAWL_AND_AUDIT_COURSE')"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    }\n\n    if (request.action === 'CRAWL_AND_AUDIT_COURSE')", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "service worker drops return true for RUN_AUDIT" "$WORK/r/test/test-extension.sh"

# 24d. re-auditing a page appends a duplicate dossier entry -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/shared/storage.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (existingIdx >= 0) {"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "if (existingIdx > 0) {", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "dossier replace-by-url off by one" "$WORK/r/test/test-extension.sh"

# 24e. side panel hides the course-audit button on a course root -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "isCourseRoot ? 'block' : 'none'"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "isCourseRoot ? 'none' : 'block'", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course-audit button hidden on a course root" "$WORK/r/test/test-extension.sh"

# 25a-25d. The full-course audit read one page of 50 assignments and turned any
# fetch failure into an empty list, and the prompt then cut that list at 20,000
# characters mid-assignment under a header that still counted every item.

# 25a. the crawler stops following Link rel="next" -> test-crawler must fail.
# Canvas pages assignments 50 at a time; reading only page 1 audited the first
# 50 of an 80-assignment course without saying so.
fresh
python3 - "$WORK/r/extension/background/canvas-crawler.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "assignmentsUrl = next ? next[1] : null;"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "assignmentsUrl = null;", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "canvas crawler ignores Link rel=next" node "$WORK/r/test/test-crawler.mjs"

# 25b. the original try/catch returns around the assignments fetch -> test-crawler
# must fail. That catch turned a 403 or a dropped connection into an empty list,
# and the audit then told the instructor the course had no assessments.
fresh
python3 - "$WORK/r/extension/background/canvas-crawler.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
for old, new in [
    ("  for (let page = 1; assignmentsUrl; page++) {\n",
     "  try {\n  for (let page = 1; assignmentsUrl; page++) {\n"),
    ("    assignmentsUrl = next ? next[1] : null;\n  }\n",
     "    assignmentsUrl = next ? next[1] : null;\n  }\n  } catch (e) {\n    console.warn('Could not fetch assignments list:', e);\n  }\n"),
]:
    assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
    s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "canvas crawler swallows assignment-fetch failures" node "$WORK/r/test/test-crawler.mjs"

# 25c. pagination page cap removed -> test-crawler must fail. The loop follows
# server-supplied links; without the cap a Link cycle crawls until OOM. The test
# fake is finite (12 pages) so this fails in milliseconds instead of hanging.
fresh
python3 - "$WORK/r/extension/background/canvas-crawler.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (page > MAX_ASSIGNMENT_PAGES) {"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "if (false) {", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "canvas crawler page cap removed" node "$WORK/r/test/test-crawler.mjs"

# 25d. the course prompt goes back to a plain 20,000-char slice of every
# assignment -> test-prompts must fail. The slice ended mid-assignment while the
# header counted every item. Reverting needs both edits: the whole-block budget
# already fits in 20,000 chars, so the slice alone would change nothing.
fresh
python3 - "$WORK/r/extension/shared/prompts.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
for old, new in [
    ("    if (next.length > 20000) break;\n", ""),
    ("${assignmentsSummary}\n", "${assignmentsSummary.slice(0, 20000)}\n"),
]:
    assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
    s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course prompt cuts the assignment list mid-block" node "$WORK/r/test/test-prompts.mjs"

# 26a-26g. The extension shipped a tier scale that put randomized trials in T2,
# demo findings citing Biggs as [Alignment-3] [T2] and a nonexistent
# [Cognitive-2], uncoded prompt citations, and a page prompt asking for a
# 'suggestion' severity. test-evidence-labels.mjs checks every label against
# evidence/references.md and CLAUDE.md; each case reverts one defect.

# 26a. TIER_METADATA relabels T2 as randomized trials -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/shared/evidence-base.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "T2: { label: 'Quasi-experimental with controls', description: 'Quasi-experimental with appropriate controls'"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "T2: { label: 'Controlled trial', description: 'Peer-reviewed empirical randomized or quasi-experimental studies'", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "tier scale puts randomized trials in T2" "$WORK/r/test/test-extension.sh"

# 26b. the demo cites Biggs as [Alignment-3] [T2] again -> test-extension must
# fail. references.md files Biggs as [Alignment-1] T5; [Alignment-3] is Pereira, T4.
fresh
python3 - "$WORK/r/extension/background/parser-helper.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "tier: 'T5',\n        citation: '[Alignment-1] Direct Constructive Alignment',\n        observation: 'Learning objectives"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "tier: 'T2',\n        citation: '[Alignment-3] Direct Constructive Alignment',\n        observation: 'Learning objectives", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "demo cites Biggs as [Alignment-3] T2" "$WORK/r/test/test-extension.sh"

# 26c. the demo cites the nonexistent [Cognitive-2] again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/background/parser-helper.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "'[CogLoad-1] Cognitive Load & Chunking'"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "'[Cognitive-2] Cognitive Load & Chunking'", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "demo cites nonexistent [Cognitive-2]" "$WORK/r/test/test-extension.sh"

# 26d. the course prompt cites Biggs uncoded at T2 again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/shared/prompts.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "([Alignment-1] Biggs (1996) [T5])."
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "(Biggs 1996 [T2], Liou et al. 2023 [T2]).", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course prompt cites Biggs uncoded at T2" "$WORK/r/test/test-extension.sh"

# 26e. the page prompt asks for a 'suggestion' severity again -> test-extension
# must fail. The course prompt, the reports and the side panel use critical|warning|info.
fresh
python3 - "$WORK/r/extension/shared/prompts.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '"severity": "critical | warning | info",'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, '"severity": "critical | warning | suggestion",', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "page prompt asks for a suggestion severity" "$WORK/r/test/test-extension.sh"

# 26f. the course prompt drops the canonical tier scale -> test-extension must
# fail. Without it the model rates tiers on whatever scale it assumes.
fresh
python3 - "$WORK/r/extension/shared/prompts.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "Rate each finding's evidence tier on this scale:\n${TIER_SCALE}\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course prompt drops the tier scale" "$WORK/r/test/test-extension.sh"

# 26g. the side panel styles a 'suggestion' finding card again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.css" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = ".finding-card.severity-info {"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, ".finding-card.severity-suggestion {\n  border-left-color: #2f7a4a;\n}\n\n.finding-card.severity-info {", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "side panel styles a suggestion severity" "$WORK/r/test/test-extension.sh"

# 27a-27f. The service worker audited whatever it was sent: a restricted tab's
# empty fallback, a lone Modules item title or an empty course came back as an
# invented audit and was saved. Malformed model JSON was saved and stuck the
# panel, and the model fetch had no timeout and carried the API key in its URL.
# test-service-worker.mjs drives the shipped worker through each case.

# 27a. RUN_AUDIT audits a page with no readable text again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (wordCount < MIN_AUDIT_WORDS) {"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "if (false) {", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "RUN_AUDIT audits a page with no text" "$WORK/r/test/test-extension.sh"

# 27b. malformed model JSON is saved and handed to the panel again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "throw new Error('The AI response did not match the audit format. Please retry the audit.');"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "malformed model JSON saved to history" "$WORK/r/test/test-extension.sh"

# 27c. the API key goes back into the URL query string -> test-extension must
# fail. A query-string key lands in proxy, gateway and crash logs.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
for old, new in [
    (":generateContent';", ":generateContent?key=' + apiKey;"),
    (", 'x-goog-api-key': apiKey", ""),
]:
    assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
    s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "API key sent in the URL query string" "$WORK/r/test/test-extension.sh"

# 27d. the model fetch loses its timeout -> test-extension must fail. Chrome
# kills a service worker whose fetch response takes over 30 s, and the panel
# then gets a closed message port instead of an explanation.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "const signal = AbortSignal.timeout(LLM_TIMEOUT_MS);"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "const signal = new AbortController().signal;", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "model fetch without a timeout" "$WORK/r/test/test-extension.sh"

# 27e. the worker drops the reason the extractor or panel gave for an unread
# page -> test-extension must fail. The user would see a generic word count.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "request.payload?.emptyReason || "
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "refusal reason from the extractor/panel dropped" "$WORK/r/test/test-extension.sh"

# 27f. a course with no syllabus and no assignments is audited again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (!courseData.syllabus.trim() && courseData.assignments.length === 0) {"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "if (false) {", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "empty course audited" "$WORK/r/test/test-extension.sh"

# 28a-28n. The extension declared an <all_urls> content script (install prompt:
# "all your data on all websites"), yet custom-domain Canvas hosts could not be
# crawled; and the service worker answered any sender, splicing the raw origin
# and courseId into credentialed Canvas fetches. Now the panel reads tabs through
# activeTab (the icon click reaches action.onClicked), requests a Canvas host per
# site, and the worker serves only its own pages and validated course targets.

# 28a. the worker gates on sender.id, which a content script shares -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (!String(sender.url || '').startsWith(chrome.runtime.getURL(''))) return;"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "if (sender.id !== chrome.runtime.id) return;", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "service worker trusts content-script senders" "$WORK/r/test/test-extension.sh"

# 28b. the course origin may carry a path or query again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "target.origin !== origin || "
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course origin smuggles a path" "$WORK/r/test/test-extension.sh"

# 28c. the course id may carry a path again -> test-extension must fail. fetch
# normalizes '../' segments, so '../../users/self' is any credentialed GET on the host.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = " || !/^\\d+$/.test(courseId)"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course id smuggles a path" "$WORK/r/test/test-extension.sh"

# 28d. the <all_urls> content script comes back -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/manifest.json" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '  "permissions": [\n'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, '  "content_scripts": [\n    {\n      "matches": ["<all_urls>"],\n      "js": ["content/extractor.js"],\n      "run_at": "document_idle"\n    }\n  ],\n' + old, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "<all_urls> content script back" "$WORK/r/test/test-extension.sh"

# 28e. the per-site optional host permission is dropped -> test-extension must
# fail. Canvas outside instructure.com could then never be crawled.
fresh
python3 - "$WORK/r/extension/manifest.json" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '  ],\n  "optional_host_permissions": [\n    "https://*/*"\n  ]\n'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, '  ]\n', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "custom-domain permission dropped" "$WORK/r/test/test-extension.sh"

# 28f. the icon click toggles the panel directly again -> test-extension must
# fail. Chrome's side-panel toggle path skips the activeTab grant.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "setPanelBehavior({ openPanelOnActionClick: false })"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "setPanelBehavior({ openPanelOnActionClick: true })", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "icon click no longer grants activeTab" "$WORK/r/test/test-extension.sh"

# 28g. the site permission is requested after an await -> test-extension must
# fail. Chrome rejects permissions.request once the click's user gesture is gone.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "    let granted = false;\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    await refreshActiveTab();\n" + old, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "site permission requested after an await" "$WORK/r/test/test-extension.sh"

# 28h. the extractor's final statement no longer yields the payload -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "} else {\n  extractPageContent();\n}\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "}\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "extractor no longer returns its payload" "$WORK/r/test/test-extension.sh"

# 28i. a top-level const in the extractor -> test-extension must fail. The panel
# re-injects into the same isolated world, where a redeclaration throws.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "function detectPageType("
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "const EXTRACTOR_READY = true;\n" + old, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "extractor breaks on re-injection" "$WORK/r/test/test-extension.sh"

# 28j. an unreadable tab is sent with no explanation -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "      emptyReason: 'idstack cannot read this tab. If you just switched to it, click the idstack toolbar icon, then audit again. Browser pages such as chrome:// and the Chrome Web Store cannot be read.'\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "unreadable tab sent with no explanation" "$WORK/r/test/test-extension.sh"

# 28k. the Chrome floor for sidePanel.open is dropped -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/manifest.json" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '  "minimum_chrome_version": "116",\n'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, '', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "Chrome floor for sidePanel.open dropped" "$WORK/r/test/test-extension.sh"

# 28l. the course crawl ignores a denied site permission -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "    if (!granted) {"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    if (false) {", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course crawl runs after the site permission is denied" "$WORK/r/test/test-extension.sh"

# 28m. the icon click no longer opens the panel -> test-extension must fail.
# With openPanelOnActionClick off, onClicked is the only way the panel opens.
fresh
python3 - "$WORK/r/extension/background/service-worker.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "  chrome.sidePanel.open({ windowId: tab.windowId });\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "icon click no longer opens the panel" "$WORK/r/test/test-extension.sh"

# 28n. the panel ignores the worker's TAB_ACCESS_GRANTED -> test-extension must
# fail. After a tab switch and an icon click the header would stay stale.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "  if (msg && msg.action === 'TAB_ACCESS_GRANTED') refreshActiveTab();\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "panel ignores newly granted tab access" "$WORK/r/test/test-extension.sh"

# 29a-29i. The extractor sent a Modules page's first item title only, read the
# whole page on any Canvas view it did not recognize (Gradebook, People, Inbox,
# discussions), treated any /courses/ URL as Canvas, and read Google Docs from
# the editor DOM, which holds no document text. test-extractor.mjs runs the
# shipped extractor on each page.

# 29a. a Modules page reads only the first item title -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "Array.from(document.querySelectorAll('.module-item-title'))"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "[document.querySelector('.module-item-title')]", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "Modules page reads only the first item title" "$WORK/r/test/test-extension.sh"

# 29b. a course home in Modules view is not detected -> test-extension must fail.
# Canvas's modules container is #context_modules, and the course home URL has no /modules.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "'#context_modules, #modules'"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "'#modules'", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course home in Modules view not detected" "$WORK/r/test/test-extension.sh"

# 29c. an unrecognized Canvas view falls back to the whole page -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "content = mainBody ? (mainBody.innerText || mainBody.textContent || '').trim() : '';"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "content = mainBody ? (mainBody.innerText || mainBody.textContent || '').trim() : (document.body ? (document.body.innerText || document.body.textContent || '').trim() : '');", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "Canvas page falls back to the whole document body" "$WORK/r/test/test-extension.sh"

# 29d. the student-record guard is disabled -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (studentRecordUrl.test(url)) {"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "if (false && studentRecordUrl.test(url)) {", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "student-record page guard disabled" "$WORK/r/test/test-extension.sh"

# 29e. custom-domain Canvas course pages are not detected as Canvas -> test-extension
# must fail. They would go through the generic reader, which reads [role=main].
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = r" || /\/courses\/\d+(?:[/?#]|$)/.test(url)"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "custom-domain Canvas course page not detected as Canvas" "$WORK/r/test/test-extension.sh"

# 29f. any /courses/<slug> site is treated as Canvas again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = r"/\/courses\/\d+(?:[/?#]|$)/.test(url)"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "url.includes('/courses/')", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "non-Canvas /courses/<slug> site treated as Canvas" "$WORK/r/test/test-extension.sh"

# 29g. rubric pages lose their text without the body fallback -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = ", #rubrics'"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "'", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "rubric text lost with the body fallback" "$WORK/r/test/test-extension.sh"

# 29h. Google Docs are read from the editor DOM again -> test-extension must fail.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "  if (!doc) return data;\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "  return data;\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "Google Docs read from the canvas-rendered DOM" "$WORK/r/test/test-extension.sh"

# 29i. the Docs export accepts any content type -> test-extension must fail. A
# signed-out export answers 200 with an HTML sign-in page, audited as the document.
fresh
python3 - "$WORK/r/extension/content/extractor.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = " || !(res.headers.get('content-type') || '').startsWith('text/plain')"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "HTML sign-in page audited as the Google Doc" "$WORK/r/test/test-extension.sh"

# 30a-30l. The side panel labelled a result with whatever tab was active when
# the reply landed, let a slow tab refresh overwrite a newer one, left the last
# result behind Add to Dossier after an error, retried the single-page audit
# whatever had failed, wiped Audit Another Page on a vote, and said "Copied!"
# when the clipboard write failed. The renderer threw on malformed findings,
# inside the sendMessage callback, so the spinner stayed up.
# test-sidepanel-state.mjs drives the shipped sidepanel.js through each case.

# 30a. a page audit is labelled with the tab active when the reply lands ->
# test-sidepanel-state must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "renderResults(response.data, sent);"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "renderResults(response.data, activePayload);", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "page audit labelled with the tab active when the reply lands" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30b. a course audit is labelled with the current page, not the course the
# worker crawled -> test-sidepanel-state must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = ("renderResults(response.data, {\n"
       "              url: `${origin}/courses/${courseId}`,\n"
       "              title: response.courseData?.title || 'Canvas Course',\n"
       "              pageType: 'Canvas Course (Full Audit)'\n"
       "            });")
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "renderResults(response.data, activePayload);", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "course audit label ignores the crawled course" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30c. every refresh passes the sequence check -> test-sidepanel-state must
# fail. A slow injection for a tab the user already left overwrites the newer
# tab's title and payload, and the next audit sends the wrong page.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "const seq = ++refreshSeq;"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "const seq = refreshSeq;", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "stale tab refresh overwrites a newer tab" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30d. an error leaves the previous result actionable -> test-sidepanel-state
# must fail. Add to Dossier would save the last success under the failed page.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "\n  activeAuditItem = null;\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "error leaves the previous result actionable" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30e. the action bar hidden by an error never comes back -> test-sidepanel-state must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "  if (actionsBar) actionsBar.style.display = '';\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "action bar never returns after an error" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30f. Copy to Clipboard says "Copied!" whether or not the write worked ->
# test-sidepanel-state must fail. The .catch keeps the failure on the label.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "copyWithFeedback(copyBtn, contentToCopy, '📋 Copy to Clipboard');"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "navigator.clipboard.writeText(contentToCopy).catch(() => {}); copyBtn.textContent = '✓ Copied!';", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "copy button claims success on a rejected write" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30g. Copy Markdown lets a rejected write escape the click handler ->
# test-sidepanel-state must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "await copyWithFeedback(copyDossierMdBtn, md, '📋 Copy Markdown');"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "await navigator.clipboard.writeText(md); copyDossierMdBtn.textContent = '✓ Copied!';", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "dossier copy leaks an unhandled rejection" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30h. Retry always runs the single-page audit -> test-sidepanel-state must
# fail. A failed course audit was retried as an audit of the current page.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (lastAuditBtn) lastAuditBtn.click();"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "document.getElementById('audit-btn').click();", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "Retry always runs the single-page audit" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30m. Retry clicks the hidden course button after a switch to a non-course tab
# -> test-sidepanel-state must fail. It would crawl, and ask for access to,
# whatever site is active now.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "      if (lastAuditBtn && lastAuditBtn.style.display === 'none') return;\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "Retry clicks the hidden course button" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30i. a feedback vote rewrites the whole row -> test-sidepanel-state must fail.
# The row also holds Audit Another Page, the only way back to the ready state.
fresh
python3 - "$WORK/r/extension/sidepanel/sidepanel.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "if (prompt) prompt.innerHTML = '<em>Thank you for your feedback!</em>';"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "row.innerHTML = '<em>Thank you for your feedback!</em>';", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "feedback vote wipes Audit Another Page" node "$WORK/r/test/test-sidepanel-state.mjs"

# 30j. the renderer trusts a non-array findings value -> test-renderer-helper must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/renderer-helper.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "Array.isArray(data.findings) ? data.findings.filter((f) => f && typeof f === 'object') : []"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "data.findings || []", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "renderer trusts non-array findings" node "$WORK/r/test/test-renderer-helper.mjs"

# 30k. the renderer keeps null and non-object findings -> test-renderer-helper must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/renderer-helper.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = ".filter((f) => f && typeof f === 'object')"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "renderer crashes on a null finding entry" node "$WORK/r/test/test-renderer-helper.mjs"

# 30l. the renderer calls toLowerCase on a non-string tier -> test-renderer-helper must fail.
fresh
python3 - "$WORK/r/extension/sidepanel/renderer-helper.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "String(f.tier || 'T1')"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "(f.tier || 'T1')", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "renderer calls toLowerCase on a non-string tier" node "$WORK/r/test/test-renderer-helper.mjs"

echo ""
echo "guarded: $pass   NOT guarded: $fail   skipped: $skip"
[ "$fail" -eq 0 ]

