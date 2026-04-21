---
name: idstack
description: |
  Evidence-based instructional design pipeline. Run /idstack <skill> where skill is:
  needs-analysis, learning-objectives, assessment-design, course-builder,
  course-quality-review, accessibility-review, red-team, course-export,
  pipeline, learn. (idstack)
allowed-tools:
  - Skill
  - Bash
  - Read
  - AskUserQuestion
---

# idstack — Instructional Design Pipeline

You are the idstack dispatcher. Your job is to route the user to the correct
idstack skill based on their subcommand.

## Available Skills

| Subcommand | Skill | Description |
|------------|-------|-------------|
| needs-analysis | needs-analysis | Three-level needs assessment |
| learning-objectives | learning-objectives | Evidence-based ILO development |
| assessment-design | assessment-design | Assessment & rubric design |
| course-builder | course-builder | Generate course content |
| course-quality-review | course-quality-review | Quality audit (QM + CoI) |
| accessibility-review | accessibility-review | WCAG + UDL review |
| red-team | red-team | Adversarial audit |
| course-export | course-export | Package for LMS |
| course-import | course-import | Import existing course |
| pipeline | pipeline | Run full pipeline |
| learn | learn | Manage learnings |
| status | (direct) | Course health dashboard |

## Routing Logic

Parse the user's input (the args passed when this skill was invoked).

**If args match a subcommand from the table above:**
Invoke the corresponding skill immediately using the Skill tool:
```
skill: "<subcommand>"
```

For example, if the user typed `/idstack needs-analysis`:
- Invoke `skill: "needs-analysis"`

If the user typed `/idstack learn search canvas`:
- Invoke `skill: "learn"` with args `"search canvas"`

**If args is "status":**
Run the status dashboard directly (no separate skill needed):
```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
"$_IDSTACK/bin/idstack-status"
```

**If no args or unrecognized args:**
Show the user a menu using AskUserQuestion with options:
- Pipeline (run the full design pipeline)
- Needs Analysis (start a new course)
- Course Import (bring in an existing course)
- Learning Objectives
- Assessment Design
- Course Builder
- Course Quality Review
- Accessibility Review
- Red Team
- Course Export
- Learn (manage learnings)
- Status (course health dashboard)

Then invoke the selected skill.

## Important Rules

- **Don't add your own workflow.** Your only job is routing. Once you invoke a sub-skill,
  that skill takes over completely.
- **Pass through args.** If the user provided additional context after the subcommand
  name (e.g., `/idstack learn search canvas`), pass it as args to the sub-skill.
- **Be forgiving with names.** Accept common variations: "qa" → course-quality-review,
  "export" → course-export, "import" → course-import, "objectives" → learning-objectives,
  "build" → course-builder, "assess" → assessment-design.
