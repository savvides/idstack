# Changelog

## v2.3.0.0 (2026-05-02)

### Added
- **Imported-course mode for `needs-analysis`, `assessment-design`, and `course-builder`.** The TMC-430 test report flagged that these skills assume net-new course design and break down for imported courses. Each now branches early on `import_metadata.source`:
  - `needs-analysis` skips the "is training the right intervention?" decision gate for credit-bearing imports (the registrar can't be told to remove the course); records the rationale and confidence automatically and runs a "design-fit" check instead.
  - `assessment-design` adds **Mode 3: Audit Existing Assessments** alongside the existing Mode 1/Mode 2 split. Reads the existing rubrics from the cartridge, classifies criteria on Bloom's, compares to ILOs, and surfaces alignment gaps — does NOT propose new assessments unless the user explicitly asks. Mode 3 takes precedence over Mode 1.
  - `course-builder` adds **gap-fill mode** triggered when `import_metadata.source` is set and `course_content.modules` is non-empty. Generates ONLY the artifacts upstream skills flagged as missing (e.g., a missing rubric, a formative practice quiz set), instead of regenerating the syllabus, modules, and rubrics that already exist in the cartridge.
  - All three skills announce the chosen mode at the start of the conversation so the user can override if the auto-detection is wrong.
  - Resolves test-report issues #7, #13, #14.
- **Canonical schema additions** (additive, no version bump): optional `needs_analysis.mode`, `assessments.mode`, `course_content.mode` (record which mode the skill ran in); `assessments.audit_notes[]` (Mode 3 outputs); `course_content.recommended_generation_targets[]` (gap-fill mode outputs). Per-section item shapes documented in `templates/manifest-schema.md`.
- **`assessment-design` switches to `bin/idstack-manifest-merge`.** Replaces the inline-write pattern (with its misleading "Include the COMPLETE schema structure" instruction) with two scoped merge calls — one for `assessments`, one for `learning_objectives`. Same atomic-write benefits introduced in v2.1.0.0.

### Changed
- Smoke test now runs 153 assertions (was 150). New: each of the 3 mode-aware skill templates must reference `import_metadata.source` (drift guard against accidental removal of the mode-detection branch).

## v2.2.0.1 (2026-05-02)

### Fixed
- **`bin/idstack-manifest-merge` validates manifest root is a JSON object.** A manifest containing a JSON list, string, or other non-object at the root previously crashed with `TypeError` on `manifest[args.section] = payload`. Now exits 2 with a clear "manifest root must be a JSON object" message. Two new unit tests (list root, string root) cover this. (Gemini code review of PR #8.)
- **`setup` legacy-cleanup paths now respect the `--local` scope.** Cleanup of legacy v2.0 dispatcher symlinks and pre-v2 per-skill symlinks previously hardcoded `$HOME/.claude/skills`, which meant `--local` installs never had their own `./.claude/skills/` cleaned up. Introduced a `LEGACY_SKILLS_DIR` variable that defaults to `$HOME/.claude/skills` and switches to `$(pwd)/.claude/skills` for `--local` — each scope only touches its own legacy path. (Gemini code review of PR #6.)
- **`fixes_applied` and `fixes_deferred` shapes documented** in `red-team` skill. The skill mentioned recording "a one-line reason" for deferred fixes but didn't show the JSON shape. Now documents `{id, description}` for applied and `{id, reason}` for deferred fixes — same convention used by other findings arrays. (Gemini code review of PR #7.)

### Changed
- **`bin/idstack-gen-skills` removed dead `frontmatter` variable.** Variable was extracted but never used (the awk pass below it handles frontmatter detection independently). (Gemini code review of PR #8.)
- **`test/test-manifest-merge.sh` simplified Test 1 assertion.** Removed a redundant `||` clause whose first half (`d["red_team_audit"] == ""`) could never be true given the dict payload — only the second half ever ran. Replaced with the single dict-equality check. (Gemini code review of PR #8.)

## v2.2.0.0 (2026-05-02)

### Changed
- **Red team now runs in a clean-context sub-agent.** Previously the audit's per-dimension scans ran as parallel sub-agents but the synthesis layer (which decides "is this course actually good?") ran in the parent's context — inheriting whatever build-bias the parent had accumulated. The skill now spawns a single `general-purpose` orchestrator with a self-contained brief; the orchestrator sees the manifest and course files fresh, runs the 5 dimensions (still parallel where Agent tool is available), writes `.idstack/red-team-report.md`, and returns a short executive summary. The parent never sees the audit reasoning, only the report — same view a real student gets.

### Added
- **Pre-spawn focus question.** The skill asks one question before invoking the orchestrator: full sweep (default) vs. a specific angle (assessment gaming, cognitive overload, persona accessibility, evidence accuracy). Lets reviewers steer depth without forcing it.
- **Triage-and-fix loop in the parent.** After the orchestrator returns, the parent surfaces the summary and asks one AskUserQuestion: which severity bucket to address (Critical only / Critical+High / All / Skip). Selected fixes are applied in-context (parent already knows the course structure), with each finding tracked as `fixes_applied` or `fixes_deferred` in the manifest. No automatic re-verification — re-running `/idstack:red-team` is opt-in.
- **Stable finding ids.** Each finding now has a `<dimension>-<n>` id (e.g., `alignment-1`) so the parent can reference findings deterministically when applying fixes and when re-running for verification.
- **`.idstack/red-team-report.md`.** Durable, user-readable artifact with the full finding list, per-dimension summaries, top 3 actions, and limitations. Manifest's `red_team_audit` section now also stores `report_path` pointing at it.
- **Red-team uses `bin/idstack-manifest-merge`.** Step 6 (update manifest) now calls the merge tool introduced in v2.1.0.0 instead of inlining the full manifest in an `Edit` operation. Atomic, foreign-section-preserving, schema-validated write. Falls back to inline write if the tool is unavailable.

### Manifest schema
- No further version bump. v2.1.0.0 already raised the schema to 1.4 and added the optional `red_team_audit.focus`, `report_path`, `fixes_applied`, `fixes_deferred` fields that this PR consumes.

## v2.1.0.0 (2026-05-02)

### Changed
- **Manifest schema centralized into one canonical source.** Each skill's SKILL.md.tmpl previously inlined its own copy of the manifest schema; the copies had drifted apart, and bin scripts had hardcoded paths that didn't always match. Now `templates/manifest-schema.md` is the single source of truth, substituted into skill templates via the existing `{{MANIFEST_SCHEMA}}` mechanism (mirroring `{{PREAMBLE}}`). Adds explicit per-section item shapes (`assessments.items`, `learning_objectives.alignment_matrix.ilo_to_activity`, `red_team_audit.dimensions.*.findings`, `accessibility_review.wcag_violations`, etc.) so downstream skills can rely on them. Resolves issues #5, #6, #9, #11, #12, #15, #19, #23 from the TMC-430 test report.
- **`bin/idstack-status` verdict logic now stricter.** Previously a course with quality 60+ and zero critical red-team findings reported `READY TO EXPORT` even when accessibility was 0 or had unaddressed Level-A WCAG violations. New gate: `READY` requires `quality_score >= 70` AND `accessibility_score >= 80` AND zero critical red-team findings AND zero WCAG Level-A violations. Per-skill rows now use a 3-tier `NOT RUN / NEEDS-WORK / READY` rating (was binary `PASS/WARN/NOT RUN`). Thresholds are named constants near the top of the script. Courses that previously reported READY may now report NEEDS-WORK or NOT-READY — re-run the relevant skills to address gaps. Resolves issues #17, #20, #24.
- **Manifest schema bumped 1.3 → 1.4.** Additive plus drift-cleanup. New optional fields under `red_team_audit` (`focus`, `report_path`, `fixes_applied`, `fixes_deferred`) and `import_metadata` (`quality_flag_details`). The 1.3 → 1.4 migration in `bin/idstack-migrate` renames `red_team_audit.summary.{critical_count,warning_count,info_count}` to `red_team_audit.findings_summary.{critical,warning,info}` (the names `bin/idstack-status` reads), and moves any legacy root `_import_quality_flags` field into `import_metadata.quality_flag_details`.

### Added
- **`bin/idstack-manifest-merge`** — Python tool that atomically replaces one top-level section of the manifest, preserving every other section and the top-level `version`/`project_name`/`created` fields. Section-level replacement (not recursive deep-merge), whitelisted section names, atomic via tempfile+rename, structured exit codes (1/2/3/4/5 for malformed payload / malformed manifest / unknown section / missing manifest / missing payload). Skills should use this in preference to inlining the full manifest in `Edit` operations. Partially resolves issue #21 (Edit-driven JSON manipulation fragility at scale).
- **`templates/manifest-schema.md`** — canonical schema reference. Documents top-level fields, ownership per skill, and per-section item shapes.
- **`test/test-manifest-merge.sh`** — 13-case unit suite for the merge tool (replace, preserve foreign sections, reject malformed input, reject unknown sections, atomic timestamp bump, etc.). Invoked from `test/smoke-test.sh`.
- **Schema-drift regression guards in smoke-test.** New assertions: every skill template that previously had an inline schema now uses `{{MANIFEST_SCHEMA}}`; no SKILL.md.tmpl mentions historically-drifted field names like `red_team_audit.summary.critical_count` or `_import_quality_flags`; every generated SKILL.md inlines the canonical v1.4 schema. Smoke test now runs 150 assertions (was 115).

### Fixed
- **`bin/idstack-timeline-log` no longer overwrites caller-supplied `ts` field.** Now uses `setdefault` semantics: if the caller passes `"ts": "..."`, it's preserved; only when absent does the script mint one. Documented in the script header. Resolves issue #2.
- **`course-import` documents the macOS `mktemp -d` portability gotcha.** The `-t` flag on macOS treats its argument as a literal prefix instead of substituting `XXXXXX` — producing a broken path. Template now states the bare `mktemp -d` form is portable and must be used. Resolves issue #3.

### Out of scope (deferred — see TMC-430 test report)
- "Imported-course mode" branching for needs-analysis, assessment-design, course-builder (issues #7, #13, #14). Substantive scope work, deserves its own PR.
- Per-skill scope improvements (#10, #16, #18, #22, #25): coverage cross-walk, scoring methodology, parallel-dispatch payload size, accessibility tooling, evidence currency check.
- Minor docs/UX polish (#4, #8). Issue #1 (sub-skill routing) was already resolved in v2.0.1.0.

## v2.0.1.0 (2026-05-02)

### Fixed
- **Plugin install actually exposes namespaced sub-skills.** v2.0.0 promised `/idstack:<skill>` but `./setup` symlinked the repo into `~/.claude/skills/idstack`, where Claude Code only discovers the top-level dispatcher SKILL.md (one level deep). The 11 sub-skills under nested directories were never registered. Setup now installs to `~/.claude/plugins/idstack` (the plugin discovery path), and the 11 skills live under `skills/` per the plugin layout — so `/idstack:needs-analysis`, `/idstack:pipeline`, etc. show up in the slash command picker.
- **Circular self-symlink when cloning into the install target.** The README's recommended one-liner clones into the install path, then runs `./setup`. The script unconditionally ran `ln -snf $REPO $TARGET` even when `$REPO == $TARGET`, producing a broken self-symlink (`~/.claude/skills/idstack/idstack -> ~/.claude/skills/idstack`) inside the repo. Setup now detects the same-path case and skips the symlink step (the install is already in place).
- **Removed root dispatcher SKILL.md.** The dispatcher only existed as a workaround for the broken symlink discovery — once the plugin install works, the namespaced skills replace it. The welcome-message logic moves into the slash command picker, where users see all 11 sub-skills directly.
- **Setup migrates legacy v2.0 installs.** If `~/.claude/skills/idstack` is a symlink, setup removes it. If it's a real directory (i.e., the v2.0 README had users clone there), setup leaves it in place but warns and tells the user how to remove it manually.

### Changed
- Repo layout: skill directories moved from repo root into `skills/` subdirectory (required by the plugin format).
- `bin/idstack-gen-skills` now reads templates from `skills/*/SKILL.md.tmpl`.
- Default install path in preamble fallback, README, and CLAUDE.md updated to `~/.claude/plugins/idstack`.

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
