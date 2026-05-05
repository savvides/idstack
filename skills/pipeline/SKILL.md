---
name: pipeline
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
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  _IDSTACK="$CLAUDE_PLUGIN_ROOT"
elif [ -n "${IDSTACK_HOME:-}" ]; then
  _IDSTACK="$IDSTACK_HOME"
else
  _IDSTACK="$HOME/.claude/plugins/idstack"
fi
_UPD=$("$_IDSTACK/bin/idstack-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD"
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A newer version of idstack is available. Run `cd ${IDSTACK_HOME:-~/.claude/plugins/idstack} && git pull && ./setup` to update. (The `./setup` step is required — it cleans up legacy symlinks.)" Then continue normally.

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
- If ALL skills are completed, tell the user via AskUserQuestion: "All pipeline skills have been completed. What would you like to do?" Options:
  - **Regenerate the pipeline report** — reads each per-skill report, refreshes `.idstack/reports/pipeline.md` with the latest cross-cutting view (no skills re-run). Recommended after editing per-skill outputs by hand.
  - **Re-run a specific skill** — e.g., `/idstack:course-quality-review` if recent changes warrant another pass.
  - **Exit** — leave everything as-is.
  If the user picks "Regenerate the pipeline report," skip directly to Step 4 (Generate Pipeline Report).

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
2. Invoke the skill using the `Skill` tool with the skill name (e.g., `skill: "needs-analysis"`)
3. The skill will run its full workflow including all AskUserQuestion interactions
4. When the skill completes (logs to timeline), **execute Step 4 (Generate Pipeline Report) inline** to refresh `.idstack/reports/pipeline.md` against the new per-skill report. This keeps the aggregate fresh if the designer pauses partway through.
5. Announce completion and move to next.

**Between skills**, briefly announce the transition:
"[skill-name] complete. Pipeline report refreshed. Moving to /next-skill..."

### Step 4: Generate Pipeline Report

After each skill completes (or after the orchestrator finishes the run, including partial runs), aggregate the per-skill reports into a single `.idstack/reports/pipeline.md` so the designer can read the full picture in one document.

**When this step runs:**

- Inline after each skill completes during the orchestrator's main loop (Step 3, item 4) — so a partial pipeline still leaves a useful aggregate behind if the designer pauses.
- As a one-shot regeneration when the "Regenerate the pipeline report" branch from Step 1 is selected (no skills are re-run; this step is the entire body of that branch).

**Inputs.** Read each per-skill report file if it exists:

- `.idstack/reports/needs-analysis.md`
- `.idstack/reports/learning-objectives.md`
- `.idstack/reports/assessment-design.md`
- `.idstack/reports/course-builder.md`
- `.idstack/reports/course-quality-review.md`
- `.idstack/reports/accessibility-review.md`
- `.idstack/reports/red-team.md`
- `.idstack/reports/course-export.md` (if present)
- `.idstack/reports/course-import.md` (if present)

Also read `.idstack/project.json` for project_name, scores, and the `report_path` fields.

**Output.** Write `.idstack/reports/pipeline.md`:

```bash
mkdir -p .idstack/reports
```

```markdown
# Pipeline Report

**Course:** [project_name]
**Generated:** [ISO-8601 timestamp]
**Pipeline run:** [partial — N of 8 skills complete | complete]

## Across your course

[2–3 paragraphs of cross-cutting synthesis. Designed to be read by a designer who
hasn't yet opened the per-skill reports. Lead with the verdict, follow with the
themes that recur across multiple skills, end with where to start.]

### Top cross-cutting issues

[The 3–5 highest-impact findings that appear in or affect multiple per-skill reports.
Each item shows the source skill(s) and the evidence tier.]

1. **[Finding title]** — appears in [skill A], [skill B] reports. [Evidence-N] [Tier]
   [One sentence: why this is the cross-cutting concern, not just a single-skill issue.]
2. ...

### Evidence themes

[Which evidence domains recur across the pipeline. Useful as a meta-read: "your
course's biggest wedge is feedback quality" or "alignment is the through-line
across 4 of 8 skills."]

- **[Domain]:** cited in [N] findings across [skill list]
- ...

### Where to start

[One paragraph. The single change (or 2–3 changes) that would address the largest
number of cross-cutting concerns. Anchored to a specific finding id in a specific
per-skill report so the designer can act on it.]

---

## Pipeline status

| Skill | Status | Score / signal | Report |
|-------|--------|----------------|--------|
| /idstack:course-import | [✓ run / not run] | [N items, F flags] | [path or —] |
| /idstack:needs-analysis | [✓ run / not run] | [training justified Y/N] | [path or —] |
| /idstack:learning-objectives | [✓ run / not run] | [N ILOs, M gaps] | [path or —] |
| /idstack:assessment-design | [✓ run / not run] | [feedback_quality_score] | [path or —] |
| /idstack:course-builder | [✓ run / not run] | [N artifacts, P placeholders] | [path or —] |
| /idstack:course-quality-review | [✓ run / not run] | [overall_score/100] | [path or —] |
| /idstack:accessibility-review | [✓ run / not run] | [overall/100, N WCAG-A] | [path or —] |
| /idstack:red-team | [✓ run / not run] | [confidence_score/100, N critical] | [path or —] |
| /idstack:course-export | [✓ run / not run] | [verdict from readiness_check] | [path or —] |

## Per-skill summaries

[For each skill that has a report file, include a subsection with:
- The Summary paragraph pulled verbatim from the per-skill report
- The top 2 findings (titles + severities + tiers — NOT the full block; the
  designer follows the link for detail)
- A link to the full per-skill report]

### /idstack:needs-analysis

[Summary paragraph from .idstack/reports/needs-analysis.md]

**Top findings:** `needs-1` [severity] [tier] · `needs-2` [severity] [tier]

**Full report:** [`.idstack/reports/needs-analysis.md`](needs-analysis.md)

---

[Repeat per skill that has a report.]

## Limitations

[Standard footer.]

- Cross-cutting findings are aggregated by reading per-skill reports, not by re-
  analyzing the course. If a per-skill report missed something, the pipeline
  report will too.
- Evidence-theme counts are based on `[Domain-N]` citation tags in the per-skill
  reports. Skills that wrote citations differently may be under-counted.
- This report is regenerated on every pipeline run — historical pipeline reports
  are not retained. The timeline at `.idstack/timeline.jsonl` carries the run
  history.

## Next steps

[Concrete pointer: which finding id to address first, or which skill to re-run
once a fix lands. Avoid generic advice.]

---

*Generated by `/idstack:pipeline`. Per-skill reports are in `.idstack/reports/`. The system-readable manifest is in `.idstack/project.json`.*
```

### Step 5: Pipeline Complete

When all remaining skills have been executed:
- Announce: "Pipeline complete. Your course has been through all 8 stages."
- Confirm the pipeline report path: "Aggregate report at `.idstack/reports/pipeline.md` — read this for the cross-cutting view; the per-skill reports under `.idstack/reports/` carry the full detail."
- If `/course-quality-review` produced a score, show it.
- Remind the user they can re-run any skill individually if needed, and that re-running `/idstack:pipeline` regenerates the aggregate report.

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
