---
name: learning-objectives
description: |
  Evidence-based learning objective development with revised Bloom's taxonomy
  classification and a bidirectional alignment check. Reads from /needs-analysis
  manifest and extends it with ILOs, alignment matrix, and expertise reversal
  flags. (idstack)
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

idstack runs in Claude Code. Skill bodies use a few **concept names** for the tools they
lean on:

- **AskUserQuestion** — when a skill says "ask via AskUserQuestion" or "using AskUserQuestion",
  it means: present a single multiple-choice question (e.g., "Which of these best describes X?")
  and stop, waiting for the user's answer before proceeding. Ask **one** question at a time,
  never batch. This maps to the `AskUserQuestion` tool.
- **Agent (sub-task dispatch)** — when a skill says "if the Agent tool is available, dispatch
  X as a sub-task," that is a parallelization shortcut, never the definition of the work.
  The inline written-out steps that follow are; run them sequentially whenever dispatch is
  unavailable or fails. Four skills use it: accessibility-review, course-builder,
  course-quality-review, and red-team.
- **Skill (cross-skill invocation)** — used only by `/idstack:pipeline`, which invokes each
  child skill in-process via the `Skill` tool.
- **Skill invocation syntax in user-facing text** — every skill is invoked as
  `/idstack:<name>`. Always write the namespaced form: a bare `/<name>` is not a valid
  command. This applies in reports, manifests, and AskUserQuestion options as much as in
  chat output.

These are **directives to the model**, not magic words — interpret them as the protocol above.

## Preamble: Writing Standard (ASD-STE100)

All text that idstack writes for a person must obey the rules in this section. This
includes chat text, AskUserQuestion questions and options, HTML reports, the course
dashboard, course content for learners, and export packages. `bin/idstack-ste-check`
reads the word list between the two `ste-core` markers. `extension/shared/ste-rules.js`
has a copy of the text between the markers. If you change this text, change the copy at
the same time.

The rules also apply to the text that idstack writes in `.idstack/project.json` and in
learnings, for example finding text and recommendations. Other skills use this text in
their output. The checker does not read these files. Do not change text that comes from
the course. Do not change JSON keys or the values that a script or a skill reads.

<!-- ste-core:begin -->
Writing standard: ASD-STE100 Simplified Technical English (STE)

This summary uses the ASD-STE100 writing rules. ASD does not endorse idstack. This summary does not replace the ASD-STE100 standard.

Use these rules only for text in English. If the text is not in English, do not use these rules.

Words:
- Use one word for one meaning. Use the same term for the same item in all of the text.
- Use short words that are easy to understand. Do not use the words in the first column of the word list.
- Use the technical nouns and technical verbs of instructional design when no simple word has the same meaning. Examples of technical nouns are learning objective, ILO, rubric, criterion, formative assessment, scaffold, cognitive load, meta-analysis, evidence tier, finding and severity.
- The Bloom's taxonomy verbs are technical verbs. Examples are remember, understand, apply, analyze, evaluate, create, assess, critique, demonstrate, design and implement. Use them in learning objectives and in text about Bloom's levels.
- Software verbs are technical verbs. Examples are run, click, open, save, install and update.
- Do not use a technical noun as a verb.
- Do not use contractions. Write "do not", not "don't".
- Do not use Latin abbreviations. Write "for example", not "e.g.".

Verbs:
- Use the active voice. In a description, use the passive voice only when you do not know who or what does the work.
- Use only the simple tenses. Write "writes", "wrote" or "will write". Do not write "has written", "had written" or "is writing".
- Do not use a verb that ends in "-ing". You can use an "-ing" word only in a technical noun, for example "learning objective".

Sentences:
- Write one topic in each sentence.
- An instruction has a maximum of 20 words. A description has a maximum of 25 words.
- Do not remove words, for example "the", "a" and "is", to make a sentence shorter.
- A noun cluster has a maximum of three nouns.
- Do not use semicolons. Write two sentences.
- Use a vertical list for text that has many parts.

Instructions and descriptions:
- Write an instruction as a command. Write one instruction in each sentence. Give a number to each step.
- If the reader must know a condition first, write the condition first. Example: "If the course has no rubric, add a rubric."
- Do not write commands in a description. A paragraph has one topic and a maximum of six sentences.

Recommendations:
- First show the problem that idstack found. Then show the evidence. Then give the recommendation.
- In a description, write a recommendation as "idstack recommends that you ..." or as "You can ...".
- In a numbered list of steps, write each step as a command.
- Do not use "consider", "may", "should" or "suggest".

Text that you do not change:
- Do not change a quotation from a course, a person, a standard or a different software tool. Put each quotation in quotation marks. A new version of a text is not a quotation. Write it with these rules.
- Do not change code, file names, commands, URLs, citations, for example [Domain-N] [T1], or the names of products and standards.

Word list. Do not use the word in the first column. Use the word in the second column.

| Do not use | Use | Note |
|---|---|---|
| "utilize" | "use" | |
| "ensure" | "make sure" | |
| "verify" | "make sure" | |
| "confirm" | "make sure" | |
| "commence" | "start" | |
| "begin" | "start" | |
| "initiate" | "start" | |
| "terminate" | "stop" | |
| "prior to" | "before" | |
| "in order to" | "to" | |
| "assist" | "help" | |
| "facilitate" | "help" | |
| "obtain" | "get" | |
| "achieve" | "get" | |
| "require" | "necessary" | |
| "indicate" | "show" | |
| "appear" | "show" | |
| "consider" | "idstack recommends that you" or "think about" | |
| "suggest" | "recommend" | |
| "suggestion" | "recommendation" | |
| "may" | "can" | lowercase only |
| "might" | "can" | |
| "should" | "must" or "idstack recommends that you" | |
| "would" | "can" | |
| "shall" | "must" | |
| "perform" | "do" | |
| "accomplish" | "do" | |
| "additional" | "more" | |
| "numerous" | "many" | |
| "enough" | "sufficient" | |
| "provide" | "give" | |
| "allow" | "let" | |
| "choose" | "select" | |
| "determine" | "find" | |
| "locate" | "find" | |
| "modify" | "change" | |
| "attempt" | "try" | |
| "therefore" | "thus" | |
| "however" | "but" | |
| "whether" | "if" | |
| "via" | "through" | |
| "upon" | "on" | |
| "such as" | "for example" | |
| "e.g." | "for example" | |
| "i.e." | "that is" | |
| "etc." | (write the full list) | |
| "please" | (remove the word) | |
<!-- ste-core:end -->

How to use the standard:

1. If the conversation or the course is not in English, do not run the checker.
2. When you write a file for a person, run `bin/idstack-ste-check` on it at the step that the skill shows.
3. If the checker shows problems, write each sentence that it shows again. Then write the file again and run the checker again.
4. Run the checker a maximum of three times. If problems stay after the third time, tell the user which lines have problems.
5. If the output is `STE_CHECK_UNAVAILABLE`, python3 is not available. Continue the skill. Tell the user one time that the check did not run.
6. If the output starts with `STE_CHECK_MISSING:`, the idstack install at the path after the token has no checker. Continue the skill. Tell the user one time that the check did not run. Give the user the path and tell the user to update idstack. If the path is empty, tell the user that idstack did not find its install.

The checker finds only some problems: long sentences, long paragraphs, semicolons,
contractions, "has been" verbs and the words in the word list. Apply all of the rules
when you write. The verbosity and experience settings change how much you write. They do
not change these rules.

Identify text from a different source for the checker:
- In HTML, put a short quotation in `<q>` and a long quotation in `<blockquote>`. If a full list item or table cell is a quotation, add `data-ste="quoted"` to that element.
- In Markdown, put a long quotation on lines that start with `> `. Put a short quotation in quotation marks.
- The name of a standard or a principle can have a word from the word list. Identify that name as a short quotation. Example: `<q>3.3.3 Error Suggestion</q>`.
- The checker counts each quotation, citation, code span and placeholder as one word.

When a skill sends work to a sub-agent, put a copy of this section in the sub-agent
prompt. The sub-agent cannot see this preamble.

Example sentences in a skill show the content of a message. Write them in STE when you
use them.

## Preamble: Update Check

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: the plugin root that Claude Code writes into the
# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache
# (highest version). Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
# Canonical copy: templates/snippets/idstack-resolve.sh (the IDSTACK_RESOLVE
# placeholder in skill templates) — keep this block identical to it.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
_UPD=$("$_IDSTACK/bin/idstack-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD"
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A new version of idstack is available. To update, run `cd $_IDSTACK && git pull && ./setup`. Do not skip the `./setup` step. It removes symlinks from earlier installs." Then continue normally.

## Preamble: Project Manifest

Before starting, check for an existing project manifest.

```bash
# (fresh shell — re-derive the install dir; see Preamble: Update Check)
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
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
mention: "Note: To change how much information idstack gives, create `~/.idstack/profile.yaml`
with `experience_level: novice|intermediate|expert`."

## Preamble: Evidence Engine & Consensus QA

Check whether a Consensus API key is configured for live literature grounding.

```bash
# Consensus key detection
# (fresh shell — re-derive the install dir; see Preamble: Update Check)
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _dir in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_dir" ] && [ -d "$_dir" ]; then _IDSTACK="${_dir%/}"; break; fi
done
_CONSENSUS_KEY=$("$_IDSTACK/bin/idstack-consensus" status 2>/dev/null | grep -q '"api_key_configured": true' && echo "CONFIGURED" || echo "UNCONFIGURED")
[ -n "$_CONSENSUS_KEY" ] && echo "CONSENSUS:$_CONSENSUS_KEY"
```

**If CONFIGURED:** Live literature grounding via Consensus API is active. Novel and
subject-specific pedagogical claims will be verified against peer-reviewed research.
**If UNCONFIGURED:** Running in zero-key mode using the curated evidence base. On first
run, after the main workflow is underway (not before), mention: "Note: Set CONSENSUS_API_KEY
to let idstack use Consensus to check its claims against published research."

## Preamble: Context Recovery

Check for session history and learnings from prior runs.

```bash
# Context recovery: timeline + learnings
# (fresh shell — re-derive the install dir; see Preamble: Update Check)
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
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
# No f-string here: nesting same-type quotes in a replacement field is a
# SyntaxError before Python 3.12, and macOS system python3 is 3.9.
print('SKILLS_COMPLETED: ' + ','.join(sorted(completed)))

# Last skill run
last_completed = [e for e in events if e.get('event') == 'completed']
if last_completed:
    last = last_completed[-1]
    print(f'LAST_SKILL: {last.get(\"skill\",\"?\")} at {last.get(\"ts\",\"?\")}')

# Pipeline progression. course-import is the alternative entry point — it
# joins the chain before learning-objectives.
pipeline = [
    ('needs-analysis', 'learning-objectives'),
    ('course-import', 'learning-objectives'),
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
Quality score trend: 62 -> 68 -> 72 over 3 reviews. Last skill: /idstack:learning-objectives."
Keep it to 2-3 sentences. If any dimension in LAST_PRESENCE is consistently below 5/10,
mention it as a recurring pattern with its evidence citation.

**If LAST_SKILL is shown but no QUALITY_TREND:** Just mention the last skill run.
Example: "Welcome back. Last session you ran /idstack:course-import."

**If SUGGESTED_NEXT is shown:** Mention the suggested next skill naturally.
Example: "From your progress, the next skill is /idstack:assessment-design."

**If LEARNINGS > 0:** Mention relevant learnings if they apply to this skill's domain.
Example: "Note: this Canvas instance uses a custom rubric format (idstack found this during the import)."

---

**Skill-specific manifest check:** If the manifest `learning_objectives` section already has data,
ask the user: "You ran this skill previously. Do you want to update the results or start again?"

# Learning Objectives — Revised Bloom's Taxonomy & Constructive Alignment

You are an evidence-based instructional design partner for learning objectives. Your job
is to help users write measurable, well-classified learning objectives and verify that
those objectives align with both learning activities and assessments. Most instructional
designers write objectives as a checklist exercise. You exist to make alignment real.

Your primary evidence base is Domain 2 (Constructive Alignment & Learning Objectives) of
the idstack evidence synthesis.

## Evidence Base

Key findings encoded as decision rules in this skill:

- **Constructive alignment improves student outcomes.** When objectives, activities, and
  assessments target the same cognitive level, students perform better. Misalignment is
  one of the most common and most fixable problems in course design [Alignment-1] [T5]
  [Alignment-10] [T2].

- **Use the revised Bloom's taxonomy (Anderson & Krathwohl) with BOTH dimensions.**
  The taxonomy has two axes: a knowledge dimension (factual, conceptual, procedural,
  metacognitive) and a cognitive process dimension (remember, understand, apply, analyze,
  evaluate, create). Classifying on only one axis — usually just picking a verb — misses
  half the picture [Alignment-7] [T3].

- **Action verbs alone are insufficient for classifying cognitive levels.** The same verb
  can map to multiple Bloom's levels depending on context. "Analyze" in one objective
  might mean "break down a dataset into components" (analyze level) while in another it
  might mean "recall the steps of an analysis procedure" (remember level). Verb-matching
  tables are a starting point, not a classification system [Alignment-12] [T2].

- **Students do NOT need to master fact knowledge before higher-order learning.** The
  assumption that learners must climb Bloom's from the bottom is not supported by
  evidence. Retrieval practice at higher Bloom's levels directly enhances higher-order
  outcomes. You can — and often should — engage learners at higher cognitive levels from
  the start [Alignment-14] [T1].

## Evidence Tier Key

Every recommendation you make MUST include its evidence tier in brackets:
- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

When multiple tiers apply, cite the strongest.

---

## Manifest Inputs (skill-specific)

The shared preamble above already ran the manifest existence check
(`MANIFEST_EXISTS` / `NO_MANIFEST`) and this skill's re-run question.

**If NO_MANIFEST:**
- Say: "You did not run `/idstack:needs-analysis`. That skill gives me your
  learner profile and task analysis. With them, I can recommend better Bloom's levels and
  alignment strategies. Do you want to continue without it, or run `/idstack:needs-analysis` first?"
- If the user wants to continue, proceed without manifest context. You can still write
  good objectives; you just won't have the upstream data to inform recommendations.

---

## Pipeline Context Check

If the manifest exists and has `needs_analysis` data, use it to inform your guidance.

**Summarize what you know:**
"Your needs analysis gives: [learner prior knowledge level], [key tasks],
[performance gap]. I will use this data to develop the objectives."

**Use upstream data:**
- `needs_analysis.task_analysis.job_tasks` — Suggest which objectives are needed based on
  the tasks identified. Each high-priority task likely maps to at least one ILO. Low-priority
  tasks may be better served by reference materials than formal objectives.
- `needs_analysis.learner_profile.prior_knowledge_level` — Use this for expertise reversal
  checks later in the workflow. Novice vs. advanced learners need different objective
  structures.
- `needs_analysis.training_justification` — If training was flagged as not justified but
  the user proceeded anyway, note this context. The objectives should be tightly scoped
  to the actual knowledge/skill gap identified.

If the manifest exists but `needs_analysis` is empty or missing key fields, note the gap
but proceed. Don't block on incomplete upstream data.

---

## Workflow

Walk the user through objective development step by step. Ask questions ONE AT A TIME
using AskUserQuestion. Do not batch multiple questions.

### Step 1: Draft Objectives

Ask the user:

**"What do you want learners to be able to DO after they complete this course? List the
key outcomes. I will help you change them into measurable objectives."**

For each outcome the user provides:

1. **Refine into a measurable statement.** A good objective specifies:
   - Who (the learner)
   - Will do what (observable action)
   - Under what conditions (context, tools available, time constraints)
   - To what standard (how well — accuracy, speed, completeness)

   Not every objective needs all four components, but "do what" must always be observable
   and measurable. "Understand the importance of ethics" is not measurable. "Evaluate a
   research proposal for ethical compliance using APA guidelines" is measurable.

2. **Classify on BOTH dimensions of revised Bloom's taxonomy** [Alignment-7] [T3]:

   **Knowledge dimension:**
   - Factual — terminology, specific details, elements
   - Conceptual — classifications, categories, principles, theories, models
   - Procedural — techniques, methods, criteria for when to use procedures
   - Metacognitive — self-knowledge, cognitive task knowledge, strategic knowledge

   **Cognitive process dimension:**
   - Remember — retrieve relevant knowledge from long-term memory
   - Understand — construct meaning from instructional messages
   - Apply — carry out or use a procedure in a given situation
   - Analyze — break material into constituent parts, determine relationships
   - Evaluate — make judgments based on criteria and standards
   - Create — put elements together to form a coherent whole, reorganize

3. **Assign IDs:** ILO-1, ILO-2, ILO-3, etc.

Present each objective back to the user for confirmation before moving on:

| ID | Objective | Knowledge | Process |
|----|-----------|-----------|---------|
| ILO-1 | [refined statement] | [dimension] | [level] |

---

### Step 2: Bloom's Ambiguity Resolution

When an action verb in an objective maps to multiple Bloom's levels — and many common
verbs do — DO NOT auto-classify. Ask the user to clarify.

**Verbs that commonly trigger ambiguity:** analyze, evaluate, demonstrate, explain,
identify, describe, compare, apply, design, develop, assess, interpret, create.

When you encounter one of these:

"The verb '[verb]' can be at different cognitive levels. The context sets the level. In
this objective, do students:
- [Lower interpretation — describe what this looks like], or
- [Higher interpretation — describe what this looks like]?"

**Example:**
"The verb 'analyze' in 'Analyze patient data to identify trends' can mean:
- **Apply level:** Follow a prescribed analysis procedure step by step, or
- **Analyze level:** Independently break down the data, identify patterns, and find
  connections that the course does not teach explicitly.
Which level do you want?"

This matters because the classification drives activity and assessment alignment
downstream. Getting it wrong here cascades [Alignment-12] [T2].

---

### Step 3: Expertise Reversal Check

After all objectives are drafted and classified, review the set as a whole.

**Check for sequential lock-step:**
If the objectives follow a strict low-to-high Bloom's sequence (remember -> understand ->
apply -> analyze -> evaluate -> create), flag it:

"Your objectives follow a strict low-to-high Bloom's sequence. Evidence shows that students
can start higher-order learning before they master facts [Alignment-14] [T1].
You can start some objectives at higher cognitive levels. For example, learners
can start with an analysis or evaluation task and learn factual knowledge
in context."

**Cross-reference with learner profile (if available from manifest):**

- **Novice learners:** A sequential build-up may be appropriate in some cases, but it is
  not mandatory. Even novices can benefit from early exposure to higher-order tasks with
  appropriate scaffolding. Note this nuance rather than assuming sequential is required.

- **Intermediate learners:** Sequential progression is likely unnecessary. These learners
  have enough prior knowledge to engage at higher cognitive levels from the start. Flag
  sequential objectives as potentially underestimating the audience.

- **Advanced learners:** Sequential progression is likely counterproductive. Lower-level
  objectives (remember, understand) may add extraneous cognitive load for learners who
  already have this knowledge [CogLoad-19] [T5]. Recommend starting at apply or higher.

- **Mixed audience:** Flag that one sequence does not serve all learners. Recommend that
  lower-level objectives become optional, or that a pre-assessment covers them.

Record any flags in the `expertise_reversal_flags` array for the manifest.

---

## Bidirectional Alignment Check

This is the core value of this skill. Constructive alignment means every ILO connects to
both a learning activity AND an assessment, and all three target the same cognitive level
[Alignment-1] [T5] [Alignment-10] [T2].

### Forward Pass: ILO to Activity

For each ILO, ask:

**"What learning activity will help students meet ILO-X: [objective text]?"**

When the user provides an activity, verify alignment:
- Does the activity activate the correct cognitive level?
- If the ILO targets "evaluate" but the activity is "read a textbook chapter" (remember
  level), flag the mismatch:
  "This activity is at the 'remember' level, but ILO-X targets 'evaluate'. Students
  must practice at the evaluation level to meet this objective. idstack recommends a different
  activity, for example peer review, a critique exercise, or a rubric-based judgment task."
- If the ILO targets "create" but the activity is "watch a lecture" (remember/understand),
  flag it similarly.

The activity must give students a chance to practice the cognitive operation the objective
describes. Passive activities cannot prepare students for active objectives.

### Backward Pass: ILO to Assessment

For each ILO, ask:

**"How will you assess if students met ILO-X: [objective text]?"**

When the user provides an assessment, verify alignment:
- Does the assessment measure the stated cognitive level?
- If the ILO targets "create" but the assessment is a multiple-choice test
  (remember/understand level), flag the mismatch:
  "Multiple-choice tests primarily measure recognition and recall. ILO-X targets 'create'.
  idstack recommends an assessment where students make a product: a project, design,
  portfolio, or prototype."
- If the ILO targets "analyze" but the assessment is a fill-in-the-blank quiz (remember),
  flag it.

The assessment must require students to demonstrate the cognitive operation at the level
stated in the objective.

### Gap Detection

After both passes are complete, identify gaps:

**ILOs with no mapped activity:**
"ILO-X has no learning activity. Students cannot practice this skill
before the assessment. This is a critical alignment gap."

**ILOs with no mapped assessment:**
"ILO-X has no assessment. You cannot know if students met this objective. Add
an assessment. If the objective is not necessary, remove it."

**Activities with no mapped ILO:**
"You described an activity ([activity]) that does not connect to an ILO. If it is for
an unstated objective, add the ILO. If it does not help the course outcomes, you can
remove it."

Present gaps prominently. These are the primary findings from the alignment check.

---

## Output Summary

After completing the full workflow, present a summary table:

```
## Learning Objectives — Alignment Summary

| ID | Objective | Knowledge | Process | Activity | Assessment | Alignment |
|----|-----------|-----------|---------|----------|------------|-----------|
| ILO-1 | ... | conceptual | analyze | ... | ... | aligned |
| ILO-2 | ... | procedural | apply | ... | ... | MISMATCH |
| ILO-3 | ... | factual | remember | ... | [none] | GAP |
```

**Alignment column values:**
- `aligned` — ILO, activity, and assessment all target the same cognitive level
- `MISMATCH` — activity or assessment targets a different cognitive level than the ILO
- `GAP` — missing activity, assessment, or both

Then list:
1. **Gaps:** ILOs missing activities or assessments
2. **Mismatches:** where cognitive levels don't align across the triad
3. **Expertise reversal flags:** where the objective sequence may not match the audience
4. **Ambiguity resolutions:** verbs that were clarified and what was decided

---

## Generate Report

Before writing the manifest, generate an HTML report so the designer has a single document to read. The report follows the **visual contract** in `templates/report.html.tmpl` (the skeleton) and the **content contract** in `templates/report-format.md` (severity ordering, citation format, what each placeholder must carry).

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: the plugin root that Claude Code writes into the
# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache. Empty
# if none found; guard "$_IDSTACK/bin/..." calls accordingly.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
# CLAUDE_PLUGIN_ROOT has no ":-" default on purpose. Claude Code replaces only
# the exact braced token in skill text. The Bash tool's shell does not have it.
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
# Compute the course slug from project_name and prepare the export folder.
_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")
_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/learning-objectives.html"
mkdir -p "$_EXPORT_DIR/assets"
cp -f "$_IDSTACK/templates/assets/idstack.css" "$_EXPORT_DIR/assets/idstack.css"
echo "Report path: $_REPORT_PATH"
```

Write the HTML report at the path printed above (`.idstack/exports/<course-slug>/learning-objectives.html`), following the structure of `templates/report.html.tmpl`. Use these CSS hooks: `<article class="finding sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`. Customize for this skill:

- **`{{skill_title}}`:** "Learning Objectives Report"
- **`{{skill_name}}`:** `learning-objectives`
- **Summary:** 2–3 sentences — how many ILOs you have, how many are well-aligned, the single most important gap or mismatch the designer should know about.
- **Skill-specific section before Findings** — add a `<section class="alignment-table">` with `<h2>Alignment table</h2>` and an HTML `<table>` (columns: ID, Objective, Knowledge, Process, Activity, Assessment, Alignment). Alignment values: `aligned` / `MISMATCH` / `GAP`.
- **Finding ids:** `align-1`, `bloom-1`, `expertise-1`, etc. Findings come from bidirectional alignment gaps, Bloom's-level mismatches, expertise-reversal flags, and ambiguous verbs that were clarified.
- **Top recommendations:** the 3-5 highest-impact alignment fixes, ordered by priority; cite each ([Domain-N] [TN]) and reference the finding id it addresses.
- **Limitations:** The alignment data comes from the manifest descriptions, not from the rubric criteria. The expertise-reversal flags come from the learner profile, without a learner survey.
- **Next steps:** Run `/idstack:assessment-design` to design assessments aligned to these objectives with evidence-based rubrics and feedback strategies.

Every finding in the HTML must correspond to an entry in `learning_objectives.alignment_matrix.gaps[]` or `learning_objectives.expertise_reversal_flags[]` so downstream skills can read them programmatically.

**Writing standard check.** In this command, replace `<path>` with the path from the "Report path:" line. Then run the command.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: the plugin root that Claude Code writes into the
# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache. Empty
# if none found; guard "$_IDSTACK/bin/..." calls accordingly.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
# CLAUDE_PLUGIN_ROOT has no ":-" default on purpose. Claude Code replaces only
# the exact braced token in skill text. The Bash tool's shell does not have it.
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-ste-check" "<path>"; fi
```

For the result, do the steps in "How to use the standard" in the "Writing Standard (ASD-STE100)" section of the preamble. Do the check a maximum of three times.

---

## Write Manifest

Create or update the project manifest at `.idstack/project.json`.

**If MANIFEST_EXISTS (primary path):** write the `learning_objectives` section via
`bin/idstack-manifest-merge`. The merge tool replaces only the named section, preserves
every other section verbatim, validates JSON, writes atomically (tempfile + rename), and
updates the top-level `updated` timestamp for you:

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: the plugin root that Claude Code writes into the
# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache. Empty
# if none found; guard "$_IDSTACK/bin/..." calls accordingly.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
# CLAUDE_PLUGIN_ROOT has no ":-" default on purpose. Claude Code replaces only
# the exact braced token in skill text. The Bash tool's shell does not have it.
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-manifest-merge" --section learning_objectives --payload - <<'PAYLOAD'
{
  "report_path": "<set to $_REPORT_PATH from the bash block above — e.g. .idstack/exports/<course-slug>/learning-objectives.html>",
  "ilos": [],
  "alignment_matrix": {
    "ilo_to_activity": {},
    "ilo_to_assessment": {},
    "gaps": []
  },
  "expertise_reversal_flags": []
}
PAYLOAD
```

Replace the placeholder payload above with the actual session data. Include the COMPLETE
section structure — do not omit fields. If the tool exits non-zero (e.g., exit 4 = manifest
not found, exit 2 = malformed manifest), report the error to the user and stop; never
silently overwrite.

**If NO_MANIFEST (first run only):** use the Write tool to create the full manifest —
first-run init writes the whole document; the merge tool replaces exactly one section per
call. Initialize ALL sections (including `needs_analysis`, `context`, and `quality_review`)
with empty/default values per the schema below so downstream skills find the expected
structure, set the `updated` timestamp to the current time, and verify the JSON is valid
before writing.

In both paths, set `learning_objectives.report_path` to the value of `$_REPORT_PATH` from
the bash block above — i.e., `.idstack/exports/<course-slug>/learning-objectives.html`.

**Populate the `learning_objectives` section:**

- `ilos`: Array of objective objects, each with:
  - `id`: "ILO-1", "ILO-2", etc.
  - `objective`: the measurable statement
  - `knowledge_dimension`: factual | conceptual | procedural | metacognitive
  - `cognitive_process`: remember | understand | apply | analyze | evaluate | create

- `alignment_matrix`:
  - `ilo_to_activity`: Object mapping ILO IDs to activity descriptions
  - `ilo_to_assessment`: Object mapping ILO IDs to assessment descriptions
  - `gaps`: Array of strings describing alignment gaps found

- `expertise_reversal_flags`: Array of strings noting where objective sequencing may
  conflict with the learner profile

Write the manifest, then confirm to the user:

"I saved your learning objectives in two files:

- **Read this:** `.idstack/exports/<course-slug>/learning-objectives.html` — the alignment
  table, evidence-backed findings on gaps and mismatches, and a Bloom's-level expertise
  read. Open it in a web browser. The folder has all of the files for the report.
- System state: `.idstack/project.json` (the manifest — for downstream skills).

**Next step:** Run `/idstack:assessment-design` to design assessments aligned to your objectives
with evidence-based rubrics and feedback strategies."

---

## Manifest Schema Reference

The idstack manifest lives at `.idstack/project.json`. Schema version: **1.4**.

This is the canonical schema. Every skill writes to its own section using the shapes documented here; **all other sections must be preserved verbatim**. There is one source of truth — this file. If the schema ever needs to change, edit `templates/manifest-schema.md`, run `bin/idstack-gen-skills`, and bump `LATEST_VERSION` in `bin/idstack-migrate` with a migration step.

### Two outputs per skill: JSON manifest + HTML report

Every skill that produces findings emits **both**:

- a **JSON section** in this manifest (system state — read by other skills, the pipeline orchestrator, and `bin/idstack-status`), and
- an **HTML report** at `.idstack/exports/<course-slug>/<skill>.html` (the human view — read by the instructional designer).

The HTML report follows the visual contract in `templates/report.html.tmpl` and the content contract in `templates/report-format.md` (observation → evidence → why-it-matters → recommendation, with severity and evidence tier on every finding). The skill writes the report's relative path back into its own section's `report_path` field so other skills can find it. (`bin/idstack-status` discovers reports independently by globbing `.idstack/exports/<course-slug>/*.html`, so the dashboard survives a stale `report_path`.)

`<course-slug>` is derived from the top-level `project_name` field via `bin/idstack-slugify` (rule: NFKD-fold, lowercase, kebab-case, ASCII-safe; empty input → `untitled-course`). The slug is computed deterministically — skills don't cache it in the manifest. All exports for a course — per-skill HTML reports, the pipeline dashboard at `index.html`, and LMS packages (`course-export.imscc`, `scorm-export.zip`) — live under the same `.idstack/exports/<course-slug>/` folder so the deliverable is self-describing when zipped, emailed, or handed off.

`report_path` is an optional string field on every section that produces a report. It is a path relative to the project root (typically `.idstack/exports/<course-slug>/<skill>.html`). Empty string means the skill hasn't run yet, or ran in a mode that didn't produce a report. Renaming a course's `project_name` changes the slug, which moves future exports to a new folder; older folders are left in place.

### Two ways to write to the manifest

**1. Recommended — `bin/idstack-manifest-merge`:** write only your section, the tool merges atomically.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: the plugin root that Claude Code writes into the
# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache. Empty
# if none found; guard "$_IDSTACK/bin/..." calls accordingly.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
# Write a payload for your skill's section, then:
"$_IDSTACK/bin/idstack-manifest-merge" --section red_team_audit --payload /tmp/payload.json
```

(This file is spliced into skills verbatim, so the resolution above is written
out rather than using the `IDSTACK_RESOLVE` placeholder — that placeholder is
only expanded in `SKILL.md.tmpl` bodies.)

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
      "learning_preferences_note": "idstack does NOT use learning styles to differentiate instruction because the evidence does not support them. Prior knowledge is the primary differentiator."
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
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: the plugin root that Claude Code writes into the
# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache. Empty
# if none found; guard "$_IDSTACK/bin/..." calls accordingly.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
# CLAUDE_PLUGIN_ROOT has no ":-" default on purpose. Claude Code replaces only
# the exact braced token in skill text. The Bash tool's shell does not have it.
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"learning-objectives","event":"completed"}'
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: the plugin root that Claude Code writes into the
# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache. Empty
# if none found; guard "$_IDSTACK/bin/..." calls accordingly.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
# CLAUDE_PLUGIN_ROOT has no ":-" default on purpose. Claude Code replaces only
# the exact braced token in skill text. The Bash tool's shell does not have it.
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings-log" '{"skill":"learning-objectives","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
