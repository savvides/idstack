# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is idstack

An open source set of Claude Code skills that bring peer-reviewed instructional design research into the course design workflow. Each skill is a SKILL.md file that defines a conversational workflow backed by evidence from ~283 papers across 11 domains.

## Commands

```bash
./setup              # Install skills (symlinks to ~/.claude/skills/)
./setup --local      # Install to .claude/skills/ in current project only
./test/smoke-test.sh # Verify all symlinks, SKILL.md files, and YAML frontmatter
```

No build step. No dependencies. Skills are plain Markdown files.

## Architecture

### Skills

Each skill is a directory with a single `SKILL.md` file:

```
{skill-name}/
└── SKILL.md    # YAML frontmatter + Markdown workflow
```

The 9 skills form a pipeline, each reading/extending the shared manifest:

```
/needs-analysis → /learning-objectives → /assessment-design → /course-builder → /course-quality-review → /accessibility-review → /red-team → /course-export
                          ↑
/course-import ───────────┘
```

Any skill also works standalone (asks questions directly if no manifest exists).

### Project manifest

Skills share state through `.idstack/project.json`. Rules when writing skills that touch the manifest:

- Validate JSON on read. If malformed, report and stop. Never silently overwrite.
- Own your section only. Read full manifest, modify only your skill's section, preserve everything else.
- Update the `updated` timestamp on every write.
- Write the complete schema structure (no partial writes).

### SKILL.md structure

Every skill file follows this pattern:

1. **YAML frontmatter** with `name`, `description`, and `allowed-tools` fields
2. **Update check preamble** (bash block calling `bin/idstack-update-check`)
3. **Manifest preamble** (check for `.idstack/project.json`)
4. **Workflow** (Markdown defining the conversational flow, decision trees, outputs)

### Evidence standards

Every recommendation in a skill must cite its evidence tier using domain codes from `evidence/references.md`:

| Tier | Meaning |
|------|---------|
| T1 | Meta-analyses, RCTs |
| T2 | Quasi-experimental with controls |
| T3 | Systematic reviews of mixed evidence |
| T4 | Observational, no comparison group |
| T5 | Expert opinion, theoretical frameworks |

Format: `[DomainCode-Number] [Tier]` (e.g., `[Alignment-14] [T1]`). Stronger evidence takes precedence when tiers conflict.

### Interaction pattern

- Use `AskUserQuestion` for all user interaction
- One question at a time, never batch multiple questions
- Skills must work without a manifest (fallback to asking questions directly)

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
