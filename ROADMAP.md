# Roadmap

What's coming next for idstack. Priorities are shaped by user feedback. [Tell us what matters to you.](https://forms.gle/6LDgDD1M6WWyYvME8)

## Just shipped

### Bidirectional pipeline + evidence depth (v1.5.1)
- All 9 skills now write back to the manifest, closing the feedback loop. Downstream skills get richer input from upstream analysis.
- Score trending: run `/course-quality-review` multiple times and see your score improve over sessions.
- `/accessibility-review` expanded to full WCAG 2.1 AA coverage with course-specific guidance for videos, quizzes, forums, PDFs, and simulations.
- `/red-team` all 5 adversarial dimensions now cite their research evidence.
- `/course-export` shows readiness info (quality, accessibility, red-team scores) before export.
- Schema migration v1.2 with chained upgrades (any version → latest in one pass).

### Course memory (v1.5.0)
- idstack remembers your design sessions across conversations. Each skill logs what it did, and the next session starts with context: quality score trends, last skill run, and suggested next step.
- Skills store project-specific discoveries (LMS quirks, format issues) as learnings that surface in future sessions.
- `bin/idstack-status` prints a course health dashboard at any time.
- Template system for contributors: shared preamble maintained in one place.

### Landing page and update check (v1.4.1)
- [idstack.org](https://idstack.org) — landing page with getting started guide, evidence grid, and SEO
- Skills check for updates and notify when a new version is available.

### SCORM import and export (v1.4.0)
- `/course-import` now accepts SCORM 1.2/2004 packages from Articulate Rise, Storyline, Adobe Captivate, Lectora, iSpring, and any SCORM-compliant authoring tool
- `/course-export` now generates SCORM 1.2 packages for any LMS or corporate training platform
- PDF and document file import also added for Rise course exports and syllabi

### Accessibility review + Red team audit (v1.3.0)
- `/accessibility-review` — WCAG 2.1 AA compliance plus Universal Design for Learning (UDL 3.0). Two-tier output: "Must Fix" for legal compliance, "Should Improve" for inclusive design.
- `/red-team` — Adversarial course audit. Assumes the course is broken and tries to prove it. Five dimensions: alignment stress test, evidence verification, cognitive load analysis, learner persona simulation, prerequisite chain integrity. Produces a confidence score.

## Coming soon

### More skills
Four more skills based on the research synthesis:

- **Model selector** — recommends the right instructional design framework for your context (ADDIE, SAM, backward design, etc.) instead of defaulting to one
- **Content sequencing** — organizes your modules and lessons to manage cognitive load, applying spacing, interleaving, and scaffolding principles
- **Media selection** — flags multimedia principle violations (redundancy, split attention, coherence) and recommends when to use video, text, diagrams, or interactive elements
- **Evaluation design** — plans how to measure whether your course actually worked, using Kirkpatrick's four levels and beyond

## Exploring

These depend on user demand. If any of these would change your workflow, [let us know](https://forms.gle/6LDgDD1M6WWyYvME8).

### Multi-platform support
Run idstack skills in Gemini CLI and Codex CLI, not just Claude Code. All three platforms use the same skill format. We're waiting for feedback before investing here.

### More LMS integrations
Direct API connections to Blackboard, Moodle, and D2L (beyond the IMS Common Cartridge format that already works). This would unlock richer data like rubrics, analytics, and student engagement metrics.

## The big vision

### Push changes back to your LMS
After `/course-quality-review` identifies issues and `/learning-objectives` generates better objectives, push the improvements directly back to Canvas (and eventually other LMS platforms). No more copy-pasting between a design document and your LMS. The output IS the course.

This is the 10x goal. It depends on stable import/export, Canvas API write support, conflict handling, and institutional partnerships. It's a ways out, but it's where we're headed.

## Shipped

See [CHANGELOG.md](CHANGELOG.md) for the full version history.
