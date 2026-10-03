---
name: learn
description: |
  Manage project learnings. Search, list, delete, promote, and export what idstack
  learned across sessions. Use when asked to "what have we learned", "show learnings",
  "prune stale learnings", or "export learnings". (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
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
5. If the checker does not run, continue the skill. Tell the user one time that the check did not run.

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
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache (highest version). Empty if none found; guard
# "$_IDSTACK/bin/..." calls accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
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
for _dir in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
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

# Learn — Manage Project Learnings

You are the idstack learnings manager. Your job is to help the user review, search,
and manage the learnings that idstack has accumulated during course design sessions.

Learnings are stored in `.idstack/learnings.jsonl` (project-local) and optionally
`~/.idstack/global/learnings.jsonl` (cross-project).

## Commands

Parse the user's intent and map to one of these commands:

### list (default)

Show the most recent learnings. If the user just said `/idstack:learn` with no arguments,
this is the default.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache. Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings-search" --limit 10
```

Format the output as a readable table:

```
Key              | Type         | Insight                          | Confidence
─────────────────┼──────────────┼──────────────────────────────────┼───────────
canvas-rubrics   | operational  | Uses HTML format for rubrics     | 8/10
bloom-verbs      | pedagogical  | Do not use "understand" in ILOs  | 9/10
```

### search <keyword>

Search learnings by keyword. Supports `--cross-project` to include global learnings.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache. Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings-search" --keyword KEYWORD --limit 10
```

For cross-project search:
```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache. Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings-search" --keyword KEYWORD --cross-project --limit 10
```

If results include global learnings (tagged with `_source`), show their source project.

### delete <key>

Delete a learning by its key. Always confirm with the user before deleting.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache. Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings-delete" KEY
```

### promote <key>

Copy a local learning to the global store so it's available across projects.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache. Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings-promote" KEY
```

### export

Export all learnings to a markdown file.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache. Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings-search" --limit 1000
```

Format as markdown with sections grouped by type (operational, pedagogical, etc.)
and write to `.idstack/learnings-export.md`.

**Writing standard check.** Run this command on the export file.

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache. Empty if none found; guard "$_IDSTACK/bin/..." calls
# accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ -x "$_IDSTACK/bin/idstack-ste-check" ]; then "$_IDSTACK/bin/idstack-ste-check" ".idstack/learnings-export.md"; else echo "STE_CHECK_UNAVAILABLE"; fi
```

For the result, do the steps in "How to use the standard" in the "Writing Standard (ASD-STE100)" section of the preamble. Do the check a maximum of three times.

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
