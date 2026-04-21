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
name: idstack-your-skill
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

Note: All skill names are prefixed with `idstack-` to avoid collisions with other skill packages. Users invoke via `/idstack your-skill`.

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

## The project manifest

Skills share state through `.idstack/project.json`. Rules:

- **Validate JSON on read.** If malformed, report the error and stop. Never silently overwrite.
- **Own your section only.** Read the full manifest, modify only the section your skill owns, preserve everything else.
- **Update the `updated` timestamp** on every write.
- **Always write the complete schema structure** — no partial writes or omissions.

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

- Use `AskUserQuestion` for all user interaction
- One question at a time — never batch multiple questions
- Let users work through the workflow at their own pace

## Testing

```bash
./setup              # Register your new skill
./test/smoke-test.sh # Verify installation
```

Then test manually in Claude Code by running `/idstack your-skill`.

## What makes a good PR

- **Focused scope** — one skill per PR
- **Evidence-backed** — recommendations cite research, not opinions
- **Tested** — smoke test passes, manual test in Claude Code works
- **Standalone** — skill works without a manifest (ask questions as fallback)
- **Pipeline-aware** — if upstream data exists in the manifest, use it to enrich recommendations

## Questions or feedback?

[Fill out this form](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed. You can also [open an issue](https://github.com/savvides/idstack/issues).
