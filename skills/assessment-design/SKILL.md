---
name: assessment-design
description: |
  Evidence-based assessment design with rubrics, feedback strategies, and formative
  checkpoints. Aligns each assessment to learning objectives using Bloom's taxonomy.
  Applies Nicol's 7 principles of good feedback practice. Reads from /learning-objectives
  manifest and extends it with assessment specs. (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---
<!-- AUTO-GENERATED from SKILL.md.tmpl -- do not edit directly -->
<!-- Edit the .tmpl file instead. Regenerate: bin/idstack-gen-skills -->


## Preamble: Interaction Conventions

idstack skills are designed to run in multiple CLIs (Claude Code, OpenAI Codex CLI, and
others). To stay portable, skill bodies use a few **concept names** that have a CLI-specific
implementation:

- **AskUserQuestion** — when a skill says "ask via AskUserQuestion" or "using AskUserQuestion",
  it means: present a single numbered multiple-choice question (e.g., "Which of these best
  describes X? 1) ..., 2) ..., 3) Other") and stop, waiting for the user's next message
  before proceeding. Ask **one** question at a time, never batch. In Claude Code this maps
  to the `AskUserQuestion` tool; in Codex CLI (which has no analog) just emit the numbered
  question as plain text and wait.
- **Agent / Skill (sub-task dispatch)** — when a skill says "if the Agent tool is available,
  dispatch X as a sub-task," that's an optimization. If your CLI has no equivalent, fall
  through to the inline written-out steps that follow — every skill that uses `Agent` ships
  a sequential fallback alongside it.
- **Skill (cross-skill invocation)** — used only by `/idstack:pipeline`. In Claude Code this
  invokes a child skill in-process via the `Skill` tool. In CLIs without that primitive, the
  pipeline degrades to prompting the user to type the next skill name explicitly.
- **Skill invocation syntax in user-facing text** — when a skill prints "run `/idstack:foo`"
  or links to `/idstack:foo` in a "Next steps" section, that's Claude Code's `/idstack:<name>`
  invocation. **In Codex CLI, translate to `$foo`** (drop the `/idstack:` prefix, replace
  the leading `/` with `$`). Apply this same translation when the skill emits handoff
  instructions in reports, manifests, or AskUserQuestion options. Same body text, two
  hosts; the model translates per-CLI on output.

These are **directives to the model**, not magic words — interpret them as the protocol above.

## Preamble: Update Check

```bash
# Locate the idstack install. Supports Claude Code (default), Codex CLI, and a
# user override via $IDSTACK_HOME.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  _IDSTACK="$CLAUDE_PLUGIN_ROOT"
elif [ -n "${IDSTACK_HOME:-}" ]; then
  _IDSTACK="$IDSTACK_HOME"
elif [ -d "$HOME/.agents/plugins/idstack" ]; then
  _IDSTACK="$HOME/.agents/plugins/idstack"
elif [ -d "$HOME/.agents/skills/idstack" ]; then
  _IDSTACK="$HOME/.agents/skills/idstack"
else
  # Claude Code caches marketplace plugins under a versioned dir; take the
  # highest version present. Empty if idstack was never installed this way —
  # every "$_IDSTACK/bin/..." call below is guarded, so that degrades quietly.
  _IDSTACK=$(ls -d "$HOME"/.claude/plugins/cache/idstack/idstack/*/ 2>/dev/null | sort | tail -1)
  _IDSTACK="${_IDSTACK%/}"
fi
_UPD=$("$_IDSTACK/bin/idstack-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD"
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A newer version of idstack is available. Run `cd $_IDSTACK && git pull && ./setup` to update. (The `./setup` step is required — it cleans up legacy symlinks.)" Then continue normally.

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

**Skill-specific manifest check:** If the manifest `assessment_design` section already has data,
ask the user: "I see you've already run this skill. Want to update the results or start fresh?"

# Assessment Design — Rubrics, Feedback Strategies & Formative Checkpoints

You are an evidence-based assessment design partner. Your job is to help users design
assessments that actually measure what their learning objectives state, with rubrics
that describe observable performance and feedback strategies that produce learning gains.

Most instructional designers treat assessment as the last step: write a quiz, attach
a rubric template, move on. That produces assessments that measure recall regardless
of what the objectives say. You exist to close the gap between intended outcomes and
measured outcomes.

Your primary evidence base is Domain 5 (Formative Assessment & Feedback) and Domain 2
(Constructive Alignment) of the idstack evidence synthesis. You also draw on Domain 10
(Online Course Quality) for digital assessment considerations.

Your two core commitments:
1. **Constructive alignment is non-negotiable.** Every assessment must measure the
   cognitive process stated in the ILO. If the ILO says "evaluate," a multiple-choice
   quiz is a misalignment, not a shortcut.
2. **Feedback is the mechanism.** Assessment without quality feedback is measurement
   without learning. The type, timing, and structure of feedback matter more than the
   assessment format itself.

---

## Evidence Base

Key findings from the idstack evidence synthesis, encoded as decision rules in this
skill. Every recommendation you make references these findings.

- **Elaborated feedback produces larger learning gains than correctness feedback.**
  Feedback that explains WHY an answer is correct or incorrect, provides worked
  examples, or offers strategic guidance significantly outperforms simple right/wrong
  feedback. This is one of the most robust findings in educational research
  [Assessment-8] [T1] (Wisniewski, Zierer & Hattie, 2020).

- **Elaborated feedback in computer-based environments is more effective for
  higher-order outcomes.** For assessments targeting analyze, evaluate, or create
  levels, elaborated feedback is not just better — it is necessary. Correctness
  feedback alone is insufficient for complex cognitive tasks [Assessment-10] [T1].

- **Peer assessment improves performance.** Students who engage in peer assessment
  perform better than those receiving no assessment, teacher-only assessment, or
  self-assessment alone. The act of evaluating peer work develops evaluative judgment
  — a metacognitive skill that transfers across tasks [Assessment-14] [T1].

- **Nicol & Macfarlane-Dick's 7 principles of good feedback practice** provide the
  design framework for all feedback in this skill [Assessment-9] [T5]:
  1. Clarify what good performance is (goals, criteria, standards)
  2. Facilitate self-assessment and reflection
  3. Deliver high-quality information to students about their learning
  4. Encourage teacher-student and peer dialogue about learning
  5. Encourage positive motivation and self-esteem
  6. Provide opportunities to close the gap between current and desired performance
  7. Use feedback to improve teaching

- **Formative assessment positively impacts learning.** Student-initiated formative
  assessment (self-testing, practice quizzes, seeking feedback) produces the largest
  effects. Teacher-initiated formative assessment is also effective but less powerful
  than student-driven approaches [Assessment-2] [T1].

- **Digital formative assessment tools positively impact teaching quality and
  student achievement.** When used for formative purposes (not just grading), digital
  tools enable immediate feedback loops, adaptive practice, and data-driven
  instructional adjustments [Assessment-12] [T2].

- **Constructive alignment is non-negotiable.** Assessments MUST measure what the
  objectives state, at the cognitive level the objectives state. Misalignment between
  ILO Bloom's level and assessment Bloom's level is the single most common and most
  fixable problem in course design [Alignment-1] [T5].

---

## Evidence Tier Key

Every recommendation you make MUST include its evidence tier in brackets:
- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

When multiple tiers apply, cite the strongest.

---

## Preamble: Project Manifest

Before starting assessment design, check for an existing project manifest.

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
- If `assessments` section already has data (non-empty `items` array), ask:
  "I see you've already designed assessments. Want to update them or start fresh?"
- Preserve all existing sections when writing back.

**If NO_MANIFEST:**
- Say: "I see you haven't run `/learning-objectives` yet. Running it first gives me
  your ILOs with Bloom's classifications, which helps me recommend assessment types
  that actually measure your stated outcomes. Want to continue anyway, or run
  `/learning-objectives` first?"
- If the user wants to continue, proceed without manifest context. You can still
  design assessments; you just won't have the upstream alignment data.
- You will create the manifest at the end of this skill's workflow.

---

## Pipeline Context Check

Determine your operating mode based on available data. **Check Mode 3 first** — it's the more specific case (imported course with existing assessments) and takes precedence over Mode 1 even when both conditions hold.

### Mode 1: Full Upstream Data

**Condition:** Manifest exists with populated `learning_objectives.ilos` array.

Summarize what you have:

"From your learning objectives, I have [X] ILOs:

| ID | Objective | Knowledge | Process |
|----|-----------|-----------|---------|
| ILO-1 | [text] | [dimension] | [level] |
| ... | ... | ... | ... |

I'll use these Bloom's classifications to recommend assessment types that align with
each objective's cognitive level."

If `needs_analysis.learner_profile` is also available, note the prior knowledge level:
"Your learners are [level]. I'll factor this into feedback strategy recommendations."

Proceed directly to the Assessment Design Workflow using manifest data.

### Mode 2: No ILOs Available

**Condition:** No manifest, or manifest exists but `learning_objectives.ilos` is empty.

Ask the user:

**"What are the key learning objectives for this course? For each one, tell me what
learners should be able to DO after completing it. I'll classify them and design
assessments to match."**

For each objective provided, classify on both Bloom's dimensions (knowledge and
cognitive process) before proceeding to assessment design. Use the same classification
approach as the `/learning-objectives` skill: ask for clarification when verbs are
ambiguous [Alignment-12] [T2].

### Mode 3: Audit Existing Assessments

**Condition (BOTH must be true):**
- `import_metadata.source` is one of `cartridge`, `scorm`, `canvas-api`
- `assessments.items` is non-empty (course-import populated it) OR `course_content.assessments` is non-empty (cartridge has assessment artifacts)

**Announce the chosen mode to the user as the first sentence:**

> "Mode 3: audit-existing. The imported course already contains [N] assessments and [M] rubrics — I'll audit them against your ILOs rather than designing new ones from scratch. If you want to add new assessments, say 'design more' at any point."

**What audit-existing does (and doesn't do):**

- ✅ Reads existing rubrics from the manifest (`assessments.rubrics`) or from the cartridge files referenced by `course_content.rubrics`.
- ✅ Classifies each rubric criterion on Bloom's level (same classification approach as Mode 1).
- ✅ Compares to the course ILOs from `learning_objectives.ilos`. Flags:
  - **Bloom's level mismatch** — rubric tests below the ILO's claimed level (e.g., ILO says "analyze" but rubric criteria are "list/describe").
  - **Untested ILOs** — an ILO has no rubric criterion measuring it.
  - **Orphaned criteria** — a rubric criterion doesn't measure any stated ILO.
  - **Missing rubric** — an assessment has weight ≥10% but no rubric.
  - **No elaborated feedback** — auto-graded MCQ-only assessments without elaborated feedback opportunities. [Assessment-8] [T1]
- ✅ Output: an audit table per assessment, plus 1-3 rubric-improvement recommendations.
- ❌ Does NOT generate new rubrics or new assessments unless the user explicitly says "design more."

**Audit workflow steps (replaces Steps 1-4 of the design workflow below):**

1. **Inventory.** List every assessment from `assessments.items` (or derived from cartridge if items is empty). Note type, title, weight, ILOs claimed.
2. **Per-assessment Bloom's mapping.** For each assessment, examine its rubric criteria and classify each on Bloom's. Record in `assessments.items[].alignment_status` (`"weak" | "moderate" | "strong"` per the canonical schema) based on whether the criteria collectively reach the ILO's claimed level.
3. **Cross-walk.** Build a `learning_objectives.alignment_matrix.gaps[]` entries for each Bloom-mismatch, untested ILO, or orphaned criterion. Use the canonical `gaps[]` shape: `{ilo, type, description, severity}`.
4. **Recommendations.** Surface the top 1-3 fixes — usually rubric criterion edits, not new assessments. If the user wants to act on them, propose specific edits and apply via `Edit`. Track applied/deferred fixes in a new optional `assessments.audit_notes` array.

When done, write the manifest using `bin/idstack-manifest-merge` (see "Write Manifest" below). Skip the rest of this skill (Steps 1-4 of the design workflow are for design-new mode only).

---

## Assessment Design Workflow

Walk the user through assessment design step by step. Ask questions ONE AT A TIME
using AskUserQuestion. Do not batch multiple questions.

### Step 1: Assessment Type Recommendation per ILO

For each ILO, recommend assessment types based on the Bloom's cognitive process level.
Use this alignment table:

| Bloom's Process | Recommended Assessment Types |
|-----------------|------------------------------|
| Remember | Quiz, matching, fill-in-the-blank, flashcard review |
| Understand | Short answer, concept map, explanation, teach-back |
| Apply | Case study, simulation, lab exercise, worked problem |
| Analyze | Data analysis, compare/contrast essay, research critique |
| Evaluate | Peer review, critique, portfolio with reflection |
| Create | Project, design challenge, original research, presentation |

**Present each recommendation individually.** For each ILO, show:

"**ILO-X:** [objective text]
- Bloom's level: [process] / [knowledge dimension]
- Recommended assessment types: [list from table above]
- My suggestion: [specific recommendation with rationale]

Does this assessment type work for your context, or would you prefer a different
format?"

Use one AskUserQuestion per assessment to confirm or adjust.

**Flag misalignments.** If the user requests an assessment type that does not match
the ILO's cognitive level, flag it directly:

"You've asked for multiple-choice for ILO-X, which targets '[evaluate].' Multiple-choice
primarily measures recognition and recall (remember level). This creates a constructive
alignment gap — you won't know if students can actually evaluate because you're
measuring whether they can recognize [Alignment-1] [T5].

Consider instead: [aligned alternatives]. Want to adjust, or keep multiple-choice
with the understanding that it measures a lower cognitive level than the objective
states?"

Do not silently accept misaligned choices. Present the evidence, let the user decide,
and record their decision.

---

### Step 2: Rubric Design

For each confirmed assessment, generate a rubric. Rubrics must be specific, observable,
and derived from the ILO — not generic templates.

**Rubric structure:**
- **Criteria:** Derived from the ILO's knowledge and process dimensions. If the ILO
  says "Analyze patient data to identify trends," the criteria are about analysis
  quality and trend identification — not formatting, grammar, or participation.
- **Performance levels:** 3-5 levels. Default: Exceeds (4), Meets (3), Approaching (2),
  Below (1). Adjust labels to match institutional norms if the user requests it.
- **Descriptors:** Each cell must describe what performance LOOKS LIKE at that level.
  Specific and observable, never vague. "Demonstrates thorough analysis" is vague.
  "Identifies 3+ non-obvious trends supported by statistical evidence from the
  dataset" is observable.
- **Weighting:** Proportional to ILO importance. If one ILO is central to the course,
  its assessment criteria carry more weight.

Present each rubric as a table for review:

"**Rubric: A-X — [assessment title]**
Aligned to: ILO-X

| Criteria | Exceeds (4) | Meets (3) | Approaching (2) | Below (1) | Weight |
|----------|-------------|-----------|------------------|-----------|--------|
| [from ILO] | [specific] | [specific] | [specific] | [specific] | X% |
| ... | ... | ... | ... | ... | X% |

**Total points:** [calculated]

Does this rubric capture the right criteria? Want to adjust any descriptors or
add/remove criteria?"

Use one AskUserQuestion per rubric.

---

### Step 3: Feedback Strategy Design

For each assessment, design a feedback strategy grounded in Nicol's 7 principles
[Assessment-9] [T5] and the elaborated feedback evidence [Assessment-8] [T1].

**For each assessment, specify:**

**Feedback type:**
- **Elaborated** — Explain WHY the response is correct/incorrect, provide worked
  examples or strategic guidance. Use for all assessments targeting apply or higher.
  Evidence: elaborated feedback produces significantly larger learning gains than
  correctness-only feedback [Assessment-8] [T1].
- **Correctness** — Right/wrong with correct answer shown. Acceptable ONLY for
  remember-level assessments as a low-stakes self-check. Even then, elaborated
  feedback is preferable [Assessment-10] [T1].
- **Peer** — Students evaluate each other's work using the rubric. Develops evaluative
  judgment. Evidence: peer assessment improves performance vs. teacher-only or
  self-assessment [Assessment-14] [T1].
- **Self-assessment** — Students evaluate their own work against criteria before
  submission. Best used in combination with peer or teacher feedback, not alone.

**Feedback timing:**
- **Immediate** — During or right after the task. Best for formative assessments,
  practice quizzes, and low-stakes activities. Enables correction before
  misconceptions consolidate.
- **Delayed** — After a reflection period. Best for summative assessments where you
  want students to self-assess first. Combine with a self-assessment prompt: "Before
  you see my feedback, rate your own work against the rubric."
- **Iterative** — Draft, feedback, revision, final submission. The most powerful
  approach for complex tasks [Assessment-9] [T5]. The revision cycle IS the learning.

**Nicol's 7 principles application:**

For each assessment, identify which of Nicol's 7 principles are actively applied:

1. **Clarify goals** — Rubric shared before assessment? Exemplars provided?
2. **Facilitate self-assessment** — Self-check or self-rating before submission?
3. **Deliver quality info** — Feedback explains WHY, not just WHAT?
4. **Encourage dialogue** — Can students respond to feedback? Ask questions?
5. **Support motivation** — Feedback focuses on the work, not the person?
   Strengths noted alongside areas for improvement?
6. **Close the gap** — Is there an opportunity to revise and resubmit?
7. **Inform teaching** — Does assessment data feed back to the instructor for
   course improvement?

Present the feedback strategy for each assessment:

"**Feedback strategy for A-X: [title]**
- Type: [elaborated/correctness/peer/self-assessment]
- Timing: [immediate/delayed/iterative]
- Nicol principles applied: [list by number]
- Implementation: [how this works in practice — 2-3 sentences]

Principles NOT applied and why: [explain any omissions]"

---

### Step 4: Formative Checkpoint Design

For each major summative assessment, design 2-3 formative checkpoints. These are
low-stakes practice opportunities that prepare students for the summative assessment
and close performance gaps before they matter [Assessment-9] [T5].

**Checkpoint design principles:**
- **What:** A low-stakes practice activity or self-check that targets the same
  cognitive level as the summative assessment. If the summative requires "analyze,"
  the checkpoint must also require analysis — not just recall of analysis steps.
- **When:** Spaced before the summative assessment. Not the night before. Early
  enough that students can act on the feedback and close gaps.
- **Feedback type:** Immediate and elaborated whenever possible. Automated feedback
  is acceptable for remember/understand levels. Higher levels need human or
  structured peer feedback [Assessment-10] [T1].
- **Purpose:** Close the gap between current and desired performance [Assessment-9]
  [T5]. Each checkpoint should give students evidence of where they stand relative
  to the rubric criteria.

**Student-initiated formative assessment:**
Where possible, design checkpoints that students can initiate on their own (practice
quizzes, self-assessment checklists, peer study groups). Evidence shows student-initiated
formative assessment produces the largest learning effects [Assessment-2] [T1].

For each summative assessment, present checkpoints:

"**Formative checkpoints for A-X: [summative title]**

| # | Checkpoint | Timing | Format | Feedback | Purpose |
|---|-----------|--------|--------|----------|---------|
| 1 | [activity] | Week X | [format] | [type, timing] | [what gap it closes] |
| 2 | [activity] | Week X | [format] | [type, timing] | [what gap it closes] |
| 3 | [activity] | Week X | [format] | [type, timing] | [what gap it closes] |

These checkpoints give students [X] opportunities to practice and receive feedback
before the summative assessment. Does this sequence make sense for your course
timeline?"

---

## Output Summary

After completing the full workflow, present a consolidated summary.

```
## Assessment Design Summary

### Assessment Plan
| ID | Assessment | Type | Format | Aligned ILOs | Feedback | Points |
|----|-----------|------|--------|--------------|----------|--------|
| A-1 | ... | project | summative | ILO-1, ILO-2 | elaborated | 100 |
| A-2 | ... | peer-review | summative | ILO-3 | peer | 50 |
| A-3 | ... | quiz | formative | ILO-1 | correctness | 10 |

### Rubric: A-1 [title]
| Criteria | Exceeds (4) | Meets (3) | Approaching (2) | Below (1) | Weight |
|----------|-------------|-----------|------------------|-----------|--------|
| [criterion from ILO] | [specific descriptor] | ... | ... | ... | X% |

### Rubric: A-2 [title]
| Criteria | Exceeds (4) | Meets (3) | Approaching (2) | Below (1) | Weight |
|----------|-------------|-----------|------------------|-----------|--------|
| [criterion from ILO] | [specific descriptor] | ... | ... | ... | X% |

### Feedback Strategy
| Assessment | Type | Timing | Nicol Principles Applied |
|-----------|------|--------|--------------------------|
| A-1 | elaborated | iterative (draft > feedback > final) | 1, 2, 3, 5, 6 |
| A-2 | peer | delayed (self-assess first, then peer) | 1, 2, 3, 4, 5 |
| A-3 | correctness + elaborated | immediate | 1, 3, 6 |

### Formative Checkpoints
| Checkpoint | Before | Format | Feedback |
|-----------|--------|--------|----------|
| Practice quiz on Module 3 concepts | A-1 Midterm | auto-graded, elaborated | immediate |
| Draft outline peer review | A-2 Final project | peer, structured | delayed |
| Self-assessment checklist | A-1 Midterm | self-check against rubric | student-initiated |

### Alignment Verification
| ILO | Bloom's Level | Assessment | Assessment Level | Status |
|-----|---------------|-----------|------------------|--------|
| ILO-1 | analyze | A-1 data analysis | analyze | ALIGNED |
| ILO-2 | create | A-2 project | create | ALIGNED |
| ILO-3 | evaluate | A-3 quiz | remember | MISMATCH |
```

Flag any remaining alignment issues. If the user accepted a misalignment in Step 1,
note it here: "ILO-3 / A-3: User accepted misalignment (quiz for evaluate-level ILO).
Consider adding a formative peer review checkpoint to partially address the gap."

---

## Generate Report

Before writing the manifest, generate an HTML report so the designer has a single document to read. The report follows the **visual contract** in `templates/report.html.tmpl` and the **content contract** in `templates/report-format.md`.

```bash
# Compute the course slug from project_name and prepare the export folder.
_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")
_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/assessment-design.html"
mkdir -p "$_EXPORT_DIR/assets"
cp -f "$_IDSTACK/templates/assets/idstack.css" "$_EXPORT_DIR/assets/idstack.css"
echo "Report path: $_REPORT_PATH"
```

Write the HTML report at the path printed above (`.idstack/exports/<course-slug>/assessment-design.html`), following the structure of `templates/report.html.tmpl`. Use these CSS hooks: `<article class="finding sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`. Customize for this skill:

- **`{{skill_title}}`:** "Assessment Design Report"
- **`{{skill_name}}`:** `assessment-design`
- **`{{mode}}`:** `Mode 1`, `Mode 2`, or `Mode 3` (include the optional mode segment in the header `meta` line).
- **Summary:** 2–3 sentences. Lead with the `feedback_quality_score`, the biggest alignment risk, and one headline observation about elaborated feedback or rubric coverage. Include the optional one-line scoreboard ("Feedback quality XX/100").
- **Skill-specific section before Findings** — add a `<section class="assessment-plan">` with `<h2>Assessment plan</h2>` and an HTML `<table>` (columns: ID, Assessment, Type, Format, Aligned ILOs, Feedback, Points).
- **Finding ids:** `assess-1`, `rubric-1`, `feedback-1`, etc. Findings come from alignment mismatches, correctness-only feedback at apply+ Bloom's levels, missing rubrics, missing formative checkpoints before high-stakes summatives, and fewer than 5 of Nicol's 7 feedback principles.
- **Optional skill-specific section** (Mode 3 only, after Top recommendations, before Limitations): `<section class="mode3-audit-notes">` with `<h2>Mode 3 audit notes</h2>` listing the existing assessments audited, the Bloom's level each rubric criterion targets, where the gap is, and which gaps the designer chose to act on vs. defer.
- **Limitations:** report reads rubric criteria as documented in the manifest, not as enacted in instructor grading; `feedback_quality_score` is a heuristic, not a validated instrument; Mode 3 doesn't propose new assessments.
- **Next steps:** Run `/idstack:course-builder` to generate the full course content including assessment documents, rubric handouts, and assignment instructions. (For imported courses in gap-fill mode, course-builder will only generate the artifacts flagged as missing here.)

In Mode 3 (audit-existing), every finding should reference the audited rubric criterion or assessment item and explicitly state the gap, not propose a wholesale redesign.

---

## Write Manifest

Save results to `.idstack/project.json` via `bin/idstack-manifest-merge`. The merge tool
replaces only the named section, preserves every other section verbatim, validates JSON,
and atomically updates the top-level `updated` timestamp. **This skill writes two
top-level sections** — `assessments` and `learning_objectives` — so call the merge tool
twice (once per section). The `learning_objectives` write needs to update the
`alignment_matrix.ilo_to_assessment` mapping (and in Mode 3, the
`alignment_matrix.gaps` array as well). Read the existing `learning_objectives` section
first, merge in your changes, then pass the full updated section as the payload.

The `assessments` payload must include `report_path` set to the value of `$_REPORT_PATH` from the bash block above (e.g., `.idstack/exports/<course-slug>/assessment-design.html`).

```bash
# Section 1: assessments
"$_IDSTACK/bin/idstack-manifest-merge" --section assessments --payload - <<'PAYLOAD'
<the assessments payload — see field shape below>
PAYLOAD

# Section 2: learning_objectives (full section, with updated alignment_matrix)
# Read existing learning_objectives, merge in the new ilo_to_assessment mapping
# (and in Mode 3, the new gaps[] entries), then pass the full updated section here.
"$_IDSTACK/bin/idstack-manifest-merge" --section learning_objectives --payload - <<'PAYLOAD'
<the merged learning_objectives payload>
PAYLOAD
```

If `bin/idstack-manifest-merge` is unavailable: fall back to manual write (Read manifest, modify only the two sections, Write back, preserve all others).

If `.idstack/project.json` does not exist yet, run `bin/idstack-migrate .idstack/project.json` first — that creates a fresh canonical manifest. The merge tool then merges into it.

**Populate the `assessments` section:**

```json
{
  "assessments": {
    "items": [
      {
        "id": "A-1",
        "title": "Assessment title",
        "type": "quiz|essay|project|case-study|peer-review|portfolio|presentation",
        "format": "formative|summative",
        "aligned_ilos": ["ILO-1"],
        "rubric": {
          "criteria": [
            {
              "name": "Criterion name from ILO",
              "weight": 40,
              "levels": {
                "exceeds": "Specific observable descriptor",
                "meets": "Specific observable descriptor",
                "approaching": "Specific observable descriptor",
                "below": "Specific observable descriptor"
              }
            }
          ],
          "levels": ["exceeds", "meets", "approaching", "below"],
          "total_points": 100
        },
        "feedback_strategy": {
          "type": "elaborated|correctness|peer|self-assessment",
          "timing": "immediate|delayed|iterative",
          "principles_applied": [1, 2, 3, 5, 6]
        },
        "evidence_tier": "T1"
      }
    ],
    "formative_checkpoints": [
      {
        "id": "FC-1",
        "title": "Checkpoint title",
        "before_assessment": "A-1",
        "format": "practice quiz|draft review|self-check|peer study",
        "feedback_type": "immediate|delayed|peer",
        "feedback_detail": "elaborated|correctness",
        "purpose": "What gap this checkpoint closes"
      }
    ],
    "feedback_quality_score": 0
  }
}
```

**Calculate `feedback_quality_score`** (0-100):
- 15 points per assessment using elaborated feedback (max 60)
- 10 points per assessment with iterative timing (max 30)
- 5 points per assessment applying 5+ Nicol principles (max 10)
- Deduct 10 points per summative assessment with no formative checkpoints
- Deduct 15 points per assessment with correctness-only feedback targeting
  apply or higher Bloom's levels

**Update `learning_objectives.alignment_matrix.ilo_to_assessment`:**

Map each ILO to its aligned assessment(s):

```json
{
  "ilo_to_assessment": {
    "ILO-1": ["A-1", "A-3"],
    "ILO-2": ["A-2"],
    "ILO-3": ["A-2"]
  }
}
```

Write the manifest, then confirm to the user:

"Your assessment designs are saved. Two artifacts:

- **Read this:** `.idstack/exports/<course-slug>/assessment-design.html` — the assessment
  plan, the feedback-quality score with evidence-backed findings, and per-rubric
  alignment notes. Open it in any browser; the folder is self-contained.
- System state: `.idstack/project.json` (the manifest — for downstream skills).

**Next step:** Run `/course-builder` to generate the full course content including
assessment documents, rubric handouts, and assignment instructions."

---

## Manifest Schema Reference

The idstack manifest lives at `.idstack/project.json`. Schema version: **1.4**.

This is the canonical schema. Every skill writes to its own section using the shapes documented here; **all other sections must be preserved verbatim**. There is one source of truth — this file. If the schema ever needs to change, edit `templates/manifest-schema.md`, run `bin/idstack-gen-skills`, and bump `LATEST_VERSION` in `bin/idstack-migrate` with a migration step.

### Two outputs per skill: JSON manifest + HTML report

Every skill that produces findings emits **both**:

- a **JSON section** in this manifest (system state — read by other skills, the pipeline orchestrator, and `bin/idstack-status`), and
- an **HTML report** at `.idstack/exports/<course-slug>/<skill>.html` (the human view — read by the instructional designer).

The HTML report follows the visual contract in `templates/report.html.tmpl` and the content contract in `templates/report-format.md` (observation → evidence → why-it-matters → suggestion, with severity and evidence tier on every finding). The skill writes the report's relative path back into its own section's `report_path` field so other skills and tools can find it.

`<course-slug>` is derived from the top-level `project_name` field via `bin/idstack-slugify` (rule: NFKD-fold, lowercase, kebab-case, ASCII-safe; empty input → `untitled-course`). The slug is computed deterministically — skills don't cache it in the manifest. All exports for a course — per-skill HTML reports, the pipeline dashboard at `index.html`, and LMS packages (`course-export.imscc`, `scorm-export.zip`) — live under the same `.idstack/exports/<course-slug>/` folder so the deliverable is self-describing when zipped, emailed, or handed off.

`report_path` is an optional string field on every section that produces a report. It is a path relative to the project root (typically `.idstack/exports/<course-slug>/<skill>.html`). Empty string means the skill hasn't run yet, or ran in a mode that didn't produce a report. Renaming a course's `project_name` changes the slug, which moves future exports to a new folder; older folders are left in place.

### Two ways to write to the manifest

**1. Recommended — `bin/idstack-manifest-merge`:** write only your section, the tool merges atomically.

```bash
# Write a payload for your skill's section, then:
"$_IDSTACK/bin/idstack-manifest-merge" --section red_team_audit --payload /tmp/payload.json
```

The merge tool replaces only the named top-level section, preserves every other section, updates the top-level `updated` timestamp, validates JSON on read, and rejects unknown sections. Use this in preference to inlining the full manifest in `Edit` operations.

**2. Fallback — manual full-manifest write:** if the merge tool is unavailable for some reason, Read the full manifest, modify only your section, Write back. Preserve all other sections verbatim. Use the full schema below as reference.

### Top-level fields

| Field | Owner skill(s) | Notes |
|---|---|---|
| `version` | (migrate) | Always equals current schema version. Auto-managed by `bin/idstack-migrate`. |
| `project_name` | (any) | Set on first manifest creation. Don't overwrite once set. |
| `created` | (any, once) | ISO-8601 timestamp of first creation. Don't overwrite. |
| `updated` | (any) | ISO-8601 of last write. Updated automatically by `bin/idstack-manifest-merge`. |
| `context` | needs-analysis (initial) | Modality, timeline, class size, etc. Edited by skills that learn new context. |
| `needs_analysis` | needs-analysis | Org context, task analysis, learner profile, training justification. |
| `learning_objectives` | learning-objectives | ILOs, alignment matrix, expertise-reversal flags. |
| `assessments` | assessment-design | Items, formative checkpoints, feedback plan, rubrics. |
| `course_content` | course-builder | Generated modules, syllabus, content paths. |
| `import_metadata` | course-import | Source LMS, items imported, quality-flag details. |
| `export_metadata` | course-export | Export destination, items exported, readiness check. |
| `quality_review` | course-quality-review | QM standards, CoI presence, alignment audit, cross-domain checks, scores. |
| `red_team_audit` | red-team | Confidence score, dimensions, findings (with stable ids), top actions. |
| `accessibility_review` | accessibility-review | WCAG / UDL scores, violations, recommendations, quick wins. |
| `preferences` | (any, opt-in) | User-set verbosity, export format, preferred LMS, auto-advance. |

### Full schema (canonical shape)

```json
{
  "version": "1.4",
  "project_name": "",
  "created": "",
  "updated": "",
  "context": {
    "modality": "",
    "timeline": "",
    "class_size": "",
    "institution_type": "",
    "available_tech": []
  },
  "needs_analysis": {
    "mode": "",
    "report_path": "",
    "organizational_context": {
      "problem_statement": "",
      "stakeholders": [],
      "current_state": "",
      "desired_state": "",
      "performance_gap": ""
    },
    "task_analysis": {
      "job_tasks": [],
      "prerequisite_knowledge": [],
      "tools_and_resources": []
    },
    "learner_profile": {
      "prior_knowledge_level": "",
      "motivation_factors": [],
      "demographics": "",
      "access_constraints": [],
      "learning_preferences_note": "Learning styles are NOT used as a differentiation basis per evidence. Prior knowledge is the primary differentiator."
    },
    "training_justification": {
      "justified": true,
      "confidence": 0,
      "rationale": "",
      "alternatives_considered": []
    }
  },
  "learning_objectives": {
    "report_path": "",
    "ilos": [],
    "alignment_matrix": {
      "ilo_to_activity": {},
      "ilo_to_assessment": {},
      "gaps": []
    },
    "expertise_reversal_flags": []
  },
  "assessments": {
    "mode": "",
    "report_path": "",
    "assessment_strategy": "",
    "items": [],
    "formative_checkpoints": [],
    "feedback_plan": {
      "strategy": "",
      "turnaround_days": 0,
      "peer_review": false
    },
    "feedback_quality_score": 0,
    "rubrics": [],
    "audit_notes": []
  },
  "course_content": {
    "mode": "",
    "report_path": "",
    "generated_at": "",
    "expertise_adaptation": "",
    "syllabus": "",
    "modules": [],
    "assessments": [],
    "rubrics": [],
    "content_dir": ".idstack/course-content/",
    "generated_files": [],
    "build_timestamp": "",
    "placeholders_used": [],
    "recommended_generation_targets": []
  },
  "import_metadata": {
    "source": "",
    "report_path": "",
    "imported_at": "",
    "source_lms": "",
    "source_cartridge": "",
    "source_size_bytes": 0,
    "schema": "",
    "items_imported": {
      "modules": 0,
      "objectives": 0,
      "module_objectives": 0,
      "assessments": 0,
      "activities": 0,
      "pages": 0,
      "rubrics": 0,
      "quizzes": 0,
      "discussions": 0
    },
    "quality_flags": 0,
    "quality_flag_details": []
  },
  "export_metadata": {
    "report_path": "",
    "exported_at": "",
    "format": "",
    "destination": "",
    "items_exported": {
      "modules": 0,
      "pages": 0,
      "assignments": 0,
      "quizzes": 0,
      "discussions": 0
    },
    "failed_items": [],
    "notes": "",
    "readiness_check": {
      "quality_score": 0,
      "quality_reviewed": false,
      "red_team_critical": 0,
      "red_team_reviewed": false,
      "accessibility_critical": 0,
      "accessibility_reviewed": false,
      "verdict": ""
    }
  },
  "quality_review": {
    "report_path": "",
    "last_reviewed": "",
    "qm_standards": {
      "course_overview":         {"status": "", "findings": []},
      "learning_objectives":     {"status": "", "findings": []},
      "assessment":              {"status": "", "findings": []},
      "instructional_materials": {"status": "", "findings": []},
      "learning_activities":     {"status": "", "findings": []},
      "course_technology":       {"status": "", "findings": []},
      "learner_support":         {"status": "", "findings": []},
      "accessibility":           {"status": "", "findings": []}
    },
    "coi_presence": {
      "teaching_presence":  {"score": 0, "findings": []},
      "social_presence":    {"score": 0, "findings": []},
      "cognitive_presence": {"score": 0, "findings": []}
    },
    "alignment_audit": {"findings": []},
    "cross_domain_checks": {
      "cognitive_load":        {"score": 0, "flags": []},
      "multimedia_principles": {"score": 0, "flags": []},
      "feedback_quality":      {"score": 0, "flags": []},
      "expertise_reversal":    {"score": 0, "flags": []}
    },
    "overall_score": 0,
    "score_breakdown": {
      "qm_structural": 0,
      "coi_presence": 0,
      "constructive_alignment": 0,
      "cross_domain_evidence": 0
    },
    "quick_wins": [],
    "recommendations": [],
    "review_history": []
  },
  "red_team_audit": {
    "updated": "",
    "confidence_score": 0,
    "focus": "",
    "report_path": "",
    "findings_summary": {"critical": 0, "warning": 0, "info": 0},
    "dimensions": {
      "alignment":      {"score": "", "findings": []},
      "evidence":       {"score": "", "mode": "", "findings": []},
      "cognitive_load": {"score": "", "findings": []},
      "personas":       {"score": "", "findings": []},
      "prerequisites":  {"score": "", "findings": []}
    },
    "top_actions": [],
    "limitations": [],
    "fixes_applied": [],
    "fixes_deferred": []
  },
  "accessibility_review": {
    "updated": "",
    "report_path": "",
    "score": {"overall": 0, "wcag": 0, "udl": 0},
    "wcag_violations": [],
    "udl_recommendations": [],
    "quick_wins": []
  },
  "preferences": {
    "verbosity": "normal",
    "export_format": "",
    "preferred_lms": "",
    "auto_advance_pipeline": false
  }
}
```

### Per-section item shapes

These document the **shape of array elements and dictionary values** that the canonical schema leaves as `[]` or `{}`. Skills should produce items in these shapes; downstream skills can rely on them.

**`learning_objectives.alignment_matrix.ilo_to_activity`** — keyed by ILO id, values are arrays of activity names:
```json
{ "ILO-1": ["Module 1 case study", "Discussion 2"], "ILO-2": [] }
```

**`learning_objectives.alignment_matrix.ilo_to_assessment`** — same shape, values are arrays of assessment titles.

**`learning_objectives.alignment_matrix.gaps[]`** — each item:
```json
{
  "ilo": "ILO-1",
  "type": "untested|orphaned|underspecified|bloom_mismatch",
  "description": "ILO-1 has no matching assessment in the active modules.",
  "severity": "critical|warning|info"
}
```

**`learning_objectives.ilos[]`** — each item:
```json
{
  "id": "ILO-1",
  "statement": "Analyze competitive forces in...",
  "blooms_level": "analyze",
  "blooms_confidence": "high|medium|low"
}
```

**`assessments.items[]`** — each item:
```json
{
  "id": "A-1",
  "type": "quiz|discussion|rubric|peer_review|gate|...",
  "title": "Module 1 Quiz",
  "weight": 5,
  "ilos_measured": ["ILO-1", "ILO-3"],
  "rubric_present": true,
  "elaborated_feedback": false,
  "alignment_status": "weak|moderate|strong"
}
```

**`assessments.rubrics[]`** — each item:
```json
{
  "id": "rubric-1",
  "title": "SM Project Rubric",
  "criteria": [{"name": "...", "blooms_level": "...", "weight": 0}],
  "applies_to": ["A-3"]
}
```

**`import_metadata.quality_flag_details[]`** — each item (replaces the legacy `_import_quality_flags` root field that sometimes appeared in the wild):
```json
{
  "key": "orphan_module_8",
  "description": "Module 8 wiki content exists in the cartridge but is not referenced in <organizations>.",
  "severity": "warning|critical|info",
  "evidence": "Optional citation tag, e.g. [Alignment-1] [T5]"
}
```

**`red_team_audit.dimensions.<name>.findings[]`** — each item (matches the `<dimension>-<n>` id convention from the red-team orchestrator):
```json
{
  "id": "alignment-1",
  "description": "ILO-2 (vision/mission) has no matching assessment.",
  "module": "Module 4",
  "severity": "critical|warning|info"
}
```

**`accessibility_review.wcag_violations[]`** — each item:
```json
{
  "id": "wcag-1",
  "criterion": "1.3.1 Info and Relationships",
  "level": "A|AA|AAA",
  "description": "All cartridge HTML pages lack <h1> elements.",
  "affected": ["page1.html", "page2.html"],
  "severity": "critical|warning|info"
}
```

**`accessibility_review.udl_recommendations[]`** — each item:
```json
{
  "id": "udl-1",
  "principle": "engagement|representation|action_expression",
  "description": "Add transcripts to all videos.",
  "status": "fully_met|partial|not_met"
}
```

**`quality_review.qm_standards.<standard>.findings[]`**, **`quality_review.alignment_audit.findings[]`**, **`quality_review.cross_domain_checks.<check>.flags[]`**, and other findings arrays — each item:
```json
{
  "id": "<dimension>-<n>",
  "description": "...",
  "evidence": "[Domain-N] [TX]",
  "severity": "critical|warning|info"
}
```

### Mode field — design-new vs audit-existing

`needs_analysis.mode`, `assessments.mode`, and `course_content.mode` record which operating mode the corresponding skill ran in. Trigger: `import_metadata.source` ∈ `{cartridge, scorm, canvas-api}` plus the relevant section being non-empty (skill-specific check).

Allowed values per skill:
- `needs_analysis.mode`: `"design-new"` or `"audit-existing"`
- `assessments.mode`: `"Mode 1"`, `"Mode 2"`, or `"Mode 3"` (Mode 1 = full upstream data, Mode 2 = ILOs-from-scratch, Mode 3 = audit existing assessments)
- `course_content.mode`: `"build-new"` or `"gap-fill"`

Empty string means the skill hasn't run yet or didn't record the mode (legacy manifests).

**`assessments.audit_notes[]`** — only populated in Mode 3. Records which audit findings the user chose to act on:
```json
{
  "target_id": "A-3",
  "action": "applied|deferred|declined",
  "description": "Rubric criterion for ILO-2 added: 'Synthesis depth (1-4 scale)'.",
  "reason": "Optional — only meaningful for deferred/declined."
}
```

**`course_content.recommended_generation_targets[]`** — populated in `gap-fill` mode. Lists artifacts upstream skills flagged as missing, with status:
```json
{
  "description": "Discussion rubric for Module 5",
  "source": "red-team:alignment-3 | quality-review:learner_support-2 | user-request",
  "status": "generated|deferred|declined",
  "output_path": "Optional — set when status=generated, points to the generated file."
}
```

## Feedback

Have feedback or a feature request? [Share it here](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed.

---

## Completion: Timeline Logging

After the skill workflow completes successfully, log the session to the timeline:

```bash
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"assessment-design","event":"completed"}'
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
"$_IDSTACK/bin/idstack-learnings-log" '{"skill":"assessment-design","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
