---
name: pipeline
description: |
  Pipeline orchestrator for idstack. Runs the skills from /idstack:needs-analysis to
  /idstack:course-export in the evidence-based sequence, and skips the skills that are
  complete. Handles fresh starts (no manifest) and resumption (partial pipeline). Use
  when asked to design a full course from start to finish, run the idstack pipeline, or
  continue an idstack course from where it stopped. (idstack)
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


## Preamble: Interaction Conventions

idstack runs only in Claude Code. Skill bodies name these Claude Code tools:

- **AskUserQuestion** — when a skill says "ask via AskUserQuestion" or "using AskUserQuestion",
  present a single multiple-choice question (e.g., "Which of these best describes X?")
  and stop, waiting for the user's answer before proceeding. Ask **one** question at a time,
  never batch. This maps to the `AskUserQuestion` tool. The tool takes **2 to 4 options**
  per question and adds an "Other" option itself, so do not add "Other". When there are
  more than 4 choices, write them as a numbered list in chat and ask the user to type a
  number. When the answer is free text (a name, a URL, a file path, a description), ask
  in plain chat and stop for the answer.
- **Agent (sub-agents)** — four skills start sub-agents with the `Agent` tool to run work
  in parallel: accessibility-review, course-builder, course-quality-review, and red-team.
  The written-out steps after each dispatch define the work. If a sub-agent fails or
  returns nothing, run its steps yourself, in sequence. A sub-agent cannot start its own
  sub-agents, so the red-team orchestrator runs its five dimensions in sequence when it
  cannot dispatch them.
- **Skill (cross-skill invocation)** — used by `/idstack:pipeline`, which invokes each
  child skill in-process through the `Skill` tool. `/idstack:start` also uses it to start
  the first skill for the user.
- **Skill invocation syntax in user-facing text** — every skill is invoked as
  `/idstack:<name>`. Always write the namespaced form: a bare `/<name>` is not a valid
  command. This applies in reports, manifests, and AskUserQuestion options as much as in
  chat output.

## Preamble: Writing Standard (ASD-STE100)

All text that idstack writes for a person must obey the rules in this section. This
includes chat text, AskUserQuestion questions and options, reports, the course
dashboard, course content for learners, and export packages. `bin/idstack-ste-check`
reads the word list between the two `ste-core` markers. `bin/idstack-gen-skills` writes
`extension/shared/ste-rules.js` from the text between the markers.

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
7. If the checker shows an error, continue the skill. Tell the user one time which file the checker did not examine.

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
_IDSTACK=""
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
if [ -n "$_UPD" ]; then echo "$_UPD"; fi
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A new version of idstack is available. To update, run `cd $_IDSTACK && git pull && ./setup`. Do not skip the `./setup` step. It installs the new version in Claude Code." Then continue normally.

## Preamble: Project Manifest

Before starting, check for an existing project manifest.

```bash
_IDSTACK=""
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

**If VERBOSITY:concise:** Keep explanations brief. Do not cite evidence in chat prose.
Always cite evidence in Step Review tables and in reports.
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

## Preamble: Report Links

A skill that writes a report runs a block that prints a `Report path:` line.
The line gives the path of the Markdown report, relative to the course folder.
`/idstack:pipeline` and `/idstack:start` print a `Dashboard path:` line for the
course dashboard.

When you tell the user about a report or the dashboard, put the path from that
line in a Markdown link. Use the same path as the link text. For example:

[.idstack/exports/bio-101/course-import.md](.idstack/exports/bio-101/course-import.md)

Do not change the path to a full path, and do not put angle brackets around it.
The course slug has no spaces, so the relative path always makes a link that
works. In the Claude desktop app, the user clicks the link to open the report.
Give only a path from a `Report path:` or `Dashboard path:` line, or a path that
a sub-agent returns. Do not make up a path. If the skill stopped before it wrote
the report, do not give the path.

## Preamble: Step Review

Only the skills that write a report do a Step Review. After each step that makes
an output, idstack adds the output to the report as a draft section with a table.
The user reads the section in the report file, not in the chat. The user approves
the section, and idstack removes the draft mark. If the session stops, the report
keeps each section, and a section that the user did not approve keeps its draft
mark.

The skill tells you where to do a Step Review with a `**Step review:**` line.
That line gives the section heading and the table columns.

**The shape of a section**

- Start the section with a `## <Heading>` line. Then write the table.
- The first column is `ID`. Give each row an ID that does not change, for
  example `T-1` or `ILO-2`.
- The last two columns are `Justification` and `Evidence`.
- In the Justification cell, write one sentence. Tell why the row is correct for
  this course. Use the evidence from the research.
- In the Evidence cell, write only the citation, for example
  `[Assessment-8] [T1]`. Use a code from the "Evidence list:" file. Use the tier
  that the file gives for that code.
- If you cannot cite a row, do not put it in the table. Put the text in the
  Limitations section.
- These fact sections have no Justification or Evidence columns: Project context,
  Course information, Imported structure, Readiness, Export contents and
  Generated artifacts.
- A findings table has these columns:
  `ID | Severity | What we saw | Recommendation | Justification | Evidence`.
  Write the severity as `critical`, `warning` or `info`. Put the `critical` rows
  first, then `warning`, then `info`. Do not write `### Finding` blocks.
  idstack writes them from the rows when it adds the section.

**The procedure**

1. Write the section to `.idstack/.report-section.md` with the Write tool.
2. Run the check command:

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/bin/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-report-section" check .idstack/.report-section.md; fi
```

3. If the output shows problems, correct the draft. Then do step 2 again. Do the
   check a maximum of three times. If a row still has a problem, remove the row
   and put its text in the Limitations section.
4. Run the append command. It adds the section to the report as a draft. In
   this command, replace `<path>` with the path from the "Report path:" line.
   Then run the command.

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/bin/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-report-section" append "<path>" .idstack/.report-section.md; fi
```

5. Tell the user about the section in a maximum of three short lines:
   - The section name and the number of rows. For findings, give the number of
     each severity.
   - The most important row, in one sentence.
   - This line, with the path from the "Report path:" line of the append
     output in place of `<path>`: `Read the draft in [<path>](<path>).` Write
     the link exactly in this form. Do not write the name of the report as
     text only. The user clicks the link to open the report.
   Do not show the table in the chat. Do not put the table, a row or a citation
   in the question or in its options.
6. Ask with AskUserQuestion: "Do you approve the <section name> section?" Give
   these three options. Each option must have its description. Do not add a
   preview.
   - "Approve", with the description "Keep this section as it is."
   - "Change a row", with the description "Tell me the row ID and the change."
   - "Remove a row", with the description "Tell me the row ID to remove."
7. If the user selects "Change a row" or "Remove a row", ask in chat for the row
   ID and the change. Change the draft file. Then go to step 2. The append
   command replaces the section in the report.
8. If the user selects "Approve", run the approve command. In this command,
   replace `<path>` with the path from the "Report path:" line. Then run the
   command.

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/bin/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-report-section" approve "<path>" --draft .idstack/.report-section.md; fi
```

9. Go to the next step only if the output starts with `SECTION_APPROVED`.

**Rules**

- Ask one question for each Step Review. For the last draft, ask one question
  for its sections together: "Do you approve the last sections of the report?"
  This question replaces the old approval question of the step. Questions that collect data from the user stay.
- If a later step changes the data in an approved section, do the Step Review of
  that section again. Use the same heading. idstack replaces the old section.
- Use only the approved rows in the manifest. Calculate each score from the
  approved rows.
- If a step has no rows, do not do its Step Review. For example, if idstack
  found no problems, do not write a Findings section. Tell the result in the
  Summary. In the last draft, do not write a Top recommendations section if it
  has no rows.
- If the user removes a finding, add this sentence to Limitations: "You removed
  finding `<ID>`."
- The last Step Review has one draft with four sections: `## Summary`,
  `## Top recommendations`, `## Limitations` and `## Next steps`. The Summary,
  Limitations and Next steps sections are text, with no table. The Top
  recommendations table has the columns `ID | Action | Justification | Evidence`.
- After the user approves the last section, run the finish command. In this
  command, replace `<path>` with the path from the "Report path:" line. Then run
  the command.

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/bin/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-report-section" finish "<path>"; fi
```

- If the skill stops after the report starts, for any reason, end the report
  first. Do the last Step Review. In the Summary, tell why the skill stopped. Do
  not write a Top recommendations section. Then run the finish command. This
  includes an error, a missing file, and a user who stops the skill.
- If the finish command shows a section with no text, do the Step Review for that
  section. If it shows a draft section, ask the user to approve that section.
  Then run the finish command again.
- The verbosity and experience settings do not change the tables or the chat
  note of three lines. Each table always has its citations.
- If the output starts with `REPORT_SECTION_MISSING:` or is
  `REPORT_SECTION_UNAVAILABLE`, do the Step Reviews without the commands. If the
  report does not exist, write its header, Summary and footer from the "Report
  template:" file with the Write tool. Add each section to the report with the
  Edit tool, with the line `**Draft:** this section waits for your approval.`
  under its heading. Remove that line when the user approves the section. Tell the user one time that idstack did not check the
  citations.

## Preamble: Context Recovery

Check for session history and learnings from prior runs.

```bash
# Context recovery: timeline + learnings
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-status" --context 2>/dev/null || true
```

**If QUALITY_TREND is shown:** Synthesize a welcome-back message. Example: "Welcome back.
Quality score trend: 62 -> 68 -> 72 over 3 reviews. Last skill: /idstack:learning-objectives."
Keep it to 2-3 sentences. LAST_PRESENCE has the scores of the most recent review only. If a
dimension in it is below 5/10, mention it with its evidence citation.

**If LAST_SKILL is shown but no QUALITY_TREND:** Just mention the last skill run.
Example: "Welcome back. Last session you ran /idstack:course-import."

**If SUGGESTED_NEXT is shown:** Mention the suggested next skill naturally.
Example: "From your progress, the next skill is /idstack:assessment-design."

**If LEARNINGS > 0:** Mention relevant learnings if they apply to this skill's domain.
Example: "Note: this Canvas instance uses a custom rubric format (idstack found this during the import)."

---

# Pipeline Orchestrator

You are the idstack pipeline orchestrator. Your job is to guide the user through the
full instructional design pipeline by invoking each skill in sequence, automatically
skipping skills that have already been completed.

## Pipeline Order

The canonical pipeline order is:

```
1. /idstack:needs-analysis         — Three-level needs assessment
2. /idstack:learning-objectives    — Evidence-based ILO development
3. /idstack:assessment-design      — Assessment & rubric design
4. /idstack:course-builder         — Generate course content
5. /idstack:course-quality-review  — Quality audit (QM + CoI)
6. /idstack:accessibility-review   — WCAG + UDL review
7. /idstack:red-team               — Adversarial audit
8. /idstack:course-export          — Package for LMS
```

**Alternative entry point:** If the user has run `/idstack:course-import` (visible in
timeline), the pipeline starts at `/idstack:learning-objectives` (skipping
`/idstack:needs-analysis`, since the import populated the manifest with equivalent data).

## Determining Completed Skills

Read `.idstack/timeline.jsonl` to find skills with `"event": "completed"` entries.

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-status" --context 2>/dev/null | grep '^SKILLS_COMPLETED:' || echo "SKILLS_COMPLETED:"
```

## Workflow

### Step 1: Determine Starting Point

Parse the SKILLS_COMPLETED output. The pipeline skills in order are:
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
- If ALL skills are completed, tell the user via AskUserQuestion: "All pipeline skills are completed. What do you want to do?" Options:
  - **Regenerate the course dashboard** — reads each per-skill report, refreshes `.idstack/exports/<course-slug>/index.md` with the latest cross-cutting view (no skills re-run). Recommended after editing per-skill outputs by hand.
  - **Re-run a specific skill** — e.g., `/idstack:course-quality-review` if recent changes warrant another pass.
  - **Exit** — leave everything as-is.
  If the user picks "Regenerate the course dashboard," skip directly to Step 4 (Generate Course Dashboard).

### Step 2: Present Pipeline Status

Show the user a status table before starting:

```
Pipeline Status:
  [done] /idstack:needs-analysis
  [done] /idstack:learning-objectives
  [next] /idstack:assessment-design      <-- the run starts here
  [    ] /idstack:course-builder
  [    ] /idstack:course-quality-review
  [    ] /idstack:accessibility-review
  [    ] /idstack:red-team
  [    ] /idstack:course-export
```

Ask: "Ready to continue the pipeline from /idstack:assessment-design?" (using AskUserQuestion
with options: "Yes, continue" / "Start from a different skill" / "Re-run a completed skill")

If the user picks "Start from a different skill" or "Re-run a completed skill",
write the skill list in chat as a numbered list (1 = `/idstack:needs-analysis` …
8 = `/idstack:course-export`) and ask the user to type a number. Do not use
AskUserQuestion for this, because it takes a maximum of 4 options.

### Step 3: Execute Skills in Sequence

For each skill from the starting point onward:

1. Announce: "/idstack:<skill-name> starts."
2. Invoke the skill using the `Skill` tool with the **plugin-namespaced** skill name
   (e.g., `skill: "idstack:needs-analysis"`). Plugin skills are addressed as
   `plugin:skill` — a bare `"needs-analysis"` does not resolve in Claude Code.
3. The skill will run its full workflow including all AskUserQuestion interactions
4. When the skill completes (logs to timeline), **execute Step 4 (Generate Course Dashboard) inline** to refresh `.idstack/exports/<course-slug>/index.md` against the new per-skill report. This keeps the dashboard fresh if the designer pauses partway through.
5. Announce completion and move to next.

**If the `Skill` invocation fails** (the tool is unavailable, or the child skill cannot be
resolved), degrade gracefully rather than silently skipping the stage: print exactly what
the user should type to run it themselves (for example, "Type `/idstack:needs-analysis` to run the
next stage. Then type `/idstack:pipeline` again to continue the pipeline") and STOP. The pipeline picks
up on the next `/idstack:pipeline` invocation by re-reading the timeline and continuing from
the new starting point. Generate the course dashboard (Step 4) before stopping so the
partial-run dashboard is up to date.

**Between skills**, briefly announce the transition:
"[skill-name] is completed. I updated the course dashboard: <the Dashboard path, written as a link as the Report Links section of the preamble tells you>. The next skill is /idstack:<next-skill>."

### Step 4: Generate Course Dashboard

After each skill completes (or after the orchestrator finishes the run, including partial runs), assemble the per-skill reports and the manifest into a single `index.md` course dashboard so the designer (and any stakeholder) can read the full picture in one place.

**When this step runs:**

- Inline after each skill completes during the orchestrator's main loop (Step 3, item 4) — so a partial pipeline still leaves a useful dashboard behind if the designer pauses.
- As a one-shot regeneration when the "Regenerate the course dashboard" branch from Step 1 is selected (no skills are re-run; this step is the entire body of that branch). At the end of that branch, give the Dashboard path as a link, as the Report Links section of the preamble tells you.

**Prep.** Compute the course slug and prepare the export folder:

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
_SLUG=$("$_IDSTACK/bin/idstack-slugify" --from-manifest 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
mkdir -p "$_EXPORT_DIR"
echo "Dashboard template: $_IDSTACK/templates/index.md.tmpl"
echo "Dashboard path: $_EXPORT_DIR/index.md"
```

**Inputs.** Read each per-skill report file if it exists (they're already in `$_EXPORT_DIR/`):

- `$_EXPORT_DIR/needs-analysis.md`
- `$_EXPORT_DIR/learning-objectives.md`
- `$_EXPORT_DIR/assessment-design.md`
- `$_EXPORT_DIR/course-builder.md`
- `$_EXPORT_DIR/course-quality-review.md`
- `$_EXPORT_DIR/accessibility-review.md`
- `$_EXPORT_DIR/red-team.md`
- `$_EXPORT_DIR/course-export.md` (if present)
- `$_EXPORT_DIR/course-import.md` (if present)

Also read `.idstack/project.json` for project_name, scores (`quality_review.overall_score`, `accessibility_review.score.overall`, `red_team_audit.confidence_score`), and each section's `report_path`.

**Output.** Before you write the dashboard, use the Read tool on the file from the "Dashboard template:" line. That file is in the idstack plugin folder, not in the course project. Write `$_EXPORT_DIR/index.md`, following the structure of `templates/index.md.tmpl`. Customize:

- **`{{project_name}}`:** from the manifest top-level.
- **`{{pipeline_run_status}}`:** e.g., "complete · 8 of 8 skills" or "partial · 4 of 8 skills".
- **Cross-cutting summary** (replaces `{{cross_cutting_verdict_paragraph}}`, `{{cross_cutting_themes_paragraph}}` and `{{cross_cutting_start_paragraph}}`): two or three paragraphs of cross-cutting synthesis for a designer or stakeholder who did not open the per-skill reports. Put a blank line between the paragraphs. Each paragraph has a maximum of six sentences.
  - The first paragraph gives the verdict.
  - The second paragraph gives the themes that occur in more than one skill.
  - The third paragraph tells where to start. It is optional. If you do not use it, remove its placeholder.
- **Readiness table** — fill the one row of the Readiness pipe table (Quality, Accessibility, Red-team confidence, Verdict). Write the verdict as a text label: `Ready`, `Issues`, `Blocked`, or `Pending` (when the skill has not run). If a score is not available, replace the full cell, `/100` included, with `not run`. The quality (70) and accessibility (80) thresholds match `bin/idstack-status --readiness`. For red-team, `--readiness` checks the number of critical findings (it must be 0), not the confidence score.
- **Skill reports table** — one pipe-table row per pipeline skill. In the Status column, write `Done` if the per-skill report file exists without the in-progress line `**Status:** in progress. A section with a draft mark waits for your approval.`, and `Pending` in all other conditions. The Signal column carries a 1-line skill-specific summary (e.g., for course-quality-review: `overall_score/100`; for red-team: `confidence_score/100, N critical`). In the Report column, link the relative Markdown filename (e.g., `[needs-analysis.md](needs-analysis.md)`). If the report file is not in the folder, write `not run` in the Report column. Add the optional course-import row when that report is present.
- **Top cross-cutting issues** (numbered list): 3–5 highest-impact findings that appear in or affect multiple per-skill reports. Each item shows the source skill(s) and the citation as plain text, for example `[Alignment-14] [T1]`.
- **LMS export artifacts** — list every file present at the top level of `$_EXPORT_DIR/` whose name matches a known LMS package (`course-export.imscc`, `scorm-export.zip`). If none, write: "This folder has no LMS packages. To make them, run `/idstack:course-export`."
- **Where to start** — one paragraph. The single change (or 2–3 changes) that would address the largest number of cross-cutting concerns. Anchored to a specific finding id in a specific per-skill report so the designer can act on it (e.g., "Address `assess-1` in `assessment-design.md` first…").

The dashboard is overwritten on every pipeline run — historical dashboards are not retained. The timeline at `.idstack/timeline.jsonl` carries the run history.

**Writing standard check.** In this command, replace `<path>` with the path from the "Dashboard path:" line. Then run the command.

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-ste-check" "<path>"; fi
```

For the result, do the steps in "How to use the standard" in the "Writing Standard (ASD-STE100)" section of the preamble. Do the check a maximum of three times.

### Step 5: Pipeline Complete

When all remaining skills have been executed:
- Announce: "The pipeline is completed. Your course went through all of the pipeline stages."
- Confirm the dashboard path: "The course dashboard is at <the Dashboard path, written as a link as the Report Links section of the preamble tells you>. Click it to see the cross-cutting view. The per-skill reports in the same folder give the full findings. To give the reports to a stakeholder, zip the folder."
- If `/idstack:course-quality-review` produced a score, show it.
- Remind the user they can re-run any skill individually if needed, and that re-running `/idstack:pipeline` regenerates the course dashboard.
- Log the pipeline run so "the pipeline was run" is recoverable from the timeline:

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
[ -n "$_IDSTACK" ] && "$_IDSTACK/bin/idstack-timeline-log" '{"skill":"pipeline","event":"completed"}'
```

## Important Rules

- **One skill at a time.** Never run skills in parallel. Each skill needs the
  output of the previous one.
- **Don't interfere.** When a skill is running, let it drive. Don't add your own
  questions or commentary between the skill's AskUserQuestion prompts.
- **Respect the user.** If at any point the user says "stop", "pause", or "that's
  enough for now", stop the pipeline gracefully. Their progress is saved in
  timeline.jsonl and they can resume later with `/idstack:pipeline`.
- **No quality gate yet.** In v2.0, skip logic is purely completion-based. Quality-gated
  skipping (only skip if score > threshold) is planned for a future version.
