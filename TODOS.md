# TODOS

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

## v2: Multi-Platform Install (Gemini CLI + Codex CLI)
Add install support for Gemini CLI (~/.gemini/skills/) and Codex CLI (~/.agents/skills/).
All three platforms use the same SKILL.md format (name + description frontmatter).
Key challenges: hardcoded ~/.claude/ paths in all 7 SKILL.md preambles need refactoring
to platform-agnostic paths (IDSTACK_HOME env var or relative resolution), allowed-tools
frontmatter uses Claude Code tool names, and tool name compatibility needs verification.
**Why:** Expands addressable market to Gemini CLI and Codex CLI users.
**Depends on:** User feedback confirming demand (via Google Form). Spike test on
one SKILL.md to verify compatibility before full implementation.
**Priority:** P2

## v2: Sub-Agent Architecture for Context Efficiency
Skills like /red-team run 5 adversarial dimensions sequentially in the main context.
Each dimension could dispatch as a sub-agent, keeping the main session lean. Carl
Vellotti's research shows sub-agents can reduce main session context from 25% to 16.5%
for equivalent work. For /red-team: dimensions 1-5 as parallel sub-agents, results
aggregated in the main session for scoring. Same pattern applies to /accessibility-review
(WCAG + UDL could be parallel sub-agents) and /course-quality-review (QM + CoI).
**Why:** Context efficiency directly affects session length. A session that compacts
after 5 messages vs one that lasts 30 is a completely different user experience.
**Depends on:** Understanding how each AI CLI handles sub-agent dispatching (Claude Code
Agent tool, Gemini CLI equivalent, Codex subagents). Template system (v2) would make
this easier to implement consistently across skills.
**Priority:** P2

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

## v3: Bidirectional LMS Sync
Push changes back to Canvas (and eventually other LMS) via API. After
/course-quality-review identifies issues and /learning-objectives generates better
ILOs, push the improvements back to the LMS. The output IS the course.
**Why:** The 10x vision. Eliminates the translation step from design doc to LMS.
**Depends on:** /course-import stable, Canvas API write operations investigated,
conflict handling designed, institutional partnerships.
