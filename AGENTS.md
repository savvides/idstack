# idstack — agent context

This file is auto-shipped to coding CLIs as `AGENTS.md` (Codex CLI), `GEMINI.md` (Gemini
CLI, future), or as the source for `CLAUDE.md` (Claude Code). It tells the model how
idstack is organized so a skill can do its job.

## What is idstack

An open-source set of skills that bring peer-reviewed instructional design research into
the course-design workflow. Each skill is a `SKILL.md` file with YAML frontmatter and a
conversational workflow backed by evidence from peer-reviewed research across 11 domains.

idstack runs in multiple CLIs. The skill bodies are CLI-agnostic; small per-CLI shims
handle interaction primitives.

## Architecture

### Skills

11 skills total. The 8-skill linear pipeline is the canonical sequence; `course-import` joins it
when there is an existing course to start from, and `learn` is a cross-project memory
utility that runs outside the pipeline.

```
pipeline (orchestrates the 8-skill linear chain, auto-skipping completed skills)

needs-analysis → learning-objectives → assessment-design → course-builder
              → course-quality-review → accessibility-review → red-team → course-export
                              ↑
course-import ────────────────┘

learn (manage cross-project learnings)
```

Any skill also works standalone (asks questions directly if no manifest exists).
Invocation syntax depends on the host CLI:

- Claude Code: `/idstack:<skill>`
- Codex CLI: `$<skill>` (or implicit selection by description)

### Project manifest and reports — the dual-output contract

Every skill that produces findings writes **both**:

1. **JSON section** in `.idstack/project.json` — system state for downstream skills, the
   pipeline orchestrator, and `bin/idstack-status`.
2. **HTML report** at `.idstack/exports/<course-slug>/<skill>.html` — the human view,
   branded and self-contained. Visual contract: `templates/report.html.tmpl` plus
   `templates/assets/idstack.css`. Content contract: `templates/report-format.md`. The
   skill writes the relative path back into its section's `report_path` field.

The HTML is what the instructional designer reads (open in any browser; the folder is
self-contained with CSS bundled). The JSON is for the system. The two stay in sync —
every finding in the report corresponds to a finding in the manifest's structured arrays.

`<course-slug>` is derived from the manifest's `project_name` via `bin/idstack-slugify`
(NFKD-fold, lowercase, kebab-case, ASCII-safe; empty → `untitled-course`). All per-course
artifacts — every per-skill HTML report, the pipeline `index.html` dashboard, and LMS
packages (`course-export.imscc`, `scorm-export.zip`) — live under the same
`.idstack/exports/<course-slug>/` folder, so the deliverable is self-describing when
zipped, emailed, or handed off.

`pipeline` produces `.idstack/exports/<course-slug>/index.html` — the cross-cutting
course dashboard with readiness scores, links to every per-skill report, and a where-to-
start pointer. Regenerated on every pipeline run (including partial runs and explicit
re-runs when all skills are already complete).

Manifest write rules:

- Validate JSON on read. If malformed, report and stop. Never silently overwrite.
- Own your section only. Read full manifest, modify only your skill's section, preserve
  everything else.
- Update the `updated` timestamp on every write.
- Use `bin/idstack-manifest-merge` for the write path: section-scoped, atomic (tempfile +
  rename), preserves foreign sections, validates against the canonical schema in
  `templates/manifest-schema.md`. Inline full-manifest edit is the deprecated fallback.

Report write rules:

- Follow the **visual contract** in `templates/report.html.tmpl` and the **content
  contract** in `templates/report-format.md` — observation → evidence → why-it-matters →
  suggestion, with severity (`critical|warning|info`) and evidence tier (`T1`–`T5`) on
  every finding. Use the CSS hooks the stylesheet styles: `<article class="finding
  sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge
  tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`.
- Every skill that writes a report copies `$_IDSTACK/templates/assets/idstack.css` into
  `.idstack/exports/<course-slug>/assets/idstack.css` so the folder is self-contained
  when zipped or moved.
- Phrase recommendations as suggestions ("consider…"), not directives. idstack is a
  collaborator.
- Cite every recommendation. Findings without a `[Domain-N] [Tier]` citation belong in
  *Limitations* or *Notes*, not *Findings*.

### SKILL.md.tmpl structure

Every skill template follows this pattern:

1. **YAML frontmatter** with `name`, `description`, and (Claude target only) `allowed-tools`
2. **`{{PREAMBLE}}`** placeholder (replaced by `templates/preamble.md` during generation)
3. **Workflow** (Markdown defining the conversational flow, decision trees, outputs)
4. **`{{MANIFEST_SCHEMA}}`** placeholder (replaced by `templates/manifest-schema.md`)
5. **Timeline logging** (logs session data to `.idstack/timeline.jsonl` on completion)

The shared preamble includes: update check, manifest check, preferences check, designer
profile check, and context recovery (reads timeline + learnings for welcome-back messages
and pipeline guidance).

### Course memory

Skills log session data to `.idstack/timeline.jsonl` (what skills ran, scores,
dimensions) and `.idstack/learnings.jsonl` (project-specific discoveries). The context
recovery preamble reads these on session start to provide continuity across
conversations.

### Evidence standards

Every recommendation in a skill must cite its evidence tier using domain codes from
`evidence/references.md`:

| Tier | Meaning |
|------|---------|
| T1 | Meta-analyses, RCTs |
| T2 | Quasi-experimental with controls |
| T3 | Systematic reviews of mixed evidence |
| T4 | Observational, no comparison group |
| T5 | Expert opinion, theoretical frameworks |

Format: `[DomainCode-Number] [Tier]` (e.g., `[Alignment-14] [T1]`). Stronger evidence
takes precedence when tiers conflict.

### Interaction pattern

- Ask one structured question at a time. Never batch multiple questions. (In Claude Code
  this is the `AskUserQuestion` tool; in Codex CLI it is a numbered multiple-choice
  question in plain text.)
- Skills must work without a manifest (fallback to asking questions directly).

## Commands (run from the idstack install directory)

```bash
./setup                          # Install for the detected CLI(s)
./test/smoke-test.sh             # Verify installation and generated artifacts
bin/idstack-gen-skills           # Regenerate skill files for all targets
bin/idstack-gen-skills --target codex    # Regenerate Codex flavor only
bin/idstack-gen-skills --dry-run         # Check if generated files are up to date
bin/idstack-doctor               # Diagnose installs across CLIs
bin/idstack-status               # Course health dashboard (run in a project dir)
bin/idstack-status --readiness   # Pre-export readiness check only
```

No build step for users. No dependencies beyond bash (python3 recommended for full
features). Skills are plain Markdown files.

## Design system

Always read `DESIGN.md` (repo root) before making any visual or UI decision in this
project. All font choices, colors, spacing, border radii, motion timing, and aesthetic
direction are defined there. Do not deviate without explicit user approval and a
corresponding update to `DESIGN.md`.

The canonical implementations are `templates/assets/idstack.css` (per-skill HTML
reports + course dashboard) and the inline `<style>` block in `docs/index.html`
(idstack.org landing page). When `DESIGN.md` changes, both implementations update
in the same PR.
