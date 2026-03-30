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
The full skill suite from the evidence synthesis includes 7 more skills:
- id-model-selector (Domain 1) — context-driven model/framework recommendation
- content-sequencing (Domain 4) — cognitive load-aware sequencing and chunking
- media-selection (Domain 6) — multimedia principle application and violation flagging
- assessment-design (Domains 2, 5) — formative/summative design with feedback quality
- evaluation-design (Domain 8) — Kirkpatrick+ evaluation planning
- prototype-iteration (Domain 9) — rapid prototyping cycle structure
- learner-analysis (Domain 7) — standalone learner characteristic profiling
**Why:** Completes the full ID lifecycle coverage. Each backed by evidence synthesis.
**Depends on:** v1 adoption and feedback from real instructional designers.

## v2+: LMS Integration
Skills that push designs directly into Canvas, Blackboard, Moodle via API.
The output IS the course, not a spec for the course.
**Why:** The 10x vision. Eliminates the translation step from design doc to LMS.
**Depends on:** v1 stable, LMS API investigation, institutional partnerships.
