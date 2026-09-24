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
SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team pipeline learn"
for skill in $SKILLS; do
  check "skills/$skill/SKILL.md reachable" "[ -f '$IDSTACK_DIR/skills/$skill/SKILL.md' ]"
done

# Check YAML frontmatter has required fields (bare names, no idstack- prefix)
for skill in $SKILLS; do
  check "$skill has name: $skill" "grep -q '^name: $skill' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
  check "$skill has description: field" "grep -q '^description:' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
  check "$skill has allowed-tools: field" "grep -q '^allowed-tools:' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check evidence file exists
check "evidence/references.md exists" "[ -f '$IDSTACK_DIR/evidence/references.md' ]"

# Check bin scripts exist and are executable
for script in idstack-migrate idstack-timeline-log idstack-learnings-log idstack-learnings-search idstack-learnings-delete idstack-learnings-promote idstack-status idstack-gen-skills idstack-doctor idstack-slugify idstack-update-check; do
  check "bin/$script exists" "[ -f '$IDSTACK_DIR/bin/$script' ]"
  check "bin/$script is executable" "[ -x '$IDSTACK_DIR/bin/$script' ]"
done

# Bash syntax gate for the shell entry points (idstack-manifest-merge is python).
for script in setup bin/idstack-doctor bin/idstack-gen-skills bin/idstack-status bin/idstack-migrate bin/idstack-slugify bin/idstack-update-check bin/lib/version-classify.sh bin/lib/plugin-status.sh test/test-helper.sh; do
  check "$script passes bash -n" "bash -n '$IDSTACK_DIR/$script'"
done

# Every suite takes its counters from test/test-helper.sh. Nine suites had
# each grown their own copy, and they had already drifted — two spelled the
# helper `assert`, and one swallowed failure output entirely, so CI reported a
# bare FAIL with no diagnostics. A local `PASS=0` is how that regrows.
check "test-helper.sh exists" "[ -f '$IDSTACK_DIR/test/test-helper.sh' ]"
for suite in smoke-test integration-test test-manifest-merge test-version-classifier \
             test-plugin-status test-preamble-python test-setup test-doctor test-status; do
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
check "templates/report.html.tmpl exists" "[ -f '$IDSTACK_DIR/templates/report.html.tmpl' ]"
check "templates/index.html.tmpl exists" "[ -f '$IDSTACK_DIR/templates/index.html.tmpl' ]"
check "templates/assets/idstack.css exists" "[ -f '$IDSTACK_DIR/templates/assets/idstack.css' ]"
check "templates/assets/idstack.css is non-empty" "[ -s '$IDSTACK_DIR/templates/assets/idstack.css' ]"
check "templates/report.html.tmpl mentions {{skill_name}}" "grep -q '{{skill_name}}' '$IDSTACK_DIR/templates/report.html.tmpl'"
check "templates/index.html.tmpl mentions {{project_name}}" "grep -q '{{project_name}}' '$IDSTACK_DIR/templates/index.html.tmpl'"
for skill in $SKILLS; do
  check "$skill has SKILL.md.tmpl" "[ -f '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' ]"
done

# Landing page (docs/index.html) - dark-only revert invariants. Guards against
# regressions: losing the dark theme, the toggle creeping back, or the stale
# bare-clone install string returning (see dea7ebc).
LANDING="$IDSTACK_DIR/docs/index.html"
check "landing/index.html exists" "[ -f '$LANDING' ]"
check "landing: dark background (#0a0a0f)" "grep -q -- '--bg: *#0a0a0f' '$LANDING'"
check "landing: dark-only, no theme toggle" "! grep -q 'theme-toggle' '$LANDING'"
check "landing: no data-theme attribute or blocks" "! grep -q 'data-theme' '$LANDING'"
check "landing: no Google Fonts dependency" "! grep -q 'fonts.googleapis' '$LANDING'"
check "landing: indigo gradient present" "grep -q 'linear-gradient' '$LANDING'"
# In HTML the '&&' is entity-escaped as '&amp;&amp;', so don't grep the literal '&&'.
# Assert the repo clone + 'cd idstack' (current marketplace form); the legacy
# ~/.claude/plugins/idstack form is caught by the next check. Escaping-independent.
check "landing: marketplace install command present" "grep -q 'github.com/savvides/idstack.git' '$LANDING' && grep -q 'cd idstack' '$LANDING'"
check "landing: no legacy plugins-dir install string" "! grep -q '.claude/plugins/idstack' '$LANDING'"
check "landing: current version v$VER present" "grep -qF 'v$VER' '$LANDING'"
check "landing: structured-data softwareVersion $VER" "grep -qF '\"softwareVersion\": \"$VER\"' '$LANDING'"
check "landing: Output section present" "grep -q 'id=.output.' '$LANDING'"
# Gradient-clipped text (hero h1, eyebrow) must keep a solid color fallback so it
# stays visible where `background-clip: text` is unsupported. Guards against a bare
# `color: transparent` (the leading [^-] excludes `-webkit-text-fill-color: transparent`).
check "landing: gradient text keeps a color fallback (no bare 'color: transparent')" \
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

check "doc accuracy check passes" "python3 '$IDSTACK_DIR/test/check-doc-accuracy.py' '$IDSTACK_DIR'"


# Open Graph card template (docs/og-template.html) - same gradient-text fallback rule.
OG_TEMPLATE="$IDSTACK_DIR/docs/og-template.html"
check "og-template.html exists" "[ -f '$OG_TEMPLATE' ]"
check "og-template: gradient text keeps a color fallback (no bare 'color: transparent')" \
  "! grep -Eq '[^-]color: *transparent' '$OG_TEMPLATE'"
check "og-template: gradient text uses -webkit-text-fill-color" \
  "grep -q 'text-fill-color: transparent' '$OG_TEMPLATE'"

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
check "idstack-slugify: implicit stdin pipeline" \
  "[ \"\$(echo 'Course via Implicit Stdin' | '$IDSTACK_DIR/bin/idstack-slugify')\" = 'course-via-implicit-stdin' ]"
check "idstack-slugify: explicit dash stdin pipeline" \
  "[ \"\$(echo 'Course via Dash Stdin' | '$IDSTACK_DIR/bin/idstack-slugify' -)\" = 'course-via-dash-stdin' ]"
check "idstack-slugify: emoji and non-ASCII characters stripped" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' 'Course 🚀 101: Intro to AI ✨')\" = 'course-101-intro-to-ai' ]"

# Skills that write per-skill HTML reports must reference the new export folder pattern
# and use the slugify helper (not the legacy .idstack/reports/<skill>.md path).
REPORT_PRODUCING_SKILLS="needs-analysis learning-objectives assessment-design course-builder course-quality-review course-import course-export accessibility-review red-team"
for skill in $REPORT_PRODUCING_SKILLS; do
  check "$skill SKILL.md.tmpl references .idstack/exports/" "grep -q '\.idstack/exports/' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl calls idstack-slugify" "grep -q 'idstack-slugify' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl copies templates/assets/idstack.css" "grep -q 'templates/assets/idstack.css' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  # report-format.md requires a "Top recommendations" section in every report.
  check "$skill SKILL.md.tmpl includes Top recommendations" "grep -qi 'Top recommendations' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# Manifest write-path contract: single-section owners go through the merge
# tool; multi-section/first-run writers document the Write-tool fallback the
# way course-import models it.
for skill in learning-objectives course-quality-review course-export; do
  check "$skill SKILL.md.tmpl uses idstack-manifest-merge" "grep -q 'idstack-manifest-merge' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
for skill in needs-analysis course-import; do
  check "$skill SKILL.md.tmpl justifies its Write-tool fallback" "grep -q 'Write-tool fallback' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# Canonical manifest section names only — these five non-canonical tokens once
# shipped in re-run checks and prose, making re-run detection dead in 5 skills.
for skill in $SKILLS; do
  check "$skill SKILL.md.tmpl free of non-canonical section names" "! grep -E '\b(assessment_design|course_builder|course_export|course_import|course_quality_review)\b' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

# User-facing skill references must be namespaced /idstack:<skill>. A bare
# /skill is not a command Claude Code resolves — plugin skills are addressed
# as plugin:skill. (Frontmatter descriptions are exempt.)
#
# This matched only the backticked form until v3.3.0.1, which let three
# unbackticked examples sit in the preamble's context-recovery section — the
# model copied them and told users to run "/assessment-design", which does
# nothing. The leading class covers a command position: line start, whitespace,
# an opening quote/paren, or a backtick. It deliberately does NOT match a `/`
# preceded by a path character, so `.idstack/exports/<slug>/red-team.html`
# stays legal, and it can't match `/idstack:<skill>` because the skill name
# there does not follow the slash.
BARE_SLASH_RE='(^|[[:space:]"(`])/(needs-analysis|learning-objectives|assessment-design|course-builder|course-quality-review|accessibility-review|red-team|course-export|course-import|pipeline|learn)\b'
# Frontmatter stays exempt: `description:` is prose the CLI shows in a skill
# picker, not a command anyone types. STRIP_FM drops everything through the
# closing `---` so only the body is scanned. Later `---` horizontal rules in
# the body keep incrementing c, which is harmless once c>=2.
STRIP_FM='awk "/^---\$/{c++; next} c>=2"'
for skill in $SKILLS; do
  check "$skill SKILL.md.tmpl body free of bare /skill refs" "! $STRIP_FM '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' | grep -qE '$BARE_SLASH_RE'"
done
# The preamble has no frontmatter — scan the whole file.
check "preamble free of bare /skill refs" "! grep -qE '$BARE_SLASH_RE' '$IDSTACK_DIR/templates/preamble.md'"
check "no '/idstack <skill>' space typos in templates" "! grep -rE '/idstack [a-z]' $IDSTACK_DIR/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md'"
check "pipeline status table uses /idstack: prefixes" "grep -qF '[done] /idstack:needs-analysis' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"
check "pipeline invokes children with the idstack: namespace" "grep -qF 'skill: \"idstack:needs-analysis\"' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"

# Canonical $_IDSTACK resolution: templates use the {{IDSTACK_RESOLVE}}
# placeholder, never a hand-rolled derivation (two skills once drifted to a
# path list that missed the marketplace cache — the way most users install).
RESOLVE_LINE="$(grep -m1 '^for _p in' "$IDSTACK_DIR/templates/snippets/idstack-resolve.sh" 2>/dev/null || true)"
check "resolve snippet has the canonical for-chain" "[ -n \"\$RESOLVE_LINE\" ]"
check "resolve snippet includes the marketplace cache path" "grep -q 'plugins/cache/idstack' '$IDSTACK_DIR/templates/snippets/idstack-resolve.sh'"
check "preamble embeds the snippet's resolve chain verbatim (x3)" "[ \"\$(grep -cF \"\$RESOLVE_LINE\" '$IDSTACK_DIR/templates/preamble.md')\" -eq 3 ]"
for skill in $SKILLS; do
  check "$skill SKILL.md.tmpl uses {{IDSTACK_RESOLVE}}" "grep -q '{{IDSTACK_RESOLVE}}' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl does not hand-roll _IDSTACK" "! grep -Eq '_IDSTACK:?=' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
check "no legacy .claude/plugins/idstack path in skill templates" "! grep -rF '.claude/plugins/idstack' $IDSTACK_DIR/skills/*/SKILL.md.tmpl '$IDSTACK_DIR/templates/preamble.md'"

# Pipeline orchestrator must produce index.html under the course folder.
# Use -E (extended regex) so the `|` alternation works under BSD grep too;
# in BRE, `\|` is a GNU extension and silently matches nothing on BSD.
check "pipeline SKILL.md.tmpl produces index.html in exports/<slug>/" "grep -qE 'exports/.*index.html|\$_EXPORT_DIR/index.html' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"

# Schema-drift regression: skills that share the canonical schema must use the
# {{MANIFEST_SCHEMA}} substitution rather than re-inlining their own copy.
SCHEMA_HOST_SKILLS="needs-analysis learning-objectives assessment-design course-builder course-quality-review course-import course-export accessibility-review"
for skill in $SCHEMA_HOST_SKILLS; do
  check "$skill SKILL.md.tmpl uses {{MANIFEST_SCHEMA}}" "grep -q '{{MANIFEST_SCHEMA}}' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill generated SKILL.md inlines canonical schema (version 1.4)" "grep -q '\"version\": \"1.4\"' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
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

# Legacy-install conflict regression: a pre-v2.0.1.0 dispatcher install at
# ~/.claude/skills/idstack/ shadows the plugin namespace and breaks
# /idstack:<skill> resolution. We only check this when run without a $1 override
# — CI fixtures point $1 at their own checkout and don't share state with the
# user's home directory.
if [ -z "${1:-}" ]; then
  LEGACY_CHECK_DIR="$HOME/.claude/skills/idstack"
  check "no legacy idstack dispatcher at ~/.claude/skills/idstack/SKILL.md (run: rm -rf $LEGACY_CHECK_DIR)" \
    "[ ! -f '$LEGACY_CHECK_DIR/SKILL.md' ] || ! grep -q '^name: idstack' '$LEGACY_CHECK_DIR/SKILL.md'"
  for skill in $SKILLS; do
    legacy_link="$HOME/.claude/skills/$skill"
    check "no pre-v2 skill symlink at ~/.claude/skills/$skill pointing into idstack" \
      "[ ! -L '$legacy_link' ] || ! readlink '$legacy_link' 2>/dev/null | grep -q idstack"
  done
fi

# Manifest-merge tool must exist and be executable, and its unit tests must pass.
check "bin/idstack-manifest-merge exists" "[ -f '$IDSTACK_DIR/bin/idstack-manifest-merge' ]"
check "bin/idstack-manifest-merge is executable" "[ -x '$IDSTACK_DIR/bin/idstack-manifest-merge' ]"
if [ -x "$IDSTACK_DIR/test/test-manifest-merge.sh" ]; then
  check "manifest-merge unit tests pass" "'$IDSTACK_DIR/test/test-manifest-merge.sh'"
fi

# Version classifier (shared by setup + bin/idstack-doctor) must classify
# multi-digit versions correctly. Pinned to catch the pattern-fragility
# regression Gemini Code Assist flagged twice. The classifier itself lives in  # IDSTACK_CLI_LEAK_ALLOW
# bin/lib/version-classify.sh — one definition sourced by setup, doctor, and
# the unit test, so the test exercises the shipped code, never a copy.
check "bin/lib/version-classify.sh exists" "[ -f '$IDSTACK_DIR/bin/lib/version-classify.sh' ]"
check "setup sources the shared version classifier" "grep -q 'lib/version-classify.sh' '$IDSTACK_DIR/setup'"
check "idstack-doctor sources the shared version classifier" "grep -q 'lib/version-classify.sh' '$IDSTACK_DIR/bin/idstack-doctor'"
check "version-classifier test sources the shared classifier" "grep -q 'lib/version-classify.sh' '$IDSTACK_DIR/test/test-version-classifier.sh'"
if [ -x "$IDSTACK_DIR/test/test-version-classifier.sh" ]; then
  check "version-classifier unit tests pass" "'$IDSTACK_DIR/test/test-version-classifier.sh'"
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
# --readiness is the pre-export gate; same reasoning as doctor above.
if [ -x "$IDSTACK_DIR/test/test-status.sh" ]; then
  check "idstack-status behavioral tests pass" "'$IDSTACK_DIR/test/test-status.sh'"
fi

# ./setup is what a new user runs first; it is exercised against a repo copy
# with a fake $HOME and a stub `claude`, never the real install.
if [ -x "$IDSTACK_DIR/test/test-setup.sh" ]; then
  check "setup behavioral tests pass" "'$IDSTACK_DIR/test/test-setup.sh' '$IDSTACK_DIR'"
fi

# Chrome extension unit and integration tests
if [ -x "$IDSTACK_DIR/test/test-extension.sh" ]; then
  check "chrome extension tests pass" "'$IDSTACK_DIR/test/test-extension.sh'"
fi

# Responsive landing page test
if [ -x "$IDSTACK_DIR/test/test-responsive-landing.js" ]; then
  check "responsive landing page tests pass" "node '$IDSTACK_DIR/test/test-responsive-landing.js'"
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

# Check preamble uses CLAUDE_PLUGIN_ROOT
check "preamble supports CLAUDE_PLUGIN_ROOT" "grep -q 'CLAUDE_PLUGIN_ROOT' '$IDSTACK_DIR/templates/preamble.md'"

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

  # Test malformed manifest cat-fallback (bin/idstack-migrate:84)
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
#   3. Lines tagged IDSTACK_CLI_LEAK_ALLOW. Three kinds of line carry the tag:
#      this block's own patterns, the dated release note on the landing page,
#      and the comments crediting "Gemini Code Assist" — a PR-review bot  # IDSTACK_CLI_LEAK_ALLOW
#      that flagged the version classifier four times, unrelated to the CLI and
#      the reason those test cases exist.
#
#      A tag is for a dated, historical mention. It is NEVER for a line that
#      claims idstack runs somewhere it does not. Tag individual lines, never
#      whole files, and never filter on a bare string: an earlier draft dropped
#      every line containing the bot's name repo-wide, which would have
#      let an untagged capability claim through anywhere it appeared.
CLI_LEAK_RE='codex|gemini'            # IDSTACK_CLI_LEAK_ALLOW
CLI_LEAK="$(grep -rIiE "$CLI_LEAK_RE" "$IDSTACK_DIR" \
  --exclude-dir=.git --exclude-dir=.gstack --exclude-dir=.idstack \
  --exclude-dir=.claude --exclude-dir=.superpowers --exclude-dir=superpowers --exclude=CHANGELOG.md 2>/dev/null || true)"
CLI_LEAK="$(printf '%s' "$CLI_LEAK" | grep -vF 'IDSTACK_CLI_LEAK_ALLOW' || true)"
# Printed through the command itself, not tested with -z, so a failure names
# the offending lines instead of just saying the string was non-empty.
check "retired-CLI references confined to CHANGELOG.md" \
  "if [ -n \"\$CLI_LEAK\" ]; then printf '%s\n' \"\$CLI_LEAK\"; false; fi"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
