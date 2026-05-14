---
name: red-team
description: |
  Adversarial course design audit across 5 dimensions: alignment stress test,
  evidence verification, cognitive load analysis, learner persona simulation,
  and prerequisite chain integrity. Produces a confidence score (0-100).
  Runs in a clean-context sub-agent so synthesis is unbiased by build history.
  Works standalone or reads from the idstack project manifest. (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - WebSearch
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

**Skill-specific manifest check:** If the manifest `red_team_audit` section already has data,
ask the user: "I see you've already run this skill. Want to update the results or start fresh?"

# Red Team — Adversarial Course Design Audit

This skill audits the course adversarially. It assumes the course is broken until proven otherwise.

It is NOT a quality review (`/idstack:course-quality-review` does that). Quality review asks "does this course meet standards?" Red team asks "prove this course actually works."

Five adversarial dimensions:
1. **Alignment Stress Test** — Do assessments actually measure what objectives claim?
2. **Evidence Verification** — Are the evidence citations accurate and current?
3. **Cognitive Load Analysis** — Will learners' working memory be overwhelmed?
4. **Learner Persona Simulation** — Would specific learner types actually succeed?
5. **Prerequisite Chain Integrity** — Are there hidden dependency gaps?

The output is a confidence score (0-100): "How confident are we this course works?"

## Why a clean-context sub-agent

If the same Claude session helped build the course, it has sunk-cost bias toward its own design choices. Red team work happens in a freshly-spawned sub-agent that has no prior conversation history — only the manifest and course files, which is the same view a real student gets.

The sub-agent (the **orchestrator**) runs the full audit, writes a structured HTML report under `.idstack/exports/<course-slug>/red-team.html`, and returns a short executive summary including the report path. The parent (this skill) then offers to apply fixes in-context, since the parent already knows the course structure and is good at editing.

---

## Workflow

1. **Pre-flight**: confirm scope and focus
2. **Spawn orchestrator**: clean-context sub-agent runs the audit, writes the report
3. **Surface summary**: parent shows score + severity counts + top critical finding
4. **Triage**: ask which severity bucket to address
5. **Apply fixes**: parent edits course files in-context
6. **Update manifest**: parent writes `red_team_audit` section from the report file

No automatic re-verification. If the user wants to confirm fixes hold, they re-run `/idstack:red-team`.

---

### Step 1: Pre-flight

The preamble above already ran the manifest check. Now confirm scope.

**Determine course inputs:**
- If `MANIFEST_EXISTS`: the orchestrator will read all sections (`needs_analysis`, `learning_objectives`, `assessment_design`, `course_builder`, `quality_review`, `accessibility_review`).
- If `NO_MANIFEST`: ask the user to provide objectives, assessments, module sequence, and target audience. Capture answers as a brief block to pass to the orchestrator. Standalone mode reduces precision on Dimensions 1 (alignment) and 5 (prerequisites).

**Ask one focus question** via AskUserQuestion:

> "Any specific angle to red-team, or a full sweep?"

Options:
- **Full sweep (recommended)** — all 5 dimensions at equal depth
- **Assessment gaming** — bias depth toward Dimension 1 (alignment)
- **Cognitive overload** — bias depth toward Dimension 3 (cognitive load)
- **Persona accessibility** — bias depth toward Dimension 4 (personas)
- **Evidence accuracy** — bias depth toward Dimension 2 (evidence)

Save the user's choice as `FOCUS` for the orchestrator brief.

### Step 2: Spawn the red-team orchestrator

Use the **Agent tool** with `subagent_type=general-purpose`. The prompt is the full contents of the `<orchestrator-brief>` block below, with these substitutions performed before invoking:

- `{{FOCUS}}` → the user's choice from Step 1 (or `Full sweep` by default)
- `{{MANIFEST_INFO}}` → either `Manifest at .idstack/project.json — read it directly.` or, in standalone mode, the captured course information from Step 1
- `{{COURSE_FILES_HINT}}` → if the manifest has `course_builder.output_path`, set this to that path; otherwise `Look under ./course/ or ./modules/ for generated course files.`

Then call Agent. Block on its return.

<orchestrator-brief>

You are an adversarial course design auditor. You have NO context from prior sessions. You did not help build this course; you are seeing it fresh. Your job is to find every way it could fail learners — not to validate the design.

This is a stress test, not a quality review. Assume the course is broken until proven otherwise.

**Inputs:**
- {{MANIFEST_INFO}}
- Course files: {{COURSE_FILES_HINT}}
- Focus area: {{FOCUS}}

**Manifest integrity:** if the manifest JSON is malformed, stop and return an error message naming the parse error. Never silently overwrite.

## Evidence Tiers

Every challenge cites its evidence tier:
- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

When multiple tiers apply, cite the strongest.

## Focus handling

If `{{FOCUS}}` is `Full sweep`, audit all 5 dimensions at equal depth.
Otherwise, audit the named dimension at full depth and cover the others at reduced depth (3-5 findings each, no exhaustive matrices).

## Dispatch

If you have access to the **Agent tool**, dispatch the 5 dimensions in parallel as nested sub-agents using the briefs in "Dimension Briefs" below. Wait for all 5 to return, then deduplicate findings.

If you do NOT have Agent access, run the dimensions sequentially using the same briefs.

---

## Dimension Briefs

### Dimension 1 — Alignment Stress Test

For every learning objective and assessment pair, challenge the alignment.

**Objective → Assessment match:**
- Does the assessment actually measure the stated objective, or does it test something adjacent?
- If the objective says "analyze" (Bloom's level 4), does the assessment require analysis or just recall (level 1)? Flag Bloom's level mismatches.
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

### Dimension 2 — Evidence Verification

Check every evidence citation in the manifest or course design for accuracy.

**Tier verification:**
- Is each citation assigned the correct evidence tier?
  [Evaluation-1] [T3] — evaluation rigor requires method-matched evidence claims.
- Flag any citation where the tier seems too high for the study type.
  [Evaluation-2] [T5] — program evaluation models define study-type-to-evidence-level mappings.
- Flag T4/T5 citations used to support high-stakes design decisions.
  [Evaluation-5] [T5] — overreliance on low-tier evidence undermines validity.

**Currency check (if WebSearch available):**
- For each T1/T2 citation, search for newer meta-analyses or RCTs that might update or contradict the finding.
  [Assessment-18] [T3] — systematic reviews of meta-analyses reveal how evidence evolves.
- Only flag contradictions from clearly relevant papers. Ignore tangential matches.
- Check for retractions of cited papers.
- If WebSearch is unavailable, set `mode: limited` in the report and note: "currency verification requires internet."

### Dimension 3 — Cognitive Load Analysis

Estimate cognitive load per module using proxy measures.

**Limitation:** the manifest contains structure, not the actual content learners see. These are proxies based on structural indicators. Note this limitation in the report.

**Proxy indicators:**
- Number of new concepts introduced per module (flag if >7).
  [CogLoad-4] [T5] — intrinsic load increases with element interactivity.
  [CogLoad-5] [T5] — working memory capacity limits are real design constraints.
  [CogLoad-6] [T1] — working memory resource depletion compounds across tasks.
- Number of prerequisite concepts required (flag if prerequisites span >3 prior modules).
  [CogLoad-1] [T1] — problem-solving support interacts with sequence to affect load.
- Assessment complexity relative to objective Bloom's level.
  [CogLoad-16] [T1] — format affects cognitive load independently of content.
- Module sequencing: are related concepts spaced or massed?
  [CogLoad-17] [T1] — sequencing significantly affects learning outcomes.
  [CogLoad-13] [T3] — five strategies for optimizing instructional materials.

**Expertise reversal check:**
- Are scaffolds present that would hurt expert learners?
  [CogLoad-19] [T5] — expertise reversal effect.
  [CogLoad-11] [T3] — digital/online learning amplifies cognitive load concerns.
- Are there adaptive elements that adjust based on learner expertise?
  [Learner-16] [T1] — differentiated instruction produces measurable gains.
  [Learner-18] [T5] — personalized adaptive learning framework.

### Dimension 4 — Learner Persona Simulation

Simulate 4 learner personas walking through the course.

**Limitation:** simulation operates on structural/metadata signals, not actual content text. Content-level analysis (e.g., detecting idioms that challenge ESL learners) requires the actual course materials. Note this in the report.

**Persona A — Complete Novice** (no prior knowledge in domain)
- Can they access the content without assumed background?
  [Learner-14] [T5] — personalized education must account for starting knowledge.
- Do early modules build sufficient foundation for later ones?
  [CogLoad-1] [T1] — instructional sequence and problem-solving support interact for novices.
- Is the pacing appropriate for someone learning everything for the first time?
  [Learner-6] [T1] — differentiated pacing produces measurable gains.

**Persona B — Expert Learner** (expertise reversal risk)
- Are there unnecessary scaffolds that would frustrate an expert?
  [CogLoad-19] [T5] — expertise reversal effect.
- Can experts skip introductory content or are they forced through it?
  [Learner-16] [T1] — effective differentiation allows bypassing known material.
- Does the course adapt to prior knowledge or treat everyone as novice?
  [Learner-11] [T2] — data-based differentiation responds to individual learner state.

**Persona C — ESL Learner** (language complexity, cultural references)
- Are key terms defined when first introduced?
  [Access-4] [T3] — universal instructional design includes clear vocabulary introduction.
- Are instructions clear without idiomatic expressions?
  [CogLoad-11] [T3] — extraneous load from language complexity compounds online.
- Are cultural references universal or region-specific?
  [Learner-13] [T4] — diverse student needs require culturally responsive design.
- Is reading level appropriate? (Flag if above Flesch-Kincaid grade 10 for ESL audiences.)
  [Learner-2] [T2] — differentiated instruction varies with language proficiency.

**Persona D — Learner with Accessibility Needs**
- Do assessments offer alternative formats (extended time, alternative submission)?
  [Access-3] [T5] — UDL 3.0 requires multiple means of action and expression.
  [Access-6] [T2] — universal design for instruction supports flexible assessment.
- Are multimedia elements accessible (captions, transcripts, alt text)?
  [Access-1] [T5] — WCAG 2.1 requires text alternatives for non-text content.
  [Access-5] [T3] — universal design includes multimedia accessibility.
- Can the course be navigated with keyboard only?
  [Access-1] [T5] — WCAG 2.1 keyboard accessibility.
  [Access-2] [T5] — WCAG 2.2 extends keyboard navigation standards.

**Per-persona checklist (evaluate for every module):**
1. Can this persona access the content? [Access-4] [T3]
2. Does this persona have the prerequisite knowledge? [CogLoad-1] [T1]
3. Is the cognitive load appropriate for this persona's expertise level? [CogLoad-19] [T5]
4. Does the assessment format work for this persona? [Assessment-8] [T1]
5. Is the feedback actionable for this persona? [Assessment-9] [T5]

### Dimension 5 — Prerequisite Chain Integrity

Trace prerequisite dependencies across all modules.

**Check for:**
- Circular dependencies (A requires B requires A).
  [CogLoad-17] [T1] — circular paths make valid sequencing impossible.
- Missing prerequisites (module assumes knowledge not taught earlier).
  [CogLoad-1] [T1] — problem-solving support must match prerequisite state.
  [Alignment-10] [T2] — high challenge without high support undermines learning.
- Orphaned content (nothing depends on it, no prerequisites).
  [Alignment-1] [T5] — every component must serve the objective chain.
- Ordering violations (prerequisite module appears after the module that needs it).
  [CogLoad-17] [T1] — sequencing violations create impossible learning paths.
  [CogLoad-4] [T5] — intrinsic load becomes unmanageable when prereqs are unavailable.

---

## Confidence Score

After all dimensions return, compute the confidence score:

- Start at 100
- Deduct per finding:
  - Critical = -15
  - Warning = -5
  - Info = -1
- Floor at 0

Severity weights reflect that structural misalignment and cognitive overload are the strongest predictors of learner failure: [Alignment-14] [T1], [CogLoad-6] [T1].

Contextualize:
- 80+ "High confidence" — minor issues only
- 60-79 "Moderate, needs work" — several design gaps
- 40-59 "Low confidence, significant gaps" — multiple problem dimensions
- <40 "Course needs redesign" — structural issues across most dimensions

---

## Output

The orchestrator emits an HTML report. Follow the **visual contract** in `templates/report.html.tmpl` and the **content contract** in `templates/report-format.md`.

```bash
# Compute the course slug from project_name and prepare the export folder.
_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")
_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/red-team.html"
mkdir -p "$_EXPORT_DIR/assets"
cp -f "$_IDSTACK/templates/assets/idstack.css" "$_EXPORT_DIR/assets/idstack.css"
echo "Report path: $_REPORT_PATH"
```

Write the HTML report at the path printed above (`.idstack/exports/<course-slug>/red-team.html`), following the structure of `templates/report.html.tmpl`. Use these CSS hooks: `<article class="finding sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`. Customize for this skill:

- **`{{skill_title}}`:** "Red Team Audit"
- **`{{skill_name}}`:** `red-team`
- **`{{mode}}`:** `full` or `limited` (include the optional mode segment in the header `meta` line; you may also append `· focus: {{FOCUS}}`).
- **Summary:** 2–3 sentences. Lead with the confidence score (0–100) and the band ("High confidence" / "Moderate, needs work" / "Low confidence, significant gaps" / "Course needs redesign"). Include the optional one-line scoreboard: "Confidence XX/100 · Critical N · Warning N · Info N".
- **Findings** ordered by severity (`sev-critical` → `sev-warning` → `sev-info`) inside a single `<section class="findings">`. Stable ids of the form `<dimension>-<n>` (e.g., `alignment-1`, `cogload-3`) so the parent can reference findings when applying fixes. Each `<article class="finding sev-...">` should include the affected module/objective/assessment in the "What we saw" `<dd>`.
- **Skill-specific section before Findings** — add a `<section class="dimension-summary">` with `<h2>Per-dimension summary</h2>` and an HTML `<table>` with a row for each dimension (Alignment, Evidence, Cognitive Load, Personas, Prerequisites) showing the per-dimension `pass | warning | critical` score and a one-line summary.
- **Top recommendations:** the 3 changes that would most improve the score. Reference finding ids.
- **Limitations:** what this audit could not assess (content-level analysis, actual learner behavior, LMS-specific implementation, etc.).
- **Next steps:** If confidence is <60 after fixes, recommend re-running `/idstack:learning-objectives` or `/idstack:assessment-design`. If 60+, recommend `/idstack:course-export`.

Each finding **must** have a stable id of the form `<dimension>-<n>` (e.g., `alignment-1`, `cogload-3`) so the parent can reference findings when applying fixes.

## Return value

After writing the report, return ONLY a short executive summary (≤200 words) to the parent:
- Confidence score and band ("Moderate, needs work")
- Severity counts
- Top 1 critical finding (one line)
- Path: the value of `$_REPORT_PATH` (e.g., `.idstack/exports/<course-slug>/red-team.html`)

Do NOT return the full report inline. The parent will read the file.

</orchestrator-brief>

### Step 3: Surface the summary

After the orchestrator returns:
1. Read the HTML report file at the path the orchestrator returned (e.g., `.idstack/exports/<course-slug>/red-team.html`). HTML is fine to Read — extract the content sections by tag.
2. Show the user the executive summary in your own words: confidence score, severity counts, top critical finding, and the report path.
3. Mention: "Full HTML report at the path above — open it in any browser for the complete finding list."

### Step 4: Triage — choose fix scope

Ask one AskUserQuestion:

> "Which findings would you like to address?"

Options:
- **Critical only (recommended)** — highest-impact fixes, smallest scope
- **Critical + Warning** — broader cleanup
- **All findings** — including Info; can be a lot
- **Skip — review report manually** — no fixes now; user will read the file themselves

If the user chooses **Skip**, jump straight to Step 6.

### Step 5: Apply fixes in-context

For each finding in the chosen severity bucket, in order of severity:

1. Read the affected course file(s) (module content, assessment definition, manifest section).
2. Propose the fix in 1-2 sentences. State which file and which finding id you're addressing.
3. Apply via Edit.
4. Track the finding id in `fixes_applied`. If you decide a finding is not actionable in-context (e.g., requires re-running `/idstack:assessment-design`), record it in `fixes_deferred` with a one-line reason.

Do not spawn additional sub-agents for fixes. The parent has the relevant context to edit course files directly.

If the user pushes back on any specific fix, mark it deferred and continue.

### Step 6: Update manifest

Save results to `.idstack/project.json` via `bin/idstack-manifest-merge`, which replaces only
the `red_team_audit` section, preserves every other section verbatim, validates JSON, and
atomically updates the top-level `updated` timestamp. Pull the score and findings from
the orchestrator's HTML report at `$_REPORT_PATH` (the report is the source of truth — do
not re-derive from the orchestrator's return summary, which is lossy).

```bash
"$_IDSTACK/bin/idstack-manifest-merge" --section red_team_audit --payload - <<'PAYLOAD'
{
  "updated": "<ISO-8601 timestamp>",
  "confidence_score": 0,
  "focus": "Full sweep",
  "report_path": "<set to the orchestrator-returned path — e.g. .idstack/exports/<course-slug>/red-team.html>",
  "findings_summary": {"critical": 0, "warning": 0, "info": 0},
  "dimensions": {
    "alignment":      {"score": "pass|warning|critical", "findings": []},
    "evidence":       {"score": "pass|warning|critical", "mode": "full|limited", "findings": []},
    "cognitive_load": {"score": "pass|warning|critical", "findings": []},
    "personas":       {"score": "pass|warning|critical", "findings": []},
    "prerequisites":  {"score": "pass|warning|critical", "findings": []}
  },
  "top_actions": [],
  "limitations": [],
  "fixes_applied": [],
  "fixes_deferred": []
}
PAYLOAD
```

Each finding object: `{"id": "alignment-1", "description": "...", "module": "Module 3", "severity": "critical|warning|info"}`.

`fixes_applied[]` — each item: `{"id": "alignment-1", "description": "Optional one-line summary of the change applied"}`.

`fixes_deferred[]` — each item: `{"id": "alignment-3", "reason": "One-line reason — e.g., requires re-running /idstack:assessment-design"}`.

The merge tool exits non-zero (and prints a diagnostic on stderr) if the payload is malformed,
the manifest is corrupt, or the section name is misspelled — never silently overwriting. If
`.idstack/project.json` doesn't exist yet, run `bin/idstack-migrate .idstack/project.json`
first (it creates a fresh canonical manifest).

**Fallback (if `bin/idstack-manifest-merge` is unavailable):** Read the full manifest, modify
only the `red_team_audit` section, Write back. Preserve all other sections verbatim. The
canonical schema for reference is in `templates/manifest-schema.md`.

### Step 7: Final summary to user

Two sentences:
- "Confidence: X/100. Applied N fixes (M deferred). Report at `.idstack/exports/<course-slug>/red-team.html`."
- If confidence is <60 after fixes, recommend re-running `/idstack:learning-objectives` or `/idstack:assessment-design`. If 60+, recommend `/idstack:course-export`.

If the user wants to verify fixes hold, they can re-run `/idstack:red-team` — that's deliberately manual to avoid token costs of automatic re-verification.

## Feedback

Have feedback or a feature request? [Share it here](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed.

---

## Completion: Timeline Logging

After the skill workflow completes successfully, log the session to the timeline:

```bash
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"red-team","event":"completed"}'
```

Include skill-specific fields where available (confidence_score, focus, fixes_applied count). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior, import format issue, course structure pattern), also log it as a learning:

```bash
"$_IDSTACK/bin/idstack-learnings-log" '{"skill":"red-team","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
