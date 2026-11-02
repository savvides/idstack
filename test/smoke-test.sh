#!/usr/bin/env bash
# idstack smoke test — verifies installation is correct
set -e

. "$(dirname "$0")/test-helper.sh"

# Verify the repo this script lives in (test/smoke-test.sh -> repo root is "..").
# Override with $1 to point at a different checkout (CI fixtures, etc.).
IDSTACK_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"

# Single source of truth for the released version — all version assertions
# derive from VERSION so a release bump can't leave this test stale.
VER="$(tr -d '[:space:]' < "$IDSTACK_DIR/VERSION" 2>/dev/null || true)"
VER3="${VER%.*}"  # 4-component 3.2.0.0 -> 3-component 3.2.0 (JSON-LD softwareVersion)

echo "idstack smoke test"
echo "  idstack dir: $IDSTACK_DIR"
echo ""

check "idstack repo dir is reachable" "[ -d '$IDSTACK_DIR' ]"

# Check plugin + marketplace manifests — both are required for the Claude Code
# marketplace install flow that ./setup drives.
check "plugin manifest exists" "[ -f '$IDSTACK_DIR/.claude-plugin/plugin.json' ]"
check "plugin manifest has name" "grep -q '\"name\": \"idstack\"' '$IDSTACK_DIR/.claude-plugin/plugin.json'"
check "marketplace manifest exists" "[ -f '$IDSTACK_DIR/.claude-plugin/marketplace.json' ]"
check "marketplace manifest names the idstack plugin" "grep -q '\"name\": \"idstack\"' '$IDSTACK_DIR/.claude-plugin/marketplace.json'"

# Version agreement — VERSION is the source of truth; plugin.json is what the
# marketplace actually serves (users only receive fixes when it bumps), and
# CHANGELOG must document every released version.
check "VERSION file exists and is non-empty" "[ -s '$IDSTACK_DIR/VERSION' ]"
check "plugin.json version matches VERSION ($VER)" "grep -qF '\"version\": \"$VER\"' '$IDSTACK_DIR/.claude-plugin/plugin.json'"
check "CHANGELOG.md has an entry for v$VER" "grep -qF '## v$VER' '$IDSTACK_DIR/CHANGELOG.md'"

# Check all skill SKILL.md files are reachable under skills/
SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team pipeline learn start"
for skill in $SKILLS; do
  check "skills/$skill/SKILL.md reachable" "[ -f '$IDSTACK_DIR/skills/$skill/SKILL.md' ]"
done

# Check YAML frontmatter has required fields (bare names, no idstack- prefix)
for skill in $SKILLS; do
  check "$skill has name: $skill" "grep -q '^name: $skill$' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
  check "$skill has description: field" "grep -q '^description:' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
  check "$skill has allowed-tools: field" "grep -q '^allowed-tools:' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check evidence file exists
check "evidence/references.md exists" "[ -f '$IDSTACK_DIR/evidence/references.md' ]"

# Check bin scripts exist and are executable
for script in idstack-migrate idstack-timeline-log idstack-learnings idstack-status idstack-gen-skills idstack-doctor idstack-slugify idstack-update-check idstack-ste-check idstack-report-section; do
  check "bin/$script exists" "[ -f '$IDSTACK_DIR/bin/$script' ]"
  check "bin/$script is executable" "[ -x '$IDSTACK_DIR/bin/$script' ]"
done

# Bash syntax gate for the shell entry points (idstack-manifest-merge is python).
for script in setup bin/idstack-doctor bin/idstack-gen-skills bin/idstack-learnings bin/idstack-status bin/idstack-migrate bin/idstack-slugify bin/idstack-update-check bin/lib/plugin-status.sh test/test-helper.sh; do
  check "$script passes bash -n" "bash -n '$IDSTACK_DIR/$script'"
done

# Every suite takes its counters from test/test-helper.sh. Nine suites had
# each grown their own copy, and they had already drifted — two spelled the
# helper `assert`, and one swallowed failure output entirely, so CI reported a
# bare FAIL with no diagnostics. A local `PASS=0` is how that regrows.
check "test-helper.sh exists" "[ -f '$IDSTACK_DIR/test/test-helper.sh' ]"
for suite in smoke-test integration-test test-manifest-merge \
             test-plugin-status test-preamble-python test-setup test-doctor test-status \
             test-skill-shell-zsh; do
  check "test/$suite.sh sources the shared helper" \
    "grep -q 'test-helper.sh' '$IDSTACK_DIR/test/$suite.sh'"
  check "test/$suite.sh defines no local counters" \
    "! grep -qE '^(PASS|FAIL|TOTAL)=0' '$IDSTACK_DIR/test/$suite.sh'"
done

# Check template system
check "templates/preamble.md exists" "[ -f '$IDSTACK_DIR/templates/preamble.md' ]"
check "templates/report-format.md exists" "[ -f '$IDSTACK_DIR/templates/report-format.md' ]"
check "templates/snippets/idstack-resolve.sh exists" "[ -f '$IDSTACK_DIR/templates/snippets/idstack-resolve.sh' ]"
check "templates/manifest-schema.md exists" "[ -f '$IDSTACK_DIR/templates/manifest-schema.md' ]"
check "templates/manifest-schema.md is non-empty" "[ -s '$IDSTACK_DIR/templates/manifest-schema.md' ]"
check "templates/report.md.tmpl exists" "[ -f '$IDSTACK_DIR/templates/report.md.tmpl' ]"
check "templates/index.md.tmpl exists" "[ -f '$IDSTACK_DIR/templates/index.md.tmpl' ]"
check "templates/report.md.tmpl mentions {{skill_name}}" "grep -q '{{skill_name}}' '$IDSTACK_DIR/templates/report.md.tmpl'"
check "templates/index.md.tmpl mentions {{project_name}}" "grep -q '{{project_name}}' '$IDSTACK_DIR/templates/index.md.tmpl'"
# Reports are Markdown now. The HTML templates and their stylesheet are gone,
# and nothing may bring them back.
check "no HTML report template or report stylesheet in templates/" \
  "[ ! -e '$IDSTACK_DIR/templates/report.html.tmpl' ] && [ ! -e '$IDSTACK_DIR/templates/index.html.tmpl' ] && [ ! -e '$IDSTACK_DIR/templates/assets/idstack.css' ]"
for skill in $SKILLS; do
  check "$skill has SKILL.md.tmpl" "[ -f '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' ]"
done

# Landing page (docs/index.html) - "Evidence Instrument" invariants (DESIGN.md,
# 2026-11-01). The landing uses the report system's Proof tokens and fonts with a
# prussian hero. Guards against regressions: the dark/indigo look or its gradients
# coming back, a theme toggle creeping in (dark mode follows prefers-color-scheme),
# the fonts drifting from the reports, or the stale bare-clone install string
# returning (see dea7ebc).
LANDING="$IDSTACK_DIR/docs/index.html"
check "landing/index.html exists" "[ -f '$LANDING' ]"
check "landing: ivory Proof background (#faf8f3)" "grep -q -- '--bg: *#faf8f3' '$LANDING'"
check "landing: prussian hero ground (#163a4a)" "grep -q -- '--hero-bg: *#163a4a' '$LANDING'"
check "landing: no theme toggle" "! grep -q 'theme-toggle' '$LANDING'"
check "landing: no data-theme attribute or blocks" "! grep -q 'data-theme' '$LANDING'"
check "landing: dark mode follows prefers-color-scheme" "grep -q 'prefers-color-scheme: dark' '$LANDING'"
# Read the URL from DESIGN.md so the two cannot drift; an empty match would make
# grep -F pass vacuously, so the URL's presence is its own check.
DESIGN_FONTS_URL="$(grep -o 'https://fonts.googleapis.com/css2[^`]*' "$IDSTACK_DIR/DESIGN.md" | head -1)"
check "DESIGN.md carries a Google Fonts URL" "[ -n '$DESIGN_FONTS_URL' ]"
check "landing: loads the Google Fonts URL from DESIGN.md" "grep -qF '$DESIGN_FONTS_URL' '$LANDING'"
check "landing: no gradients" "! grep -q 'linear-gradient' '$LANDING'"
# In HTML the '&&' is entity-escaped as '&amp;&amp;', so don't grep the literal '&&'.
# Assert the repo clone + 'cd idstack' (current marketplace form); the legacy
# ~/.claude/plugins/idstack form is caught by the next check. Escaping-independent.
check "landing: marketplace install command present" "grep -q 'github.com/savvides/idstack.git' '$LANDING' && grep -q 'cd idstack' '$LANDING'"
check "landing: no legacy plugins-dir install string" "! grep -q '.claude/plugins/idstack' '$LANDING'"
check "landing: current version v$VER present" "grep -qF 'v$VER' '$LANDING'"
check "landing: structured-data softwareVersion $VER" "grep -qF '\"softwareVersion\": \"$VER\"' '$LANDING'"
check "landing: Output section present" "grep -q 'id=.output.' '$LANDING'"
# No transparent text. The landing once clipped gradients into its headings and
# needed a solid fallback color; the gradients are gone, and this keeps a bare
# `color: transparent` from returning (the leading [^-] excludes
# `-webkit-text-fill-color: transparent`).
check "landing: no transparent text (no bare 'color: transparent')" \
  "! grep -Eq '[^-]color: *transparent' '$LANDING'"

# The landing page's evidence cards restate evidence/references.md: a study count
# and a tier range per domain. They were hand-maintained and three had drifted —
# two advertised T2 for domains whose strongest evidence is T3, which is the one
# error idstack cannot afford, since tier honesty is the whole product. Derived
# from the reference file now, so the numbers cannot disagree.
#
# Skipped without python3 rather than silently passing; a crash in the checker
# becomes drift text so it fails loudly instead of vacuously.
EVIDENCE_DRIFT=""
if command -v python3 &>/dev/null; then
  EVIDENCE_DRIFT="$(python3 "$IDSTACK_DIR/test/check-evidence-cards.py" "$IDSTACK_DIR" 2>&1)" \
    || EVIDENCE_DRIFT="evidence-card checker failed:
$EVIDENCE_DRIFT"
  check "landing evidence cards match evidence/references.md" \
    "if [ -n \"\$EVIDENCE_DRIFT\" ]; then printf '%s\n' \"\$EVIDENCE_DRIFT\"; false; fi"
fi

# Skills and templates cite evidence as "[Code-N] [Tn]", and the reports copy
# those citations. Four skills cited the two Sweller papers ([CogLoad-4],
# [CogLoad-19]) as T1, but references.md files both as T5. The tier is read
# from the reference file, as for the cards above. test-evidence-labels.mjs
# checks the extension. Same python3 guard and crash handling as the cards.
TIER_DRIFT=""
if command -v python3 &>/dev/null; then
  TIER_DRIFT="$(python3 "$IDSTACK_DIR/test/check-citation-tiers.py" "$IDSTACK_DIR" 2>&1)" \
    || TIER_DRIFT="citation-tier checker failed:
$TIER_DRIFT"
  check "skill and template citations state their evidence/references.md tier" \
    "if [ -n \"\$TIER_DRIFT\" ]; then printf '%s\n' \"\$TIER_DRIFT\"; false; fi"
  # A clean repo proves nothing about a form the checker cannot see. These tests
  # give it codes separated by commas and a citation that a line break splits.
  check "citation-tier checker unit tests pass" "python3 '$IDSTACK_DIR/test/test-citation-tiers.py'"
fi

check "doc accuracy check passes" "python3 '$IDSTACK_DIR/test/check-doc-accuracy.py' '$IDSTACK_DIR'"


# Open Graph card template (docs/og-template.html) - same rules as the landing:
# the prussian hero ground, no gradients, no transparent text.
OG_TEMPLATE="$IDSTACK_DIR/docs/og-template.html"
check "og-template.html exists" "[ -f '$OG_TEMPLATE' ]"
check "og-template: prussian hero ground (#163a4a)" "grep -q -- '--hero-bg: *#163a4a' '$OG_TEMPLATE'"
check "og-template: no transparent text (no bare 'color: transparent')" \
  "! grep -Eq '[^-]color: *transparent' '$OG_TEMPLATE'"
check "og-template: no gradients" "! grep -q 'linear-gradient' '$OG_TEMPLATE'"

# Slugify behavior — pinned cases protect the slug derivation rule that the manifest
# schema and every skill's report-write block depend on.
check "idstack-slugify: 'Introduction to Biology 101' → introduction-to-biology-101" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' 'Introduction to Biology 101')\" = 'introduction-to-biology-101' ]"
check "idstack-slugify: empty input → untitled-course" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' '')\" = 'untitled-course' ]"
check "idstack-slugify: '!!!' → untitled-course" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' '!!!')\" = 'untitled-course' ]"
check "idstack-slugify: unicode ASCII-folds — 'Géographie I' → geographie-i" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' 'Géographie I')\" = 'geographie-i' ]"
# --from-manifest owns the project_name -> slug rule for the skills and the
# dashboard; each once read the name with its own inline Python, and the copies
# disagreed on the needs_analysis.project_name fallback.
SLUG_TMP=$(mktemp -d)
printf '%s' '{"project_name": "Intro Bio"}' > "$SLUG_TMP/a.json"
printf '%s' '{"needs_analysis": {"project_name": "Old Name"}}' > "$SLUG_TMP/b.json"
check "idstack-slugify --from-manifest reads project_name" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' --from-manifest '$SLUG_TMP/a.json')\" = 'intro-bio' ]"
check "idstack-slugify --from-manifest falls back to needs_analysis.project_name" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' --from-manifest '$SLUG_TMP/b.json')\" = 'old-name' ]"
check "idstack-slugify --from-manifest on a missing manifest → untitled-course" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' --from-manifest '$SLUG_TMP/none.json')\" = 'untitled-course' ]"
rm -rf "$SLUG_TMP"
check "no skill template reads project_name with inline Python" \
  "! grep -l \"get('project_name'\" $IDSTACK_DIR/skills/*/SKILL.md.tmpl | grep -q ."
check "idstack-slugify: implicit stdin pipeline" \
  "[ \"\$(echo 'Course via Implicit Stdin' | '$IDSTACK_DIR/bin/idstack-slugify')\" = 'course-via-implicit-stdin' ]"
check "idstack-slugify: explicit dash stdin pipeline" \
  "[ \"\$(echo 'Course via Dash Stdin' | '$IDSTACK_DIR/bin/idstack-slugify' -)\" = 'course-via-dash-stdin' ]"
check "idstack-slugify: emoji and non-ASCII characters stripped" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' 'Course 🚀 101: Intro to AI ✨')\" = 'course-101-intro-to-ai' ]"

# Skills that write per-skill Markdown reports must reference the new export folder pattern
# and use the slugify helper (not the legacy .idstack/reports/<skill>.md path).
REPORT_PRODUCING_SKILLS="needs-analysis learning-objectives assessment-design course-builder course-quality-review course-import course-export accessibility-review red-team"
for skill in $REPORT_PRODUCING_SKILLS; do
  check "$skill SKILL.md.tmpl references .idstack/exports/" "grep -q '\.idstack/exports/' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl calls idstack-slugify" "grep -q 'idstack-slugify' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl writes a .md report" "grep -qE '_REPORT_PATH=\"\\\$_EXPORT_DIR/$skill\.md\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  # report-format.md requires a "Top recommendations" section in every report.
  # The closing Step Review writes it, so the match is that Step review line.
  check "$skill SKILL.md.tmpl includes Top recommendations" "grep -qF 'Section: \`## Summary\`, \`## Top recommendations\`, \`## Limitations\` and \`## Next steps\`' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# Manifest write-path contract: every manifest writer goes through the merge
# tool, and every merge call passes --create. Skills run standalone; a merge
# without it exits 4 on a missing manifest and the results are never saved
# (course-builder once ran a bare migrate that made nothing). Multi-section
# writers use one call so the write is atomic.
MANIFEST_WRITERS="needs-analysis course-import learning-objectives assessment-design course-builder course-quality-review accessibility-review red-team course-export"
for skill in $MANIFEST_WRITERS; do
  check "$skill SKILL.md.tmpl uses idstack-manifest-merge" "grep -q 'idstack-manifest-merge\" --create' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl has no merge call without --create" "! grep 'bin/idstack-manifest-merge\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' | grep -vq -- '--create'"
  check "$skill SKILL.md.tmpl does not seed the manifest with idstack-migrate" "! grep -q 'idstack-migrate' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
for skill in needs-analysis course-import; do
  check "$skill SKILL.md.tmpl writes its sections in one merge call" "grep -q -- '--section context --payload' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl sets project_name through the merge tool" "grep -q -- '--set project_name=' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# The learning_preferences_note text has two copies: the schema default and the
# needs-analysis step that fills it. Both are fixed STE text and must keep the
# same words, or the manifest says one thing and the skill writes another.
NOTE_SYNC_PY='import re, sys
d = sys.argv[1]
schema = open(d + "/templates/manifest-schema.md", encoding="utf-8").read()
skill = open(d + "/skills/needs-analysis/SKILL.md.tmpl", encoding="utf-8").read()
a = re.search(r"\x22learning_preferences_note\x22: \x22([^\x22]+)\x22", schema)
b = re.search(r"always populated with:\s*\x22([^\x22]+)\x22", skill)
same = a and b and " ".join(a.group(1).split()) == " ".join(b.group(1).split())
sys.exit(0 if same else 1)'
check "learning_preferences_note has the same words in manifest-schema.md and needs-analysis" "python3 -c '$NOTE_SYNC_PY' '$IDSTACK_DIR'"

# needs-analysis and course-import write project_name, and they write the
# report before the manifest. A slug read from the manifest at that point is
# empty on a first run: the report went to exports/untitled-course/ and every
# later skill wrote to exports/<real-slug>/. The slug must come from the
# course title of the session, the same text the skill then writes as project_name.
SLUG_SOURCE_PY='import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
blocks = [b for b in re.findall(r"```bash\n(.*?)```", s, re.S) if "idstack-slugify" in b]
ok = len(blocks) == 1 and ".idstack/project.json" not in blocks[0] and "<project name>" in blocks[0]
sys.exit(0 if ok else 1)'
for skill in needs-analysis course-import; do
  check "$skill takes the report slug from the course title, not the manifest it writes later" "python3 -c '$SLUG_SOURCE_PY' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
# If the model runs the slug block with <project name> still in it, the block must
# stop before it makes a folder. A warning alone left an empty exports/project-name/.
# Run the generated block in an empty directory, as a skill does.
SLUG_GUARD_PY='import os, re, shutil, subprocess, sys, tempfile
s = open(sys.argv[1], encoding="utf-8").read()
block = [b for b in re.findall(r"```bash\n(.*?)```", s, re.S) if "idstack-slugify" in b][0]
env = dict(os.environ, IDSTACK_HOME=sys.argv[2])
env.pop("CLAUDE_PLUGIN_ROOT", None)
d = tempfile.mkdtemp()
r = subprocess.run(["bash", "-c", block], cwd=d, env=env, stdout=subprocess.PIPE,
                   stderr=subprocess.STDOUT, universal_newlines=True)
made = os.path.exists(os.path.join(d, ".idstack", "exports", "project-name"))
shutil.rmtree(d)
print(r.stdout)
sys.exit(0 if "PROJECT_NAME_NOT_SET" in r.stdout and r.returncode != 0 and not made else 1)'
for skill in needs-analysis course-import; do
  check "$skill stops before it makes a folder for an unreplaced course title" "python3 -c '$SLUG_GUARD_PY' '$IDSTACK_DIR/skills/$skill/SKILL.md' '$IDSTACK_DIR'"
done

# Canonical manifest section names only — these five non-canonical tokens once
# shipped in re-run checks and prose, making re-run detection dead in 5 skills.
for skill in $SKILLS; do
  check "$skill SKILL.md.tmpl free of non-canonical section names" "! grep -E '\b(assessment_design|course_builder|course_export|course_import|course_quality_review)\b' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# User-facing skill references must be namespaced /idstack:<skill>. A bare
# /skill is not a command Claude Code resolves — plugin skills are addressed
# as plugin:skill. This includes the frontmatter description: Claude Code
# shows it in the skill list and the model reads it to route requests, so a
# bare name there gets copied into chat as a command that does nothing.
#
# This matched only the backticked form until v3.3.0.1, which let three
# unbackticked examples sit in the preamble's context-recovery section — the
# model copied them and told users to run "/assessment-design", which does
# nothing. The leading class covers a command position: line start, whitespace,
# an opening quote/paren, or a backtick. It deliberately does NOT match a `/`
# preceded by a path character, so `.idstack/exports/<slug>/red-team.md`
# stays legal, and it can't match `/idstack:<skill>` because the skill name
# there does not follow the slash.
BARE_SLASH_RE='(^|[[:space:]"(`])/(needs-analysis|learning-objectives|assessment-design|course-builder|course-quality-review|accessibility-review|red-team|course-export|course-import|pipeline|learn|start)\b'
for skill in $SKILLS; do
  check "$skill SKILL.md.tmpl (frontmatter and body) free of bare /skill refs" "! grep -qE '$BARE_SLASH_RE' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill description says when to use it" \
    "awk '/^description:/{f=1; next} f && /^[a-z-]+:/{exit} f' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' | tr -s ' \n' '  ' | grep -q 'Use when'"
done
# The preamble has no frontmatter — scan the whole file.
check "preamble free of bare /skill refs" "! grep -qE '$BARE_SLASH_RE' '$IDSTACK_DIR/templates/preamble.md'"
check "no '/idstack <skill>' space typos in templates" "! grep -rE '/idstack [a-z]' $IDSTACK_DIR/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md'"
check "pipeline status table uses /idstack: prefixes" "grep -qF '[done] /idstack:needs-analysis' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"
check "pipeline invokes children with the idstack: namespace" "grep -qF 'skill: \"idstack:needs-analysis\"' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"
check "start hands off with the idstack: namespace" "grep -qF 'skill: \"idstack:course-import\"' '$IDSTACK_DIR/skills/start/SKILL.md.tmpl'"
# start runs before any course work. A timeline event from it would become
# LAST_SKILL and spoil every welcome-back and next-step line.
check "start does not log to the timeline" "[ -f '$IDSTACK_DIR/skills/start/SKILL.md.tmpl' ] && ! grep -q 'idstack-timeline-log' '$IDSTACK_DIR/skills/start/SKILL.md.tmpl'"
check "start releases its limits when it hands off" "grep -qF 'the limits of this' '$IDSTACK_DIR/skills/start/SKILL.md.tmpl'"

# Canonical $_IDSTACK resolution: templates use the {{IDSTACK_RESOLVE}}
# placeholder, never a hand-rolled derivation (two skills once drifted to a
# path list that missed the marketplace cache — the way most users install).
RESOLVE_LINE="$(grep -m1 '^for _p in' "$IDSTACK_DIR/templates/snippets/idstack-resolve.sh" 2>/dev/null || true)"
check "resolve snippet has the canonical for-chain" "[ -n \"\$RESOLVE_LINE\" ]"
check "resolve snippet includes the marketplace cache path" "grep -q 'plugins/cache/idstack' '$IDSTACK_DIR/templates/snippets/idstack-resolve.sh'"
# The preamble once kept hand copies of the chain, and one drifted unseen. Now
# gen-skills expands the placeholder there too, and no hand-written chain is left.
check "preamble uses {{IDSTACK_RESOLVE}}" "grep -q '{{IDSTACK_RESOLVE}}' '$IDSTACK_DIR/templates/preamble.md'"
check "no hand-written resolve chain in the preamble or schema" "! grep -qE '^for _[a-z]+ in ' '$IDSTACK_DIR/templates/preamble.md' '$IDSTACK_DIR/templates/manifest-schema.md'"
check "every generated resolve chain is the snippet's" "! grep -h '^for _[a-z]* in ' $IDSTACK_DIR/skills/*/SKILL.md | grep -vqxF \"\$RESOLVE_LINE\""
for skill in $SKILLS; do
  check "$skill SKILL.md.tmpl uses {{IDSTACK_RESOLVE}}" "grep -q '{{IDSTACK_RESOLVE}}' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl does not hand-roll _IDSTACK" "! grep -Eq '_IDSTACK:?=' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
check "no legacy .claude/plugins/idstack path in skill templates" "! grep -rF '.claude/plugins/idstack' $IDSTACK_DIR/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md'"
# Claude Code writes the plugin root into a skill's text only where it finds the
# exact token ${CLAUDE_PLUGIN_ROOT}. The Bash tool's shell does not have the
# variable, and a token with a default (":-") stays as it is. The chain used
# that form until this check, so every skill fell through to the newest cache
# dir: under --plugin-dir, and for a marketplace added from a local path, that
# was an old install with no bin/idstack-ste-check. Do to the generated text
# what Claude Code does, then run the first chain with a stale cache present.
RESOLVE_SIM=$(mktemp -d)
mkdir -p "$RESOLVE_SIM/plugin" "$RESOLVE_SIM/home/.claude/plugins/cache/idstack/idstack/0.0.1.0"
RESOLVE_SIM_GOT=$({ awk '/^_IDSTACK=""$/{f=1} f{print} f && /^done$/{exit}' "$IDSTACK_DIR/skills/learn/SKILL.md" \
    | sed "s|\${CLAUDE_PLUGIN_ROOT}|$RESOLVE_SIM/plugin|g"; echo 'printf "%s" "$_IDSTACK"'; } \
  | env -u CLAUDE_PLUGIN_ROOT -u IDSTACK_HOME HOME="$RESOLVE_SIM/home" bash)
check "the substituted plugin root wins over a stale cache install" "[ '$RESOLVE_SIM_GOT' = '$RESOLVE_SIM/plugin' ]"
rm -rf "$RESOLVE_SIM"
check "no resolve chain gives the plugin root a default" "! grep -rlF '\${CLAUDE_PLUGIN_ROOT:-' '$IDSTACK_DIR/templates' $IDSTACK_DIR/skills/*/SKILL.md.tmpl $IDSTACK_DIR/skills/*/SKILL.md"

# Pipeline orchestrator must produce index.md under the course folder.
# Use -E (extended regex) so the `|` alternation works under BSD grep too;
# in BRE, `\|` is a GNU extension and silently matches nothing on BSD.
check "pipeline SKILL.md.tmpl produces index.md in exports/<slug>/" "grep -qE 'exports/.*index\.md|\$_EXPORT_DIR/index\.md' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"

# Schema-drift regression: skills that share the canonical schema must use the
# {{MANIFEST_SCHEMA}} substitution rather than re-inlining their own copy. Only
# the skills that build several sections inline it; the single-section writers
# Read the file from the plugin root when they need another section's shape.
SCHEMA_HOST_SKILLS="needs-analysis course-import"
for skill in $SCHEMA_HOST_SKILLS; do
  check "$skill SKILL.md.tmpl uses {{MANIFEST_SCHEMA}}" "grep -q '{{MANIFEST_SCHEMA}}' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill generated SKILL.md inlines canonical schema (version 1.4)" "grep -q '\"version\": \"1.4\"' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done
for skill in learning-objectives assessment-design course-builder course-quality-review course-export accessibility-review red-team; do
  check "$skill SKILL.md.tmpl reads the schema from the plugin root" "grep -qF '\${CLAUDE_PLUGIN_ROOT}/templates/manifest-schema.md' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# Schema-drift regression: drifted field names must NOT appear in any SKILL.md.tmpl
# (they were the source of issues #19, #23, etc. in the TMC-430 test report).
DRIFT_FIELDS='red_team_audit\.summary\.critical_count\|accessibility\.score\.overall_pct\|_import_quality_flags'
for skill in $SKILLS; do
  check "$skill SKILL.md.tmpl free of drifted field names" "! grep -E '$DRIFT_FIELDS' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# Imported-course mode regression (issues #7, #13, #14): each affected skill must
# branch on import_metadata.source and announce the chosen mode.
MODE_AWARE_SKILLS="needs-analysis assessment-design course-builder"
for skill in $MODE_AWARE_SKILLS; do
  check "$skill branches on import_metadata.source" "grep -q 'import_metadata.source' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# Manifest-merge tool must exist and be executable, and its unit tests must pass.
check "bin/idstack-manifest-merge exists" "[ -f '$IDSTACK_DIR/bin/idstack-manifest-merge' ]"
check "bin/idstack-manifest-merge is executable" "[ -x '$IDSTACK_DIR/bin/idstack-manifest-merge' ]"
if [ -x "$IDSTACK_DIR/test/test-manifest-merge.sh" ]; then
  check "manifest-merge unit tests pass" "'$IDSTACK_DIR/test/test-manifest-merge.sh'"
fi

# `claude plugin list` parsing, also extracted to bin/lib/ so it is testable.
# A fixed-size window here once reported a disabled idstack as enabled.
check "bin/lib/plugin-status.sh exists" "[ -f '$IDSTACK_DIR/bin/lib/plugin-status.sh' ]"
check "idstack-doctor sources the shared plugin-status parser" "grep -q 'lib/plugin-status.sh' '$IDSTACK_DIR/bin/idstack-doctor'"
check "idstack-doctor no longer uses a fixed -A4 window" "! grep -q 'grep -A4' '$IDSTACK_DIR/bin/idstack-doctor'"
if [ -x "$IDSTACK_DIR/test/test-plugin-status.sh" ]; then
  check "plugin-status unit tests pass" "'$IDSTACK_DIR/test/test-plugin-status.sh'"
fi
# Hooked in here as well as in CI because release.yml's gate runs only
# smoke-test.sh — doctor's branches would otherwise be unverified at release.
if [ -x "$IDSTACK_DIR/test/test-doctor.sh" ]; then
  check "doctor behavioral tests pass" "'$IDSTACK_DIR/test/test-doctor.sh'"
fi
# Skill blocks run in zsh for most macOS users; same reasoning as doctor above.
if [ -x "$IDSTACK_DIR/test/test-skill-shell-zsh.sh" ]; then
  check "skill bash blocks work in bash and zsh" "'$IDSTACK_DIR/test/test-skill-shell-zsh.sh'"
fi
# --readiness is the pre-export gate; same reasoning as doctor above.
if [ -x "$IDSTACK_DIR/test/test-status.sh" ]; then
  check "idstack-status behavioral tests pass" "'$IDSTACK_DIR/test/test-status.sh'"
fi

# The ASD-STE100 checker. Skills run it on each file they write, so a false
# positive costs the user three rewrite passes on every run.
if command -v python3 &>/dev/null; then
  check "ste checker unit tests pass" "python3 '$IDSTACK_DIR/test/test-ste-check.py'"
fi
# Each skill runs the checker on the files it writes for a person. The match is
# the bash call itself, not the prose around it, so a step that loses its
# command fails here even when the text that names the check stays.
for skill in $SKILLS; do
  case "$skill" in course-builder|course-export|red-team) want=2 ;; start) want=0 ;; *) want=1 ;; esac
  # grep -c exits 1 on zero matches; without "|| true", set -e ends the run with no FAIL line.
  got=$(grep -cF '"$_IDSTACK/bin/idstack-ste-check"' "$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl" || true)
  check "$skill SKILL.md.tmpl runs the ste checker at all $want check steps" "[ '$got' -eq $want ]"
done
# A check step must tell an install with no checker apart from a missing
# python3. Under --plugin-dir the chain once found a 3.5.1.0 install with no
# checker, and the step printed the python3 token. The skill then said only
# "the check did not run", and nothing told the user that the install was old.
STE_NOCHK=$(mktemp -d)
for skill in $SKILLS; do
  check "$skill check steps name an install that has no checker" \
    "grep -F '\"\$_IDSTACK/bin/idstack-ste-check\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' | while IFS= read -r l; do _IDSTACK='$STE_NOCHK' bash -c \"\$l\" | grep -qxF 'STE_CHECK_MISSING: $STE_NOCHK' || exit 1; done"
done
rm -rf "$STE_NOCHK"

# The Step Review. Each report skill shows the output of each step in a table,
# the user approves it, and bin/idstack-report-section adds it to the report.
if command -v python3 &>/dev/null; then
  check "report-section unit tests pass" "python3 '$IDSTACK_DIR/test/test-report-section.py'"
fi
check "preamble has the Step Review section" "grep -q '^## Preamble: Step Review' '$IDSTACK_DIR/templates/preamble.md'"
# The concise setting once told skills to drop citations. Each table row now
# needs its citation, so that text must not come back.
check "preamble no longer tells skills to skip citations" "! grep -qF 'Skip evidence citations inline' '$IDSTACK_DIR/templates/preamble.md'"
# One "**Step review:**" line for each review point. A lost line is a step that
# goes into the report with no approval, so the counts are exact.
for skill in $REPORT_PRODUCING_SKILLS; do
  case "$skill" in
    needs-analysis) want=7 ;; learning-objectives) want=5 ;; assessment-design) want=11 ;;
    course-builder) want=10 ;; course-quality-review) want=7 ;; accessibility-review) want=6 ;;
    red-team) want=10 ;; course-export) want=5 ;; course-import) want=6 ;;
  esac
  got=$(grep -c '^\*\*Step review:\*\*' "$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl" || true)
  check "$skill SKILL.md.tmpl has all $want Step review lines" "[ '$got' -eq $want ]"
  got=$(grep -cF 'idstack-report-section" init "$_REPORT_PATH"' "$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl" || true)
  check "$skill SKILL.md.tmpl starts the report with one init line" "[ '$got' -eq 1 ]"
  check "$skill SKILL.md.tmpl prints the evidence list path" \
    "grep -qF 'echo \"Evidence list: \$_IDSTACK/evidence/references.md\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl does not write the report in one step" \
    "! grep -qF 'Write the Markdown report at the path printed above' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
# An install with no helper must say so, as the ste-check steps do above. Each
# init line and each Step Review block of the preamble runs with an empty plugin.
RS_NOHELPER=$(mktemp -d)
for skill in $REPORT_PRODUCING_SKILLS; do
  check "$skill init line names an install that has no report helper" \
    "grep -F 'idstack-report-section\" init' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' | while IFS= read -r l; do _IDSTACK='$RS_NOHELPER' _REPORT_PATH=x.md bash -c \"\$l\" | grep -qxF 'REPORT_SECTION_MISSING: $RS_NOHELPER' || exit 1; done"
done
check "preamble has the four Step Review commands" \
  "[ \"\$(grep -cF '\"\$_IDSTACK/bin/idstack-report-section\" ' '$IDSTACK_DIR/templates/preamble.md')\" -eq 4 ]"
check "preamble Step Review has the approve command" \
  "grep -qF 'idstack-report-section\" approve \"<path>\"' '$IDSTACK_DIR/templates/preamble.md'"
check "preamble Step Review commands name an install that has no report helper" \
  "grep -F '\"\$_IDSTACK/bin/idstack-report-section\" ' '$IDSTACK_DIR/templates/preamble.md' | while IFS= read -r l; do _IDSTACK='$RS_NOHELPER' bash -c \"\$l\" | grep -qxF 'REPORT_SECTION_MISSING: $RS_NOHELPER' || exit 1; done"
rm -rf "$RS_NOHELPER"
# The user reads each table in the report file. A table in the chat or in the
# question card is too dense to read, so the preamble forbids both.
SR_TEXT=$(awk '/^## Preamble: Step Review/{f=1;next} /^## Preamble: /{f=0} f' "$IDSTACK_DIR/templates/preamble.md")
check "preamble Step Review keeps the table out of the chat" \
  "printf '%s' \"\$SR_TEXT\" | grep -qF 'Do not show the table in the chat.'"
check "preamble Step Review keeps the table out of the question" \
  "printf '%s' \"\$SR_TEXT\" | grep -qF 'Do not put the table, a row or a citation'"
# AskUserQuestion refuses an option with no description. A rule that removed
# the descriptions made every Step Review question fail in the app.
check "preamble Step Review gives each approval option its description" \
  "printf '%s' \"\$SR_TEXT\" | grep -qF '\"Approve\", with the description' && printf '%s' \"\$SR_TEXT\" | grep -qF '\"Change a row\", with the description' && printf '%s' \"\$SR_TEXT\" | grep -qF '\"Remove a row\", with the description'"
# In the app, a relative Markdown link opens the report. A report name written
# as text is not a link, and the model wrote it that way when step 5 said only
# "the report link".
check "preamble Step Review gives the exact report link line" \
  "printf '%s' \"\$SR_TEXT\" | grep -qF 'Read the draft in [<path>](<path>).'"
check "no template tells the model to leave out the option descriptions" \
  "! grep -iE 'do not add a description|without a description|no description' '$IDSTACK_DIR'/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md'"
check "no skill template tells the model to repeat a review table word for word" \
  "! grep -iE 'word for word' '$IDSTACK_DIR'/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md' | grep -qiE 'table|row|section|review'"
check "no skill template tells the model to show a review table in the chat" \
  "! grep -iE '(show|paste|display|give)[^.]*(table|rows)[^.]*(in|to) (the )?(chat|user)' '$IDSTACK_DIR'/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md' | grep -viE 'do not (show|paste|display|give)' | grep -q ."
# course-quality-review computes its scores from the approved rows, so the
# manifest write comes after the report is finished.
check "course-quality-review writes the manifest after the report finish" \
  "awk '/^Run the finish command of the Step Review/{f=NR} /^## Write Manifest/{w=NR} END{exit !(f && w > f)}' '$IDSTACK_DIR/skills/course-quality-review/SKILL.md.tmpl'"
# The red-team orchestrator writes only the findings file. The parent writes
# the report after the user approves each table.
RT_BRIEF=$(awk '/^<orchestrator-brief>/{f=1} f; /^<\/orchestrator-brief>/{exit}' "$IDSTACK_DIR/skills/red-team/SKILL.md.tmpl")
check "red-team orchestrator brief writes .red-team-findings.json" \
  "printf '%s' \"\$RT_BRIEF\" | grep -qF '.idstack/.red-team-findings.json'"
check "red-team orchestrator brief does not write the report" \
  "! printf '%s' \"\$RT_BRIEF\" | grep -qE '_REPORT_PATH|red-team\.md|idstack-report-section|Write the Markdown report'"
# Every report and the course dashboard copy the fixed labels in these two
# templates, so one bad label puts a problem in every report.
if command -v python3 &>/dev/null; then
  check "report and dashboard templates pass the ste checker" \
    "'$IDSTACK_DIR/bin/idstack-ste-check' --format markdown '$IDSTACK_DIR/templates/report.md.tmpl' '$IDSTACK_DIR/templates/index.md.tmpl'"
fi

# ./setup is what a new user runs first; it is exercised against a repo copy
# with a fake $HOME and a stub `claude`, never the real install.
if [ -x "$IDSTACK_DIR/test/test-setup.sh" ]; then
  check "setup behavioral tests pass" "'$IDSTACK_DIR/test/test-setup.sh' '$IDSTACK_DIR'"
fi

# The node-dependent suites. Guarded on node, not on the files' exec bits — those are tracked
# at 100755 so they never vary, while node is the part that can actually be absent. CI installs it
# (see .github/workflows/test.yml); the guard is for a bare machine. The SKIP lines matter: without
# them a node-less run just reports a smaller total than CLAUDE.md documents, with nothing saying why.
if command -v node &>/dev/null; then
  check "chrome extension tests pass" "'$IDSTACK_DIR/test/test-extension.sh'"
  check "responsive landing page tests pass" "node '$IDSTACK_DIR/test/test-responsive-landing.js'"
  # Renders the page in headless Chrome and asserts the OUTCOME (no sideways scroll, touch
  # targets, column counts) rather than the CSS text. Skips loudly without a browser; the
  # text suite above still runs. See test/test-rendered-landing.js for why both exist.
  check "rendered landing page tests pass" "node '$IDSTACK_DIR/test/test-rendered-landing.js'"
  # A Chrome that stops at startup must fail the test at once and give its exit code and last
  # output. Before, the test waited 12s and said only that no debugging port opened, so two CI
  # failures left no clue. Needs no real browser: CHROME_PATH points at a stub that stops.
  FAKE_CHROME_DIR=$(mktemp -d)
  printf '#!/bin/sh\necho "fake-chrome-startup-failure" >&2\nexit 3\n' > "$FAKE_CHROME_DIR/chrome"
  chmod +x "$FAKE_CHROME_DIR/chrome"
  check "rendered landing test reports why Chrome stopped at startup" \
    "CHROME_PATH='$FAKE_CHROME_DIR/chrome' node '$IDSTACK_DIR/test/test-rendered-landing.js'" \
    1 "exit code 3.*fake-chrome-startup-failure"
  # Chrome's helper processes can write to stderr after the main process exits. The
  # message must still give that output, so the test waits for stderr to close. The
  # stub's child writes 0.2s after the stub exits, which makes the case certain.
  printf '#!/bin/sh\n(sleep 0.2; echo "fake-chrome-late-output" >&2) &\nexit 4\n' > "$FAKE_CHROME_DIR/late"
  chmod +x "$FAKE_CHROME_DIR/late"
  check "rendered landing test gives output that Chrome writes after it exits" \
    "CHROME_PATH='$FAKE_CHROME_DIR/late' node '$IDSTACK_DIR/test/test-rendered-landing.js'" \
    1 "exit code 4.*fake-chrome-late-output"
  rm -rf "$FAKE_CHROME_DIR"
  # The fixed text that the extension shows must obey ASD-STE100: the demo audits,
  # the Markdown export, the rendered findings, the error messages and the side-panel
  # page. pipefail: a printer that crashes must fail here, not send empty text.
  if command -v python3 &>/dev/null; then
    check "extension Markdown output passes the STE checker" "( set -o pipefail; node '$IDSTACK_DIR/test/print-extension-output.mjs' markdown | python3 '$IDSTACK_DIR/bin/idstack-ste-check' --format markdown - )"
    check "extension HTML output passes the STE checker" "( set -o pipefail; node '$IDSTACK_DIR/test/print-extension-output.mjs' html | python3 '$IDSTACK_DIR/bin/idstack-ste-check' --format html - )"
    check "side-panel page passes the STE checker" "python3 '$IDSTACK_DIR/bin/idstack-ste-check' '$IDSTACK_DIR/extension/sidepanel/index.html'"
  else
    echo "  SKIP: extension STE checks (python3 not installed)"
  fi
else
  echo "  SKIP: chrome extension tests (node not installed)"
  echo "  SKIP: responsive landing page tests (node not installed)"
  echo "  SKIP: rendered landing page tests (node not installed)"
  echo "  SKIP: rendered landing startup report (node not installed)"
  echo "  SKIP: rendered landing late-output report (node not installed)"
  echo "  SKIP: extension STE checks (node not installed)"
fi

# Check generated files have auto-generated header
for skill in $SKILLS; do
  check "$skill SKILL.md has auto-generated header" "grep -q 'AUTO-GENERATED from SKILL.md.tmpl' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check all preamble-based skills have context recovery
for skill in $SKILLS; do
  check "$skill has context recovery" "grep -q 'Context Recovery' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check pipeline-originated skills have timeline logging (pipeline logs its
# own completion so "the pipeline was run" is recoverable)
TIMELINE_SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team pipeline"
for skill in $TIMELINE_SKILLS; do
  check "$skill has timeline logging" "grep -q 'idstack-timeline-log' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check every generated skill resolves through CLAUDE_PLUGIN_ROOT (the preamble
# gets it from the {{IDSTACK_RESOLVE}} expansion)
check "every generated SKILL.md supports CLAUDE_PLUGIN_ROOT" "! grep -L 'CLAUDE_PLUGIN_ROOT' $IDSTACK_DIR/skills/*/SKILL.md | grep -q ."

# The preamble's embedded python must run on the oldest supported interpreter
# (macOS system python3 is 3.9) — a SyntaxError there dies silently behind
# `2>/dev/null || true` in every generated skill.
if [ -x "$IDSTACK_DIR/test/test-preamble-python.sh" ]; then
  check "preamble embedded-python tests pass" "'$IDSTACK_DIR/test/test-preamble-python.sh'"
fi

# Migration tests. One tempdir root cleaned by trap; every cp + migrate runs
# inside a check so a migrate failure records a FAIL instead of killing the
# whole suite under `set -e` with no summary (and no leaked tempdir).
FIXTURE_DIR="$IDSTACK_DIR/test/fixtures"
if [ -d "$FIXTURE_DIR" ] && command -v python3 &>/dev/null; then
  MIG_ROOT=$(mktemp -d)
  trap 'rm -rf "$MIG_ROOT"' EXIT

  # Test v1.0 → v1.4 chained migration
  MIG="$MIG_ROOT/v10"; mkdir -p "$MIG"
  check "v1.0→v1.4: migrate runs" "cp '$FIXTURE_DIR/manifest-v1.0.json' '$MIG/project.json' && '$IDSTACK_DIR/bin/idstack-migrate' '$MIG/project.json' >/dev/null"
  check "v1.0→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert d['version']=='1.4'\""
  check "v1.0→v1.4: has preferences" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert 'preferences' in d\""
  check "v1.0→v1.4: preserves project_name" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert d['project_name']=='Test Course v1.0'\""

  # Test v1.1 → v1.4 migration (export_metadata.failed_items was an int count
  # in v1.1; v1.2+ made it a list of item descriptors — see bin/idstack-migrate).
  MIG="$MIG_ROOT/v11"; mkdir -p "$MIG"
  check "v1.1→v1.4: migrate runs" "cp '$FIXTURE_DIR/manifest-v1.1.json' '$MIG/project.json' && '$IDSTACK_DIR/bin/idstack-migrate' '$MIG/project.json' >/dev/null"
  check "v1.1→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert d['version']=='1.4'\""
  check "v1.1→v1.4: failed_items int converted to list" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert isinstance(d['export_metadata']['failed_items'], list)\""

  # Test v1.2 → v1.4 migration
  MIG="$MIG_ROOT/v12"; mkdir -p "$MIG"
  check "v1.2→v1.4: migrate runs" "cp '$FIXTURE_DIR/manifest-v1.2.json' '$MIG/project.json' && '$IDSTACK_DIR/bin/idstack-migrate' '$MIG/project.json' >/dev/null"
  check "v1.2→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert d['version']=='1.4'\""
  check "v1.2→v1.4: has preferences" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert d['preferences']['verbosity']=='normal'\""
  check "v1.2→v1.4: idempotent" "'$IDSTACK_DIR/bin/idstack-migrate' '$MIG/project.json' >/dev/null && python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert d['version']=='1.4'\""

  # Test v1.3-drifted → v1.4 cleanup migration (renames red_team_audit.summary.*_count
  # to red_team_audit.findings_summary.*, moves _import_quality_flags into
  # import_metadata.quality_flag_details).
  if [ -f "$FIXTURE_DIR/manifest-v1.3-drifted.json" ]; then
    MIG="$MIG_ROOT/v13"; mkdir -p "$MIG"
    check "v1.3-drifted→v1.4: migrate runs" "cp '$FIXTURE_DIR/manifest-v1.3-drifted.json' '$MIG/project.json' && '$IDSTACK_DIR/bin/idstack-migrate' '$MIG/project.json' >/dev/null"
    check "v1.3-drifted→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert d['version']=='1.4'\""
    check "v1.3-drifted→v1.4: red_team summary renamed to findings_summary" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); rt=d['red_team_audit']; assert 'summary' not in rt; assert rt['findings_summary']=={'critical': 3, 'warning': 5, 'info': 2}\""
    check "v1.3-drifted→v1.4: _import_quality_flags moved into import_metadata" "python3 -c \"import json; d=json.load(open('$MIG/project.json')); assert '_import_quality_flags' not in d; details=d['import_metadata']['quality_flag_details']; assert len(details)==2 and details[0]['key']=='orphan_module_8'\""
  fi

  # Test malformed manifest cat-fallback (bin/idstack-migrate, when the version read fails)
  MIG="$MIG_ROOT/malformed"; mkdir -p "$MIG"
  echo "INVALID { JSON" > "$MIG/project.json"
  check "migrate: malformed JSON falls back to raw cat and exits 0" \
    "[ \"\$('$IDSTACK_DIR/bin/idstack-migrate' '$MIG/project.json')\" = 'INVALID { JSON' ]"
fi

# Template freshness check
check "generated SKILL.md files are up to date" "'$IDSTACK_DIR/bin/idstack-gen-skills' --dry-run"

# Claude-Code-only invariant (v3.4.0.0). idstack shipped a second CLI target
# from v2.5.0.0 to v3.3.0.4 and dropped it. The machinery is easy to reintroduce
# by accident — a cherry-pick from an older branch, a doc paragraph copied
# forward — and each piece fails differently: a dangling `dist/` ships dead
# files, a `--target` flag in a caller exits 2, a doc line sends a user to an
# install path that no longer exists. Pin all of it.
check "no second-CLI distribution bundle" "[ ! -e '$IDSTACK_DIR/dist' ]"
check "no repo-root AGENTS.md" "[ ! -e '$IDSTACK_DIR/AGENTS.md' ]"
check "no templates/agent-context.md" "[ ! -e '$IDSTACK_DIR/templates/agent-context.md' ]"
check "generator takes no --target flag" "! grep -q -- '--target' '$IDSTACK_DIR/bin/idstack-gen-skills'"
check "generator exits 2 on an unknown argument" "'$IDSTACK_DIR/bin/idstack-gen-skills' --bogus 2>/dev/null; [ \$? -eq 2 ]"
check "resolve chain drops the ~/.agents fallbacks" "! grep -q '\.agents/' '$IDSTACK_DIR/templates/snippets/idstack-resolve.sh'"
check "preamble embeds no ~/.agents fallbacks" "! grep -q '\.agents/' '$IDSTACK_DIR/templates/preamble.md'"

# Repo-wide sweep for the retired CLI's name. Three exemptions:
#
#   1. CHANGELOG.md — the release record, which has to keep describing what was
#      removed and how to clean up after it.
#   2. .superpowers/, .gstack/, .idstack/, .claude/ — git-ignored tool scratch
#      directories. Implementation reports and review notes written during
#      development are not shipped and CI never sees them (fresh checkout), but
#      they can discuss the sweep and trip it unreliably.
#      --exclude-dir matches a name at any depth, so never add the dotless
#      `superpowers`: it exempted the committed specs and plans under
#      docs/superpowers/ and superpowers/.
#   3. Lines tagged IDSTACK_CLI_LEAK_ALLOW. Kinds of line that carry the tag
#      include: this block's own patterns, the unsupported-fork pointer on
#      the landing page and in README.md, the comments crediting "Gemini Code Assist" — a PR-review bot  # IDSTACK_CLI_LEAK_ALLOW
#      that flagged the version classifier four times, unrelated to the CLI and
#      the reason those test cases exist — and mentions of the Gemini model API  # IDSTACK_CLI_LEAK_ALLOW
#      the Chrome extension calls, which is an LLM endpoint, not a CLI.
#
#      A tag is for a dated, historical mention or the extension's model API.
#      It is NEVER for a line that claims idstack runs somewhere it does not.
#      Tag individual lines, never whole files, and never filter on a bare
#      string: an earlier draft dropped every line containing the bot's name
#      repo-wide, which would have let an untagged capability claim through
#      anywhere it appeared.
CLI_LEAK_RE='codex|gemini|antigravity' # IDSTACK_CLI_LEAK_ALLOW
CLI_LEAK="$(grep -rIiE "$CLI_LEAK_RE" "$IDSTACK_DIR" \
  --exclude-dir=.git --exclude-dir=.gstack --exclude-dir=.idstack \
  --exclude-dir=.claude --exclude-dir=.superpowers \
  --exclude-dir=docs/designs --exclude-dir=designs --exclude=CHANGELOG.md 2>/dev/null || true)"
CLI_LEAK="$(printf '%s' "$CLI_LEAK" | grep -vF 'IDSTACK_CLI_LEAK_ALLOW' || true)"
# Printed through the command itself, not tested with -z, so a failure names
# the offending lines instead of just saying the string was non-empty.
check "retired-CLI references confined to CHANGELOG.md" \
  "if [ -n \"\$CLI_LEAK\" ]; then printf '%s\n' \"\$CLI_LEAK\"; false; fi"


# Skill bash blocks run in Claude Code's Bash tool: in the user's shell (zsh on
# macOS), with BSD tools, and in a new shell for each call. CI runs only bash,
# so these patterns pass every other suite and fail for real users:
#   - `head -n -1` is GNU-only. BSD head rejects it, so the Canvas push read an
#     empty body and posted every item to /modules//items.
#   - `for x in $VAR` does not word-split in zsh, so it loops once.
#   - `ls *.md *.docx` aborts in zsh when one glob matches nothing (NOMATCH),
#     even with 2>/dev/null.
#   - A Canvas block that does not source .idstack/canvas.env has no token,
#     because the variable from an earlier call is gone.
#   - A relative `templates/report.md.tmpl` does not exist in a course
#     project. The report block must print the plugin path for the Read tool.
SHELL_SRC=$(ls "$IDSTACK_DIR"/skills/*/SKILL.md.tmpl "$IDSTACK_DIR"/templates/*.md "$IDSTACK_DIR"/templates/snippets/*.sh)
check "no GNU-only 'head -n -N' in skill shell" \
  "! grep -nE 'head -n -[0-9]' $(echo $SHELL_SRC)"
check "no unquoted 'for x in \$VAR' word-split loop in skill shell" \
  "! grep -nE 'for [A-Za-z_]+ in \\\$[A-Za-z_{]' $(echo $SHELL_SRC)"
check "no bare 'ls *.ext' glob in skill shell" \
  "! grep -nE '^[[:space:]]*ls [^#]*[[:space:]][^[:space:]\"]*\\*\\.[A-Za-z]' $(echo $SHELL_SRC)"
check "no /tmp merge payloads in skill shell" \
  "! grep -nE -- '--payload /tmp/' $(echo $SHELL_SRC)"
check "every Canvas API block loads .idstack/canvas.env" "python3 - $(echo $SHELL_SRC) <<'PY'
import re, sys
bad = []
for f in sys.argv[1:]:
    for m in re.finditer(r'\`\`\`bash\n(.*?)\`\`\`', open(f, encoding='utf-8').read(), re.S):
        b = m.group(1)
        if ('Bearer \$TOKEN' in b) or ('CANVAS_TOKEN' in b and 'curl' in b and '. ./.idstack/canvas.env' not in b):
            bad.append('%s: %s' % (f, b.strip().splitlines()[0]))
print('\n'.join(bad))
sys.exit(1 if bad else 0)
PY"
# The list is fixed. A gate on the "Report template:" text skipped a skill that
# lost its only copy of that text, so the check never ran for it.
for name in $REPORT_PRODUCING_SKILLS pipeline; do
  tmpl="$IDSTACK_DIR/skills/$name/SKILL.md.tmpl"
  if [ "$name" = "pipeline" ]; then
    check "$name prints the plugin path of its dashboard template" \
      "grep -qF 'echo \"Dashboard template: \$_IDSTACK/templates/index.md.tmpl\"' '$tmpl'"
  else
    check "$name prints the plugin path of its report template" \
      "grep -qF 'echo \"Report template: \$_IDSTACK/templates/report.md.tmpl\"' '$tmpl'"
  fi
done

# A desktop user opens a report by clicking a link in chat. Each report block
# prints the relative path, and the closing message links it as the preamble
# tells; the pipeline does the same for the dashboard.
for skill in $REPORT_PRODUCING_SKILLS; do
  check "$skill prints a relative report path" \
    "grep -qF 'echo \"Report path: \$_REPORT_PATH\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill closing message points at the Report Links rule" \
    "grep -qF 'as the Report Links section of the preamble tells you' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
check "pipeline prints a relative dashboard path" \
  "grep -qF 'echo \"Dashboard path: \$_EXPORT_DIR/index.md\"' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"
# Regression: skills gave the user an absolute path in angle brackets. The
# path had a space (Application Support), and the Claude desktop app did not
# make it a link. Only relative paths are printed now.
check "no skill or preamble prints an absolute report or dashboard link" \
  "! grep -nE 'pwd -P\)/\\\$_(REPORT_PATH|EXPORT_DIR)|Report link:|Dashboard link:' $IDSTACK_DIR/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md'"
check "preamble Report Links section has no angle-bracket link" \
  "! awk '/^## Preamble: Report Links/{f=1; next} f && /^## /{exit} f' '$IDSTACK_DIR/templates/preamble.md' | grep -qF '](<'"
check "preamble tells skills to give the report link" \
  "grep -q '^## Preamble: Report Links' '$IDSTACK_DIR/templates/preamble.md'"
check "no skill tells the user to open a report in a web browser" \
  "! grep -l 'Open it in a web browser' $IDSTACK_DIR/skills/*/SKILL.md.tmpl"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
