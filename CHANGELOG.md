# Changelog

## v2.0.0.0 (2026-04-20)

### Added
- **Pipeline orchestrator.** `/idstack:pipeline` chains all 8 design skills automatically, auto-skipping completed ones. Pause anytime, resume later. Your progress is saved in timeline.jsonl.
- **Cross-course intelligence.** Learnings from one course now appear in another via `~/.idstack/global/learnings.jsonl`. Keyword search with `--keyword` and `--cross-project` flags.
- **`/idstack:learn` skill.** Search, list, delete, promote, and export project learnings. Promote local discoveries to the global store for cross-project reuse.
- **Course readiness dashboard.** `bin/idstack-status --readiness` shows a pre-export gate: quality score, red-team critical findings, accessibility score, with pass/fail verdict. Integrated into `/idstack:course-export`.
- **Designer profile.** Create `~/.idstack/profile.yaml` with `experience_level: novice|intermediate|expert`. Skills adapt explanation depth to your expertise.
- **Manifest preferences.** Schema v1.3 adds `preferences` section: verbosity, export_format, preferred_lms, auto_advance_pipeline.
- **Sub-agent architecture.** On Claude Code, review skills dispatch parallel sub-agents for speed: `/idstack:red-team` (5 agents), `/idstack:accessibility-review` (2 agents), `/idstack:course-quality-review` (3 agents). Graceful sequential fallback on other platforms.
- **Spec review loop.** `/idstack:course-builder` validates alignment via adversarial sub-agent after generating content. Reports "Review: N issues found, M fixed."
- **Claude Code plugin.** `.claude-plugin/plugin.json` manifest for marketplace distribution. Install via `claude plugin install idstack` or traditional `git clone && ./setup`.
- **`IDSTACK_HOME` env var.** All internal paths now use `${IDSTACK_HOME:-~/.claude/skills/idstack}`. Set this to install anywhere.
- **New bin scripts.** `bin/idstack-learnings-delete`, `bin/idstack-learnings-promote` for managing learnings programmatically.

### Changed
- **Namespace refactor.** All skills now invoked via `/idstack:<skill>` (e.g., `/idstack:needs-analysis`) instead of `/<skill>`. Avoids name collisions with other skill packages.
- **Setup creates single symlink.** `./setup` now creates only `~/.claude/skills/idstack` (cleans up legacy individual symlinks automatically).
- **Manifest schema v1.3.** Adds preferences section. Chained migration from v1.0/v1.1/v1.2 in one pass.
- **Preamble reads designer profile and preferences** on every skill start.

## v1.5.1.0 (2026-04-10)

### Added
- **Bidirectional pipeline.** All 9 skills now write back to the manifest. Previously 5 skills were read-only (course-quality-review, course-builder, red-team, accessibility-review, course-export). Now every skill contributes to the shared project state, so downstream skills get richer input.
- **Score trending.** Run `/course-quality-review` multiple times and see your score improve: "Score: 78/100 (+16 since last review)." Current score in the manifest, history in the timeline. One source of truth per data point.
- **Export readiness info.** `/course-export` now shows quality, red-team, and accessibility scores before export. Informational only, never blocks.
- **WCAG 2.1 AA depth.** `/accessibility-review` expanded from 8 to 20+ evidence citations with full WCAG success criteria. Course-specific guidance for videos, quizzes, forums, PDFs, and simulations.
- **Red-team evidence grounding.** `/red-team` expanded from 12 to ~45 evidence citations. All 5 adversarial dimensions now cite their research.
- **Chained schema migrations.** `bin/idstack-migrate` refactored to support migration chains (1.0→1.1→1.2). Users on any version get upgraded in one pass.
- **Migration test fixtures.** New `test/fixtures/` with v1.0 and v1.1 manifest fixtures. 11 new migration assertions in smoke-test.sh.

### Changed
- Manifest schema bumped to v1.2 (additive only, no breaking changes).

## v1.5.0.2 (2026-04-06)

### Fixed
- **Security:** Removed silent auto-update that pulled and executed code from GitHub without user review. Skills now notify when updates are available. Users update manually with `git pull && ./setup`.

## v1.5.0.1 (2026-04-04)

- Landing page now shows development updates and roadmap at [idstack.org](https://idstack.org). Timeline with recent releases (dates as primary identifiers, not version numbers) plus "Coming soon" items and a "Where we're headed" narrative. Non-technical visitors can see what's new without navigating GitHub.
- Updated architecture description on landing page to reflect course memory (timeline, learnings).
- Removed stale architecture ASCII diagram from landing page (replaced with prose description).

## v1.5.0 (2026-04-04)

- **Course memory.** idstack now remembers your design sessions. Each skill logs what it did to `.idstack/timeline.jsonl`, and the next session starts with a welcome-back message: quality score trend, last skill run, suggested next step. Your course context compounds across sessions instead of starting from scratch.
- **Learnings.** When a skill discovers something specific to your project (Canvas uses custom rubric formatting, SCORM packages from Rise need special handling), it stores the discovery in `.idstack/learnings.jsonl`. Future sessions surface relevant learnings automatically.
- **Pipeline guidance.** Skills now suggest the next step based on what you've already completed, replacing inconsistent static "Next step:" text with data-driven recommendations.
- **`bin/idstack-status`** prints a course health dashboard: skills completed, quality score trend, dimension breakdown, and suggested next skill.
- **Template system.** Shared preamble code (update check, manifest check, context recovery) is now maintained in one place (`templates/preamble.md`). Skills use `.tmpl` files with a `{{PREAMBLE}}` placeholder. Run `bin/idstack-gen-skills` to regenerate.
- **python3 recommended.** Course memory features work best with python3 (score trends, search filtering, JSON validation). Without it, basic timeline logging still works via bash fallback.

## v1.4.1.1 (2026-04-03)

- Setup now tells you to restart Claude Code if it's already running, so skills appear immediately
- Post-install message routes you to the right starting skill: `/course-import` if you have an existing course, `/needs-analysis` if starting fresh

## v1.4.1 (2026-04-02)

- Landing page live at [idstack.org](https://idstack.org) with getting started guide, terminal demo, skill pipeline diagram, and evidence grid across 11 research domains
- Skills check for updates and notify when a new version is available.
- SEO: Open Graph and Twitter card tags, JSON-LD structured data, OG image, and favicon for link previews when shared on social media

## v1.4.0 (2026-04-01)

- You can now import SCORM 1.2 and 2004 packages directly into `/course-import`. Works with Articulate Rise, Storyline, Adobe Captivate, Lectora, iSpring, and any SCORM-compliant authoring tool. Extracts course structure, objectives, and assessments from the imsmanifest.xml.
- You can now export to SCORM 1.2 packages from `/course-export`. Produces a standard SCORM ZIP that works with every LMS and corporate training platform.
- PDF and document file import added to `/course-import` for Articulate Rise exports and course syllabi

## v1.3.0 (2026-04-01)

- You can now run `/accessibility-review` to audit your course for WCAG 2.1 AA compliance and Universal Design for Learning (UDL 3.0). Two-tier output: "Must Fix" for legal accessibility violations, "Should Improve" for inclusive design recommendations. Scores accessibility 0-100.
- You can now run `/red-team` to stress-test your course design. Five adversarial dimensions: alignment gaps, evidence verification, cognitive load analysis, learner persona simulation, and prerequisite chain integrity. Produces a confidence score so you know how solid your design is before you export.
- New evidence domain added: Domain 11 (Accessibility & Universal Design for Learning) with 9 citations covering WCAG, UDL Guidelines 3.0, and differentiated instruction research
- Pipeline extended: `/accessibility-review` and `/red-team` sit between `/course-quality-review` and `/course-export` as the final quality gates
- Smoke tests expanded from 46 to 58 checks covering all 9 skills

## v1.2.1 (2026-04-01)

- You can now submit feedback and feature requests without a GitHub account via a [Google Form](https://forms.gle/6LDgDD1M6WWyYvME8)
- Feedback link added to every skill, so you can share thoughts right after using one
- README intro softened for a warmer, more inviting tone
- Multi-platform install (Gemini CLI + Codex CLI) added to roadmap as a P2 item

## v1.2.0 (2026-03-31)

- Cross-domain quality checks in `/course-quality-review`: cognitive load, multimedia principles, feedback quality, and expertise reversal flags
- Manifest versioning with automatic schema migration (`bin/idstack-migrate`)
- Fix-link integration so quality review recommendations point you to the skill that fixes each issue
- Quick-win prioritization ranks recommendations by effort vs impact
- Score trending tracks your course quality across review sessions
- Shareable quality report and per-category scoring breakdown
- Pipeline reordered so `/course-quality-review` runs before `/course-export`
- Auto-create GitHub Release on tag push

## v1.1.1 (2026-03-31)

- VERSION file added for tracking
- Branch protection and CONTRIBUTING.md for contributors

## v1.1.0 (2026-03-30)

- 4 new skills: `/assessment-design`, `/course-builder`, `/course-export`, `/course-import`
- Full pipeline from import to export now works end to end
- Automatic update check in all skills (tells you when a new version is available)
- README rewritten with install-by-pasting flow and live demo walkthrough

## v1.0.0 (2026-03-30)

- Initial release with 3 skills: `/needs-analysis`, `/learning-objectives`, `/course-quality-review`
- Evidence base from peer-reviewed research across 11 domains
- Shared project manifest (`.idstack/project.json`)
- Evidence tier citations (T1-T5) on every recommendation
