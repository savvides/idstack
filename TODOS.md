# TODOS

## ~~v2.4: Dual-Output Report Contract + Pipeline Aggregator~~ SHIPPED (v2.4.0.0)
Shipped in v2.4.0.0. Every finding-producing skill now writes both
`.idstack/project.json` (system state) and `.idstack/reports/<skill>.md` (human view)
following the canonical observation → evidence → why-it-matters → suggestion structure
in `templates/report-format.md`. `/idstack:pipeline` produces `.idstack/reports/pipeline.md`
— a cross-cutting aggregate over per-skill reports with top recurring issues, evidence
themes, and where to start. `bin/idstack-status` lists every report under
`.idstack/reports/` with `pipeline.md` first. Plus install-hygiene fix: setup actively
removes pre-v2.0.1.0 dispatcher clones, smoke-test catches the regression, new
`bin/idstack-doctor` for diagnostics.

## ~~v1.1: Manifest Versioning~~ SHIPPED (v1.2.0)
Shipped in v1.2.0. `bin/idstack-migrate` handles schema migrations.
All 7 skill preambles call it automatically.

## ~~v2: Cross-Domain Quality Checks~~ SHIPPED (v1.2.0)
Shipped in v1.2.0. Four checks added to /course-quality-review:
cognitive load, multimedia principles, feedback quality, expertise reversal.
Plus: fix-link integration, quick-win prioritization, score trending,
shareable quality report, and per-category scoring breakdown.

## ~~v2: Template System~~ SHIPPED (v1.5.0)
Shipped in v1.5.0. `bin/idstack-gen-skills` generates SKILL.md from .tmpl templates.
Shared preamble (update check, manifest check, context recovery) maintained in
`templates/preamble.md`. Contributors edit .tmpl files, run gen-skills to regenerate.

## v2: Additional Skills (from literature synthesis)
The remaining skill suite from the evidence synthesis includes 4 more skills:
- id-model-selector (Domain 1) — context-driven model/framework recommendation
- content-sequencing (Domain 4) — cognitive load-aware sequencing and chunking
- media-selection (Domain 6) — multimedia principle application and violation flagging
- evaluation-design (Domain 8) — Kirkpatrick+ evaluation planning
**Why:** Extends coverage for specialized ID workflows. Each backed by evidence synthesis.
**Depends on:** User feedback on which capabilities are most requested.
**Note:** assessment-design, course-builder, and course-export are now shipped (v1.1).
learner-analysis is partially covered by /needs-analysis (Level 3) and /course-import.
prototype-iteration overlaps with the build/export pipeline.

## v2: LMS-Specific API Integrations
Add Blackboard (xAPI), Moodle (web services), and D2L (Valence API) as import
sources alongside Canvas. The IMS Common Cartridge format covers these generically,
but LMS-specific APIs unlock richer data (rubrics, analytics, student engagement).
**Why:** Each LMS has unique data that cartridge export doesn't capture.
**Depends on:** /course-import Canvas API path stable and tested. User demand.
**Priority:** P3

## ~~v2: SCORM/xAPI Package Import~~ SHIPPED (v1.4.0)
Shipped in v1.4.0. SCORM 1.2/2004 import added as Path E in /course-import.
SCORM 1.2 export added as Path C in /course-export. PDF import also added (Path D).

## ~~v2: Standardize Next-Step Formatting~~ SHIPPED (v1.5.0)
Shipped in v1.5.0. Pipeline progression guidance now generates dynamic next-step
recommendations based on timeline data. The shared preamble handles this consistently
across all skills.

## v2: Multi-Platform Install (Gemini CLI + Codex CLI) — PARTIALLY SHIPPED
**Codex CLI: SHIPPED in v2.5.0.0.** Per-skill auto-discovery at `$CODEX_HOME/skills/idstack-<name>/`,
plus a whole-repo symlink at `~/.agents/plugins/idstack/` for in-skill `bin/` resolution. Multi-target
generator (`--target {claude|codex|all}`) emits the Codex flavor under `dist/codex/skills/` with
`allowed-tools:` stripped. Concept-name preamble lets the same skill body run in both CLIs.

**Gemini CLI: still pending (v2.6).** `.tmpl` → `.toml` transform, `gemini-extension.json`
manifest, `ask_user` tool mapping. Gemini's built-in structured-question tool is a clean
drop-in for the AskUserQuestion concept.

**Marketplace publishing: still pending (v2.6).** v2.5 uses simpler per-skill auto-discovery;
proper Codex marketplace.json + .codex-plugin/plugin.json packaging would let users do
`codex plugin marketplace add savvides/idstack` without cloning.

**Why:** Expands addressable market beyond Claude Code.
**Priority:** P2 (Codex done; Gemini next)

## ~~v2: Sub-Agent Architecture for Context Efficiency~~ SHIPPED (v2.0–v2.2)
Shipped across v2.0 and v2.2. /accessibility-review runs WCAG and UDL as parallel
sub-agents; /course-quality-review parallelizes its QM/CoI/alignment dimensions; v2.2
moved /red-team into a clean-context sub-agent that returns to the parent for a
triage-and-fix loop (Critical / Critical+High / All / Skip). Claude Code only;
graceful degradation elsewhere.

## v2: Config System
Add `bin/idstack-config` for persistent user preferences (auto-update on/off, default
export format, context recovery verbosity). Plain YAML at `.idstack/config.yaml`.
**Why:** As course memory adds configurable behaviors, users need a way to set preferences.
**Depends on:** Course memory system (v1.5.0) proving useful. User feedback on what
to make configurable.
**Priority:** P3

## v2: Cross-Course Intelligence
Enable learnings and patterns to transfer across courses (e.g., PSY101 to PSY201).
Requires a global storage location (`~/.idstack/global/learnings.jsonl`) alongside
the project-local `.idstack/` files. Institutional knowledge compounds across semesters.
**Why:** IDs who teach multiple courses discover the same quirks repeatedly.
**Depends on:** Course memory system (v1.5.0) in use. Needs design for how global
vs project-local learnings interact.
**Priority:** P2

## v2: Interactive Landing Page Demo
Upgrade the "See it work" section on idstack.org from static text to an interactive
pre-install demo. The current section shows a text transcript of /course-import and
/course-quality-review. A richer version could include: animated terminal replay
(CSS-only, building on the existing typing animation), clickable pipeline explorer
showing what each of the 11 skills does, or expanded sample output with evidence
citations. The goal is to let prospective users experience the value before installing.
**Why:** CEO review killed a post-install /demo command because IDs always have a course.
The real TTHW problem is pre-install: visitors on idstack.org need to understand the
value before committing to install. The landing page demo is where that conversion happens.
**Depends on:** Design review of the current landing page to identify what's working
and what's not. User feedback on whether the current "See it work" section is compelling.
**Priority:** P2

## v3: Bidirectional LMS Sync
Push changes back to Canvas (and eventually other LMS) via API. After
/course-quality-review identifies issues and /learning-objectives generates better
ILOs, push the improvements back to the LMS. The output IS the course.
**Why:** The 10x vision. Eliminates the translation step from design doc to LMS.
**Depends on:** /course-import stable, Canvas API write operations investigated,
conflict handling designed, institutional partnerships.
