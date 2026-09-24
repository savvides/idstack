# Roadmap

What's coming next for idstack. Priorities are shaped by user feedback. [Tell us what matters to you.](https://forms.gle/6LDgDD1M6WWyYvME8)

## Just shipped

### Consensus evidence checks & Chrome extension hardening (v3.6.0.0)
- **An optional Consensus evidence engine, on your own API key.** `bin/idstack-consensus` looks up and caches claims. `/idstack:course-quality-review`, `/idstack:assessment-design`, and `/idstack:red-team` check their findings with it before writing them, and correct four known neuromyths with or without a key.
- **The Chrome extension (1.1.0) reads only the tab you point it at.** It no longer asks for access to every website, refuses Canvas pages that show student records, and reads every page of a course's assignments.
- **Its privacy notes match the code.** The side panel and PRIVACY.md say what is sent to Google and to Consensus, and where results are kept.

### Mobile fixes for idstack.org & test-harness repair (v3.5.1.0)
- **idstack.org is usable on a phone.** Every content section sat under the display cutout, buttons and inputs fell below the 44px touch floor at every width above 480px, and a viewport clip was hiding horizontal overflow instead of preventing it. Measured clean at 11 widths from 320px up. No skill behavior changed.
- **The mutation suite could not fail.** `test/mutation-test.sh` never copied `extension/` into its throwaway repos, so `test/test-extension.sh` broke before any mutation was applied and all 36 mutations reported GUARDED whether their guard worked or not. A null-mutation control now aborts the run when an unmutated copy is already red.
- **The landing page is tested by rendering it.** `test/test-rendered-landing.js` loads the page in headless Chrome and asserts what it does at 11 widths, not what its CSS says. Six kinds of edit had shipped a broken page past the text-only suite; all six fail this one.

### Chrome Extension, Course Dossier & Robustness (v3.5.0.0)
- **Native Chrome Side Panel extension for Canvas LMS & Google Docs.** Officially published on the [Chrome Web Store](https://chromewebstore.google.com/detail/eclnhfehloplcnidkkopphamllnlhinm). Audits course content and assignments with cognitive demand classification (Bloom's Revised Taxonomy) and empirical evidence citations directly in the browser.
- **Automated background Canvas course crawler.** Audits entire Canvas courses in the background via active session cookies without requiring developer API keys.
- **Course Dossier multi-page compiler & Markdown exporter.** Compiles multi-page course findings into unified structured markdown dossiers with TOC, reading time estimates, and metadata sidecars.
- **Automated Web Store packaging.** Added `bin/package-extension.sh` to package clean `.zip` bundles for the Chrome Web Store Developer Console.
- **Atomic learnings deletion with permission preservation (#60).** Replaced destructive file truncation in `bin/lib/idstack-learnings-delete` with an atomic tempfile-and-rename pattern that preserves POSIX permissions.
- **Cross-project local-over-global search precedence (#61).** Enforces project-local learnings priority over global store records during cross-project searches in `bin/idstack-learnings-search`.
- **Full test coverage for slugify stdin/emojis & migrate malformed manifest fallback (#62).** Added smoke tests for stdin piping, emoji handling in `bin/idstack-slugify`, and graceful fallback on malformed JSON manifests in `bin/idstack-migrate`.

### Documentation accuracy & automated verification (v3.4.0.1)
- **Evidence cards derived from research references.** `test/check-evidence-cards.py` verifies landing page cards against `evidence/references.md` in `smoke-test.sh` so study counts and tier spans match.
- **Privacy policy disclosures updated.** `PRIVACY.md` discloses outbound Canvas API uploads in `/idstack:course-export` and `git fetch` operations in `bin/idstack-update-check`.
- **Windows setup instructions fixed.** `README.md` specifies WSL or Git Bash for Windows installs (PowerShell does not run extensionless bash scripts).

### Single-host Claude Code plugin architecture (v3.4.0.0)
- **Claude Code plugin invariant.** Removed retired Codex CLI target and `dist/` bundle layout. `bin/idstack-gen-skills` operates on single canonical layout (`skills/<name>/SKILL.md`). <!-- IDSTACK_CLI_LEAK_ALLOW -->
- **`$_IDSTACK` resolution cleaned.** In-skill path resolution dropped legacy `.agents/` fallbacks.

### Follow-up fixes to the v3.3.0.0 audit (v3.3.0.1–v3.3.0.4)
- **Skills stopped suggesting commands that don't exist.** Welcome-back and next-step messages named things like `/assessment-design`, which resolves in neither CLI. It landed inside the context-recovery message v3.3.0.0 had just repaired, so it was the first thing you saw once those messages started working again (v3.3.0.1).
- **Searching your learnings for a word with an apostrophe returned the wrong answer.** `Bloom's` or `learner's` made the search code a syntax error, which was swallowed, and the fallback that took over ignores the `--type` filter — so it answered with a record of the wrong type instead of failing. Those are ordinary search terms in this tool (v3.3.0.2).
- Smaller: a malformed payload can no longer corrupt the manifest, and on machines without python3 the search fallback's `--type` filter works at all (it had never matched anything idstack wrote).

### Course memory, pipeline orchestration, and re-run detection fixed (v3.3.0.0)
- **Welcome-back messages work on stock macOS.** The session-memory code embedded in every skill contained an f-string that is a SyntaxError on any Python below 3.12 — including the 3.9 macOS ships. It failed silently, so context recovery, quality-score trends, and next-step suggestions produced nothing. Fixed, and now exercised on 3.9 in CI so the class of bug can't ship again.
- **`/idstack:pipeline` invokes its child skills correctly.** It was calling them by an unnamespaced name that never resolved in Claude Code.
- **Skills notice previous runs again.** Re-run detection ("update the results or start fresh?") was dead in five skills, which looked up manifest sections that don't exist.
- **Marketplace installs resolve `bin/` correctly.** `learn` and `course-export` missed the marketplace cache — the way most users are installed — so their tool calls pointed at a nonexistent directory.
- **Apostrophes no longer blank the dashboard**, imported courses get a proper next-step suggestion, and `bin/idstack-doctor` can no longer report a disabled install as healthy.
- **Standalone runs persist.** `bin/idstack-migrate --init` creates a canonical manifest, so a skill run outside the pipeline has something to write into instead of silently discarding its results.

### Test infrastructure and CI (v3.3.0.0–v3.3.0.4, for contributors)
- The suite had never run automatically. GitHub Actions runs every suite on each push and pull request, across ubuntu (Python 3.9 + 3.12) and macOS — eight suites at v3.3.0.0, and more since; `CONTRIBUTING.md` lists the current set.
- `./setup` — the primary deliverable — went from zero coverage to 17 behavioral tests.
- `bin/idstack-doctor` and `bin/idstack-status --readiness` gained their first execution coverage in v3.3.0.4. Both are what a user reaches for when something has already gone wrong, and neither had any.
- `test/mutation-test.sh` reintroduces each fixed defect and asserts its guarding test fails, which is how a test that only appeared to test something gets caught. Every mutation in it is guarded; the suite prints the current count when you run it.

### Install through the Claude Code plugin marketplace (v3.2.0.0)
- `./setup` registers idstack as a Claude Code plugin marketplace and installs from there. Recent Claude Code versions stopped discovering plugins from the bare symlink older setups created, so `/idstack:<skill>` commands silently never appeared in the slash picker. If that happened to you, pull the latest and re-run `./setup`.

### `DESIGN.md` and design-system reconciliation (v3.1.0.0)
- The visual system behind the report stylesheet and the landing page is documented at the repo root in `DESIGN.md` — fonts, colors, spacing, radii, motion, plus anti-patterns and a dated decisions log. Skills, contributors, and reviewers read it before touching anything visual.
- Publication-grade type (Source Serif 4, Public Sans, JetBrains Mono), an ivory palette in place of parchment, sharper card corners, and a second annotation color mirroring the two-pen academic-editor convention. Reports written by older versions still render correctly.

### Branded HTML reports + per-course export folder (v3.0.0)
- **HTML replaces Markdown for the human view.** Every skill that produces findings now writes a branded, self-contained HTML report at `.idstack/exports/<course-slug>/<skill>.html`. Visual contract: `templates/report.html.tmpl` + `templates/assets/idstack.css` (scholarly serif body, severity-colored finding cards, evidence-tier badges, print-friendly, auto light/dark via `prefers-color-scheme`). Content contract is unchanged — observation → evidence → why-it-matters → suggestion, severity + tier on every finding.
- **One folder per course, by name.** All per-course artifacts — every per-skill HTML report, the pipeline `index.html` dashboard, the bundled CSS, and LMS packages (`course-export.imscc`, `scorm-export.zip`) — live under `.idstack/exports/<course-slug>/`. The slug is derived from `project_name` via `bin/idstack-slugify` (NFKD-fold, kebab-case, ASCII-safe). Zip the folder to hand the whole deliverable to a stakeholder.
- **`/idstack:pipeline` produces a course dashboard.** `index.html` at the folder root, with readiness scores (Quality / Accessibility / Red-team confidence), a pipeline status table with links to every per-skill report, top cross-cutting issues, and a where-to-start pointer. Replaces the old `pipeline.md` aggregate.
- **`bin/idstack-status` reads the new layout.** Surfaces the dashboard first, then per-skill HTML reports, then LMS packages — all from the course folder. Auto-resolves the slug from `project_name`; falls back to the only `.idstack/exports/*` subfolder when present.
- **Breaking change.** `report_path` semantics moved from `.idstack/reports/<skill>.md` to `.idstack/exports/<course-slug>/<skill>.html`. Existing `.idstack/reports/*.md` files from previous runs are left in place but treated as legacy — re-run the pipeline (or any skill) to migrate.

### Dual-output report contract + pipeline aggregator (v2.4)
- **Two artifacts per skill.** Every finding-producing skill now writes both `.idstack/project.json` (system state for downstream skills) and `.idstack/reports/<skill>.md` (the human view). Each finding follows observation → evidence → why-it-matters → suggestion, with severity and evidence tier. Recommendations are framed as "consider…", not directives — idstack collaborates on your design, doesn't dictate it.
- **`/idstack:pipeline` produces `.idstack/reports/pipeline.md`.** A single aggregate document the designer can read for the full audit across all 8 stages: top recurring issues, evidence themes, where to start. Regenerated on every pipeline run, including partial runs and explicit re-runs.
- **`bin/idstack-status` lists report paths.** New "Reports" block surfaces every Markdown report under `.idstack/reports/` with `pipeline.md` first.
- **Install hygiene.** `setup` now actively removes legacy pre-v2.0.1.0 installs at `~/.claude/skills/idstack/` that shadowed the plugin namespace. `bin/idstack-doctor` diagnoses install state. `test/smoke-test.sh` regression-catches the conflict.

### Imported-course mode (v2.3)
- `/idstack:needs-analysis`, `/idstack:assessment-design`, and `/idstack:course-builder` auto-detect imported courses and switch behavior. Needs-analysis runs a design-fit check instead of the training-decision gate. Assessment-design switches to audit mode (classifies existing rubric criteria on Bloom's). Course-builder switches to gap-fill mode (generates only the artifacts upstream skills flagged as missing).

### Red-team in a clean-context sub-agent + triage-and-fix loop (v2.2)
- `/idstack:red-team` now spawns a clean-context sub-agent so the audit can't inherit build-bias from the parent. After the audit, control returns to the parent with a triage-and-fix prompt (Critical / Critical+High / All / Skip).

### Manifest-merge tool + schema cleanup (v2.1)
- New `bin/idstack-manifest-merge` is the canonical write path: section-scoped, atomic (tempfile + rename), preserves foreign sections, validates against `templates/manifest-schema.md`. Inline full-manifest `Edit` is the deprecated fallback.
- Schema migration v1.4 fixes drifted field names (`red_team_audit.summary.*_count` → `findings_summary.*`, `_import_quality_flags` → `import_metadata.quality_flag_details`).

### idstack v2 — Pipeline orchestrator, intelligence, sub-agents
- **`/idstack:pipeline`** — chains all 8 skills automatically. Auto-skips completed skills, shows pipeline status, pause and resume anytime.
- **Namespace refactor** — all skills now invoked via `/idstack:<skill>` (e.g., `/idstack:needs-analysis`). No more name collisions with other skill packages.
- **Cross-course intelligence** — learnings from one course appear in another. Global store at `~/.idstack/global/learnings.jsonl` with keyword search.
- **`/idstack:learn`** — search, delete, promote, and export learnings.
- **Course readiness dashboard** — pre-export gate showing quality/red-team/accessibility status. Integrated into `/idstack:course-export`.
- **Designer profile** — `~/.idstack/profile.yaml` with experience level. Skills adapt explanation depth (novice/intermediate/expert).
- **Manifest preferences** — schema v1.3 adds verbosity, export format, preferred LMS settings.
- **Sub-agent architecture** — `/idstack:red-team` (5 parallel agents), `/idstack:accessibility-review` (2 parallel), `/idstack:course-quality-review` (3 parallel). Claude Code only, graceful degradation elsewhere.
- **Spec review loop** — `/idstack:course-builder` validates alignment via adversarial subagent after generating content.
- **IDSTACK_HOME** — all paths portable via env var. Foundation for multi-platform support.

### Bidirectional pipeline + evidence depth (v1.5.1)
- All 9 skills now write back to the manifest. Downstream skills get richer input from upstream analysis.
- Score trending: run `/idstack:course-quality-review` multiple times and see your score improve over sessions.
- `/idstack:accessibility-review` expanded to full WCAG 2.1 AA coverage with course-specific guidance for videos, quizzes, forums, PDFs, and simulations.
- `/idstack:red-team` all 5 adversarial dimensions now cite their research evidence.
- `/idstack:course-export` shows readiness info (quality, accessibility, red-team scores) before export.
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
- `/idstack:course-import` now accepts SCORM 1.2/2004 packages from Articulate Rise, Storyline, Adobe Captivate, Lectora, iSpring, and any SCORM-compliant authoring tool
- `/idstack:course-export` now generates SCORM 1.2 packages for any LMS or corporate training platform
- PDF and document file import also added for Rise course exports and syllabi

### Accessibility review + Red team audit (v1.3.0)
- `/idstack:accessibility-review` — WCAG 2.1 AA compliance plus Universal Design for Learning (UDL 3.0). Two-tier output: "Must Fix" for legal compliance, "Should Improve" for inclusive design.
- `/idstack:red-team` — Adversarial course audit. Assumes the course is broken and tries to prove it. Five dimensions: alignment stress test, evidence verification, cognitive load analysis, learner persona simulation, prerequisite chain integrity. Produces a confidence score.

## Coming soon

### More skills
Four more skills based on the research synthesis:

- **Model selector** — recommends the right instructional design framework for your context (ADDIE, SAM, backward design, etc.) instead of defaulting to one
- **Content sequencing** — organizes your modules and lessons to manage cognitive load, applying spacing, interleaving, and scaffolding principles
- **Media selection** — flags multimedia principle violations (redundancy, split attention, coherence) and recommends when to use video, text, diagrams, or interactive elements
- **Evaluation design** — plans how to measure whether the course met its learning outcomes, using Kirkpatrick's four levels and beyond

## Exploring

These depend on user demand. If any of these would change your workflow, [let us know](https://forms.gle/6LDgDD1M6WWyYvME8).

### More LMS integrations
Direct API connections to Blackboard, Moodle, and D2L (beyond the IMS Common Cartridge format that already works). This would unlock richer data like rubrics, analytics, and student engagement metrics.

## The big vision

### Push changes back to your LMS
After `/idstack:course-quality-review` identifies issues and `/idstack:learning-objectives` generates better objectives, push the improvements directly back to Canvas (and eventually other LMS platforms). No more copy-pasting between a design document and your LMS. The output IS the course.

This is the 10x goal. It depends on stable import/export, Canvas API write support, conflict handling, and institutional partnerships. It's a ways out, but it's where we're headed.

## Shipped

See [CHANGELOG.md](CHANGELOG.md) for the full version history.
