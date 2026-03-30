# TODOS

## v1.1: Manifest Versioning
Add a version migration check to the manifest preamble. When the schema changes,
existing project.json files need graceful upgrade rather than silent breakage.
Check manifest.version field on read, apply migrations if needed.
**Why:** Zero users now, but once people have real project.json files, schema
changes will break their work.
**Depends on:** v1 shipped and schema changes needed.

## v2: Cross-Domain Quality Checks
Add 4 deferred checks to /course-quality-review:
- Cognitive load flags (Domain 4, T1 evidence) — split attention, redundancy, poor sequencing
- Multimedia principle violations (Domain 6, T1 evidence) — contiguity, segmenting, modality
- Feedback quality check (Domain 5, T1 evidence) — elaborated vs correctness feedback
- Expertise reversal check (Domains 4/7, T1 evidence) — strategy-audience mismatch
**Why:** These are the strongest evidence domains in the synthesis. High value.
**Depends on:** v1 quality review skill stable and tested.

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

## v3: Bidirectional LMS Sync
Push changes back to Canvas (and eventually other LMS) via API. After
/course-quality-review identifies issues and /learning-objectives generates better
ILOs, push the improvements back to the LMS. The output IS the course.
**Why:** The 10x vision. Eliminates the translation step from design doc to LMS.
**Depends on:** /course-import stable, Canvas API write operations investigated,
conflict handling designed, institutional partnerships.
