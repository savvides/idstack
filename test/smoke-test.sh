#!/usr/bin/env bash
# idstack smoke test — verifies installation is correct
set -e

PASS=0
FAIL=0
TOTAL=0

# Verify the repo this script lives in (test/smoke-test.sh -> repo root is "..").
# Override with $1 to point at a different checkout (CI fixtures, etc.).
IDSTACK_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" 2>/dev/null; then
    echo "  PASS: $1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
  fi
}

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
for script in idstack-migrate idstack-timeline-log idstack-learnings-log idstack-learnings-search idstack-learnings-delete idstack-learnings-promote idstack-status idstack-gen-skills idstack-doctor idstack-slugify; do
  check "bin/$script exists" "[ -f '$IDSTACK_DIR/bin/$script' ]"
  check "bin/$script is executable" "[ -x '$IDSTACK_DIR/bin/$script' ]"
done

# Check template system
check "templates/preamble.md exists" "[ -f '$IDSTACK_DIR/templates/preamble.md' ]"
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
check "landing: current version v3.2.0.0 present" "grep -q 'v3.2.0.0' '$LANDING'"
check "landing: structured-data softwareVersion 3.2.0" "grep -qF '\"softwareVersion\": \"3.2.0\"' '$LANDING'"
check "landing: Output section present" "grep -q 'id=.output.' '$LANDING'"
# Gradient-clipped text (hero h1, eyebrow) must keep a solid color fallback so it
# stays visible where `background-clip: text` is unsupported. Guards against a bare
# `color: transparent` (the leading [^-] excludes `-webkit-text-fill-color: transparent`).
check "landing: gradient text keeps a color fallback (no bare 'color: transparent')" \
  "! grep -Eq '[^-]color: *transparent' '$LANDING'"

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

# Skills that write per-skill HTML reports must reference the new export folder pattern
# and use the slugify helper (not the legacy .idstack/reports/<skill>.md path).
REPORT_PRODUCING_SKILLS="needs-analysis learning-objectives assessment-design course-builder course-quality-review course-import course-export accessibility-review red-team"
for skill in $REPORT_PRODUCING_SKILLS; do
  check "$skill SKILL.md.tmpl references .idstack/exports/" "grep -q '\.idstack/exports/' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl calls idstack-slugify" "grep -q 'idstack-slugify' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill SKILL.md.tmpl copies templates/assets/idstack.css" "grep -q 'templates/assets/idstack.css' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done

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
# regression Gemini flagged twice.
if [ -x "$IDSTACK_DIR/test/test-version-classifier.sh" ]; then
  check "version-classifier unit tests pass" "'$IDSTACK_DIR/test/test-version-classifier.sh'"
fi

# Check generated files have auto-generated header
for skill in $SKILLS; do
  check "$skill SKILL.md has auto-generated header" "grep -q 'AUTO-GENERATED from SKILL.md.tmpl' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check all preamble-based skills have context recovery
for skill in $SKILLS; do
  check "$skill has context recovery" "grep -q 'Context Recovery' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check pipeline-originated skills have timeline logging
TIMELINE_SKILLS="needs-analysis learning-objectives course-quality-review course-import assessment-design course-builder course-export accessibility-review red-team"
for skill in $TIMELINE_SKILLS; do
  check "$skill has timeline logging" "grep -q 'idstack-timeline-log' '$IDSTACK_DIR/skills/$skill/SKILL.md'"
done

# Check preamble uses CLAUDE_PLUGIN_ROOT
check "preamble supports CLAUDE_PLUGIN_ROOT" "grep -q 'CLAUDE_PLUGIN_ROOT' '$IDSTACK_DIR/templates/preamble.md'"

# Migration tests
FIXTURE_DIR="$IDSTACK_DIR/test/fixtures"
if [ -d "$FIXTURE_DIR" ] && command -v python3 &>/dev/null; then
  # Test v1.0 → v1.4 chained migration
  TMPDIR_MIG=$(mktemp -d)
  cp "$FIXTURE_DIR/manifest-v1.0.json" "$TMPDIR_MIG/project.json"
  "$IDSTACK_DIR/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
  check "v1.0→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.4'\""
  check "v1.0→v1.4: has preferences" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert 'preferences' in d\""
  check "v1.0→v1.4: preserves project_name" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['project_name']=='Test Course v1.0'\""
  rm -rf "$TMPDIR_MIG"

  # Test v1.2 → v1.4 migration
  TMPDIR_MIG=$(mktemp -d)
  cp "$FIXTURE_DIR/manifest-v1.2.json" "$TMPDIR_MIG/project.json"
  "$IDSTACK_DIR/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
  check "v1.2→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.4'\""
  check "v1.2→v1.4: has preferences" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['preferences']['verbosity']=='normal'\""
  check "v1.2→v1.4: idempotent" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.4'\" && '$IDSTACK_DIR/bin/idstack-migrate' '$TMPDIR_MIG/project.json' >/dev/null 2>&1 && python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.4'\""
  rm -rf "$TMPDIR_MIG"

  # Test v1.3-drifted → v1.4 cleanup migration (renames red_team_audit.summary.*_count
  # to red_team_audit.findings_summary.*, moves _import_quality_flags into
  # import_metadata.quality_flag_details).
  if [ -f "$FIXTURE_DIR/manifest-v1.3-drifted.json" ]; then
    TMPDIR_MIG=$(mktemp -d)
    cp "$FIXTURE_DIR/manifest-v1.3-drifted.json" "$TMPDIR_MIG/project.json"
    "$IDSTACK_DIR/bin/idstack-migrate" "$TMPDIR_MIG/project.json" >/dev/null 2>&1
    check "v1.3-drifted→v1.4: version bumped" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert d['version']=='1.4'\""
    check "v1.3-drifted→v1.4: red_team summary renamed to findings_summary" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); rt=d['red_team_audit']; assert 'summary' not in rt; assert rt['findings_summary']=={'critical': 3, 'warning': 5, 'info': 2}\""
    check "v1.3-drifted→v1.4: _import_quality_flags moved into import_metadata" "python3 -c \"import json; d=json.load(open('$TMPDIR_MIG/project.json')); assert '_import_quality_flags' not in d; details=d['import_metadata']['quality_flag_details']; assert len(details)==2 and details[0]['key']=='orphan_module_8'\""
    rm -rf "$TMPDIR_MIG"
  fi
fi

# Template freshness check (covers all targets: claude + codex)
check "generated files are up to date for all targets" "'$IDSTACK_DIR/bin/idstack-gen-skills' --dry-run"

# Codex bundle — generated artifacts for Codex CLI consumers.
# AGENTS.md lives at the repo root (Codex memory file for sessions inside the
# idstack repo). End-user skill installs go into $CODEX_HOME/skills/idstack-<name>/
# via per-skill symlinks created by setup; Codex auto-discovers skills there.
# SKILL.md files are generated under dist/codex/skills/idstack-<name>/.
CODEX_SKILLS_DIR="$IDSTACK_DIR/dist/codex/skills"
check "Codex AGENTS.md at repo root exists" "[ -f '$IDSTACK_DIR/AGENTS.md' ]"
check "AGENTS.md matches templates/agent-context.md" "cmp -s '$IDSTACK_DIR/templates/agent-context.md' '$IDSTACK_DIR/AGENTS.md'"
check "Codex skills dir exists" "[ -d '$CODEX_SKILLS_DIR' ]"
for skill in $SKILLS; do
  check "Codex skills/idstack-$skill/SKILL.md exists" "[ -f '$CODEX_SKILLS_DIR/idstack-$skill/SKILL.md' ]"
  check "Codex $skill has name: $skill" "grep -q '^name: $skill' '$CODEX_SKILLS_DIR/idstack-$skill/SKILL.md'"
  check "Codex $skill has description: field" "grep -q '^description:' '$CODEX_SKILLS_DIR/idstack-$skill/SKILL.md'"
  # Codex has no per-skill tool allowlist; the field must be stripped.
  check "Codex $skill has allowed-tools: stripped" "! grep -q '^allowed-tools:' '$CODEX_SKILLS_DIR/idstack-$skill/SKILL.md'"
done

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
