# Roadmap

What's coming next for idstack. Priorities are shaped by user feedback. [Tell us what matters to you.](https://forms.gle/6LDgDD1M6WWyYvME8)

## Just shipped

### Branded HTML reports + per-course export folder (v3.0.0)
- **HTML replaces Markdown for the human view.** Every skill that produces findings now writes a branded, self-contained HTML report at `.idstack/exports/<course-slug>/<skill>.html`. Visual contract: `templates/report.html.tmpl` + `templates/assets/idstack.css` (scholarly serif body, severity-colored finding cards, evidence-tier badges, print-friendly, auto light/dark via `prefers-color-scheme`). Content contract is unchanged — observation → evidence → why-it-matters → suggestion, severity + tier on every finding.
- **One folder per course, by name.** All per-course artifacts — every per-skill HTML report, the pipeline `index.html` dashboard, the bundled CSS, and LMS packages (`course-export.imscc`, `scorm-export.zip`) — live under `.idstack/exports/<course-slug>/`. The slug is derived from `project_name` via `bin/idstack-slugify` (NFKD-fold, kebab-case, ASCII-safe). Zip the folder to hand the whole deliverable to a stakeholder.
- **`/idstack:pipeline` produces a course dashboard.** `index.html` at the folder root, with readiness scores (Quality / Accessibility / Red-team confidence), a pipeline status table with links to every per-skill report, top cross-cutting issues, and a where-to-start pointer. Replaces the old `pipeline.md` aggregate.
- **`bin/idstack-status` reads the new layout.** Surfaces the dashboard first, then per-skill HTML reports, then LMS packages — all from the course folder. Auto-resolves the slug from `project_name`; falls back to the only `.idstack/exports/*` subfolder when present.
- **Breaking change.** `report_path` semantics moved from `.idstack/reports/<skill>.md` to `.idstack/exports/<course-slug>/<skill>.html`. Existing `.idstack/reports/*.md` files from previous runs are left in place but treated as legacy — re-run the pipeline (or any skill) to migrate.

### OpenAI Codex CLI support (v2.5.0.0)
- **Run idstack natively in Codex CLI.** Same 11 skills, same evidence base, same `.idstack/` dual-output contract, same manifest schema. `./setup` auto-detects `codex` on PATH and installs alongside Claude.
- **Multi-target generator.** `bin/idstack-gen-skills --target {claude|codex|all}` emits per-CLI flavors from a single `.tmpl` source. Codex output goes to `dist/codex/skills/idstack-<name>/` — the `allowed-tools:` block is stripped (Codex has no per-skill allowlist).
- **Concept-name preamble.** `AskUserQuestion`, `Agent`, and `Skill (cross-skill invocation)` are now portable concept names defined in `templates/preamble.md`. Same body, two hosts; the model interprets per-CLI.
- **Codex install layout.** Per-skill symlinks at `$CODEX_HOME/skills/idstack-<name>/` for Codex auto-discovery, plus a whole-repo symlink at `~/.agents/plugins/idstack/` so in-skill `$_IDSTACK/bin/...` calls resolve.
- **Memory file at repo root.** `AGENTS.md` is generated from `templates/agent-context.md` for Codex sessions running inside the idstack repo.

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
- **`/idstack pipeline`** — chains all 8 skills automatically. Auto-skips completed skills, shows pipeline status, pause and resume anytime.
- **Namespace refactor** — all skills now invoked via `/idstack <skill>` (e.g., `/idstack needs-analysis`). No more name collisions with other skill packages.
- **Cross-course intelligence** — learnings from one course appear in another. Global store at `~/.idstack/global/learnings.jsonl` with keyword search.
- **`/idstack learn`** — search, delete, promote, and export learnings.
- **Course readiness dashboard** — pre-export gate showing quality/red-team/accessibility status. Integrated into `/idstack course-export`.
- **Designer profile** — `~/.idstack/profile.yaml` with experience level. Skills adapt explanation depth (novice/intermediate/expert).
- **Manifest preferences** — schema v1.3 adds verbosity, export format, preferred LMS settings.
- **Sub-agent architecture** — `/idstack red-team` (5 parallel agents), `/idstack accessibility-review` (2 parallel), `/idstack course-quality-review` (3 parallel). Claude Code only, graceful degradation elsewhere.
- **Spec review loop** — `/idstack course-builder` validates alignment via adversarial subagent after generating content.
- **IDSTACK_HOME** — all paths portable via env var. Foundation for multi-platform support.

### Bidirectional pipeline + evidence depth (v1.5.1)
- All 9 skills now write back to the manifest. Downstream skills get richer input from upstream analysis.
- Score trending: run `/idstack course-quality-review` multiple times and see your score improve over sessions.
- `/idstack accessibility-review` expanded to full WCAG 2.1 AA coverage with course-specific guidance for videos, quizzes, forums, PDFs, and simulations.
- `/idstack red-team` all 5 adversarial dimensions now cite their research evidence.
- `/idstack course-export` shows readiness info (quality, accessibility, red-team scores) before export.
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

### Gemini CLI support (v2.6)
Add native Gemini CLI as a third target. `.tmpl` → `.toml` transform plus a `gemini-extension.json` manifest. Gemini's built-in `ask_user` tool maps cleanly to the AskUserQuestion concept (drop-in), and inline `!{cmd}` shell interpolation will speed up the manifest-merge call paths. Codex shipped first because its SKILL.md format is a 1:1 match; Gemini needs the file-format transform.

### Marketplace publishing (v2.6)
Publish idstack via `codex plugin marketplace add savvides/idstack` so users don't need to clone the repo. Requires building the proper two-tier marketplace.json + .codex-plugin/plugin.json schema. v2.5 ships with simpler per-skill auto-discovery at `$CODEX_HOME/skills/`, which works without a marketplace.

### More skills
Four more skills based on the research synthesis:

- **Model selector** — recommends the right instructional design framework for your context (ADDIE, SAM, backward design, etc.) instead of defaulting to one
- **Content sequencing** — organizes your modules and lessons to manage cognitive load, applying spacing, interleaving, and scaffolding principles
- **Media selection** — flags multimedia principle violations (redundancy, split attention, coherence) and recommends when to use video, text, diagrams, or interactive elements
- **Evaluation design** — plans how to measure whether your course actually worked, using Kirkpatrick's four levels and beyond

## Exploring

These depend on user demand. If any of these would change your workflow, [let us know](https://forms.gle/6LDgDD1M6WWyYvME8).

### More LMS integrations
Direct API connections to Blackboard, Moodle, and D2L (beyond the IMS Common Cartridge format that already works). This would unlock richer data like rubrics, analytics, and student engagement metrics.

## The big vision

### Push changes back to your LMS
After `/course-quality-review` identifies issues and `/learning-objectives` generates better objectives, push the improvements directly back to Canvas (and eventually other LMS platforms). No more copy-pasting between a design document and your LMS. The output IS the course.

This is the 10x goal. It depends on stable import/export, Canvas API write support, conflict handling, and institutional partnerships. It's a ways out, but it's where we're headed.

## Shipped

See [CHANGELOG.md](CHANGELOG.md) for the full version history.
