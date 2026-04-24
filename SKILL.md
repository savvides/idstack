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

First, run this context detection block:

```bash
# Context detection for welcome message
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST:yes"
fi

if [ -f ".idstack/timeline.jsonl" ]; then
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
lines = open('.idstack/timeline.jsonl').readlines()
events = []
for line in lines:
    try: events.append(json.loads(line))
    except: pass
if not events:
    sys.exit(0)
completed = set()
for e in events:
    if e.get('event') == 'completed':
        completed.add(e.get('skill', ''))
if completed:
    print('STATE:returning')
    print('COMPLETED:' + ','.join(sorted(completed)))
    print('COMPLETED_COUNT:' + str(len(completed)))
scores = [e for e in events if e.get('skill') == 'course-quality-review' and 'score' in e]
if scores:
    trend = ' -> '.join(str(s['score']) for s in scores[-5:])
    print('QUALITY:' + trend)
last_completed = [e for e in events if e.get('event') == 'completed']
if last_completed:
    last = last_completed[-1]
    print('LAST:' + last.get('skill', '?'))
pipeline = [
    ('needs-analysis', 'learning-objectives'),
    ('learning-objectives', 'assessment-design'),
    ('assessment-design', 'course-builder'),
    ('course-builder', 'course-quality-review'),
    ('course-quality-review', 'accessibility-review'),
    ('accessibility-review', 'red-team'),
    ('red-team', 'course-export'),
]
for prev, nxt in pipeline:
    if prev in completed and nxt not in completed:
        print('NEXT:' + nxt)
        break
" 2>/dev/null || true
  else
    # Bash fallback: check if timeline has completed events
    if grep -q '"completed"' .idstack/timeline.jsonl 2>/dev/null; then
      echo "STATE:returning"
    fi
  fi
fi

if [ -f ".idstack/learnings.jsonl" ]; then
  _LC=$(wc -l < .idstack/learnings.jsonl 2>/dev/null | tr -d ' ')
  [ "$_LC" -gt 0 ] 2>/dev/null && echo "LEARNINGS:$_LC"
fi
```

Then print the welcome message based on the output. Do not use AskUserQuestion.

**If output contains `STATE:returning` (returning user):**

Print a warm welcome back message. Include:
- "Welcome back to idstack."
- If `QUALITY:` is shown, include the quality score trend (e.g., "Quality score trend: 62 -> 68 -> 72")
- If `COMPLETED_COUNT:` is shown, mention how many skills they've run
- If `NEXT:` is shown, suggest it (e.g., "Next up in your pipeline: `/idstack <skill>`")
- If `LEARNINGS:` is shown, mention their learnings count
- Then print the full command listing below

**If output contains `MANIFEST:yes` but NOT `STATE:returning` (started user):**

Print:
- "You have a course started but haven't completed any pipeline steps yet."
- "Pick up where you left off with `/idstack pipeline`, or run a specific skill below."
- Then print the full command listing below

**If neither `MANIFEST:yes` nor `STATE:returning` appears (new user):**

Print:
- "idstack — Evidence-based instructional design skills for Claude Code."
- "Every recommendation cites peer-reviewed research across 11 domains, so you always know how strong the evidence is."
- A "Getting started" section:
  - "Have an existing course? `/idstack course-import`"
  - "Designing from scratch? `/idstack needs-analysis`"
  - "Run the full pipeline: `/idstack pipeline`"
- Then print the full command listing below

**Always end with this command listing** (after the welcome message):

```
Skills:
  needs-analysis         Three-level needs assessment (org, task, learner)
  learning-objectives    Measurable ILOs with Bloom's taxonomy + alignment check
  assessment-design      Rubrics, feedback strategies, formative checkpoints
  course-builder         Generate syllabus, modules, assignments, rubrics
  course-quality-review  Quality Matters audit + Community of Inquiry analysis
  accessibility-review   WCAG 2.1 AA + Universal Design for Learning review
  red-team               Adversarial audit across 5 dimensions
  course-export          Package for Canvas, Blackboard, Moodle (IMSCC/SCORM)
  course-import          Import from any LMS or authoring tool
  pipeline               Run all 8 skills in order (auto-skips completed)
  learn                  Search, promote, delete project learnings
  status                 Course health dashboard

More info: https://idstack.org
```

Stop after printing. Do not invoke any skill.

## Important Rules

- **Don't add your own workflow.** Your only job is routing. Once you invoke a sub-skill,
  that skill takes over completely.
- **Pass through args.** If the user provided additional context after the subcommand
  name (e.g., `/idstack learn search canvas`), pass it as args to the sub-skill.
- **Be forgiving with names.** Accept common variations: "qa" → course-quality-review,
  "export" → course-export, "import" → course-import, "objectives" → learning-objectives,
  "build" → course-builder, "assess" → assessment-design.
