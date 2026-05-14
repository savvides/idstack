# Changelog

## v3.2.0.0 (2026-05-14)

### Fixed — Claude Code install uses the plugin marketplace flow

`./setup` registered the plugin by symlinking the repo into `~/.claude/plugins/idstack`. Current Claude Code (2.1.x) does not discover plugins from bare symlinks — it requires marketplace registration — so `claude plugin list` showed nothing and `/idstack:<skill>` never appeared in the slash-command picker. New Claude Code users could not install idstack.

- **`.claude-plugin/marketplace.json`** — new one-plugin marketplace manifest (`source: "./"`), the manifest the install flow requires.
- **`setup`** — the Claude branch now runs `claude plugin marketplace add` + `claude plugin install --scope <user|project>` (both idempotent; `--local` maps to project scope). Detects a missing `claude` on `PATH` and prints manual steps. Removes the now-vestigial bare symlink from older installs (only ever a symlink, never a real directory). Codex install path unchanged.
- **`bin/idstack-doctor`** — self-locates the repo and checks the real signal: `claude plugin list` for `idstack@idstack` installed and enabled, plus the plugin and marketplace manifests. Legacy-conflict detection retained.
- **`templates/preamble.md`** — `$_IDSTACK` detection no longer falls back to the removed bare symlink; the last-ditch branch resolves the marketplace cache directory. All 22 skill files regenerated.
- **`test/smoke-test.sh`** — `$IDSTACK_DIR` self-locates the repo instead of assuming `~/.claude/plugins/idstack`.

The install command in the README and on idstack.org changes from `git clone … ~/.claude/plugins/idstack && …` to `git clone … && cd idstack && ./setup`.

### Changed — idstack.org SEO and landing-page copy

- **Discoverability.** Added `docs/robots.txt` and `docs/sitemap.xml`; the `SoftwareApplication` JSON-LD gained `softwareVersion`, `datePublished`, and `dateModified`; the `<head>` announces the GitHub releases Atom feed.
- **Evidence section redesign.** The per-domain bar graph that counted studies is replaced with eleven short descriptions of what each body of evidence claims, plus a compact tier legend.
- **Branded OG share card.** `docs/og-image.png` regenerated against the current design system; `docs/og-template.html` added as the regenerable source.
- **Language pass.** Evidence-card copy, four other landing-page lines, and AI-language tells across the repo's other Markdown were rewritten to drop negative parallelism, metaphor stacking, and marketing clichés.

### Notes

- No manifest schema, path, or API changes. Minor version bump: the installer mechanism changed and the landing page got substantive work, but nothing breaks existing course folders or downstream skills.
- Claude Code copies marketplace plugins into a versioned cache; a re-run of `./setup` refreshes it on a version bump. For live plugin development, use `claude --plugin-dir <repo>`.

## v3.1.0.0 (2026-05-13)

### Added — `DESIGN.md` and design-system reconciliation

The visual system that ships in the report stylesheet and the landing page is now documented at the repo root in `DESIGN.md`. Skills, contributors, and reviewers read it before touching anything visual. `CLAUDE.md` and `AGENTS.md` route to it.

- **`DESIGN.md` at the repo root.** Source of truth for fonts, colors, spacing, border radii, motion timing, and aesthetic direction. North-star is **Proof** — the artifact should read like a peer-reviewed clinical reference. Includes anti-patterns to never ship and a dated decisions log.
- **Web fonts swapped to publication-grade.** Source Serif 4 (display + body), Public Sans (UI/labels/badges), JetBrains Mono (citations/IDs/code), loaded via Google Fonts `<link>` in `docs/index.html`, `templates/report.html.tmpl`, and `templates/index.html.tmpl`. System-font fallbacks preserved so pages stay legible offline.
- **Palette shift: ivory replaces parchment.** Background goes from `#fbfaf6` (parchment-warm) to `#faf8f3` (pristine ivory). Reads as "good paper," not "old book."
- **Second annotation color added.** Prussian blue `#1d4a5e` joins library-stamp red `#7a1f1f`. Links and citation cross-references now use blue; the kicker / primary marks stay red. Mirrors the two-pen academic-editor convention.
- **Sharper corners across the surface.** Finding cards and other card surfaces are now `border-radius: 0`. Buttons, badges, chips, install snippets normalize to `2px`. The publication signal at the expense of consumer-SaaS softness.
- **Tier-badge weights amplified.** T1 / T2 render bold (the strongest evidence reads heaviest); T5 stays light grey (expert opinion reads weakest). Hex values unchanged.

### Changed

- `templates/assets/idstack.css` — reconciled to `DESIGN.md` tokens (ivory bg, prussian-blue links, sharp finding cards, new font tokens). Shipped to every course folder as before.
- `docs/index.html` — same token swap; UI chrome (eyebrows, badges, copy button, footer form, brand-beta, severity chips, pipeline labels) now uses Public Sans via `--font-ui`.
- `templates/report.html.tmpl` / `templates/index.html.tmpl` — `<head>` now includes Google Fonts preconnect + stylesheet link for Source Serif 4 / Public Sans / JetBrains Mono.
- `CLAUDE.md` / `AGENTS.md` (via `templates/agent-context.md`) — new **Design system** section instructing skills to read `DESIGN.md` before any UI decision.

### Notes

- No path, manifest, or API changes; minor version bump because the design system is now load-bearing for new skills and reviewers.
- Reports written by older versions still render correctly with the new stylesheet — the existing class hooks (`finding sev-{severity}`, `tier-badge tier-T{N}`, `sev-badge`, `citation`) are unchanged.

## v3.0.0.0 (2026-05-13)

### Changed — branded HTML reports + per-course export folder

The human-facing report format is now HTML. The container is now a per-course folder. Every artifact that belongs to a course — every per-skill report, the pipeline dashboard, the bundled stylesheet, and any LMS packages — lives under one self-describing folder: `.idstack/exports/<course-slug>/`. Zip the folder to hand the whole deliverable to a stakeholder.

- **HTML replaces Markdown for the human view.** Every skill that produces findings now writes a branded, self-contained HTML report at `.idstack/exports/<course-slug>/<skill>.html`. Visual contract: `templates/report.html.tmpl` (the HTML skeleton) plus `templates/assets/idstack.css` (the brand stylesheet). Content contract is unchanged: observation → evidence → why-it-matters → suggestion, severity (`critical|warning|info`) and evidence tier (`T1`–`T5`) on every finding.
- **Brand stylesheet matches `idstack.org`.** Scholarly serif body, ink-on-parchment palette, severity-colored finding cards (rust/amber/slate), tier badges weighted by strength (T1 heaviest, T5 lightest), citation marks in mono. Print-friendly. Auto light/dark via `prefers-color-scheme`. No JavaScript, no external fonts, no network — open and read.
- **Course folder, by name.** `<course-slug>` is derived from `project_name` via `bin/idstack-slugify` (NFKD-fold, lowercase, kebab-case, ASCII-safe; empty input → `untitled-course`). Renaming a course's `project_name` moves future exports to a new folder; older folders are left in place.
- **`/idstack:pipeline` produces a course dashboard.** `.idstack/exports/<course-slug>/index.html` carries readiness scores (Quality / Accessibility / Red-team confidence), a pipeline status table with links to every per-skill report, top cross-cutting issues, evidence themes, the LMS artifact list, and a where-to-start pointer. Same structure as `templates/index.html.tmpl`. Replaces the old `pipeline.md` aggregate.
- **LMS packages move into the course folder.** `course-export.imscc` and `scorm-export.zip` now write to `.idstack/exports/<course-slug>/`, not the root `.idstack/`. The `export_metadata.destination` field reflects the new path.
- **`course-export` now writes a report.** Previously the only pipeline skill without a human-facing report. Now produces `.idstack/exports/<course-slug>/course-export.html` alongside the LMS package.
- **`bin/idstack-status` reads the new layout.** Surfaces the dashboard first, then per-skill HTML reports, then LMS packages — all from the course folder. Auto-resolves the slug from `project_name`; falls back to the only `.idstack/exports/*` subfolder when present.
- **`bin/idstack-slugify` is a new CLI helper.** Standalone bash + python3 script implementing the slug rule. Documented in `templates/manifest-schema.md`; called by every skill that writes a report.

### Added

- `templates/report.html.tmpl` — per-skill HTML skeleton (visual contract).
- `templates/index.html.tmpl` — course dashboard skeleton.
- `templates/assets/idstack.css` — branded stylesheet matching `idstack.org` tone.
- `bin/idstack-slugify` — `project_name` → course slug.
- `bin/idstack-gen-skills` now sanity-checks that the three new template files exist; fails loud if any is missing.

### Breaking

- `report_path` semantics moved from `.idstack/reports/<skill>.md` to `.idstack/exports/<course-slug>/<skill>.html`. Existing `.idstack/reports/*.md` files from previous runs are left in place but treated as legacy — re-run the pipeline (or any skill) to migrate. Manifest schema version is unchanged (still 1.4) since field shape is identical; only the path the field points to has changed.
- LMS package paths moved: `.idstack/course-export.imscc` → `.idstack/exports/<course-slug>/course-export.imscc`; `.idstack/scorm-export.zip` → `.idstack/exports/<course-slug>/scorm-export.zip`. Tooling and docs that hard-coded the old paths need updating.

### Notes

- `bin/idstack-status` reads from the new location; legacy `.idstack/reports/*.md` are not surfaced in the dashboard listing.
- Plugin manifest version bumped to `3.0.0.0` (major: breaking `report_path` semantics).

## v2.5.0.0 (2026-05-09)

### Added — OpenAI Codex CLI support

idstack now runs natively in OpenAI Codex CLI in addition to Claude Code. Same 11
skills, same evidence base, same `.idstack/` dual-output contract, same manifest
schema. The skill bodies are CLI-agnostic; small per-CLI shims handle interaction
primitives.

- **Multi-target generator.** `bin/idstack-gen-skills --target {claude|codex|all}`.
  Codex output goes to `dist/codex/` (committed, so `codex marketplace add` works
  directly from a clone). Claude output unchanged at `skills/<name>/SKILL.md`.
- **Frontmatter portability.** The `allowed-tools:` block is stripped from Codex
  output (Codex has no per-skill allowlist; tool restrictions are session-global
  via approval policy + per-MCP `enabled_tools`/`disabled_tools`).
- **Concept-name preamble.** New "Interaction Conventions" section in
  `templates/preamble.md` defines `AskUserQuestion`, `Agent`, and `Skill (cross-skill
  invocation)` as portable concept names. Skill bodies use the same wording in both
  CLIs; the preamble interprets the concept per-host. Same body, two hosts, no
  per-target text substitution.
- **Pipeline graceful degradation.** `pipeline` skill picks up a "If the Skill tool
  is NOT available" branch — Codex prompts the user to type the next skill name and
  resumes when they re-invoke `$pipeline`. The partial-run report is regenerated
  before stopping.
- **Codex bundle artifacts.** Top-level `AGENTS.md` (memory file generated from
  `templates/agent-context.md`) and 11 `dist/codex/skills/idstack-<name>/SKILL.md`
  files. All committed; all freshness-checked by smoke test. Skill discovery in
  Codex happens at `$CODEX_HOME/skills/<name>/SKILL.md` (Codex auto-discovers
  skills there) — no marketplace.json or `.codex-plugin/plugin.json` needed for
  v1 distribution. Marketplace publishing is on the v2.6 roadmap.
- **Multi-CLI install path detection.** Preamble path resolution and the in-skill
  `_IDSTACK` chain in `course-export` and `learn` now check, in order:
  `$CLAUDE_PLUGIN_ROOT`, `$IDSTACK_HOME`, `~/.claude/plugins/idstack`,
  `~/.agents/plugins/idstack`, `~/.agents/skills/idstack`. One install layout per
  CLI; same code finds either.
- **`setup` extended.** Auto-detects `codex` on PATH and creates a two-part Codex
  install: per-skill symlinks at `$CODEX_HOME/skills/idstack-<name>/` (Codex auto-
  discovers each skill) plus a whole-repo symlink at `~/.agents/plugins/idstack/`
  (so the in-skill `$_IDSTACK/bin/idstack-*` resolves via the preamble's path
  fallback chain). Force on with `--codex`, opt out with `--no-codex`. Existing
  Claude Code install is unchanged for users who don't have Codex CLI. Setup also
  detects pre-existing real directories at install targets and removes them before
  symlinking (avoids the `ln -snf` symlink-inside-dir footgun). Caught in PR
  review by Gemini bot.
- **Smoke test extended.** New checks for `dist/codex/` artifacts: bundle directory,
  marketplace.json validity, AGENTS.md presence, all 11 Codex SKILL.md files with
  correct frontmatter and stripped `allowed-tools`. Total: 217 checks (was 161).

### Changed

- **README** marks idstack as supporting Claude Code **and** Codex CLI. (Gemini
  CLI is on the v2.6 roadmap.)
- **Plugin manifest version** bumped to `2.5.0.0` (minor: adds CLI target without
  breaking Claude Code).

## v2.4.0.2 (2026-05-05)

### Fixed — version-pattern fragility (Gemini code review, third pass)

Third Gemini-flagged iteration on the same legacy-version classifier (PR #15 → PR #19 → PR #20 → PR #21). The v2.4.0.1 pattern `1[0-9]*` correctly handled multi-digit majors starting with `1` (10–19, 100–199, …) but silently missed any other multi-digit major: `20.x`, `25.x`, `200.x`, etc. fell through both arms of the `case` and ended up classified as `unknown` — meaning a future v20 install at the legacy path would neither be skipped nor flagged for cleanup.

- **Pattern generalized.** Replaced `1[0-9]*` with `[1-9][0-9]*` in `setup`, `bin/idstack-doctor`, and `test/test-version-classifier.sh`. Strictly more general, no false positives against the legacy arm (`0.*|1.*|2.0.0.*|2.0.0`) since `[1-9][0-9]*` requires a second digit and the legacy arm requires a literal `.` or matches the bare `2.0.0`.
- **Test fixture extended.** Seven new fixtures pin the previously-silent cases: `20.0.0.0`, `21.5.0`, `25.99.0`, `29.0.0`, `30.0.0`, `200.0.0`, `999.0.0`. Total fixture count: 27. Comment header updated to record the third Gemini iteration so the next maintainer can see the history.

### Changed

- **Plugin manifest version aligned with `VERSION`.** `.claude-plugin/plugin.json` bumped to `2.4.0.2`.

## v2.4.0.1 (2026-05-05)

### Fixed — install-hygiene follow-ups (Gemini code review)

Two rounds of post-ship Gemini review caught fragility in the install-hygiene code that v2.4.0.0 introduced. All fixes target `setup` and `bin/idstack-doctor`; no skill behavior changes.

- **Multi-digit version classification.** The `case` statement that decides "modern install — leave alone" vs "pre-v2.0.1.0 — flag for cleanup" used literal-dot + single-digit `[1-9]` patterns that broke on multi-digit components like `2.0.10.0`, `2.10.0.0`, and `100.0.0` — a future v2.0.10.0 install at the legacy path would fall through both arms and produce a false "not recognized" warning. Replaced with multi-digit-safe globs (`2.0.[1-9]*|2.[1-9]*|[3-9]*|1[0-9]*`) mirrored across both files. (Gemini code review of PR #19.)
- **`test/test-version-classifier.sh`.** New unit test pins the version-glob behavior against 20 representative inputs (legacy + modern + multi-digit). Wired into `test/smoke-test.sh`. Second time Gemini caught a version-pattern bug in this code path; the test stops the third.
- **Argument parsing.** `setup --keep-legacy` and `bin/idstack-doctor --local` now match in any argument position (were: only `$1`/`$2`). Matches typical CLI flag-handling expectations. (Gemini code review of PR #15, #16.)
- **Doctor robustness.** `bin/idstack-doctor` now: explicitly `-d` checks the plugin dir (catches the rare "exists but isn't a directory or symlink" case), flags silently-failing version parses as a problem instead of swallowing them, and uses bash-native `[[ == ]]` for symlink-target matching (avoids subshell + grep, dodges the leading-dash echo footgun). (Gemini code review of PR #15.)
- **Voice-consistency in user-facing copy.** README status callout uses 3-digit `v2.4.0` to match the landing-page timeline convention; canonical 4-digit form stays in `CHANGELOG` / `VERSION` / `plugin.json`. `docs/index.html` hero-beta line now says "between minor versions" to match the README phrasing. (Gemini code review of PR #18.)

### Changed

- **Plugin manifest version aligned with `VERSION`.** `.claude-plugin/plugin.json` bumped to `2.4.0.1` to track this patch. Same alignment rule established in v2.4.0.0.

## v2.4.0.0 (2026-05-05)

### Fixed — install-hygiene

`/idstack:<skill>` was failing with `Unknown skill` on machines that still had a pre-v2.0.1.0 clone at `~/.claude/skills/idstack/`. The legacy clone shipped a top-level dispatcher `SKILL.md` (`name: idstack`); Claude Code matched it on `/idstack <args>`, the dispatcher then asked for bare-name child skills, and the plugin-only layout (post-v2.0.1.0) no longer exposes those names — so resolution failed in both fallbacks.

- **`setup` actively cleans up legacy installs.** The `~/.claude/skills/idstack/` warning branch now deletes the directory when the dispatcher SKILL.md or `VERSION < 2.0.1.0` is present. Pass `--keep-legacy` to opt out. Other contents of `~/.claude/skills/` are left alone.
- **`test/smoke-test.sh` regression checks.** Fails when `~/.claude/skills/idstack/SKILL.md` declares `name: idstack`, or when any `~/.claude/skills/<skill-name>` is a pre-v2 symlink pointing into the idstack tree. Skipped under `--local` and CI-fixture runs that pass a custom plugins dir.
- **New `bin/idstack-doctor`.** One-shot diagnostic: plugin presence + manifest version, all 11 SKILL.md files reachable, legacy-install conflicts. Prints exact remediation commands and exits non-zero on any problem.

### Added — the dual-output report contract

Every skill that produces findings now writes **both** a JSON manifest section (system state) and a human-readable Markdown report at `.idstack/reports/<skill>.md` (the designer's view). idstack is positioned as a collaborator on the designer's work, not a course builder — reports speak in observation → evidence → why-it-matters → suggestion, with severity and evidence tier on every finding, and recommendations phrased as "consider…", not "you must…".

- **Canonical format.** New `templates/report-format.md` documents the per-finding structure and the voice rules: suggest don't direct, cite every recommendation, uncited claims belong in *Limitations* not *Findings*. Skills reference this file as the contract for tone and per-finding fields.
- **Schema additions** (additive, no version bump): optional `report_path` field on every section in `templates/manifest-schema.md` that produces findings — `needs_analysis`, `learning_objectives`, `assessments`, `course_content`, `import_metadata`, `export_metadata`, `quality_review`, `accessibility_review`. (`red_team_audit` already had the field from v1.4.) Skills write the relative path of their Markdown report into this field so other skills, the pipeline orchestrator, and `bin/idstack-status` can find it.
- **Per-skill rollout.** All 8 finding-producing skills now write a Markdown report:
  - `needs-analysis`, `learning-objectives`, `assessment-design`, `course-builder`, `course-import`, `accessibility-review` — each got a new "Generate Report" step before the manifest write, with stable finding ids per skill (`needs-1`, `align-1`, `assess-1`, `cogload-1`, `import-1`, `wcag-1`, `udl-1`, etc.) so other skills and the aggregator can cross-reference findings deterministically.
  - `red-team` and `course-quality-review` migrated from flat `.idstack/red-team-report.md` / `.idstack/quality-report.md` onto the new `.idstack/reports/` directory layout. `course-quality-review` now also writes `report_path` into the manifest.

### Added — pipeline cross-cutting aggregate

`/idstack:pipeline` now produces `.idstack/reports/pipeline.md` — a single document the designer can read for the full audit across all 8 stages. Three sections:

- **Across your course** — top cross-cutting issues (findings that recur in multiple per-skill reports), evidence themes (which research domains keep showing up), and where to start. The designer's 30-second read of the whole audit.
- **Pipeline status** — table of all 8 skills with status, headline score/signal, and report path.
- **Per-skill summaries** — Summary paragraph from each per-skill report plus the top 2 finding ids, with a link out to the per-skill report for detail.

Re-invoking `/idstack:pipeline` when all skills are already complete now offers **"Regenerate the pipeline report"** as the primary option via `AskUserQuestion`, alongside re-run-a-skill and exit. Useful after the designer edits per-skill outputs by hand and wants the aggregate refreshed without re-running skills. Also regenerated automatically after every skill the orchestrator completes, so a partial pipeline still leaves a useful aggregate behind if the designer pauses.

### Changed

- **`bin/idstack-status` lists report paths.** New "Reports (read these for the human view)" block under the existing readiness verdict surfaces every Markdown report present under `.idstack/reports/`, with `pipeline.md` listed first as the entry point.
- **Plugin manifest version aligned with `VERSION`.** `.claude-plugin/plugin.json` was stale at `2.0.1.0` (frozen since v2.0.1, never bumped through v2.1, v2.2, v2.3); now matches `VERSION` at `2.4.0.0`.
- **Outward-facing tone pass across all 8 skills.** Confirmation messages now point the designer at *two artifacts* uniformly: "Read this: `.idstack/reports/<skill>.md`. System state: `.idstack/project.json`." Recommendations across reports framed as suggestions ("consider…", "you may want to…"), citations are mandatory on every recommendation, and uncited claims are moved to *Limitations*.

### Manifest schema

No version bump (still 1.4). The `report_path` additions are optional fields; existing manifests without them continue to read correctly.

### Out of scope (future)

- Pipeline-level fix-application loop. Red-team has a parent-side triage-and-fix flow today; the pipeline aggregator could surface cross-cutting fixes for batch application.
- `bin/idstack-status` ranks reports lexicographically. Ranking by recency-of-write or severity-of-topmost-finding would be more useful for a designer scanning a long-running course.
- A smoke-test guard that asserts every skill template both calls the report-write step and writes `report_path` to the manifest. Worth adding once the contract has been live in main for a few releases and is unlikely to change.

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
