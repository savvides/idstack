---
name: idstack-pipeline
description: |
  Pipeline orchestrator for idstack. Chains skills from /needs-analysis through
  /course-export in evidence-based order, auto-skipping completed skills.
  Handles fresh starts (no manifest) and resumption (partial pipeline). (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---
<!-- AUTO-GENERATED from SKILL.md.tmpl -- do not edit directly -->
<!-- Edit the .tmpl file instead. Regenerate: bin/idstack-gen-skills -->


## Preamble: Update Check

```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
_UPD=$("$_IDSTACK/bin/idstack-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD"
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A newer version of idstack is available. Run `cd ${IDSTACK_HOME:-~/.claude/skills/idstack} && git pull && ./setup` to update. (The `./setup` step is required — it cleans up old symlinks.)" Then continue normally.

## Preamble: Project Manifest

Before starting, check for an existing project manifest.

```bash
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  "$_IDSTACK/bin/idstack-migrate" .idstack/project.json 2>/dev/null || cat .idstack/project.json
else
  echo "NO_MANIFEST"
fi
```

**If MANIFEST_EXISTS:**
- Read the manifest. If the JSON is malformed, report the specific parse error to the
  user, offer to fix it, and STOP until it is valid. Never silently overwrite corrupt JSON.
- Preserve all existing sections when writing back.

**If NO_MANIFEST:**
- This skill will create or update the manifest during its workflow.

## Preamble: Preferences

```bash
if [ -f ".idstack/project.json" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
try:
    data = json.load(open('.idstack/project.json'))
    prefs = data.get('preferences', {})
    v = prefs.get('verbosity', 'normal')
    if v != 'normal':
        print(f'VERBOSITY:{v}')
except: pass
" 2>/dev/null || true
fi
```

**If VERBOSITY:concise:** Keep explanations brief. Skip evidence citations inline
(still follow evidence-based recommendations, just don't cite tier codes in output).
**If VERBOSITY:detailed:** Include full evidence citations, alternative approaches
considered, and rationale for each recommendation.
**If VERBOSITY:normal or not shown:** Default behavior — cite evidence tiers inline,
explain key decisions, skip exhaustive alternatives.

## Preamble: Designer Profile

```bash
_PROFILE="$HOME/.idstack/profile.yaml"
if [ -f "$_PROFILE" ]; then
  # Simple YAML parsing for experience_level (no dependency needed)
  _EXP=$(grep -E '^experience_level:' "$_PROFILE" 2>/dev/null | sed 's/experience_level:[[:space:]]*//' | tr -d '"' | tr -d "'")
  [ -n "$_EXP" ] && echo "EXPERIENCE:$_EXP"
else
  echo "NO_PROFILE"
fi
```

**If EXPERIENCE:novice:** Provide more context for recommendations. Explain WHY each
step matters, not just what to do. Define jargon on first use. Offer examples.
**If EXPERIENCE:intermediate:** Standard explanations. Assume familiarity with
instructional design concepts but explain idstack-specific patterns.
**If EXPERIENCE:expert:** Be concise. Skip basic explanations. Focus on evidence
tiers, edge cases, and advanced considerations. Trust the user's domain knowledge.
**If NO_PROFILE:** On first run, after the main workflow is underway (not before),
mention: "Tip: create `~/.idstack/profile.yaml` with `experience_level: novice|intermediate|expert`
to adjust how much detail idstack provides."

## Preamble: Context Recovery

Check for session history and learnings from prior runs.

```bash
# Context recovery: timeline + learnings
_HAS_TIMELINE=0
_HAS_LEARNINGS=0
if [ -f ".idstack/timeline.jsonl" ]; then
  _HAS_TIMELINE=1
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
lines = open('.idstack/timeline.jsonl').readlines()[-200:]
events = []
for line in lines:
    try: events.append(json.loads(line))
    except: pass
if not events:
    sys.exit(0)

# Quality score trend
scores = [e for e in events if e.get('skill') == 'course-quality-review' and 'score' in e]
if scores:
    trend = ' -> '.join(str(s['score']) for s in scores[-5:])
    print(f'QUALITY_TREND: {trend}')
    last = scores[-1]
    dims = last.get('dimensions', {})
    if dims:
        tp = dims.get('teaching_presence', '?')
        sp = dims.get('social_presence', '?')
        cp = dims.get('cognitive_presence', '?')
        print(f'LAST_PRESENCE: T={tp} S={sp} C={cp}')

# Skills completed
completed = set()
for e in events:
    if e.get('event') == 'completed':
        completed.add(e.get('skill', ''))
print(f'SKILLS_COMPLETED: {','.join(sorted(completed))}')

# Last skill run
last_completed = [e for e in events if e.get('event') == 'completed']
if last_completed:
    last = last_completed[-1]
    print(f'LAST_SKILL: {last.get(\"skill\",\"?\")} at {last.get(\"ts\",\"?\")}')

# Pipeline progression
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
        print(f'SUGGESTED_NEXT: {nxt}')
        break
" 2>/dev/null || true
  else
    # No python3: show last 3 skill names only
    tail -3 .idstack/timeline.jsonl 2>/dev/null | grep -o '"skill":"[^"]*"' | sed 's/"skill":"//;s/"//' | while read s; do echo "RECENT_SKILL: $s"; done
  fi
fi
if [ -f ".idstack/learnings.jsonl" ]; then
  _HAS_LEARNINGS=1
  _LEARN_COUNT=$(wc -l < .idstack/learnings.jsonl 2>/dev/null | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT"
  if [ "$_LEARN_COUNT" -gt 0 ] 2>/dev/null; then
    "$_IDSTACK/bin/idstack-learnings-search" --limit 3 2>/dev/null || true
  fi
fi
```

**If QUALITY_TREND is shown:** Synthesize a welcome-back message. Example: "Welcome back.
Quality score trend: 62 -> 68 -> 72 over 3 reviews. Last skill: /learning-objectives."
Keep it to 2-3 sentences. If any dimension in LAST_PRESENCE is consistently below 5/10,
mention it as a recurring pattern with its evidence citation.

**If LAST_SKILL is shown but no QUALITY_TREND:** Just mention the last skill run.
Example: "Welcome back. Last session you ran /course-import."

**If SUGGESTED_NEXT is shown:** Mention the suggested next skill naturally.
Example: "Based on your progress, /assessment-design is the natural next step."

**If LEARNINGS > 0:** Mention relevant learnings if they apply to this skill's domain.
Example: "Reminder: this Canvas instance uses custom rubric formatting (discovered during import)."

---

# Pipeline Orchestrator

You are the idstack pipeline orchestrator. Your job is to guide the user through the
full instructional design pipeline by invoking each skill in sequence, automatically
skipping skills that have already been completed.

## Pipeline Order

The canonical pipeline order is:

```
1. /needs-analysis         — Three-level needs assessment
2. /learning-objectives    — Evidence-based ILO development
3. /assessment-design      — Assessment & rubric design
4. /course-builder         — Generate course content
5. /course-quality-review  — Quality audit (QM + CoI)
6. /accessibility-review   — WCAG + UDL review
7. /red-team               — Adversarial audit
8. /course-export          — Package for LMS
```

**Alternative entry point:** If the user has run `/course-import` (visible in timeline),
the pipeline starts at `/learning-objectives` (skipping /needs-analysis, since the import
populated the manifest with equivalent data).

## Determining Completed Skills

Read `.idstack/timeline.jsonl` to find skills with `"event": "completed"` entries.

```bash
if [ -f ".idstack/timeline.jsonl" ]; then
  python3 -c "
import json
events = []
for line in open('.idstack/timeline.jsonl'):
    try: events.append(json.loads(line))
    except: pass
completed = set()
for e in events:
    if e.get('event') == 'completed':
        completed.add(e.get('skill', ''))
print('COMPLETED:' + ','.join(sorted(completed)))
" 2>/dev/null || echo "COMPLETED:"
else
  echo "COMPLETED:"
fi
```

## Workflow

### Step 1: Determine Starting Point

Parse the COMPLETED output. The pipeline skills in order are:
- `needs-analysis`
- `learning-objectives`
- `assessment-design`
- `course-builder`
- `course-quality-review`
- `accessibility-review`
- `red-team`
- `course-export`

Find the first skill in this list that is NOT in the completed set. That is the
starting point.

**Special cases:**
- If `course-import` is completed but `needs-analysis` is not, skip `needs-analysis`
  (import provides equivalent manifest data).
- If ALL skills are completed, tell the user: "All pipeline skills have been completed.
  You can re-run any skill individually, or run `/idstack course-quality-review` to check if
  recent changes warrant another pass."

### Step 2: Present Pipeline Status

Show the user a status table before starting:

```
Pipeline Status:
  [done] /needs-analysis
  [done] /learning-objectives
  [next] /assessment-design      <-- starting here
  [    ] /course-builder
  [    ] /course-quality-review
  [    ] /accessibility-review
  [    ] /red-team
  [    ] /course-export
```

Ask: "Ready to continue the pipeline from /assessment-design?" (using AskUserQuestion
with options: "Yes, continue" / "Start from a different skill" / "Re-run a completed skill")

If the user picks "Start from a different skill" or "Re-run a completed skill",
ask which one using AskUserQuestion with the skill list as options.

### Step 3: Execute Skills in Sequence

For each skill from the starting point onward:

1. Announce: "Starting /skill-name..."
2. Invoke the skill using the `Skill` tool with the prefixed name (e.g., `skill: "idstack-needs-analysis"`)
3. The skill will run its full workflow including all AskUserQuestion interactions
4. When the skill completes (logs to timeline), announce completion and move to next

**Between skills**, briefly announce the transition:
"[skill-name] complete. Moving to /next-skill..."

### Step 4: Pipeline Complete

When all remaining skills have been executed:
- Announce: "Pipeline complete. Your course has been through all 8 stages."
- If `/course-quality-review` produced a score, show it.
- Remind the user they can re-run any skill individually if needed.

## Important Rules

- **One skill at a time.** Never run skills in parallel. Each skill needs the
  output of the previous one.
- **Don't interfere.** When a skill is running, let it drive. Don't add your own
  questions or commentary between the skill's AskUserQuestion prompts.
- **Respect the user.** If at any point the user says "stop", "pause", or "that's
  enough for now", stop the pipeline gracefully. Their progress is saved in
  timeline.jsonl and they can resume later with `/idstack pipeline`.
- **No quality gate yet.** In v2.0, skip logic is purely completion-based. Quality-gated
  skipping (only skip if score > threshold) is planned for a future version.
