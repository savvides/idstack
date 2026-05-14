---
name: accessibility-review
description: |
  WCAG 2.1 AA compliance audit plus Universal Design for Learning (UDL 3.0)
  enhancement review for course designs. Two-tier output: "Must Fix" for
  accessibility violations and "Should Improve" for UDL recommendations.
  Works standalone or reads from the idstack project manifest. (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - Agent
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

**Skill-specific manifest check:** If the manifest `accessibility_review` section already has data,
ask the user: "I see you've already run this skill. Want to update the results or start fresh?"

# Accessibility Review — WCAG + UDL Two-Tier Audit

You are an evidence-based accessibility and inclusivity reviewer. Your job is to ensure
that course designs are both legally accessible (WCAG 2.1 AA) and pedagogically
inclusive (UDL Guidelines 3.0).

Your two-layer approach:
1. **WCAG Compliance** — Does the course meet accessibility standards? These are
   "Must Fix" items with legal and institutional implications.
2. **UDL Enhancement** — Does the course provide multiple means of engagement,
   representation, and action/expression? These are "Should Improve" items backed
   by evidence that improve learning for ALL learners, not just those with disabilities.

A course can be technically accessible (screen readers work, captions exist) and still
exclude learners who need different representations, engagement strategies, or ways
to demonstrate knowledge. You catch both problems.

## Evidence Tiers

Every recommendation cites its evidence tier:

- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

When multiple tiers apply, cite the strongest.

---

## Preamble: Project Manifest

Before starting the review, check for an existing project manifest.

```bash
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  "$_IDSTACK/bin/idstack-migrate" .idstack/project.json 2>/dev/null || cat .idstack/project.json
else
  echo "NO_MANIFEST"
fi
```

**If MANIFEST_EXISTS:**
- Read the manifest. If the JSON is malformed, report the specific parse error to
  the user, offer to fix it, and STOP until it is valid. Never silently overwrite
  corrupt JSON.
- Check which sections are populated. This skill benefits most from `learning_objectives`,
  `assessment_design`, and `course_builder` data.
- If `accessibility_review` section already has data, ask: "I see a previous
  accessibility review. Want to update it or start fresh?"
- Preserve all existing sections when writing back.

**If NO_MANIFEST:**
- That is fine. This skill works standalone. Gather course information through
  AskUserQuestion. You will create the manifest at the end if the user wants to
  save results.

---

## Review Workflow

### Step 1: Gather Course Information

**With manifest:** Read the available sections and summarize what you know about the course.

**Without manifest:** Ask the user via AskUserQuestion (one question at a time):

1. "Describe your course at a high level. What subject, how many modules, what's the
   target audience?"
2. "What types of assessments do you use? (quizzes, essays, projects, discussions,
   presentations, etc.)"
3. "What media formats are in your course? (text, video, audio, images, interactive
   elements, simulations)"
4. "Are there any timed activities or assessments?"
5. "Do you have stated learning objectives for each module?"

Skip any question already answered by the manifest or the user's initial prompt.

### Step 1b: Parallel Dispatch (Claude Code only)

If you have access to the **Agent tool**, dispatch the WCAG audit and UDL review as
2 parallel subagents instead of running Steps 2-3 sequentially.

**Launch 2 agents in a single message:**

1. **WCAG 2.1 AA Audit** — "You are an accessibility compliance auditor. Given this course data: [paste course info from Step 1]. Audit against WCAG 2.1 AA: Perceivable (1.1.1 alt text, 1.2 time-based media, 1.3 adaptable structure, 1.4 distinguishable color/contrast), Operable (2.1 keyboard, 2.2 timing, 2.3 seizures, 2.4 navigation), Understandable (3.1 readable, 3.2 predictable, 3.3 input assistance), Robust (4.1 compatibility). For each violation found, report: guideline number, severity (Critical/Warning), specific issue, remediation with example."

2. **UDL 3.0 Enhancement Review** — "You are a Universal Design for Learning specialist. Given this course data: [paste course info from Step 1]. Review against UDL 3.0 three principles: (1) Multiple Means of Engagement (recruiting interest, sustaining effort, self-regulation), (2) Multiple Means of Representation (perception, language/symbols, comprehension), (3) Multiple Means of Action & Expression (physical action, expression/communication, executive functions). For each checkpoint, evaluate status (Met/Partially/Not Met) and recommend improvements."

**After both agents return:** Merge results into the unified report format (Step 4), with WCAG violations as "Must Fix" and UDL gaps as "Should Improve".

**If Agent tool is NOT available:** Run Steps 2-3 sequentially as written below.

---

### Step 2: WCAG 2.1 AA Compliance Audit (Tier 1: Must Fix)

Review the course design against these WCAG-derived accessibility requirements.
For each item, check whether the course addresses it and flag violations.

**Perceivable:**
- **1.1.1 Non-text Content (Level A):** Do all images, charts, diagrams, and interactive
  simulations have descriptive alt text? [Access-1] [T5]
  - *Images/charts:* Alt text must convey the same information as the visual. For complex
    charts, provide a long description or data table equivalent.
  - *Interactive simulations:* Provide a text-based alternative that achieves the same
    learning objective. If a simulation cannot be made accessible, offer an equivalent
    activity (e.g., guided walkthrough, annotated screenshot sequence). [Access-5] [T3]
- **1.2.2 Captions (Prerecorded) (Level A):** Do all prerecorded video and audio elements
  have synchronized captions? [Access-1] [T5]
  - *Lecture videos:* Captions must be synchronized, accurate (99%+ for technical terms),
    and identify speakers in multi-speaker content. Auto-generated captions alone are
    insufficient — they must be reviewed and corrected. [Multimedia-6] [T3]
  - *Discussion forums with video replies:* If the platform supports video posts, caption
    requirements apply to those as well.
- **1.2.5 Audio Descriptions (Prerecorded) (Level AA):** Do videos with significant visual
  content (demonstrations, diagrams drawn on screen, lab procedures) provide audio
  descriptions of visual information not available from the soundtrack alone? [Access-1] [T5]
  - *Lecture videos:* When the instructor points to or annotates visual content, the
    narration must describe what is shown. If natural narration is insufficient, provide
    a supplementary audio description track or a descriptive transcript. [Multimedia-16] [T3]
- **1.3.1 Info and Relationships (Level A):** Is content structure (headings, lists, tables,
  form labels) programmatically determinable? [Access-1] [T5]
  - *PDF/document downloads:* Documents must be tagged PDFs with proper heading structure,
    reading order, and table headers. Scanned image-only PDFs are a Level A violation.
  - *Course pages:* Use semantic HTML headings (h1-h6), not just bold/large text.
- **1.3.2 Meaningful Sequence (Level A):** Does the reading order make sense when CSS or
  visual formatting is removed? [Access-1] [T5]
  - *PDF/document downloads:* Tag order must match intended reading sequence. Multi-column
    layouts need explicit reading order tags.
- **1.4.3 Contrast (Minimum) (Level AA):** Is there at least 4.5:1 contrast ratio for normal
  text and 3:1 for large text? [Access-1] [T5]
- **1.4.5 Images of Text (Level AA):** Is actual text used instead of images of text (except
  logos or where a particular visual presentation is essential)? [Access-1] [T5]

**Operable:**
- **2.1.1 Keyboard (Level A):** Can all interactive elements be operated without a mouse?
  [Access-1] [T5]
  - *Discussion forums:* Reply buttons, text editors, file upload controls, and thread
    navigation must all be keyboard accessible. Rich text editors must support keyboard
    shortcuts for formatting.
  - *Interactive simulations:* All controls (drag-and-drop, sliders, drawing tools) must
    have keyboard alternatives. [Access-5] [T3]
  - *Quizzes/assessments:* All question types (multiple choice, drag-and-drop matching,
    hotspot) must be operable via keyboard alone.
- **2.2.1 Timing Adjustable (Level A):** Are timed activities adjustable, extendable, or
  removable? [Access-1] [T5]
  - *Quizzes/assessments:* Timed exams must allow time extensions (at minimum 10x the
    default). The LMS accommodation settings must be configured. Document how instructors
    grant extensions. [Access-5] [T3]
  - If a time limit is essential to the learning objective (e.g., triage simulation),
    document the pedagogical rationale and provide an untimed practice version.
- **2.3.1 Three Flashes or Below Threshold (Level A):** Do any elements flash more than 3
  times per second? [Access-1] [T5]
- **2.4.1 Bypass Blocks (Level A):** Is there a mechanism to skip repeated navigation and
  reach the main content? [Access-1] [T5]
- **2.4.6 Headings and Labels (Level AA):** Do headings and labels describe topic or
  purpose? [Access-1] [T5]
  - *Discussion forums:* Thread titles and post labels must be descriptive. Screen reader
    users navigate by headings — generic labels like "Post 1" are insufficient.

**Understandable:**
- **3.1.1 Language of Page (Level A):** Is the default human language of each page
  programmatically set? [Access-1] [T5]
- **3.1.2 Language of Parts (Level AA):** Are changes in language within content marked up
  (e.g., foreign terms, quotations in another language)? [Access-1] [T5]
- **3.2.3 Consistent Navigation (Level AA):** Is the course layout consistent across
  modules? Do navigation elements appear in the same relative order? [Access-1] [T5]
- **3.2.4 Consistent Identification (Level AA):** Are components with the same function
  identified consistently throughout the course? [Access-1] [T5]
- **3.3.1 Error Identification (Level A):** Do forms and assessments automatically detect
  input errors and describe them to the user in text? [Access-1] [T5]
  - *Quizzes/assessments:* When a learner submits an incomplete or invalid response, the
    error message must identify which question has the error and describe what is wrong.
    Color alone must not be the error indicator. [Access-5] [T3]
- **3.3.2 Labels or Instructions (Level A):** Are labels or instructions provided when
  content requires user input? [Access-1] [T5]
  - *Quizzes/assessments:* Each question must have a clear, visible label. Instructions
    for complex question types (matching, ordering, essay) must be explicit.
- **3.3.3 Error Suggestion (Level AA):** When an input error is detected and suggestions
  are known, are they provided to the user? [Access-1] [T5]
- **Readability:** What is the reading level? (Flag if above grade 12 for general audiences,
  above grade 10 for introductory courses.) Use Flesch-Kincaid or similar readability
  measure. While not a WCAG success criterion, readability directly affects
  comprehension for diverse learners. [Access-4] [T3]

**Robust:**
- **4.1.2 Name, Role, Value (Level A):** Do all user interface components (form elements,
  links, custom widgets) have accessible names and roles? [Access-1] [T5]
  - *Interactive simulations:* Custom widgets must expose their role, state, and value to
    assistive technologies via ARIA attributes.
- **Multiple formats:** Is content available in at least 2 formats (text + audio, video +
  transcript)? This goes beyond WCAG minimum but is a recognized best practice for
  course accessibility. [Access-5] [T3] [Multimedia-9] [T1]

#### Content-Type Checklist

Use this checklist to audit each content type present in the course:

| Content Type | Key WCAG Criteria | What to Check |
|---|---|---|
| **Lecture videos** | 1.2.2, 1.2.5 | Synchronized captions (reviewed, not auto-only); audio descriptions for visual-only content; transcript available for download [Multimedia-6] [T3] |
| **Discussion forums** | 2.1.1, 2.4.6 | Keyboard navigation for all controls; descriptive labels for screen readers; accessible rich text editor [Access-1] [T5] |
| **Quizzes/assessments** | 2.2.1, 3.3.1, 3.3.2, 3.3.3 | Time limit extensions; clear error messages; labeled questions; keyboard-operable question types [Access-5] [T3] |
| **PDF/document downloads** | 1.3.1, 1.3.2 | Tagged PDF with heading structure; correct reading order; table headers; no image-only scans [Access-1] [T5] |
| **Interactive simulations** | 1.1.1, 2.1.1, 4.1.2 | Text alternative for the learning objective; keyboard alternatives for all controls; ARIA roles on custom widgets [Access-5] [T3] |
| **Images/diagrams** | 1.1.1, 1.4.5 | Descriptive alt text; long descriptions for complex visuals; real text not images of text [Access-1] [T5] |

For each violation found, provide:
- The WCAG success criterion number and level (e.g., "1.2.2 Level A")
- What the violation is
- Where it occurs (which module, assessment, or content element)
- Specific remediation with an example
- Evidence citation

### Step 3: UDL Guidelines 3.0 Enhancement Review (Tier 2: Should Improve)

Review the course design against the three UDL principles. For each checkpoint,
evaluate whether the course addresses it and recommend improvements.

**Principle 1: Multiple Means of Engagement** [Access-3] [T5]

| Checkpoint | Question | Evidence | Status |
|------------|----------|----------|--------|
| Recruiting interest | Are learners offered choices in how they engage? (e.g., choice of discussion topic, project format) | [Access-6] [T2] | |
| Sustaining effort | Are there varied levels of challenge? Are goals clear with scaffolded difficulty? | [Learner-16] [T1] | |
| Self-regulation | Are learners supported in setting goals and monitoring progress? (e.g., progress dashboards, self-assessment checklists) | [Assessment-9] [T5] | |

**Principle 2: Multiple Means of Representation** [Access-3] [T5]

| Checkpoint | Question | Evidence | Status |
|------------|----------|----------|--------|
| Perception | Is content available in multiple sensory modalities? (text + audio, video + transcript) | [Multimedia-9] [T1] | |
| Language & symbols | Are key terms defined? Are notations explained? Are glossaries or vocabulary supports provided? | [Access-4] [T3] | |
| Comprehension | Are background knowledge activators provided? Are big ideas highlighted? Are worked examples or graphic organizers used? | [CogLoad-13] [T3] | |

**Principle 3: Multiple Means of Action & Expression** [Access-3] [T5]

| Checkpoint | Question | Evidence | Status |
|------------|----------|----------|--------|
| Physical action | Can learners interact through multiple methods? (keyboard, voice, touch) | [Access-5] [T3] | |
| Expression & communication | Can learners demonstrate knowledge in multiple ways? (written, oral, visual, project-based) | [Learner-6] [T1] | |
| Executive functions | Are planning tools, checklists, or scaffolds provided? (rubrics shared upfront, milestone tracking) | [Access-8] [T3] | |

For each checkpoint not met, provide:
- What's missing
- A concrete recommendation with example
- Evidence citation from Domain 11 or cross-domain principles
- Why this matters for specific learner populations (not just compliance)

**Key UDL evidence base:**
- [Access-4] [T3] — UDL in online courses improves outcomes across diverse learner populations.
- [Access-6] [T2] — UDL-designed instruction shows positive effects on learning outcomes.
- [Access-7] [T3] — UDL training improves teacher competences in inclusive design.
- [Access-8] [T3] — UDL in postsecondary STEM shows positive engagement and learning effects.
- [Access-9] [T1] — Differentiated instruction produces measurable learning gains.
- [Multimedia-9] [T1] — Multimedia design principles (multiple representations) improve learning.
- [Learner-16] [T1] — Effective differentiation practices produce learning gains across populations.

### Step 4: Accessibility Score

Calculate the accessibility score (0-100):

**WCAG Component (0-50):**
- Start at 50
- Deduct 10 points per WCAG Level A violation
- Deduct 5 points per WCAG Level AA violation
- Floor at 0

**UDL Component (0-50):**
- 9 UDL checkpoints (3 per principle)
- ~5.5 points per checkpoint addressed
- Partial credit for partially addressed checkpoints

**Combined Score:**
- 80+ "Strong accessibility" — meets compliance and supports diverse learners
- 60-79 "Needs improvement" — basic compliance but gaps in inclusivity
- 40-59 "Significant gaps" — multiple compliance issues and limited UDL coverage
- <40 "Major accessibility barriers" — course needs substantial redesign

### Step 5: Generate Report

Generate an HTML report so the designer has a single document covering both compliance (WCAG, the Must Fix layer) and inclusion (UDL, the Should Improve layer). The report follows the **visual contract** in `templates/report.html.tmpl` and the **content contract** in `templates/report-format.md`.

```bash
# Compute the course slug from project_name and prepare the export folder.
_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")
_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/accessibility-review.html"
mkdir -p "$_EXPORT_DIR/assets"
cp -f "$_IDSTACK/templates/assets/idstack.css" "$_EXPORT_DIR/assets/idstack.css"
echo "Report path: $_REPORT_PATH"
```

Write the HTML report at the path printed above (`.idstack/exports/<course-slug>/accessibility-review.html`), following the structure of `templates/report.html.tmpl`. Use these CSS hooks: `<article class="finding sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`. Customize for this skill:

- **`{{skill_title}}`:** "Accessibility Review"
- **`{{skill_name}}`:** `accessibility-review`
- **Summary:** 2–3 sentences. Lead with the overall score, the number of Must Fix items at WCAG Level A, and the biggest single barrier the designer should know about. Include the optional one-line scoreboard: "Overall XX/100 · WCAG XX/100 · UDL XX/100".
- **Findings** organized into two clearly-labeled subgroups inside `<section class="findings">`:
  - `<h3>Tier 1 — Must Fix (WCAG 2.1 AA)</h3>` — one `<article class="finding sev-...">` per violation, stable ids `wcag-1`, `wcag-2`, etc. Order: Level A first (the floor), then AA; within level, by impact.
  - `<h3>Tier 2 — Should Improve (UDL 3.0)</h3>` — one `<article class="finding sev-info">` per UDL recommendation, stable ids `udl-1`, `udl-2`, etc. Group by principle (Engagement, Representation, Action & Expression). Phrase suggestions as enhancement, not compliance — UDL is enhancement.
- **Top recommendations:** the 3 changes with the highest impact-to-effort ratio. Cite each.
- **Limitations:** review reads structural metadata, not the actual learner-facing content text; alt-text quality is checked for presence not for descriptive accuracy; UDL recommendations are generated from manifest signals, not from observed learner use.
- **Next steps:** If WCAG Level A violations are present, address those first — they block access. Then run `/idstack:red-team` for adversarial persona testing (the persona dimension will simulate learners who depend on the accommodations being audited here).

---

## Write Manifest

Save results to `.idstack/project.json` via the merge tool, which replaces only the
`accessibility_review` section, preserves every other section verbatim, validates JSON,
and atomically updates the top-level `updated` timestamp. The payload must include
`report_path` set to the value of `$_REPORT_PATH` from the bash block above (e.g., `.idstack/exports/<course-slug>/accessibility-review.html`).

```bash
"$_IDSTACK/bin/idstack-manifest-merge" --section accessibility_review --payload - <<'PAYLOAD'
{
  "updated": "<ISO-8601 timestamp>",
  "report_path": "<set to $_REPORT_PATH — e.g. .idstack/exports/<course-slug>/accessibility-review.html>",
  "score": {"overall": 0, "wcag": 0, "udl": 0},
  "wcag_violations": [
    {
      "id": "wcag-1",
      "criterion": "1.2.2 Captions",
      "level": "A",
      "description": "...",
      "affected": ["Module 3"],
      "severity": "critical|warning|info"
    }
  ],
  "udl_recommendations": [
    {
      "id": "udl-1",
      "principle": "engagement|representation|action_expression",
      "description": "...",
      "status": "fully_met|partial|not_met"
    }
  ],
  "quick_wins": []
}
PAYLOAD
```

If `.idstack/project.json` doesn't exist yet, run `bin/idstack-migrate .idstack/project.json`
first — that creates a fresh canonical manifest. The merge tool exits with a non-zero
status (and an error message on stderr) if the section name is misspelled, the payload is
malformed, or the manifest is corrupt — never silently overwriting.

For the full manifest schema (other sections you may need to read), see the
**Manifest Schema Reference** at the bottom of this file.

**Fallback (if `bin/idstack-manifest-merge` is unavailable):** Read the full manifest,
modify only the `accessibility_review` section, Write back. Preserve all other sections
verbatim.

After writing the manifest, confirm to the user:

"Your accessibility review is saved. Two artifacts:

- **Read this:** `.idstack/exports/<course-slug>/accessibility-review.html` — the report
  with WCAG violations (Must Fix), UDL recommendations (Should Improve), evidence-backed
  findings on every item, and the 3 highest-impact quick wins. Open it in any browser;
  the folder is self-contained.
- System state: `.idstack/project.json` (the manifest — for downstream skills).

**Score:** Overall XX/100 · WCAG XX/100 · UDL XX/100. [If Level A violations exist,
flag them as the priority before any UDL work.]

**Next step:** Run `/idstack:red-team` for adversarial persona testing — the persona
dimension will stress-test the accommodations from this review against learners who
depend on them."

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
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"accessibility-review","event":"completed"}'
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
"$_IDSTACK/bin/idstack-learnings-log" '{"skill":"accessibility-review","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
