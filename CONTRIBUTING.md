# Contributing to idstack

## Quick start

1. Fork the repo and clone your fork
2. Create a branch: `git checkout -b my-skill`
3. Add your skill (see below)
4. Run `./setup` to register it
5. Run `./test/smoke-test.sh` to verify
6. Submit a PR

## How skills work

One directory, one file:

```
your-skill/
└── SKILL.md
```

That's the entire skill. No backend, no config files, no registration step beyond `./setup`.

### SKILL.md structure

**1. YAML frontmatter:**

```yaml
---
name: your-skill
description: |
  What this skill does, in 2-3 lines. (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---
```

The bare `name` field becomes the slash-command suffix: `name: course-import` is invoked as `/idstack:course-import`. The installed plugin handles the `idstack:` namespace; do not prefix the name yourself.

**2. `{{PREAMBLE}}` placeholder** — this is replaced by `bin/idstack-gen-skills` with the shared preamble (update check, manifest check, context recovery).

**3. Skill implementation** — the rest of the file is Markdown that defines the skill's workflow, decision trees, and outputs.

**4. Timeline logging** — at the end, a section that logs the session to `.idstack/timeline.jsonl` with skill-specific fields.

### Template system

Skills use a template system to share common preamble code. Edit `{skill}/SKILL.md.tmpl`, not `SKILL.md` directly. The generated `SKILL.md` files have an `<!-- AUTO-GENERATED -->` header.

After editing a `.tmpl` file or `templates/preamble.md`, regenerate:

```bash
bin/idstack-gen-skills
```

The smoke test includes a freshness check that fails if any `SKILL.md` is stale.

## The dual-output contract

Every skill that produces findings writes **both**:

1. **JSON section** in `.idstack/project.json` — system state for downstream skills, the pipeline orchestrator, and `bin/idstack-status`.
2. **HTML report** at `.idstack/exports/<course-slug>/<skill>.html` — the branded, self-contained human view. Follow the visual contract in `templates/report.html.tmpl` and the content contract in `templates/report-format.md`: observation → evidence → why-it-matters → suggestion, with severity (`critical|warning|info`) and evidence tier (`T1`–`T5`) on every finding. The skill writes the relative path back into its section's `report_path` field, and copies `templates/assets/idstack.css` into the course folder so the deliverable is self-contained when zipped.

Phrase recommendations as suggestions ("consider…"), not directives. Cite every recommendation with `[DomainCode-N] [Tier]`; uncited claims belong in *Limitations* or *Notes*, not *Findings*.

### Manifest-write rules

- **Validate JSON on read.** If malformed, report the error and stop. Never silently overwrite.
- **Own your section only.** Read the full manifest, modify only the section your skill owns, preserve everything else.
- **Update the `updated` timestamp** on every write.
- **Use `bin/idstack-manifest-merge`** for the write path. It's section-scoped, atomic (tempfile + rename), preserves foreign sections, and validates against the canonical schema in `templates/manifest-schema.md`. Inline full-manifest `Edit` is the deprecated fallback.

## Evidence standards

Every recommendation must cite its evidence tier:

| Tier | Meaning |
|------|---------|
| T1 | Meta-analyses, RCTs |
| T2 | Quasi-experimental with controls |
| T3 | Systematic reviews of mixed evidence |
| T4 | Observational, no comparison group |
| T5 | Expert opinion, theoretical frameworks |

Use domain codes from `evidence/references.md` (e.g., `[Alignment-14] [T1]`). Stronger evidence takes precedence when tiers conflict.

## Interaction pattern

- Ask one structured question at a time. In Claude Code this maps to the `AskUserQuestion` tool; in Codex CLI emit a numbered multiple-choice question in plain text and wait. The preamble's "Interaction Conventions" section defines this protocol — your skill body uses the same wording in both CLIs.
- Never batch multiple questions
- Let users work through the workflow at their own pace
- When emitting next-step text like "/idstack:foo" in handoff sections, the model translates to "$foo" on Codex output. You don't need to write per-CLI variants.

## Testing

```bash
./setup              # Register your new skill (auto-detects Claude Code and codex on PATH)
./test/smoke-test.sh # Verify installation across all targets
```

Then test manually:
- Claude Code: `/idstack:your-skill`
- Codex CLI: `$your-skill`

## What makes a good PR

- **Focused scope** — one skill per PR
- **Evidence-backed** — recommendations cite research, not opinions
- **Tested** — smoke test passes, manual test in Claude Code works
- **Standalone** — skill works without a manifest (ask questions as fallback)
- **Pipeline-aware** — if upstream data exists in the manifest, use it to enrich recommendations

## Questions or feedback?

[Fill out this form](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed. You can also [open an issue](https://github.com/savvides/idstack/issues).
