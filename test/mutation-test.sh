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

pass=0; fail=0; skip=0
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

skip_case() { # <name> <why>
  echo "  SKIPPED: $1 ($2)"
  skip=$((skip+1))
}

# Some defects only manifest on specific interpreters. PEP 701 (Python 3.12)
# legalized reusing a quote character inside an f-string replacement field, so
# the preamble f-string bug is a SyntaxError on 3.9-3.11 and valid code on
# 3.12+. Mutating it under 3.12 would report a false NOT-GUARDED.
PY_LT_312=$(python3 -c 'import sys; print(1 if sys.version_info < (3,12) else 0)' 2>/dev/null || echo 0)

fresh() {
  rm -rf "$WORK/r"
  mkdir -p "$WORK/r"
  # Copy only what the suites need; skip .git and any nested worktrees.
  for item in bin skills templates test evidence docs extension .claude-plugin \
              VERSION CHANGELOG.md README.md TODOS.md CONTRIBUTING.md \
              DESIGN.md ROADMAP.md CLAUDE.md setup; do
    [ -e "$SRC/$item" ] && cp -R "$SRC/$item" "$WORK/r/"
  done
  return 0
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

# Null-mutation control. expect_fail only checks that smoke-test exits non-zero, so if the
# UNMUTATED copy already fails, every GUARDED below is vacuous — the suite would report a
# perfect score while proving nothing. This actually happened: `extension` was missing from
# fresh()'s copy list, so test-extension.sh failed on every copy and all 36 mutations reported
# GUARDED regardless of whether their guard worked. Prove the baseline is green before trusting
# a single result.
fresh
if ! "$WORK/r/test/smoke-test.sh" "$WORK/r" >/dev/null 2>&1; then
  echo "  ABORT: smoke-test fails on an UNMUTATED copy — every GUARDED below would be vacuous." >&2
  echo "  Run it by hand on \$WORK/r to see which check fails; fresh() is probably missing a path." >&2
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
p = sys.argv[1]; s = open(p).read()
old = '<h2 id="install-title">Get started in seconds.</h2>'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old,
              '<h2 id="install-title">Get started in seconds.</h2>\n'
              "      <p>Also runs in OpenAI Codex CLI.</p>", 1)  # IDSTACK_CLI_LEAK_ALLOW
open(p,'w').write(s)
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
p = sys.argv[1]; s = open(p).read()
old = '<h2 id="install-title">Get started in seconds.</h2>'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old,
              '<h2 id="install-title">Get started in seconds.</h2>\n'
              "      <p>Reviewed by Gemini Code Assist. Also runs in Codex CLI.</p>", 1)  # IDSTACK_CLI_LEAK_ALLOW
open(p,'w').write(s)
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

# 23. The notch-safe gutter drops back to a plain var(--pad-x), leaving .section
# (which wraps every content region) under the notch once viewport-fit=cover is
# set. This is the defect the shared container rule fixed.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """    .nav, .section, .hero, .footer {
      max-width: var(--max);
      margin-inline: auto;
      padding-inline:
        max(var(--pad-x), env(safe-area-inset-left))
        max(var(--pad-x), env(safe-area-inset-right));
    }"""
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
new = """    .nav, .section, .hero, .footer {
      max-width: var(--max);
      margin-inline: auto;
      padding-inline: var(--pad-x);
    }"""
open(p, 'w').write(s.replace(old, new, 1))
PY
expect_fail "notch-safe gutter loses its env() inset" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 24. A later :root override ships 30px touch targets below 480px while the 44px
# declaration is still present, so an existence check on --tap-min would pass.
# Proves the assertion requires exactly one declaration, not merely the string.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "  </style>"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    @media (max-width: 480px) { :root { --tap-min: 30px; } }\n" + old, 1)
open(p, 'w').write(s)
PY
expect_fail "a later override shrinks the 44px touch target" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 25. The viewport clip returns. It hides horizontal overflow instead of
# preventing it, so a regression becomes unreachable content rather than a
# visible bug -- measured in Chrome as 305px of the install command unreachable
# when an element does overflow.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "    html { scroll-behavior: smooth; }"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    html { scroll-behavior: smooth; overflow-x: clip; }", 1)
open(p, 'w').write(s)
PY
expect_fail "root overflow-x clip masks page overflow" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 26. The 44px floor is hoisted out of the unconditional cascade into a
# min-width query, so phones get no floor at all while the token and the
# declaration both still exist. This is the original scoping bug in mirror
# image, and an assertion that scans the whole sheet cannot see it.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "      min-height: var(--tap-min);\n      color: var(--ink-soft);"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "      color: var(--ink-soft);", 1)
s = s.replace("  </style>",
              "    @media (min-width: 900px) { .copy-btn { min-height: var(--tap-min); } }\n  </style>", 1)
open(p, 'w').write(s)
PY
expect_fail "touch-target floor hoisted into a desktop-only query" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 27. A second <style> block overrides the token. Every assertion reads the
# stylesheet, so a scanner that stops at the first block is blind to it --
# and that blindness would also defeat mutation 24.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "</head>"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "<style>:root{--tap-min:30px}</style>\n</head>", 1)
open(p, 'w').write(s)
PY
expect_fail "a second <style> block overrides the touch-target token" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 28. The breakpoint rule moves into `@media not all and (max-width: 480px)`,
# which applies ABOVE 480px. The prelude still contains the breakpoint string,
# so a substring match counts it as scoped when it is inverted.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """    @media (max-width: 480px) {
      .pipeline-flow { grid-template-columns: 1fr; }
    }"""
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, """    @media not all and (max-width: 480px) {
      .pipeline-flow { grid-template-columns: 1fr; }
    }""", 1)
open(p, 'w').write(s)
PY
expect_fail "an inverted @media prelude passes as breakpoint-scoped" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 29. A later base rule at equal specificity re-declares the touch-target floor
# in px. The token is untouched and the first .copy-btn block still reads
# var(--tap-min), so a positive check that stops at the first match cannot see
# it -- only counting the declarations sheet-wide can.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "  </style>"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    .copy-btn { min-height: 30px; }\n" + old, 1)
open(p, 'w').write(s)
PY
expect_fail "a later base rule outranks the touch-target token" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 30. The viewport clip returns as the `overflow` shorthand rather than the
# `overflow-x` longhand. Same rendered effect, different spelling.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "    html { scroll-behavior: smooth; }"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    html { scroll-behavior: smooth; overflow: clip; }", 1)
open(p, 'w').write(s)
PY
expect_fail "root overflow shorthand masks page overflow" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 31. The mobile breakpoint stops collapsing to one column. `1fr 1fr` still
# contains `1fr`, so an unanchored match treats the two-column regression as
# satisfying the single-column assertion.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "      .pipeline-flow { grid-template-columns: 1fr; }"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "      .pipeline-flow { grid-template-columns: 1fr 1fr; }", 1)
open(p, 'w').write(s)
PY
expect_fail "pipeline stays two-column at the mobile breakpoint" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 32. A selector LIST shrinks the touch target below 480px. The text suite anchors every
# touch-target guard on the single-selector spelling `.copy-btn {`, so `.copy-btn, .btn-badge {`
# is invisible to all three of its checks at once and it exits 0. Only the rendered suite
# catches this, by measuring the button at 375px. This mutation is the reason
# test-rendered-landing.js exists: it forbids the outcome, not the spelling.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "  </style>"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    @media (max-width: 480px) { .copy-btn, .btn-badge { min-height: 30px; } }\n" + old, 1)
open(p, 'w').write(s)
PY
expect_fail "a selector list shrinks the touch target past the text guard" "$WORK/r/test/smoke-test.sh" "$WORK/r"

echo ""
echo "guarded: $pass   NOT guarded: $fail   skipped: $skip"
[ "$fail" -eq 0 ]

