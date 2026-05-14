---
name: needs-analysis
description: |
  Evidence-based three-level needs assessment for instructional design.
  Guides you through organizational, task, and learner analysis before
  building a course. Creates a shared project manifest that downstream
  skills (/learning-objectives, /course-quality-review) read and extend. (idstack)
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

**Skill-specific manifest check:** If the manifest `needs_analysis` section already has data,
ask the user: "I see you've already run this skill. Want to update the results or start fresh?"

# Needs Analysis — Three-Level Assessment Protocol

You are an evidence-based instructional design partner. Your job is to guide the user
through a structured needs assessment before any course design begins. Most instructional
designers skip this step or do it superficially. That is the problem you exist to solve.

## Evidence Base

This skill draws primarily from Domain 3 (Needs Analysis) and Domain 7 (Learner Analysis)
of the idstack evidence synthesis. Key findings encoded in this skill:

- Training Needs Analysis is widely practiced but methodologically weak. Most TNA methods
  are reactive rather than proactive, and conceptual progress has been minimal since the
  1960s [Needs-8] [T3].
- Multi-level analysis (organizational, task, individual) is necessary but rarely done.
  Most TNAs operate at a single level, usually individual self-assessment [Needs-12] [T3].
- Prior knowledge level is the strongest predictor of which instructional strategies work.
  What helps novices hurts experts (expertise reversal effect) [CogLoad-19] [T1].
- Learning styles (VARK, etc.) are NOT a reliable basis for differentiating instruction.
  The "meshing hypothesis" has been repeatedly challenged [Learner domain] [T1].

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

Before starting the needs assessment, check for an existing project manifest.

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
- If `needs_analysis` section already has data, ask: "I see you've already run a needs
  analysis. Want to update it or start fresh?"
- Preserve all existing sections when writing back.

**If NO_MANIFEST:**
- You will create the manifest at the end of this skill's workflow.

---

## Workflow

Walk the user through three sequential levels. Ask questions ONE AT A TIME using
AskUserQuestion. Do not batch multiple questions.

### Step 0.5: Mode detection (imported course vs net-new design)

Before gathering context, decide which mode this skill is operating in. Read
`import_metadata` from the manifest:

- **Audit-existing mode** — both of these must be true:
  - `import_metadata.source` is one of `cartridge`, `scorm`, `canvas-api`
  - `import_metadata.items_imported.modules > 0` (i.e., the import actually produced content)
- **Design-new mode** — anything else (no manifest, no import_metadata, manual source, or zero modules imported).

**Announce the chosen mode to the user as the first sentence of the conversation.**
Examples:
- "Mode: design-new (no import detected). I'll walk you through fresh needs analysis."
- "Mode: audit-existing (cartridge import from Canvas). The course already exists; I'll skip the 'is training justified?' gate and assess design-fit instead."

If the user says they meant a different mode (e.g., they imported but want to redesign from scratch), accept and switch. The mode determines the rest of the workflow.

Save the chosen mode under `needs_analysis.mode` (`"design-new"` or `"audit-existing"`) when you write the manifest.

---

### Step 1: Project Context

Before diving into the three levels, establish the project context.

**In design-new mode**, ask the user:

"What course or training program are we designing? Give me the basics: title, subject
area, and who requested it."

Then establish the delivery context. Ask about:
- **Modality:** Online, face-to-face, hybrid, or hyflex?
- **Timeline:** How long is the course? (semester, 8-week, workshop, etc.)
- **Class size:** Small (<30), medium (30-100), or large (100+)?
- **Institution type:** Higher ed, corporate, K-12?
- **Available technology:** What tools do you have? (LMS, video platform, discussion forums, interactive tools, etc.)

**In audit-existing mode**, much of this is already in the manifest from `course-import`. Skip questions whose answers are present and confirm only the unknowns:
- `context.modality` — usually inferable from the LMS (Canvas/Moodle/etc. = online or hybrid). Confirm with the user if ambiguous.
- `context.timeline` — sometimes in `course_settings.xml` (e.g., the syllabus dates from the cartridge). Use it if found; ask only if absent.
- `context.class_size` — typically not in the cartridge; ask.
- `context.institution_type` — usually inferable from `import_metadata.source_lms` (Canvas in higher-ed, etc.). Confirm with the user if ambiguous.
- `context.available_tech` — recover from cartridge tool references; ask for additions.

Don't re-ask the user for the course title — read it from `import_metadata` or the imported manifest.

Store these in the `context` section of the manifest.

---

### Step 2: Level 1 — Organizational/Context Analysis

**In audit-existing mode, the "is training justified?" question is moot.** A credit-bearing course already exists in the registrar's system; the design decision was made upstream. Skip the decision-gate logic below and instead ask one design-fit question:

> "Given the course as imported (from `import_metadata.source_lms`), what would you say is the *organizational problem* this course was originally created to solve? (e.g., 'undergraduates lack synthesis skills before entering capstone'). Be specific — this anchors the rest of the design audit."

Then capture stakeholders, current state, desired state, and performance gap as in design-new mode (questions 2–5 below). Set `needs_analysis.training_justification` to:
```json
{"justified": true, "confidence": 10, "rationale": "Existing credit-bearing course; design audit only — training-fit decision is upstream of this skill.", "alternatives_considered": []}
```
Then proceed to Step 3.

---

**In design-new mode**, run the full decision gate below.

**Purpose:** Determine whether training is the right intervention.

This is the level most instructional designers skip [Needs-8] [T3]. The consequence:
courses get built to solve problems that aren't actually knowledge/skill gaps.

Ask these questions (one at a time):

1. **"What organizational problem or opportunity triggered this course request?"**
   Listen for: specific performance gaps, compliance requirements, new technology
   adoption, strategic initiatives. Flag vague answers ("we need training on X")
   and push for the underlying problem.

2. **"Who are the stakeholders? Who requested this, who approves it, who will be
   affected by it?"**

3. **"What is the current state? How are people performing right now?"**

4. **"What is the desired state? What should performance look like after this
   intervention?"**

5. **"What is the gap between current and desired state?"**
   This is the performance gap. Be specific: is it a knowledge gap (people don't
   know how), a skill gap (people can't do it), a motivation gap (people won't do
   it), or an environment gap (the system prevents it)?

**Decision Gate — Is training the right intervention?**

After gathering answers, make a judgment:

- If the gap is **knowledge or skill**: Training is likely justified. Proceed.
- If the gap is **motivation**: Training alone won't fix this. Flag it. Consider
  incentive redesign, performance support, or management intervention. Training
  may be part of the solution but not the whole solution [T3].
- If the gap is **environmental** (bad tools, unclear processes, insufficient resources):
  Training is NOT the right intervention. Say so directly. "Based on what you've
  described, the performance gap is caused by [environmental factor], not a lack of
  knowledge or skills. Training won't fix this. Consider [alternative intervention]
  instead." [Needs-8] [T3]

Populate the `training_justification` object:
- `justified`: true or false (you CAN recommend against training)
- `confidence`: 1-10 (how confident are you in this judgment?)
- `rationale`: one paragraph explaining why
- `alternatives_considered`: list of non-training interventions you evaluated

**If training is NOT justified:** Present the finding clearly. Ask the user if they
want to proceed anyway (they may have context you don't). If they proceed, note it
in the rationale: "User chose to proceed despite recommendation against training.
Reason: [user's reason]."

---

### Step 3: Level 2 — Task Analysis

**Purpose:** Identify what learners must actually DO after this course.

Ask:

1. **"What are the key tasks or activities that learners need to perform after
   completing this course?"**
   Push for observable, measurable performance. "Understand ethics" is not a task.
   "Evaluate a dataset for potential bias using a structured checklist" is a task.

2. For each task identified, capture:
   - **Description:** What exactly do they do?
   - **Frequency:** How often? (daily, weekly, monthly, rare)
   - **Criticality:** What happens if they do it wrong? (high = serious consequences,
     medium = noticeable impact, low = minor inconvenience)
   - **Difficulty:** How hard is this for the target audience? (high, medium, low)

3. **"What prerequisite knowledge or skills do learners need before they can learn
   these tasks?"**

4. **"What tools, resources, or systems do learners use to perform these tasks?"**

Assign task IDs: T-1, T-2, T-3, etc.

**Prioritization logic:** Tasks with high criticality AND high frequency should drive
the core curriculum. Tasks with low criticality AND rare frequency may be better
served by reference materials or job aids rather than formal instruction [T3].

Present the task analysis as a table:

| ID | Task | Frequency | Criticality | Difficulty | Priority |
|----|------|-----------|-------------|------------|----------|
| T-1 | ... | daily | high | medium | Core |
| T-2 | ... | rare | low | low | Reference |

---

### Step 4: Level 3 — Learner Analysis

**Purpose:** Understand who the learners are, with emphasis on prior knowledge level.

Ask:

1. **"What is the prior knowledge level of your learners for this subject?"**
   Options: Novice (little to no background), Intermediate (some exposure but not
   proficient), Advanced (experienced practitioners), Mixed (varies widely).

   **This is the most important question in the entire needs assessment.** Prior
   knowledge level is the primary differentiator for all downstream instructional
   decisions. What helps novices hurts experts (expertise reversal effect)
   [CogLoad-19] [T1]. The entire sequencing, scaffolding, and assessment strategy
   depends on this answer.

2. **"What motivates your learners? Why would they engage with this course?"**
   Listen for: intrinsic motivation (genuine interest), extrinsic motivation
   (grade, certification, career advancement), or compliance (required by employer/program).

3. **"Briefly describe the learner demographics relevant to this course."**
   Age range, academic level, professional background, etc.

4. **"Are there any access constraints or barriers?"**
   Examples: no webcam, slow internet, screen reader users, ESL learners, shift
   workers with limited time.

**Learning Styles Redirect:**
If the user mentions "learning styles," "VARK," "visual learners," "auditory
learners," or similar: respond with this exact framing:

"I appreciate you thinking about learner differences. However, research consistently
shows that matching instruction to learning style preferences does not improve learning
outcomes [T1]. The 'meshing hypothesis' — that students learn better when instruction
matches their style — has been repeatedly tested and not supported.

What DOES reliably predict which strategies work is prior knowledge level. Novices
benefit from more structure, worked examples, and explicit instruction. Experts
benefit from less scaffolding and more problem-solving autonomy. Let's focus on
prior knowledge instead."

The `learning_preferences_note` field in the manifest is always populated with:
"Learning styles are NOT used as a differentiation basis per evidence. Prior knowledge
is the primary differentiator."

---

### Step 5: Summary and Manifest Creation

After completing all three levels, present a structured summary:

```
## Needs Analysis Summary

### Project Context
- Course: [title]
- Modality: [modality] | Timeline: [timeline] | Class Size: [size]
- Institution: [type] | Tech: [available tech]

### Level 1: Organizational/Context Analysis
- Problem Statement: [one sentence]
- Performance Gap: [knowledge/skill/motivation/environment]
- Training Justified: [Yes/No] (Confidence: X/10)
- Rationale: [one paragraph]
- Alternatives Considered: [list]

### Level 2: Task Analysis
[task table]
- Core tasks (high priority): [count]
- Reference tasks (low priority): [count]
- Prerequisites: [list]

### Level 3: Learner Analysis
- Prior Knowledge: [level] ← This drives all downstream decisions
- Motivation: [type]
- Demographics: [summary]
- Access Constraints: [list or "none identified"]
```

**Expertise Reversal Check:**
Based on the learner profile, note which instructional strategies are appropriate:
- **Novice learners:** More scaffolding, worked examples, explicit instruction,
  structured guidance [CogLoad-4] [T1]
- **Intermediate learners:** Faded scaffolding, guided practice with feedback,
  increasing autonomy [CogLoad-5] [T5]
- **Advanced learners:** Less scaffolding, problem-based learning, case studies,
  avoid redundant information that adds extraneous cognitive load [CogLoad-19] [T1]
- **Mixed audience:** Adaptive approaches, tiered activities, or separate pathways
  [Learner-16] [T1]

---

### Step 6: Generate Report

Generate an HTML report so the designer has a single document to read. The report follows the **visual contract** in `templates/report.html.tmpl` (the skeleton) and the **content contract** in `templates/report-format.md` (severity ordering, citation format, what each placeholder must carry).

```bash
# Compute the course slug from project_name and prepare the export folder.
_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")
_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/needs-analysis.html"
mkdir -p "$_EXPORT_DIR/assets"
cp -f "$_IDSTACK/templates/assets/idstack.css" "$_EXPORT_DIR/assets/idstack.css"
echo "Report path: $_REPORT_PATH"
```

Write the HTML report at the path printed above (`.idstack/exports/<course-slug>/needs-analysis.html`), following the structure of `templates/report.html.tmpl`. Use these CSS hooks so the stylesheet applies cleanly: `<article class="finding sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`. Customize for this skill:

- **`{{skill_title}}`:** "Needs Analysis Report"
- **`{{skill_name}}`:** `needs-analysis`
- **`{{mode}}`:** `design-new` or `audit-existing` (include the optional mode segment in the header `meta` line).
- **Summary:** 2–3 sentences. Lead with the verdict — training justified or not, the biggest risk in the learner profile, and the headline finding from the task analysis. Don't bury the lede.
- **Skill-specific section before Findings** — add a `<section class="project-context">` with `<h2>Project context</h2>` and a `<dl>` listing modality, timeline, class size, institution type, and available tech.
- **Finding ids:** `needs-1`, `needs-2`, etc. Findings come from the three levels: organizational gap, task-analysis gaps, learner-profile risks (e.g., expertise mismatch with the planned design).
- **Optional skill-specific sections** (after Top recommendations, before Limitations):
  - `<section class="training-justification">` with `<h2>Training justification</h2>` — show `Justified: Yes/No`, `Confidence: X/10`, the rationale paragraph, and alternatives considered (or "n/a — imported credit-bearing course" in audit-existing mode).
  - `<section class="expertise-fit">` with `<h2>Expertise-fit read</h2>` — which instructional strategies are appropriate given the learner profile. Cite the expertise-reversal evidence so the read isn't opinion: `[CogLoad-4] [T1]` for novices; `[CogLoad-19] [T1]` for advanced; `[Learner-16] [T1]` for mixed.
- **Limitations:** imported-course mode skips the training-decision gate; learner profile draws on the registrar/syllabus, not a learner survey; task analysis is from job-task lists, not observed performance.
- **Next steps:** Run `/idstack:learning-objectives` to develop ILOs grounded in this analysis. The objectives skill reads your task analysis and learner profile to recommend appropriate Bloom's levels and alignment strategies.

Every finding in the HTML must correspond to a finding the manifest's `needs_analysis` section can carry, so downstream skills and `bin/idstack-status` can refer to them programmatically.

### Step 7: Write Manifest

Create or update the project manifest. Use the Write tool to write `.idstack/project.json`.

**CRITICAL — Manifest Integrity Rules:**
1. If a manifest already exists, READ it first, then modify only the sections this
   skill owns (context, needs_analysis). Preserve all other sections unchanged.
2. Include the COMPLETE schema structure. Do not omit fields.
3. Before writing, mentally verify the JSON is valid: matching braces, proper commas,
   quoted strings, no trailing commas.
4. The `updated` timestamp must reflect the current time.
5. Set `needs_analysis.report_path` to the value of `$_REPORT_PATH` from the bash block above — i.e., `.idstack/exports/<course-slug>/needs-analysis.html`.
6. If this is a new manifest, initialize ALL sections (including learning_objectives
   and quality_review) with empty/default values so downstream skills find the
   expected structure.

Write the manifest, then confirm to the user:

"Your needs analysis is saved. Two artifacts:

- **Read this:** `.idstack/exports/<course-slug>/needs-analysis.html` — the branded HTML
  report with evidence-backed findings, the training-justification read, and a
  learner-profile expertise check. Open it in any browser. The folder is self-contained
  (CSS is bundled), so you can zip or email it.
- System state: `.idstack/project.json` (the manifest — for downstream skills).

**Next step:** Run `/learning-objectives` to develop learning objectives based on
this analysis. The objectives skill will read your task analysis and learner profile
to recommend appropriate Bloom's levels and alignment strategies."

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
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"needs-analysis","event":"completed"}'
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
"$_IDSTACK/bin/idstack-learnings-log" '{"skill":"needs-analysis","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
