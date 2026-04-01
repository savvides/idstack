# TODOS

## ~~v1.1: Manifest Versioning~~ SHIPPED (v1.2.0)
Shipped in v1.2.0. `bin/idstack-migrate` handles schema migrations.
All 7 skill preambles call it automatically.

## ~~v2: Cross-Domain Quality Checks~~ SHIPPED (v1.2.0)
Shipped in v1.2.0. Four checks added to /course-quality-review:
cognitive load, multimedia principles, feedback quality, expertise reversal.
Plus: fix-link integration, quick-win prioritization, score trending,
shareable quality report, and per-category scoring breakdown.

## v2: Template System
At 5+ skills, evaluate SKILL.md.tmpl -> SKILL.md template system for shared preamble
(manifest read/write, cross-cutting concerns, evidence tier definitions).
**Why:** Duplication across 3 skills is acceptable. Across 8+ it becomes a maintenance burden.
**Depends on:** Decision to build additional skills beyond v1's 3.

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

## v2: Standardize Next-Step Formatting
Normalize the "next step" section format across all SKILL.md files.
Currently inconsistent: "Next step:" (singular), "Next steps:" (plural),
"Recommended next steps:" (course-import).
**Why:** Consistency improves the user experience and makes the pipeline feel cohesive.
**Depends on:** Nothing. Low-effort cleanup.
**Priority:** P3

## v3: Bidirectional LMS Sync
Push changes back to Canvas (and eventually other LMS) via API. After
/course-quality-review identifies issues and /learning-objectives generates better
ILOs, push the improvements back to the LMS. The output IS the course.
**Why:** The 10x vision. Eliminates the translation step from design doc to LMS.
**Depends on:** /course-import stable, Canvas API write operations investigated,
conflict handling designed, institutional partnerships.
