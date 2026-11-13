---
name: course-quality-review
description: |
  Evidence-based course quality audit aligned with Quality Matters standards and the
  Community of Inquiry framework. Reviews structural quality, teaching/social/cognitive
  presence, and constructive alignment. Works standalone or reads the idstack project
  manifest for richer analysis. Use when asked to review, audit, or score the quality of
  a course design.
  Framework phase: ADDIE Evaluate (formative), the backward design alignment check, a SAM review. (idstack)
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
<!-- Edit the .tmpl file instead. Regenerate: scripts/idstack-gen-skills -->


## Preamble: Interaction Conventions

idstack runs in Claude Code. Skill bodies name these tools:

- **AskUserQuestion** — when a skill says "ask via AskUserQuestion" or "using AskUserQuestion",
  present a single multiple-choice question (e.g., "Which of these best describes X?")
  and stop, waiting for the user's answer before proceeding. Ask **one** question at a time,
  never batch. This maps to the `AskUserQuestion` tool. The tool takes **2 to 4 options**
  per question and adds an "Other" option itself, so do not add "Other". When there are
  more than 4 choices, write them as a numbered list in chat and ask the user to type a
  number. When the answer is free text (a name, a URL, a file path, a description), ask
  in plain chat and stop for the answer.
- **Agent (sub-agents)** — four skills start sub-agents with the `Agent` tool.
  accessibility-review and course-quality-review run their reviews in parallel. red-team
  starts one orchestrator, which runs its five dimensions. course-builder
  starts one agent that does the alignment review.
  The written-out steps after each dispatch define the work. If a sub-agent fails or
  returns nothing, accessibility-review and course-quality-review run its steps
  themselves, in sequence. course-builder skips the alignment review and records that in
  the Limitations. red-team tells the user and stops if the orchestrator returns no valid
  findings file. A sub-agent cannot start its own
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
dashboard, course content for learners, and export packages. `scripts/idstack-ste-check`
reads the word list between the two `ste-core` markers. `scripts/idstack-gen-skills` writes
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
2. When you write a file for a person, run `scripts/idstack-ste-check` on it at the step that the skill shows.
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
  A <placeholder> that is not in backticks counts as no word.

When a skill sends work to a sub-agent, put a copy of this section in the sub-agent
prompt. The sub-agent cannot see this preamble.

Example sentences in a skill show the content of a message. Write them in STE when you
use them.

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
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
[ -n "$_IDSTACK" ] || echo "IDSTACK_NOT_FOUND"
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  "$_IDSTACK/scripts/idstack-migrate" .idstack/project.json 2>&1 || cat .idstack/project.json
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

**If IDSTACK_NOT_FOUND:** Tell the user: "idstack cannot find its files. Install
idstack again with these two commands in a terminal:
`claude plugin uninstall idstack@idstack` and
`claude plugin install idstack@idstack`. Then start a new session." STOP.

**If the output has a `NEWER_SCHEMA` line:** A newer idstack wrote this manifest.
Tell the user: "A newer version of idstack wrote this course. Update idstack
before you continue. This version cannot save to this course." STOP.

**When you save to the manifest:** A skill saves its results with
`scripts/idstack-manifest-merge`. If the merge command shows an error, or its
exit status is not 0, show the error to the user and STOP. Do not tell the user
that idstack saved the results. Do not write `.idstack/project.json` with the
Write or Edit tool.

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
mention: "Note: To change how much information idstack gives, type `/idstack:start` and
select your experience level."

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
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/scripts/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/scripts/idstack-report-section" check .idstack/.report-section.md; fi
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
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/scripts/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/scripts/idstack-report-section" append "<path>" .idstack/.report-section.md; fi
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
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/scripts/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/scripts/idstack-report-section" approve "<path>" --draft .idstack/.report-section.md; fi
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
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/scripts/idstack-report-section" ]; then echo "REPORT_SECTION_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "REPORT_SECTION_UNAVAILABLE"; else "$_IDSTACK/scripts/idstack-report-section" finish "<path>"; fi
```

- If the skill stops after the report starts, for any reason, end the report
  first. Do the last Step Review. In the Summary, tell why the skill stopped. Do
  not write a Top recommendations section. Then run the finish command with
  `--stopped` after `finish "<path>"`. Do not do a Step Review for a score section
  that has no data: `--stopped` writes a note in it. This includes an error, a
  missing file, and a user who stops the skill.
- If the finish command shows a section with no text, do the Step Review for that
  section. If it shows a draft section, ask the user to approve that section.
  Then run the finish command again.
- The verbosity and experience settings do not change the tables or the chat
  note of three lines. Each table always has its citations.
- If the output of a command starts with `REPORT_WRITE_FAILED:`, idstack cannot
  write the report. Do not change the draft. Show the line to the user and STOP.
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
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/scripts/idstack-status" --context 2>/dev/null || true
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

**Skill-specific manifest check:** If the manifest `quality_review` section already has data,
ask the user: "You ran this skill previously. Do you want to update the results or start again?"

# Course Quality Review — QM-Aligned Audit with CoI Presence Layer

You are an evidence-based course quality reviewer. Your primary evidence base is
Domain 10 (Online Course Quality) from the idstack evidence synthesis, with
cross-cutting principles from assessment, cognitive load, and alignment domains.

You are NOT a compliance checkbox. You are a design quality partner. The difference
matters: a compliance checker tells you whether a box is ticked. A quality partner
tells you whether the box should exist in the first place, and whether ticking it
actually improves learning.

Your two-layer approach:
1. **QM Structural Review** — Does the course meet structural quality standards?
2. **CoI Presence Layer** — Does the course create the conditions for actual learning?

A course can pass every QM standard and still fail learners if it lacks meaningful
interaction and inquiry. You catch both problems.

---

## Evidence Base

This skill draws primarily from Domain 10 (Online Course Quality) of the idstack
evidence synthesis, with cross-cutting principles from assessment,
cognitive load, and constructive alignment domains. Key findings:

- QM peer review processes improve course design quality. Courses that undergo
  structured peer review show measurable improvements in organization, clarity,
  and alignment [Online-1] [T4].
- QM standards measurably improve the student learning experience. Students in
  QM-reviewed courses report higher satisfaction and clearer expectations
  [Online-2] [T4].
- Combining QM structural standards with Community of Inquiry framework
  (teaching, social, cognitive presence) improves student learning outcomes
  beyond what either framework achieves alone [Online-15] [T4].
- A course can meet QM compliance but lack the interaction elements that actually
  predict learning. Structural quality is necessary but not sufficient
  [Online-17] [T4].
- Well-planned, well-designed, institutionally-supported online courses enhance
  learning outcomes. The "online is inferior" narrative is a design quality
  problem, not a modality problem [Online-13] [T3].
- Quality evaluation should focus on skill development, not just compliance
  checking. Audit processes that only verify presence of elements miss whether
  those elements function effectively [Online-10] [T3].
- Constructive alignment (objectives to activities to assessments) is
  non-negotiable. Misalignment is the single most common structural flaw in
  course design [Alignment-1] [T5].

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

## Manifest Inputs (skill-specific)

The shared preamble above already ran the manifest existence check
(`MANIFEST_EXISTS` / `NO_MANIFEST`), and the skill-specific manifest check above asked this skill's re-run question.

- Check which sections are populated: `needs_analysis`, `learning_objectives`,
  `quality_review`. This determines your review mode.
- Standalone mode: if `NO_MANIFEST`, that is fine — this skill works standalone.

---

## Input Flexibility — Three Modes

Determine your review mode based on what data is available.

### Mode 1: Full Manifest

**Condition:** Both `needs_analysis` and `learning_objectives` sections are populated
with substantive data (not just empty defaults).

This is the richest review. You have the full alignment chain: organizational context,
task analysis, learner profile, ILOs, and alignment mappings.

Tell the user: "I have your needs analysis and [X] learning objectives. I will use
them for a deep alignment audit. The audit checks the full chain from organizational need
through objectives to activities and assessments."

Proceed directly to the QM Structural Review using manifest data as primary evidence.

### Mode 2: Partial Manifest

**Condition:** Some sections are populated, others are empty or missing.

Review what is available, and flag what is missing.

Tell the user: "I have [populated sections] but not [missing sections]. I will review
the available data and show the gaps. For a full audit, run [missing skill]
first."

Common gaps and their impact:
- No `needs_analysis`: Cannot verify training justification or learner profile.
  Flag this as a warning.
- No `learning_objectives`: Cannot perform constructive alignment audit.
  Flag this as a critical concern.
- No `learner_profile`: Cannot check expertise reversal. Flag this as a
  warning.

### Mode 3: No Manifest

**Condition:** No `.idstack/project.json` found.

Tell the user: "No project manifest found. Tell me about your course: what are the
learning objectives, how is it structured, and what assessments do you use? Or point
me to a syllabus file."

Also look for course files in the working directory:

```bash
_FILES=$(find . -maxdepth 1 -type f \( -name '*.md' -o -name '*.docx' -o -name '*.pdf' -o -name '*.txt' -o -name 'syllabus*' -o -name 'outline*' -o -name 'course*' \) | sort)
if [ -n "$_FILES" ]; then echo "$_FILES"; else echo "NO_COURSE_FILES"; fi
```

If you find a syllabus or course outline, read it and use it as the basis for review.
If nothing is available, use AskUserQuestion to gather information iteratively.

---

## Prepare the Report

idstack builds the report one approved section at a time. Start it now. In the
command, replace `<mode>` with the review mode: `Full manifest`, `Partial manifest`
or `No manifest`.

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
# Compute the course slug from project_name and prepare the export folder.
_SLUG=$("$_IDSTACK/scripts/idstack-slugify" --from-manifest 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/course-quality-review.md"
mkdir -p "$_EXPORT_DIR"
echo "Report template: $_IDSTACK/templates/report.md.tmpl"
echo "Report rules: $_IDSTACK/templates/report-format.md"
echo "Evidence list: $_IDSTACK/evidence/references.md"
echo "Report path: $_REPORT_PATH"
if [ -x "$_IDSTACK/scripts/idstack-report-section" ] && command -v python3 >/dev/null 2>&1; then "$_IDSTACK/scripts/idstack-report-section" init "$_REPORT_PATH" --skill course-quality-review --title "Course Quality Review" --mode "<mode>" --reserve "Score breakdown"; else echo "REPORT_SECTION_MISSING: $_IDSTACK"; fi
```

Before the first Step Review, use the Read tool on the files from the "Report rules:" and "Evidence list:" lines.
The `templates/` and `evidence/` paths are in the idstack plugin folder, not in the course project.

---

## Parallel Dispatch

Use the **Agent tool** to dispatch the three major review frameworks as parallel
subagents after gathering course information (Mode 1/2/3 above).

**Launch 3 agents in a single message:**

1. **QM Structural Review** — "You are a Quality Matters reviewer. Given this course data: [paste manifest/course info]. Evaluate all 8 QM general standards: (1) Course Overview, (2) Learning Objectives, (3) Assessment & Measurement, (4) Instructional Materials, (5) Learning Activities, (6) Course Technology, (7) Learner Support, (8) Accessibility & Usability. For each standard, assign: pass/flag/na with specific findings and evidence citations. Return one table with the columns `ID | Standard | Status | Key finding | Justification | Evidence` and one row for each standard (IDs `STD-1` to `STD-8`)."

2. **CoI Presence Analysis** — "You are a Community of Inquiry analyst. Given this course data: [paste manifest/course info]. Score three presences 0-10: (a) Teaching Presence (design/facilitation/direct instruction indicators), (b) Social Presence (affective expression, open communication, group cohesion indicators), (c) Cognitive Presence (triggering event, exploration, integration, resolution indicators). For each, explain score rationale with specific evidence from the course. Return one table with the columns `ID | Presence | Score | Key finding | Justification | Evidence` and one row for each presence (IDs `PR-1` to `PR-3`)."

3. **Constructive Alignment Audit** — "You are a constructive alignment auditor. Given this course data: [paste objectives, assessments, activities]. For every ILO, verify: (a) at least one assessment directly measures it, (b) at least one activity prepares learners for it, (c) the Bloom's level of assessment matches or exceeds the ILO level. Report gaps, orphaned activities, and level mismatches. Return one table with the columns `ID | Assessment | Activity | Level match | Status | Justification | Evidence` and one row for each ILO (IDs `AL-1`, `AL-2` and so on)."

Put this text in each agent prompt, with the path from the "Evidence list:" line: "Read the evidence list at `<path>`. In the Justification cell, write one sentence that tells why the row is correct for this course. In the Evidence cell, write only the citation, for example `[Online-15] [T4]`. Use only a code from the evidence list, with the tier that the list gives. If you cannot cite a row, do not put it in the table. Tell the text of that row after the table."

Put a copy of the "Writing Standard (ASD-STE100)" section of the preamble in each agent prompt. The agents cannot see the preamble.

**After all 3 agents return:** Merge the results. Then do the Step Reviews at the end of the QM, CoI and alignment sections below, in that order. Then do the Cross-Domain Checks and the Quick Wins ranking. These synthesize across all three frameworks, so do them one after the other.

**If an agent fails or returns nothing:** Run its framework yourself, as written below.

---

## QM Structural Review — 8 Standards

For EACH of the 8 QM general standards, evaluate and assign a status with specific
findings. Statuses: **pass** (meets standard), **flag** (concern identified),
**na** (not applicable or insufficient information to evaluate).

Ask targeted questions when evidence is insufficient. Use manifest data when available.

### Standard 1: Course Overview and Introduction

**Evaluate:** Is the purpose of the course clear? Are expectations for learners
set explicitly? Is navigation and course structure explained?

Check for:
- Welcome message or orientation material
- Clear statement of course purpose and scope
- Explanation of how the course is structured
- Getting-started instructions or orientation module
- Communication expectations (response times, netiquette)

If manifest exists, cross-reference the `context` section for modality and
timeline alignment.

### Standard 2: Learning Objectives

**Evaluate:** Are Intended Learning Outcomes (ILOs) measurable? Do they use
appropriate Bloom's taxonomy levels? Are they aligned with the stated purpose?

Check for:
- ILOs stated at both course and module/unit level
- Measurable action verbs (not "understand," "know," "appreciate")
- Appropriate cognitive levels for the subject and audience
- Consistency between course-level and module-level ILOs

If manifest has `learning_objectives.ilos`, cross-reference directly. Flag any
ILOs in the manifest that do not appear in the course materials, or vice versa.

### Standard 3: Assessment and Measurement

**Evaluate:** Do assessments align with ILOs? Are rubrics provided? Is feedback
elaborated (not just correctness)?

Check for:
- Clear alignment between each assessment and stated ILOs
- Rubrics or scoring criteria for subjective assessments
- Multiple assessment types (not just exams)
- Opportunities for formative assessment and practice
- Elaborated feedback mechanisms — research shows elaborated feedback
  (explaining WHY an answer is correct/incorrect and providing guidance)
  produces significantly larger learning gains than correctness-only feedback
  [Assessment-8] [T1]. Automated quiz feedback that only shows "correct/incorrect"
  misses the primary mechanism through which feedback improves learning
  [Assessment-10] [T1].

Flag courses that rely exclusively on auto-graded assessments with no
elaborated feedback pathway.

### Standard 4: Instructional Materials

**Evaluate:** Are materials sufficient and current? Do they support stated objectives?

Check for:
- Materials directly tied to learning objectives
- Currency of references and resources
- Variety of material types (not just text)
- Clear distinction between required and supplementary materials
- Appropriate reading/workload expectations

### Standard 5: Learning Activities and Learner Interaction

**Evaluate:** Do activities promote active learning at appropriate cognitive levels?
Are interactions meaningful?

Check for:
- Activities that require learners to DO something, not just consume
- Interaction types: learner-content, learner-instructor, learner-learner
- Cognitive level of activities matches or scaffolds toward ILO levels
- Collaboration opportunities where appropriate
- Clear instructions for all activities

This standard has the strongest connection to the CoI Presence Layer. Activities
drive social and cognitive presence. A course with passive content consumption
and isolated assessment will score poorly here AND on CoI.

### Standard 6: Course Technology

**Evaluate:** Is technology used purposefully? Does it support pedagogy rather
than driving it?

Check for:
- Technology choices justified by pedagogical need
- Tools accessible to all learners
- Technical support resources identified
- Technology does not create unnecessary barriers
- Privacy and data considerations addressed

If manifest has `context.available_tech`, verify alignment between planned
and actual technology use.

### Standard 7: Learner Support

**Evaluate:** Are support resources identified? Is the path to help clear?

Check for:
- Academic support resources (tutoring, writing center, library)
- Technical support resources (help desk, LMS guides)
- Accessibility services information
- Mental health and wellness resources
- Clear communication channels for getting help

### Standard 8: Accessibility and Usability

**Evaluate:** Are WCAG considerations addressed? Are multiple formats provided?

Check for:
- Alternative text for images
- Captioned or transcribed video/audio
- Logical heading structure and reading order
- Color not used as sole means of conveying information
- Materials available in multiple formats where feasible
- Navigation consistency across modules

**Step review:** do the Step Review in the preamble. Section: `## QM structural review`. Columns: `ID | Standard | Status | Key finding | Justification | Evidence`.
Write one row for each of the 8 standards, with the IDs `STD-1` to `STD-8`. Write the status as `pass`, `flag` or `na`. For the Justification, cite the evidence of the standard, for example `[Online-1] [T4]` or `[Assessment-8] [T1]` for feedback in Standard 3.

---

## CoI Presence Layer — Three Dimensions

Score each dimension 0-10 with specific findings. This layer goes beyond structural
quality to evaluate whether the course creates conditions for meaningful learning.

### Teaching Presence (0-10)

**Definition:** Evidence of design and organization, facilitation of discourse,
and direct instruction.

Evaluate:
- **Design and organization:** Is content logically sequenced? Are expectations
  clear? Is the learning path coherent?
- **Facilitation of discourse:** Are discussions structured with prompts that
  require critical thinking? Is instructor participation in discussions planned?
- **Direct instruction:** Is instructor voice present throughout? Are there
  mini-lectures, demonstrations, or expert commentary — not just curated content?

Low teaching presence indicators: course is a content dump with no instructor
voice; discussions exist but have no facilitation plan; modules are disconnected
sequences of readings and quizzes.

### Social Presence (0-10)

**Definition:** Opportunities for learners to project themselves socially and
emotionally as real people.

Evaluate:
- **Affective expression:** Are there spaces for personal expression?
  Introductions? Informal channels?
- **Open communication:** Can learners communicate freely with each other?
  Are there low-stakes discussion spaces?
- **Group cohesion:** Are there collaborative activities? Peer review?
  Small group work? Shared projects?

Low social presence indicators: no peer interaction at all; discussions are
post-and-reply with no genuine exchange; all work is individual; no community
building activities.

### Cognitive Presence (0-10)

**Definition:** The extent to which learners construct meaning through sustained
inquiry and discourse.

Evaluate the inquiry cycle:
- **Triggering event:** Are there problems, questions, or scenarios that provoke
  curiosity and engagement?
- **Exploration:** Do activities allow learners to explore ideas, gather
  information, and consider alternatives?
- **Integration:** Are there opportunities to synthesize, connect, and make
  sense of what was explored?
- **Resolution:** Can learners apply what they have learned to real or
  realistic problems?

Low cognitive presence indicators: activities never progress beyond recall;
no problem-solving or application tasks; discussions stay at surface level
("I agree with your post"); no integration or transfer activities.

### The Critical Insight

After scoring all three dimensions, write this synthesis. It goes in the report, in the rows and the Summary. In the chat note, use only its first sentence, with no citation:

"This course [meets/does not meet] QM structural requirements but scores
[high/low] on [weakest presence dimension] ([score]/10). Courses with low
social presence show weaker learning outcomes in online settings [Online-15] [T4].
A structurally compliant course is not automatically an effective course."

This is the core value proposition of the two-layer approach. QM tells you the
course is built correctly. CoI tells you it will actually work.

**Step review:** do the Step Review in the preamble. Section: `## Community of Inquiry presence`. Columns: `ID | Presence | Score | Key finding | Justification | Evidence`.
Write one row for each presence, with the IDs `PR-1` (teaching), `PR-2` (social) and `PR-3` (cognitive). Write the score as `X/10`. In the chat note, use the synthesis of "The Critical Insight" as the sentence about the most important row.

---

## Constructive Alignment Audit

This is the cross-domain integration check. Constructive alignment means every
objective has a corresponding activity and assessment at the appropriate cognitive
level [Alignment-1] [T5].

### If Manifest Has ILOs and Alignment Data

Check the full chain for each ILO:

- **Objective to Activity:** Does every ILO have at least one learning activity
  that gives learners practice at the required cognitive level?
- **Objective to Assessment:** Does every ILO have at least one assessment that
  measures the stated outcome?
- **Activity to Assessment level match:** Is the assessment at the same or
  higher Bloom's level as the activity? If learners practice at the "apply"
  level but are assessed at "remember," the assessment is misaligned.

Flag these specific misalignments:
- Activity at a lower Bloom's level than the objective (learners never practice
  at the level they are expected to perform)
- Assessment measuring recall when the objective targets application or higher
  (the most common misalignment in course design)
- Objective with no mapped activity (learners are expected to achieve something
  they never practice)
- Objective with no mapped assessment (an objective that is never evaluated
  is functionally decorative)
- Activity with no corresponding objective (orphan activity — likely inherited
  from a previous version of the course)

Reference the `learning_objectives.alignment_matrix` from the manifest when
available. Flag any `gaps` already identified there.

### If No Alignment Data Available

Ask the user targeted questions:

1. "For each of your main learning objectives, what activities do learners
   complete to practice that skill?"
2. "How is each objective assessed? What does the learner produce or
   demonstrate?"
3. "Do you teach objectives that you do not formally assess?"

Build a rough alignment map from the answers and check for the same
misalignment patterns listed above.

**Step review:** do the Step Review in the preamble. Section: `## Constructive alignment audit`. Columns: `ID | Assessment | Activity | Level match | Status | Justification | Evidence`.
Write one row for each ILO, with the IDs `AL-1`, `AL-2` and so on, and start the Assessment cell with the ILO ID. Write the status as `aligned`, `gap` or `mismatch`. Write each orphan activity as a row with `none` in the Assessment cell.

If no ILOs are available, write one row that tells that the audit could not run.

---

## Cross-Domain Evidence Checks

Run all four checks below. Each check produces a list of flags with severity
(critical / warning / info) and a fix-link pointing to the idstack skill that
resolves the issue. When a check has no findings, record "No flags."

### Check 1: Cognitive Load Flags

**Evidence:** [CogLoad-1] [CogLoad-16] [T1] [CogLoad-17] [T2]

Scan the course design for these cognitive load violations:

- **Split attention:** Content explanation is separated from the diagram, example,
  or visual it references. Learners must mentally integrate information from
  multiple sources that should be physically co-located. Flag as warning.
  Fix: run /idstack:course-builder to regenerate module with integrated content.
- **Redundancy:** The same information is presented in multiple formats
  simultaneously with no added instructional value. NOTE: do NOT flag spaced
  practice or retrieval practice as redundancy — deliberate repetition across
  time is evidence-based [Assessment-8] [T1]. Only flag identical information
  presented simultaneously (e.g., reading aloud on-screen text verbatim).
  Flag as info.
  Fix: run /idstack:course-builder to consolidate redundant presentations.
- **Poor sequencing:** High-complexity material appears before the prerequisites
  it depends on are established. Look for modules that reference concepts not
  yet introduced, or activities that assume skills not yet practiced.
  Flag as critical.
  Fix: run /idstack:course-builder to resequence modules based on prerequisite chain.
- **Overloaded modules:** A single module introduces more than 6-8 new concepts
  without interleaved practice breaks. Count distinct new concepts per module
  and flag any that exceed this threshold without embedded practice.
  Flag as warning.
  Fix: run /idstack:course-builder to split module or add practice checkpoints.

### Check 2: Multimedia Principle Violations

**Evidence:** [Multimedia-1] [Multimedia-5] [Multimedia-9] [T1]

Scan for violations of Mayer's multimedia learning principles:

- **Spatial contiguity:** Text and related visuals are physically separated
  (e.g., figure on one page, explanation on another; caption far from image).
  Flag as warning.
  Fix: run /idstack:course-builder to co-locate text and visuals.
- **Temporal contiguity:** Narration and visuals are not synchronized (e.g.,
  a video describes a diagram that appears 30 seconds later). Flag as warning.
  Fix: run /idstack:course-builder to synchronize narration with visual presentation.
- **Segmenting:** Presentations exceed 15 minutes without embedded questions
  or activities. Continuous passive exposure beyond this threshold reduces
  retention. Flag as warning.
  Fix: run /idstack:course-builder to segment long presentations with embedded activities.
- **Modality:** Complex material uses only one modality (text-only or audio-only)
  where dual-channel presentation (visual + auditory) would reduce cognitive
  load. Flag as info.
  Fix: run /idstack:course-builder to add complementary modality.
- **Coherence:** Extraneous material (decorative images, tangential stories,
  background music) does not support the learning objective. Seductive details
  hurt learning. Flag as info.
  Fix: run /idstack:course-builder to remove extraneous elements.

### Check 3: Feedback Quality

**Evidence:** [Assessment-8] [Assessment-10] [T1]

Scan the assessment design for feedback quality issues:

- **Correctness-only feedback at apply+ Bloom's levels:** This is the most
  critical flag. Assessments targeting application, analysis, evaluation, or
  creation that only report correct/incorrect provide no learning mechanism.
  Elaborated feedback (explaining WHY and providing guidance) produces
  significantly larger learning gains. Flag as critical.
  Fix: run /idstack:assessment-design to add elaborated feedback for higher-order assessments.
- **No feedback pathway for summative assessments:** Students complete a
  summative assessment and receive only a grade with no opportunity to learn
  from mistakes. Flag as warning.
  Fix: run /idstack:assessment-design to add post-submission feedback or reflection activity.
- **Feedback lacks elaboration:** Feedback tells students WHAT is wrong but
  not WHY it is wrong or how to improve. Flag as warning.
  Fix: run /idstack:assessment-design to add elaborated feedback with explanations.
- **No student-initiated feedback opportunity:** All feedback is
  teacher-initiated (returned on assignments). There is no mechanism for
  students to seek feedback when they need it (e.g., self-check quizzes,
  rubric previews, peer review). Flag as info.
  Fix: run /idstack:assessment-design to add formative self-check opportunities.

### Check 4: Expertise Reversal

**Evidence:** [CogLoad-19] [T5]

If a learner profile is available (from manifest `needs_analysis.learner_profile`
or from user input), systematically check whether instructional strategies match
the audience expertise level. If no learner profile exists, flag the absence as
a warning and recommend running /idstack:needs-analysis.

- **Novice + minimal scaffolding:** Novice learners face open-ended
  problem-solving, minimal worked examples, or discovery learning without
  structured guidance. This causes cognitive overload and poor learning
  outcomes. Flag as critical.
  Fix: run /idstack:course-builder to regenerate module with scaffolding and worked examples.
- **Expert + excessive scaffolding:** Expert learners are forced through
  mandatory step-by-step instructions or worked examples they do not need.
  Redundant scaffolding competes for working memory resources that experts
  use for schema building — the expertise reversal effect. Flag as warning.
  Fix: run /idstack:course-builder to offer advanced-track options that skip scaffolding.
- **Mixed audience + no differentiation:** The course serves learners at
  different expertise levels but provides only one pathway with no tiered
  activities, adaptive branching, or differentiated resources. Flag as warning.
  Fix: run /idstack:needs-analysis to establish a detailed learner profile, then
  run /idstack:course-builder to create differentiated pathways.
- **Strategy-audience mismatch with no acknowledgment:** The course uses a
  strategy mismatched to audience expertise without any rationale. This is
  distinct from a deliberate pedagogical choice — an instructor who
  intentionally uses productive failure for novices should document why.
  Undocumented mismatches are flags. Flag as info.
  Fix: run /idstack:course-builder to add instructor rationale or adjust strategy.

**Step review:** do the Step Review in the preamble. Section: `## Cross-domain evidence checks`. Columns: `ID | Check | Flags | Severity | Fix | Justification | Evidence`.
Write one row for each check: `CD-1` cognitive load, `CD-2` multimedia principles, `CD-3` feedback quality and `CD-4` expertise reversal. In the Flags cell, write the flags or "No flags", and in the Severity cell, write the highest severity or `info`. Cite the evidence line of the check.

---

## Quick Wins

After completing all checks (QM Structural, CoI Presence, Constructive Alignment,
and Cross-Domain Evidence), rank every finding by impact using this formula:

**Impact score = Evidence tier weight x Severity x Ease of fix**

| Factor | Values |
|--------|--------|
| Evidence tier | T1=5, T2=4, T3=3, T4=2, T5=1 |
| Severity | critical=3, warning=2, info=1 |
| Ease of fix | S (small, <1 hour)=3, M (medium, 1-4 hours)=2, L (large, >4 hours)=1 |

Use the impact scores to rank the Top recommendations in the last Step Review.
Rank only the approved rows of the `## Findings` section. If the user removed a
finding, remove it from the ranking. The three highest impact scores are the top 3
quick wins.

Estimate the ease of fix based on: S = a single skill run fixes it, M = requires
reworking one module or assessment, L = requires rethinking course structure.

---

## Report Sections

The Step Reviews above added the QM, CoI, alignment and cross-domain sections to
the report. Do the Step Reviews of this part next, in this order.

### Findings

**Step review:** do the Step Review in the preamble. Section: `## Findings`. Columns: `ID | Severity | What we saw | Recommendation | Justification | Evidence`.
Write one row for each flagged QM standard, low presence, alignment gap and cross-domain flag in the approved rows of the earlier sections. Use stable IDs with the prefix of the dimension: `qm-1`, `coi-1`, `align-1`, `cogload-1`, `multimedia-1`, `feedback-1`, `expertise-1` and so on. In the Recommendation cell, name the idstack skill that repairs the problem, as "Cross-Referencing Other idstack Skills" below tells.

### Score breakdown

Calculate the scores with the Scoring Rubric below. Use only the approved rows. A QM standard that the user removed counts as `na`. A finding that the user removed does not cause a deduction.

**Step review:** do the Step Review in the preamble. Section: `## Score breakdown`. Columns: `ID | Category | Score | Status | Justification | Evidence`.
Write four rows: `SC-1` QM Structural `XX/40`, `SC-2` CoI Presence `XX/25`, `SC-3` Constructive Alignment `XX/15` and `SC-4` Cross-Domain Evidence `XX/20`. In the Status cell, write the number of flags, the weakest presence or the alignment status. This section replaces the placeholder that the init command wrote.

In the chat note, write the overall score on the first line: "Quality score: XX/100". If `.idstack/timeline.jsonl` has a previous course-quality-review score, add "Previous score: X/100 (reviewed YYYY-MM-DD). Delta: +/-Z." to that line.

### Scoring Rubric

Calculate the overall score from these components (total: 100 points):

- **QM Structural Review (40 points):** 5 points per standard. Pass = full
  points, flag = half points (2.5), na = excluded from denominator and
  remaining points redistributed across evaluated standards.
- **CoI Presence Layer (25 points):** Each dimension scored 0-10, summed
  to a raw score out of 30, then scaled to 25 (raw_sum / 30 * 25).
- **Constructive Alignment (15 points):** Full points if alignment verified.
  Deduct 5 points per critical misalignment, 2 per warning.
- **Cross-Domain Evidence Checks (20 points):** 5 points per check. Full
  points if no flags. Deduct per flag: critical = -3, warning = -2,
  info = -1. Minimum 0 per check.

### Cross-Referencing Other idstack Skills

When recommending fixes, point users to the appropriate idstack skill:

- Misaligned or weak ILOs: "Run `/idstack:learning-objectives` to realign ILO-3 with
  its assessment."
- Missing learner profile: "Run `/idstack:needs-analysis` to add the learner
  profile. The course does not have a learner profile."
- No task analysis: "Run `/idstack:needs-analysis` — the task analysis will inform
  which activities are core vs. reference."
- Weak alignment chain: "Run `/idstack:learning-objectives` to rebuild the alignment
  matrix from your task analysis."

### Summary, Top recommendations, Limitations and Next steps

**Step review:** do the Step Review in the preamble. Section: `## Summary`, `## Top recommendations`, `## Limitations` and `## Next steps`. Columns: `ID | Action | Justification | Evidence`.
This is the last Step Review. Write the four sections in one draft. Only Top recommendations has a table.

- **Summary:** 2 or 3 sentences. Start with the overall score and the most important finding. Add the line "Quality XX/100 · Teaching XX/10 · Social XX/10 · Cognitive XX/10". If the timeline has a previous score, add "Previous: X/100 (YYYY-MM-DD), delta +/-Z".
- **Top recommendations:** 3 to 5 rows. Put the top 3 quick wins from the Quick Wins ranking first. Use the finding ID as the row ID. In the Action cell, write one command that names the skill to run.
- **Limitations:** The review reads the course data in the manifest or, with no manifest, the course files and your answers. It does not read each page of learner content. The cognitive-load assessments are heuristic. The CoI presence scores come from this course data, not from a survey.
- **Next steps:** 1–3 specific next actions referencing other idstack skills. When no critical issues remain, include: "Run `/idstack:course-export` to package your course."

Run the finish command of the Step Review.

**Writing standard check.** In this command, replace `<path>` with the path from the "Report path:" line. Then run the command.

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/scripts/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; else "$_IDSTACK/scripts/idstack-ste-check" "<path>"; fi
```

For the result, do the steps in "How to use the standard" in the "Writing Standard (ASD-STE100)" section of the preamble. Do the check a maximum of three times.

---

## Write Manifest

After the finish command and the writing standard check, save the results via the section-scoped merge tool. It
validates the section name against the canonical schema, preserves every other
section verbatim, bumps the top-level `updated` timestamp, and writes atomically:

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
# payload file holds ONLY the quality_review section object (shape below)
"$_IDSTACK/scripts/idstack-manifest-merge" --create --section quality_review --payload .idstack/.quality_review-payload.json && rm -f .idstack/.quality_review-payload.json
```

Write the payload object to `.idstack/.quality_review-payload.json` with the
Write tool first, then run the merge. `--create` makes a canonical manifest first if `.idstack/project.json` does not
exist yet (the standalone case). It never replaces a manifest that exists.

**CRITICAL — Manifest Integrity Rules:**
1. The payload must be valid JSON: matching braces, proper commas, quoted
   strings, no trailing commas. The merge tool rejects malformed payloads
   (exit code 1).
2. Never write secrets or credentials into the manifest.

Payload shape — the file contains ONLY the section object, no `"quality_review"` wrapper:

```json
{
    "report_path": "<set to $_REPORT_PATH from the Prepare the Report block above — e.g. .idstack/exports/<course-slug>/course-quality-review.md>",
    "last_reviewed": "ISO-8601 timestamp",
    "qm_standards": {
      "course_overview": {"status": "pass|flag|na", "findings": ["..."]},
      "learning_objectives": {"status": "pass|flag|na", "findings": ["..."]},
      "assessment": {"status": "pass|flag|na", "findings": ["..."]},
      "instructional_materials": {"status": "pass|flag|na", "findings": ["..."]},
      "learning_activities": {"status": "pass|flag|na", "findings": ["..."]},
      "course_technology": {"status": "pass|flag|na", "findings": ["..."]},
      "learner_support": {"status": "pass|flag|na", "findings": ["..."]},
      "accessibility": {"status": "pass|flag|na", "findings": ["..."]}
    },
    "coi_presence": {
      "teaching_presence": {"score": 0, "findings": ["..."]},
      "social_presence": {"score": 0, "findings": ["..."]},
      "cognitive_presence": {"score": 0, "findings": ["..."]}
    },
    "alignment_audit": {"findings": ["..."]},
    "cross_domain_checks": {
      "cognitive_load": {"flags": [], "score": 5},
      "multimedia_principles": {"flags": [], "score": 5},
      "feedback_quality": {"flags": [], "score": 5},
      "expertise_reversal": {"flags": [], "score": 5}
    },
    "overall_score": 0,
    "score_breakdown": {
      "qm_structural": 0,
      "coi_presence": 0,
      "constructive_alignment": 0,
      "cross_domain_evidence": 0
    },
    "quick_wins": [
      {
        "finding": "...",
        "impact_score": 0,
        "evidence_tier": "T1-T5",
        "severity": "critical|warning|info",
        "ease": "S|M|L",
        "fix_skill": "/idstack:<skill-name>"
      }
    ],
    "recommendations": [
      {
        "finding": "...",
        "evidence_tier": "T1-T5",
        "severity": "critical|warning|info",
        "fix": "..."
      }
    ]
}
```

When building the payload:
- Populate ALL fields in the `quality_review` section from the approved rows of the report.
  Use only the approved rows. Fill `recommendations` from the approved Findings rows. Fill `quick_wins` from the
  approved Top recommendations rows that are quick wins. Take `impact_score`, `ease` and
  `evidence_tier` from the Quick Wins ranking. Use the scores of the Score breakdown section.
- The merge tool updates the top-level `updated` timestamp automatically.

### Score Trending Display

After writing the manifest, check `.idstack/timeline.jsonl` for prior course-quality-review
scores. The preamble's context recovery already reads this file, but the score trending
display should also appear in the completion message.

- If 1 prior score exists: show delta. "Score: 78/100 (+16 since last review on Mar 15)"
- If 3+ prior scores exist: show trend. "The score went up: 62 -> 72 -> 78 in 3 reviews."
- If no prior scores exist: just show the current score.

The manifest stores the current overall_score. The timeline stores historical scores.
One source of truth per data point.

### Closing Message

After writing both the manifest and the quality report, confirm to the user:

"I saved your quality review to `.idstack/project.json`. I also wrote a shareable
report: <the Report path, written as a link as the Report Links section of the preamble tells you>. The
report shows the QM structural review, CoI presence scores, alignment audit,
cross-domain evidence checks, and recommendations, with the most important first. Click the link to open it.

**Score: XX/100** [If previous: "Previous: X/100 (DATE). Delta: +/-Z."]

**Next steps based on findings:**
[List 1-3 specific next actions based on the review results, referencing
other idstack skills where applicable. When no critical issues remain,
include: Run `/idstack:course-export` to package your course as an IMS Common
Cartridge or push to Canvas.]"

For the full manifest schema (other sections you may need to read), Read
`${CLAUDE_PLUGIN_ROOT}/templates/manifest-schema.md`.

## Feedback

Have feedback or a feature request? [Share it here](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed.

---

## Completion: Timeline Logging

After the skill workflow completes successfully, log the session to the timeline.
Include the overall_score so the preamble's context recovery can display score trends
across sessions (e.g., "Quality score trend: 62 -> 72 -> 78 over 3 reviews").

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
IFS= read -r -d '' _EVENT <<'IDSTACK_EVENT' || true
{"skill":"course-quality-review","event":"completed","score":OVERALL_SCORE,"dimensions":{"teaching_presence":TP,"social_presence":SP,"cognitive_presence":CP}}
IDSTACK_EVENT
"$_IDSTACK/scripts/idstack-timeline-log" "$_EVENT"
```

Replace OVERALL_SCORE with the actual overall score (0-100), and TP/SP/CP with the
CoI presence dimension scores (0-10 each). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
_idstack_skill="${CLAUDE_SKILL_DIR}"
[ -n "$_idstack_skill" ] && _idstack_skill="$_idstack_skill/../.."
for _p in "${CLAUDE_PLUGIN_ROOT}" "$_idstack_skill" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
IFS= read -r -d '' _LEARNING <<'IDSTACK_LEARNING' || true
{"skill":"course-quality-review","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}
IDSTACK_LEARNING
"$_IDSTACK/scripts/idstack-learnings" log "$_LEARNING"
```
