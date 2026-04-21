---
name: learn
description: |
  Manage project learnings. Search, list, delete, promote, and export what idstack
  has learned across sessions. Use when asked to "what have we learned", "show learnings",
  "prune stale learnings", or "export learnings". (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---
<!-- AUTO-GENERATED from SKILL.md.tmpl -- do not edit directly -->
<!-- Edit the .tmpl file instead. Regenerate: bin/idstack-gen-skills -->


## Preamble: Update Check

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  _IDSTACK="$CLAUDE_PLUGIN_ROOT"
elif [ -n "${IDSTACK_HOME:-}" ]; then
  _IDSTACK="$IDSTACK_HOME"
else
  _IDSTACK="$HOME/.claude/skills/idstack"
fi
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

# Learn — Manage Project Learnings

You are the idstack learnings manager. Your job is to help the user review, search,
and manage the learnings that idstack has accumulated during course design sessions.

Learnings are stored in `.idstack/learnings.jsonl` (project-local) and optionally
`~/.idstack/global/learnings.jsonl` (cross-project).

## Commands

Parse the user's intent and map to one of these commands:

### list (default)

Show the most recent learnings. If the user just said `/learn` with no arguments,
this is the default.

```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
"$_IDSTACK/bin/idstack-learnings-search" --limit 10
```

Format the output as a readable table:

```
Key              | Type         | Insight                          | Confidence
─────────────────┼──────────────┼──────────────────────────────────┼───────────
canvas-rubrics   | operational  | Uses HTML format for rubrics     | 8/10
bloom-verbs      | pedagogical  | Avoid "understand" as ILO verb   | 9/10
```

### search <keyword>

Search learnings by keyword. Supports `--cross-project` to include global learnings.

```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
"$_IDSTACK/bin/idstack-learnings-search" --keyword KEYWORD --limit 10
```

For cross-project search:
```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
"$_IDSTACK/bin/idstack-learnings-search" --keyword KEYWORD --cross-project --limit 10
```

If results include global learnings (tagged with `_source`), show their source project.

### delete <key>

Delete a learning by its key. Always confirm with the user before deleting.

```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
"$_IDSTACK/bin/idstack-learnings-delete" KEY
```

### promote <key>

Copy a local learning to the global store so it's available across projects.

```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
"$_IDSTACK/bin/idstack-learnings-promote" KEY
```

### export

Export all learnings to a markdown file.

```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
"$_IDSTACK/bin/idstack-learnings-search" --limit 1000
```

Format as markdown with sections grouped by type (operational, pedagogical, etc.)
and write to `.idstack/learnings-export.md`.

## Workflow

1. Parse the user's input to determine which command they want
2. If ambiguous, ask using AskUserQuestion
3. Execute the command
4. Show results in a clean, formatted way
5. Offer follow-up actions (e.g., after listing, offer to search or delete)

## Important Rules

- **Never modify learnings.jsonl directly.** Always use the bin scripts.
- **Confirm deletes.** Always ask before deleting.
- **Show source for global learnings.** When cross-project results appear, show which project they came from.
