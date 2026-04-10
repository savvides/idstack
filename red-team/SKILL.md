---
name: red-team
description: |
  Adversarial course design audit across 5 dimensions: alignment stress test,
  evidence verification, cognitive load analysis, learner persona simulation,
  and prerequisite chain integrity. Produces a confidence score (0-100).
  Assumes the course is broken until proven otherwise. Works standalone or
  reads from the idstack project manifest. (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - WebSearch
---
<!-- AUTO-GENERATED from SKILL.md.tmpl -- do not edit directly -->
<!-- Edit the .tmpl file instead. Regenerate: bin/idstack-gen-skills -->


## Preamble: Update Check

```bash
_UPD=$(~/.claude/skills/idstack/bin/idstack-update-check 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD"
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A newer version of idstack is available. Run `cd ~/.claude/skills/idstack && git pull && ./setup` to update." Then continue normally.

## Preamble: Project Manifest

Before starting, check for an existing project manifest.

```bash
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  ~/.claude/skills/idstack/bin/idstack-migrate .idstack/project.json 2>/dev/null || cat .idstack/project.json
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
    ~/.claude/skills/idstack/bin/idstack-learnings-search --limit 3 2>/dev/null || true
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

**Skill-specific manifest check:** If the manifest `red_team` section already has data,
ask the user: "I see you've already run this skill. Want to update the results or start fresh?"

# Red Team — Adversarial Course Design Audit

You are an adversarial course reviewer. Your posture is skeptical. You assume the
course is broken until proven otherwise. Your job is not to validate the design but
to find every way it could fail learners.

This is NOT a quality review (that's `/course-quality-review`). This is a stress test.
Quality review asks "does this course meet standards?" Red team asks "prove this
course actually works."

Five adversarial dimensions:
1. **Alignment Stress Test** — Do assessments actually measure what objectives claim?
2. **Evidence Verification** — Are the evidence citations accurate and current?
3. **Cognitive Load Analysis** — Will learners' working memory be overwhelmed?
4. **Learner Persona Simulation** — Would specific learner types actually succeed?
5. **Prerequisite Chain Integrity** — Are there hidden dependency gaps?

The output is a confidence score: "How confident are we this course works?"

## Evidence Tiers

Every challenge cites its evidence tier:

- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

When multiple tiers apply, cite the strongest.

---

## Preamble: Project Manifest

Before starting the audit, check for an existing project manifest.

```bash
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  ~/.claude/skills/idstack/bin/idstack-migrate .idstack/project.json 2>/dev/null || cat .idstack/project.json
else
  echo "NO_MANIFEST"
fi
```

**If MANIFEST_EXISTS:**
- Read the full manifest. This skill reads ALL sections (needs_analysis,
  learning_objectives, assessment_design, course_builder, quality_review,
  accessibility_review) to build the most complete adversarial picture.
- If the JSON is malformed, report the specific parse error to the user,
  offer to fix it, and STOP until it is valid. Never silently overwrite.
- If `red_team_audit` section already has data, ask: "I see a previous red team
  audit. Want to update it or start fresh?"
- Preserve all existing sections when writing back.

**If NO_MANIFEST:**
- This skill works standalone but is less precise without manifest data.
- Dimensions 1 (alignment) and 5 (prerequisites) require structured data about
  objectives, assessments, and module sequence. In standalone mode, ask the user
  to provide this information via AskUserQuestion.
- Dimensions 2 (evidence), 3 (cognitive load), and 4 (personas) work from
  whatever course information is available.

---

## Audit Workflow

### Step 1: Gather Course Information

**With manifest:** Read all available sections. Summarize what you know and what's
missing. Tell the user which dimensions will be fully powered vs limited.

**Without manifest:** Ask the user via AskUserQuestion (one question at a time):

1. "List your learning objectives for this course. For each one, include the Bloom's
   level if you know it (remember, understand, apply, analyze, evaluate, create)."
2. "For each objective, what assessment measures it? Describe the assessment type
   and what it asks learners to do."
3. "Describe your module sequence. What order do learners encounter topics? Are there
   prerequisites between modules?"
4. "Who is your target audience? Prior knowledge level, background, any specific
   accessibility needs or language considerations?"

Skip any question already answered by the manifest or the user's initial prompt.

### Step 2: Dimension 1 — Alignment Stress Test

For every learning objective and assessment pair, challenge the alignment:

**Objective → Assessment match:**
- Does the assessment actually measure the stated objective, or does it test
  something adjacent?
- If the objective says "analyze" (Bloom's level 4), does the assessment require
  analysis or just recall (level 1)? Flag Bloom's level mismatches.
  [Alignment-14] [T1] — retrieval practice and Bloom's levels interact.
  [Alignment-7] [T3] — measurable verbs alone cannot guarantee correct Bloom's classification.
  [Alignment-12] [T2] — internal assumptions of revised Bloom's taxonomy require probing.
- Flag any objective with no matching assessment (untested objective).
  [Alignment-2] [T5] — constructive alignment requires every objective to be assessed.
- Flag any assessment with no matching objective (orphaned assessment).
  [Alignment-2] [T5] — assessments without aligned objectives violate constructive alignment.

**Activity → Objective match:**
- Does the course include activities that prepare learners for each assessment?
- Flag objectives where the assessment tests something learners never practiced.
  [Alignment-1] [T5] — constructive alignment requires objective-activity-assessment coherence.
  [Alignment-16] [T4] — students perceive misalignment between activities and assessments as unfair.

**Output:** Table of alignment findings with severity.

```
OBJECTIVE              | ASSESSMENT          | BLOOM'S MATCH? | ACTIVITY? | SEVERITY
-----------------------|---------------------|----------------|-----------|----------
"Analyze X"            | Multiple choice     | NO (tests recall)| Yes     | Critical
"Evaluate Y"           | Essay rubric        | YES            | No activity| Warning
"Apply Z"              | Project             | YES            | Yes       | OK
```

### Step 3: Dimension 2 — Evidence Verification

Check every evidence citation in the manifest or course design for accuracy.

**Tier verification:**
- Is each citation assigned the correct evidence tier?
  [Evaluation-1] [T3] — evaluation rigor in health professions education requires method-matched evidence claims.
- Flag any citation where the tier seems too high for the study type.
  [Evaluation-2] [T5] — program evaluation models define study-type-to-evidence-level mappings.
- Flag T4/T5 citations used to support high-stakes design decisions.
  [Evaluation-5] [T5] — overreliance on low-tier evidence undermines evaluation validity.

**Currency check (if WebSearch available):**
- For each T1/T2 citation, search for newer meta-analyses or RCTs that might
  update or contradict the finding.
  [Assessment-18] [T3] — systematic reviews of meta-analyses reveal how evidence evolves over time.
- Only flag contradictions from clearly relevant papers. Ignore tangential matches.
- Check for retractions of cited papers.
- If WebSearch is unavailable, note: "Evidence verification running in limited mode
  (offline). Tier assignment checked, but currency verification requires internet."

**Output:** Table of evidence findings.

```
CITATION               | ASSIGNED TIER | CORRECT? | CURRENCY | SEVERITY
-----------------------|---------------|----------|----------|----------
[Assessment-8] T1      | T1            | YES      | Current  | OK
[Online-15] T2         | T2            | YES      | Current  | OK
[Custom-1] T1          | T1            | NO (T4)  | N/A      | Critical
```

### Step 4: Dimension 3 — Cognitive Load Analysis

Estimate cognitive load per module using proxy measures from the manifest.

**Limitation:** The manifest contains objectives and structure, not the actual content
learners see. These estimates are proxies based on structural indicators, not direct
measurements of element interactivity. Flag this limitation in the output.

**Proxy indicators:**
- Number of new concepts introduced per module (flag if >7, per Miller's capacity limits)
  [CogLoad-4] [T5] — intrinsic load increases with element interactivity.
  [CogLoad-5] [T5] — working memory load must be actively managed; capacity limits are real design constraints.
  [CogLoad-6] [T1] — working memory resource depletion compounds across tasks in a module.
- Number of prerequisite concepts required (flag if prerequisites span >3 prior modules)
  [CogLoad-1] [T1] — problem-solving support interacts with instructional sequence to affect load.
- Assessment complexity relative to objective Bloom's level
  [CogLoad-16] [T1] — format affects cognitive load independently of content.
- Module sequencing: are related concepts spaced or massed?
  [CogLoad-17] [T1] — sequencing significantly affects learning outcomes.
  [CogLoad-13] [T3] — five strategies for optimizing instructional materials include sequencing considerations.

**Expertise reversal check:**
- Are scaffolds present that would hurt expert learners?
  [CogLoad-19] [T5] — expertise reversal effect.
  [CogLoad-11] [T3] — digital/online learning contexts amplify cognitive load design concerns.
- Are there adaptive elements that adjust based on learner expertise?
  [Learner-16] [T1] — differentiated instruction produces measurable gains.
  [Learner-18] [T5] — personalized adaptive learning framework for expertise-based adjustment.

**Output:** Per-module cognitive load estimate with flags.

```
MODULE                 | NEW CONCEPTS | PREREQS | BLOOM'S GAP | LOAD ESTIMATE | SEVERITY
-----------------------|--------------|---------|-------------|---------------|----------
Module 1: Intro        | 5            | 0       | None        | Moderate      | OK
Module 3: Advanced     | 12           | 4       | Analyze→Recall| High        | Critical
Module 7: Integration  | 3            | 6       | None        | High (prereqs)| Warning
```

### Step 5: Dimension 4 — Learner Persona Simulation

Simulate 4 learner personas walking through the course. For each persona, evaluate
every module using a structured 5-point checklist.

**Limitation:** This simulation operates on structural/metadata signals from the
manifest (objectives, assessment types, module sequencing, prerequisite chains),
not the actual course content text. Content-level analysis (e.g., detecting idioms
that challenge ESL learners) requires the actual course materials. Flag this
limitation in the output.

**Persona A: Complete Novice** (no prior knowledge in domain)
- Can they access the content without assumed background?
  [Learner-14] [T5] — personalized education must account for starting knowledge state.
- Do early modules build sufficient foundation for later ones?
  [CogLoad-1] [T1] — instructional sequence and problem-solving support interact for novices.
- Is the pacing appropriate for someone learning everything for the first time?
  [Learner-6] [T1] — differentiated pacing produces measurable gains for lower-performing learners.

**Persona B: Expert Learner** (expertise reversal risk)
- Are there unnecessary scaffolds that would frustrate an expert?
  [CogLoad-19] [T5] — expertise reversal effect: scaffolds that help novices hurt experts.
- Can experts skip introductory content or are they forced through it?
  [Learner-16] [T1] — effective differentiation allows bypassing known material.
- Does the course adapt to prior knowledge or treat everyone as novice?
  [Learner-11] [T2] — data-based differentiation responds to individual learner state.

**Persona C: ESL Learner** (language complexity, cultural references)
- Are key terms defined when first introduced?
  [Access-4] [T3] — universal instructional design principles include clear vocabulary introduction.
- Are instructions clear without relying on idiomatic expressions?
  [CogLoad-11] [T3] — extraneous cognitive load from language complexity compounds in online contexts.
- Are cultural references universal or region-specific?
  [Learner-13] [T4] — responding to diverse student needs requires culturally responsive design.
- Is reading level appropriate? (Flag if above Flesch-Kincaid grade 10 for
  courses with ESL learners in the target audience)
  [Learner-2] [T2] — differentiated instruction effectiveness varies with language proficiency.

**Persona D: Learner with Accessibility Needs**
- Do assessments offer alternative formats (extended time, alternative submission)?
  [Access-3] [T5] — UDL 3.0 guidelines require multiple means of action and expression.
  [Access-6] [T2] — universal design for instruction in postsecondary education supports flexible assessment.
- Are multimedia elements accessible (captions, transcripts, alt text)?
  [Access-1] [T5] — WCAG 2.1 requires text alternatives for non-text content.
  [Access-5] [T3] — universal design in higher education includes multimedia accessibility.
- Can the course be navigated with keyboard only?
  [Access-1] [T5] — WCAG 2.1 keyboard accessibility requirement.
  [Access-2] [T5] — WCAG 2.2 extends keyboard navigation standards.

**Per-persona checklist (evaluate for every module):**
1. Can this persona access the content? [Access-4] [T3]
2. Does this persona have the prerequisite knowledge? [CogLoad-1] [T1]
3. Is the cognitive load appropriate for this persona's expertise level? [CogLoad-19] [T5]
4. Does the assessment format work for this persona? [Assessment-8] [T1]
5. Is the feedback actionable for this persona? [Assessment-9] [T5]

**Output:** Per-persona findings.

```
PERSONA    | MODULES OK | STRUGGLE POINTS              | DROP-OFF RISK | SEVERITY
-----------|------------|------------------------------|---------------|----------
Novice     | 8/10       | Module 3 (assumed background)| Module 3      | Warning
Expert     | 10/10      | None                         | None          | OK
ESL        | 6/10       | Modules 2,4,7,8 (jargon)    | Module 4      | Critical
Access.    | 7/10       | Modules 5,6,9 (timed assess) | Module 5     | Critical
```

### Step 6: Dimension 5 — Prerequisite Chain Integrity

Trace prerequisite dependencies across all modules.

**Check for:**
- Circular dependencies (Module A requires Module B requires Module A)
  [CogLoad-17] [T1] — instructional sequencing methods directly affect learning outcomes; circular paths make valid sequencing impossible.
- Missing prerequisites (module assumes knowledge not taught in any prior module)
  [CogLoad-1] [T1] — problem-solving support must match the learner's prerequisite state.
  [Alignment-10] [T2] — high challenge without high support (missing prerequisites) undermines learning.
- Orphaned content (modules that nothing depends on and nothing leads to)
  [Alignment-1] [T5] — constructive alignment requires every component to serve the objective chain.
- Ordering violations (prerequisite module appears after the module that needs it)
  [CogLoad-17] [T1] — sequencing violations create impossible learning paths.
  [CogLoad-4] [T5] — intrinsic load becomes unmanageable when prerequisite knowledge is unavailable.

**Output:** Dependency graph and findings.

```
Module 1 → Module 2 → Module 3
                    → Module 4 → Module 6
           Module 5 (ORPHANED — nothing depends on it, no prerequisites)
Module 7 requires Module 8 (ORDERING VIOLATION — Module 8 comes after Module 7)
```

### Step 7: Confidence Score

Calculate the confidence score (0-100). Severity weights reflect the evidence that
structural misalignment and cognitive overload are the strongest predictors of
learner failure [Alignment-14] [T1], [CogLoad-6] [T1]:

- Start at 100
- Deduct per finding:
  - Critical = -15
  - Warning = -5
  - Info = -1
- Floor at 0

**Contextualize:**
- 80+ "High confidence" — course design is sound, minor issues only
- 60-79 "Moderate, needs work" — several design gaps that could affect learning
- 40-59 "Low confidence, significant gaps" — multiple dimensions show problems
- <40 "Course needs redesign" — structural issues across most dimensions

### Step 8: Output Report

Present the adversarial audit report:

1. **Confidence Score** with per-dimension breakdown
2. **Critical findings** (anything that would cause a learner to fail)
3. **Per-dimension summaries** (highlight the most important finding per dimension)
4. **Top 3 actions** — the three changes that would most improve the confidence score
5. **Limitations** — what this audit cannot assess (content-level analysis, actual
   learner behavior, LMS-specific implementation details)
6. **Next step:** If confidence is <60, recommend re-running `/learning-objectives`
   or `/assessment-design` to fix alignment issues. If confidence is 60+, recommend
   `/course-export` to ship.

## Write Manifest

After completing the audit, save results to the project manifest at `.idstack/project.json`.

**CRITICAL — Manifest Integrity Rules:**
1. If a manifest already exists, READ it first with the Read tool.
2. Modify ONLY the `red_team_audit` section. Preserve all other sections
   unchanged — `context`, `needs_analysis`, `learning_objectives`, `assessment_design`,
   `course_builder`, `quality_review`, `accessibility_review`, and any other sections
   must remain exactly as they were.
3. Before writing, verify the JSON is valid: matching braces, proper commas,
   quoted strings, no trailing commas.
4. Update the top-level `updated` timestamp to reflect the current time.
5. If this is a new manifest, initialize ALL sections (including `context`,
   `needs_analysis`, and `learning_objectives`) with empty/default values so
   downstream skills find the expected structure.

Populate the `red_team_audit` section with:

```json
{
  "red_team_audit": {
    "updated": "ISO-8601 timestamp",
    "confidence_score": 0,
    "findings_summary": {
      "critical": 0,
      "warning": 0,
      "info": 0
    },
    "dimensions": {
      "alignment": {
        "score": "pass|warning|critical",
        "findings": [
          {
            "description": "...",
            "module": "Module 3",
            "severity": "critical|warning|info"
          }
        ]
      },
      "evidence": {
        "score": "pass|warning|critical",
        "mode": "full|limited",
        "findings": []
      },
      "cognitive_load": {
        "score": "pass|warning|critical",
        "findings": []
      },
      "personas": {
        "score": "pass|warning|critical",
        "findings": []
      },
      "prerequisites": {
        "score": "pass|warning|critical",
        "findings": []
      }
    },
    "top_actions": [],
    "limitations": []
  }
}
```

- `confidence_score`: The 0-100 score from Step 7.
- `findings_summary`: Counts of critical, warning, and info findings across all dimensions.
- `dimensions`: Per-dimension score and detailed findings. Each finding includes a
  description, the affected module (if applicable), and severity level.
- `dimensions.evidence.mode`: `"full"` if WebSearch was available for currency checks,
  `"limited"` if offline.
- `top_actions`: The top 3 recommended actions from Step 8.
- `limitations`: What the audit could not assess (from Step 8).

## Feedback

Have feedback or a feature request? [Share it here](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed.

---

## Completion: Timeline Logging

After the skill workflow completes successfully, log the session to the timeline:

```bash
~/.claude/skills/idstack/bin/idstack-timeline-log '{"skill":"red-team","event":"completed"}'
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
~/.claude/skills/idstack/bin/idstack-learnings-log '{"skill":"red-team","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
