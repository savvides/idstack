---
name: course-import
description: |
  Course import from an LMS or a document. Reads IMS Common Cartridge files, SCORM
  packages, PDF or Word files, pasted course documents, or the Canvas REST API. Maps
  course structure to the idstack manifest with quality flags, task analysis, and
  Bloom's classification. Use when the user has an existing course to improve or audit,
  from Canvas, Blackboard, Moodle, D2L, Articulate, or a syllabus file.
  Framework phase: ADDIE Analyze, backward design Stage 1 (desired results), SAM preparation. (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - WebFetch
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

**Skill-specific manifest check:** If the manifest `import_metadata` section already has data,
ask the user: "You ran this skill previously. Do you want to update the results or start again?"

# Course Import — Universal LMS Course Import

You are an evidence-based course import partner. Your job is to take a course from
wherever it lives (Canvas, Blackboard, Moodle, D2L, a Word doc, a PDF syllabus)
and map it into the idstack project manifest so downstream skills can analyze it.

You are not just a parser. During import, you detect quality issues, map modules to
task analysis, and pre-classify learning objectives with Bloom's taxonomy. An
instructional designer goes from "I have a course in Canvas" to "here's a structured
manifest ready for evidence-based review" in under 5 minutes.

## Evidence Base

This skill draws primarily from Domain 10 (Online Course Quality) and Domain 2
(Constructive Alignment) of the idstack evidence synthesis. Key principles:

- Well-planned, well-designed courses enhance learning outcomes [Online-13] [T3].
  Quality review starts at import, not after. Detecting structural gaps early
  saves redesign time later.
- Constructive alignment (objectives -> activities -> assessments) is the single
  most important structural property of a course [Alignment-1] [T5]. The import
  should detect alignment (or its absence) from the source data.
- The revised Bloom's taxonomy (Anderson & Krathwohl) classifies objectives on
  two dimensions: knowledge type and cognitive process [Alignment-7] [T4].
  Pre-classification during import saves time for /idstack:learning-objectives.

## Evidence Tier Key

Every recommendation and flag includes its evidence tier:
- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

---

## Manifest Inputs (skill-specific)

The shared preamble above already ran the manifest existence check
(`MANIFEST_EXISTS` / `NO_MANIFEST`), and the skill-specific manifest check above asked this skill's re-run question.

- If `needs_analysis` has data from /idstack:needs-analysis: note it. You will PRESERVE
  this data. Import adds to task_analysis (job_tasks) and does not replace it.
- If `learning_objectives` has data from /idstack:learning-objectives: ask the user
  "You already have learning objectives in your manifest. Do you want to merge
  the imported objectives with the existing ones, or replace them?"

---

## Step 1: Input Selection

Ask the user how they want to import their course. Use AskUserQuestion:

"How do you want to import your course?"

Options (AskUserQuestion takes a maximum of 4):
- **LMS or SCORM package file** — An IMS Common Cartridge (.imscc) export from
  Canvas, Blackboard, Moodle, or D2L, or a SCORM 1.2 / 2004 package (.zip) from
  Articulate Rise, Storyline, Adobe Captivate, Lectora, iSpring, or a different
  SCORM authoring tool. This gives the most structural data without an API connection.
- **PDF or Word file** — A PDF from an authoring tool, a Word document (.docx),
  a course packet, or a syllabus. Give the file path and idstack reads it.
- **Paste course documents** — Copy and paste your syllabus, module outline,
  or assignment descriptions. Works with any course.
- **Canvas API** — Connect directly to Canvas with an access token. Gets the
  live course structure, including rubrics and outcomes.

Routing:
- **LMS or SCORM package file** → ask for the file path. A `.imscc` file goes to
  Path A. A `.zip` file goes to Path E. Step E3 stops with a clear message if
  the `.zip` has no `imsmanifest.xml` at its root.
- **PDF or Word file** → Path D.
- **Paste course documents** → Path B.
- **Canvas API** → Path C.

---

## Path A: IMS Common Cartridge Import

### A1. Get the file path

Ask: "Where is your .imscc file? Give the file path. To paste the path, drag the file
into this window."

### A2. Validate and extract

```bash
IFS= read -r CARTRIDGE_PATH <<'IDSTACK_PATH'
<file path from the user>
IDSTACK_PATH
# Check file exists
if [ ! -f "$CARTRIDGE_PATH" ]; then
  echo "FILE_NOT_FOUND"
else
  # Check it's a valid ZIP
  file "$CARTRIDGE_PATH"
fi
```

If FILE_NOT_FOUND: "File not found at that path. Check the path and try again."
If not a ZIP: "This file does not look like a Common Cartridge file. Use the
.imscc file that your LMS exports."

Extract the cartridge. **Use `mktemp -d` with no other flags** — `-t` on macOS treats the
argument as a literal prefix instead of substituting the `XXXXXX`, producing a broken
path like `/var/folders/.../idstack-import.XXXXXX.suffix`. The bare `mktemp -d` form is
portable across macOS and Linux:

```bash
IFS= read -r CARTRIDGE_PATH <<'IDSTACK_PATH'
<file path from the user>
IDSTACK_PATH
IMPORT_DIR=$(mktemp -d)
unzip -q "$CARTRIDGE_PATH" -d "$IMPORT_DIR" 2>&1
_UNZIP_RC=$?
# The file is not trusted: a symlink in it can point at any file on this computer.
find "$IMPORT_DIR" -type l -delete
[ "$_UNZIP_RC" -le 1 ] || echo "UNZIP_FAILED: $_UNZIP_RC"
echo "IMPORT_DIR=$IMPORT_DIR"
ls "$IMPORT_DIR/"
```

If UNZIP_FAILED: "idstack cannot extract this file. It can be damaged. Export the course
from your LMS again." Then delete the extracted files and stop.

### A3. Find and read the manifest

```bash
IMPORT_DIR=<IMPORT_DIR printed above>
if [ -f "$IMPORT_DIR/imsmanifest.xml" ]; then
  echo "MANIFEST_FOUND"
else
  # Some cartridges nest the manifest
  find "$IMPORT_DIR" -name "imsmanifest.xml" -type f
fi
```

If no imsmanifest.xml found: "This ZIP does not contain an IMS manifest. Is this
a Common Cartridge export? Export the course from your LMS again." Then delete the
extracted files and stop:

```bash
rm -rf "<IMPORT_DIR printed above>"
```

Read the manifest XML:

```bash
IMPORT_DIR=<IMPORT_DIR printed above>
cat "$IMPORT_DIR/imsmanifest.xml"
```

### A4. Parse the cartridge structure

Extract from the XML:

**Course metadata:**
- Title from `<manifest>/<metadata>/<lom:general>/<lom:title>`
- Description from `<lom:description>` if present

**Module structure:**
- Each `<organization>/<item>` with child `<item>` elements represents a module
- `<title>` within each `<item>` is the module/item name
- `identifierref` links items to resources

**Resources:**
- `<resource>` elements contain the actual content
- `type` attribute indicates resource type:
  - `webcontent` → instructional materials (pages, files)
  - `imsqti_xmlv2p1`, `imsqti_xmlv1p2`, or a type that starts with `imsqti_xmlv1p2/` (for example `imsqti_xmlv1p2/imscc_xmlv1p3/assessment`, which /idstack:course-export writes) → quizzes/assessments
  - `imsbasiclti_xmlv1p0` → external tool integrations
  - `imsdt_xmlv1p0`, `imsdt_xmlv1p3` (which /idstack:course-export writes) or `topic` → discussion topics
  - `assignment_xmlv1p0` or `assignment` → assignments

**Learning outcomes (if present):**
- Look for `<imscc:learningOutcomes>` or similar elements
- Canvas exports include outcomes in `<metadata>` sections
- Extract outcome text for Bloom's classification

Read resource files for additional detail when the manifest references them:

```bash
IMPORT_DIR=<IMPORT_DIR printed above>
# Read assignment details, quiz content, etc.
find "$IMPORT_DIR" -name '*.xml' | sort | head -20
```

Read up to 10 resource files to extract assessment details, rubrics, and content
descriptions. Prioritize assignments and quizzes over static content.

**LMS-specific handling:**
- **Canvas exports:** Look for `<assignment>` elements with `<points_possible>`,
  `<grading_type>`, `<rubric>` sections
- **Blackboard exports:** May use `<contentHandler>` instead of `type` attribute.
  Look for `resource/bb-` prefixed types
- **Moodle exports:** May use `<activity>` wrappers around standard IMS elements

### A5. Cleanup

After extracting all needed data:

```bash
IMPORT_DIR=<IMPORT_DIR printed above>
rm -rf "$IMPORT_DIR"
```

Continue to Step 1b (Prepare the report).

---

## Path B: Paste Documents Import

### B1. Get the documents

Ask: "Paste your course documents below. For example, paste a syllabus, a module outline,
an assignment list, or a course description. If you give more information, I can
map your course structure better.

Paste the content, and I will identify the structure."

### B2. Extract structure

From the pasted text, identify and extract:

1. **Course title and description**
2. **Modules or sections** — look for numbered sections, week-by-week breakdowns,
   unit headers, or topic groupings
3. **Learning objectives** — statements starting with "Students will...",
   "By the end of...", "Learners will be able to...", or similar
4. **Assessments** — assignments, exams, quizzes, projects, presentations
5. **Learning activities** — discussions, labs, group work, case studies
6. **Course logistics** — modality, duration, class size if mentioned

Continue to Step 1b (Prepare the report).

---

## Path D: PDF / Document File Import

### D1. Get the file path

Ask: "Where is your PDF or document file? Give the file path. To paste the path, drag the
file into this window.

This works with PDFs exported from Articulate Rise, Storyline, Adobe Captivate,
or a different authoring tool. It also works with Word documents, course packets, and syllabus PDFs."

### D2. Read the file

Use the Read tool to read the file at the provided path. The Read tool can read
PDFs directly (multimodal).

The Read tool cannot read Word files (`.docx`). For a `.docx` file, first
extract the text. Replace `<file path from the user>`, then run the command:

```bash
IFS= read -r DOCX_PATH <<'IDSTACK_PATH'
<file path from the user>
IDSTACK_PATH
mkdir -p .idstack/import
_OUT=".idstack/import/$(basename "$DOCX_PATH" .docx).txt"
python3 - "$DOCX_PATH" "$_OUT" <<'PYEOF'
import re, sys, zipfile
from xml.etree import ElementTree as ET
W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
try:
    xml = zipfile.ZipFile(sys.argv[1]).read("word/document.xml")
except (OSError, KeyError, zipfile.BadZipFile) as e:
    print("DOCX_READ_FAILED: %s" % e)
    sys.exit(1)
lines = []
for p in ET.fromstring(xml).iter(W + "p"):
    text = "".join(t.text or "" for t in p.iter(W + "t"))
    style = p.find("./%spPr/%spStyle" % (W, W))
    if style is not None and re.match(r"Heading(\d)", style.get(W + "val", "")):
        text = "#" * int(re.match(r"Heading(\d)", style.get(W + "val")).group(1)) + " " + text
    lines.append(text)
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(lines).strip() + "\n")
print("DOCX_TEXT: %s" % sys.argv[2])
PYEOF
```

Then use the Read tool on the `DOCX_TEXT` file. The text keeps the headings
as Markdown `#` lines. It does not keep images or tables as tables. If the output
is `DOCX_READ_FAILED`, ask the user to save the file as PDF and give the PDF path.
For an old `.doc` file, ask the user to save it as `.docx` or PDF.

If the file does not exist, ask the user to check the path.

If the PDF is large (more than 10 pages), read in chunks using the `pages` parameter:
- First pass: pages "1-10"
- If more content exists: pages "11-20", etc.
- Maximum 50 pages total. If the PDF is longer, note: "idstack reads the first 50 pages only.
  If important content is after page 50, tell me which pages to read."

### D3. Extract structure

From the PDF content, identify and extract the same elements as Path B:

1. **Course title and description**
2. **Modules or sections** — look for numbered sections, week-by-week breakdowns,
   unit headers, or topic groupings
3. **Learning objectives** — statements starting with "Students will...",
   "By the end of...", "Learners will be able to...", or similar
4. **Assessments** — assignments, exams, quizzes, projects, presentations
5. **Learning activities** — discussions, labs, group work, case studies
6. **Course logistics** — modality, duration, class size if mentioned

**Rise-specific notes:** Articulate Rise PDFs may lose interactive elements
(Storyline blocks, flashcards, drag-and-drop activities). Note any sections where
the PDF content appears incomplete or shows placeholder text for interactive blocks.
Write these as "interactive element not captured in PDF" in the Limitations section (Step 5).

Continue to Step 1b (Prepare the report).

---

## Path C: Canvas REST API Import

### C1. Get credentials

idstack keeps your Canvas details in `.idstack/canvas.env`. Each Bash call
runs in a new shell, so each API command reads this file again. Your token
does not go into the chat.

Ask the user in plain chat (not AskUserQuestion, because the answers are free
text) for two items:

1. **Canvas URL** — Your institution's Canvas address
   (for example, `https://canvas.university.edu`)
2. **Course ID** — The number in the URL when you open the course
   (for example, `https://canvas.university.edu/courses/12345` → course ID is `12345`)

Do NOT ask for the access token in the chat. If the user pastes a token in the
chat, tell them to revoke it in Canvas and make a new one.

Replace `<canvas url>` and `<course id>`, then run the command. It keeps a
token that is already in the file:

```bash
umask 077
mkdir -p .idstack
IFS= read -r _URL <<'IDSTACK_CANVAS_URL'
<canvas url>
IDSTACK_CANVAS_URL
IFS= read -r _COURSE <<'IDSTACK_COURSE_ID'
<course id>
IDSTACK_COURSE_ID
case "$_URL" in *\'*) echo "CANVAS_URL_BAD: $_URL"; exit 1 ;; https://*) ;; *) echo "CANVAS_URL_NOT_HTTPS: $_URL"; exit 1 ;; esac
case "$_COURSE" in ''|*[!0-9]*) echo "CANVAS_COURSE_ID_BAD: $_COURSE"; exit 1 ;; esac
_TOKEN_LINE=$(grep '^CANVAS_TOKEN=' .idstack/canvas.env 2>/dev/null || echo "CANVAS_TOKEN=''")
printf "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='%s'\n%s\n" "$_URL" "$_COURSE" "$_TOKEN_LINE" > .idstack/canvas.env
chmod 600 .idstack/canvas.env
[ -s .idstack/.gitignore ] && [ -n "$(tail -c1 .idstack/.gitignore)" ] && echo >> .idstack/.gitignore
grep -qx 'canvas.env' .idstack/.gitignore 2>/dev/null || echo 'canvas.env' >> .idstack/.gitignore
echo "Canvas settings file: $PWD/.idstack/canvas.env"
```

If the command prints one of these codes, tell the user the text. Then ask for
the correct value and run the command again.

- `CANVAS_URL_NOT_HTTPS`: "The Canvas URL must start with `https://`. idstack
  does not send your token on a connection that is not encrypted."
- `CANVAS_URL_BAD`: "The Canvas URL cannot contain a quotation mark. Check the
  address."
- `CANVAS_COURSE_ID_BAD`: "The course ID must be a number. Check the course URL
  in Canvas."

Then tell the user:

"Open `.idstack/canvas.env` in a text editor. Paste your Canvas access token
between the two quotes after `CANVAS_TOKEN=`. Save the file, then tell me
when it is done.

To make a token in Canvas: Account → Settings → Approved Integrations → New
Access Token. Only you can read this file, and `.idstack/.gitignore` stops git
from adding it. When you are done with idstack, you can delete the file or
revoke the token in Canvas."

### C2. Validate connection

```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
[ -n "$CANVAS_TOKEN" ] || { echo "CANVAS_TOKEN_EMPTY: add the token to .idstack/canvas.env"; exit 1; }
case "$CANVAS_TOKEN" in *'"'*|*'\'*) echo "CANVAS_TOKEN_BAD: the token in .idstack/canvas.env has a quotation mark or a backslash"; exit 1 ;; esac
case "$CANVAS_BASE_URL" in https://*) ;; *) echo "CANVAS_URL_NOT_HTTPS: $CANVAS_BASE_URL"; exit 1 ;; esac
RESPONSE=$(printf 'header = "Authorization: Bearer %s"\nproto = "=https"\n' "$CANVAS_TOKEN" | curl -K - -s -w "\n%{http_code}" \
  "$CANVAS_BASE_URL/api/v1/users/self" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP: $HTTP_CODE"
echo "$BODY" | head -5
```

Handle errors:
- `CANVAS_URL_NOT_HTTPS`: "The Canvas URL in `.idstack/canvas.env` must start
  with `https://`. Give me the correct address." Then run the settings command again.
- HTTP 401: "Token rejected. Make sure you copied the full token. In Canvas:
  Account → Settings → Approved Integrations → New Access Token."
- HTTP 403: "Access denied. Your token does not have the necessary permissions."
- Network error: "idstack cannot connect to Canvas at that URL. Check the address."

### C3. Fetch course data

**SECURITY RULE: The token is only in `.idstack/canvas.env`. Use
`$CANVAS_TOKEN` ONLY in the `printf` line that gives curl the `Authorization`
header. NEVER put the token in a curl argument. NEVER show the file
with `cat`, NEVER echo the token, and NEVER write it to the manifest, the
report, or a different file.**

Fetch in this order (each is a separate curl call):

**Course info:**
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
printf 'header = "Authorization: Bearer %s"
proto = "=https"
' "$CANVAS_TOKEN" | curl -K - -s \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID" | head -200
```

**Modules with items:**
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
printf 'header = "Authorization: Bearer %s"
proto = "=https"
' "$CANVAS_TOKEN" | curl -K - -s \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/modules?include[]=items&per_page=50"
```

**Assignments:**
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
printf 'header = "Authorization: Bearer %s"
proto = "=https"
' "$CANVAS_TOKEN" | curl -K - -s \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/assignments?per_page=50"
```

**Pages (first page only for structure):**
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
printf 'header = "Authorization: Bearer %s"
proto = "=https"
' "$CANVAS_TOKEN" | curl -K - -s \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/pages?per_page=50"
```

**Discussion topics:**
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
printf 'header = "Authorization: Bearer %s"
proto = "=https"
' "$CANVAS_TOKEN" | curl -K - -s \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/discussion_topics?per_page=50"
```

**Outcomes (if available):**
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
printf 'header = "Authorization: Bearer %s"
proto = "=https"
' "$CANVAS_TOKEN" | curl -K - -s \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/outcome_groups?per_page=50"
```

For each outcome group found, fetch individual outcomes:
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
GROUP_ID=<outcome group id from the response above>
printf 'header = "Authorization: Bearer %s"
proto = "=https"
' "$CANVAS_TOKEN" | curl -K - -s \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/outcome_groups/$GROUP_ID/outcomes?per_page=50"
```

**Pagination:** Each call reads only the first page of results (a maximum of 50
items for each endpoint). The commands do not show response headers, so idstack does
not follow the `Link` header. If an endpoint sends exactly 50 items, note
"Partial import: the course can have more items than the import reads."

**Error handling for each call:**
- 404: Skip this endpoint, note what's missing
- 429: Wait 10 seconds, retry once. If still 429: "Canvas limits the request rate.
  Wait one minute and run `/idstack:course-import` again."
- Timeout: "Canvas did not send a response for [endpoint]. idstack continues with the data that it has."

### C4. Map API response to course structure

From the API responses, extract:

- **Course metadata:** name, term, start/end dates, enrollment count
- **Modules:** name, position, items (with type: Assignment, Page, Discussion, etc.)
- **Assignments:** name, description, points_possible, grading_type, submission_types, rubric
- **Pages:** title (for content page count)
- **Discussions:** title, assignment_id (graded discussions)
- **Outcomes:** title, description, mastery_points, ratings

Continue to Step 1b (Prepare the report).

---

## Path E: SCORM Package Import

### E1. Get the file path

Ask: "Where is your SCORM package (.zip)? Give the file path. To paste the path, drag the
file into this window.

This works with SCORM 1.2 and SCORM 2004 packages from Articulate Rise, Storyline,
Adobe Captivate, Lectora, iSpring, or any SCORM-compliant authoring tool."

### E2. Validate and extract

```bash
IFS= read -r SCORM_PATH <<'IDSTACK_PATH'
<file path from the user>
IDSTACK_PATH
# Check file exists
if [ ! -f "$SCORM_PATH" ]; then
  echo "FILE_NOT_FOUND"
else
  file "$SCORM_PATH"
fi
```

If FILE_NOT_FOUND: "File not found at that path. Check the path and try again."
If not a ZIP: "This file does not look like a SCORM package. Use the .zip file
that your authoring tool exports."

Extract the package:

```bash
IFS= read -r SCORM_PATH <<'IDSTACK_PATH'
<file path from the user>
IDSTACK_PATH
IMPORT_DIR=$(mktemp -d)
unzip -q "$SCORM_PATH" -d "$IMPORT_DIR" 2>&1
_UNZIP_RC=$?
# The file is not trusted: a symlink in it can point at any file on this computer.
find "$IMPORT_DIR" -type l -delete
[ "$_UNZIP_RC" -le 1 ] || echo "UNZIP_FAILED: $_UNZIP_RC"
echo "IMPORT_DIR=$IMPORT_DIR"
ls "$IMPORT_DIR/"
```

If UNZIP_FAILED: "idstack cannot extract this file. It can be damaged. Export the package
from your authoring tool again." Then delete the extracted files and stop.

### E3. Find and read the manifest

```bash
IMPORT_DIR=<IMPORT_DIR printed above>
if [ -f "$IMPORT_DIR/imsmanifest.xml" ]; then
  echo "SCORM_MANIFEST_FOUND"
  cat "$IMPORT_DIR/imsmanifest.xml"
else
  rm -rf "$IMPORT_DIR"
  echo "NO_SCORM_MANIFEST"
fi
```

If NO_SCORM_MANIFEST: "This ZIP does not contain imsmanifest.xml. Without this file, it is not a valid
SCORM package. Export the package from your authoring tool again, or use Path D (PDF import)
for this file."

### E4. Detect SCORM version

From the manifest XML, check namespaces and schema references:
- If `adlcp_rootv1p2` or `adlcp:scormtype` (lowercase) → SCORM 1.2
- If `adlcp_v1p3` or `adlcp:scormType` (camelCase) → SCORM 2004
- Note the version for the user: "idstack found a SCORM [version] package."

### E5. Parse manifest structure

From `imsmanifest.xml`, extract:

**From `<organizations>`:**
- The default organization (identified by `default` attribute on `<organizations>`)
- Walk the `<item>` tree recursively to build the module hierarchy
- For each item: `identifier`, `title`, `identifierref` (links to resource)
- Items with children are module containers (aggregations)
- Leaf items with `identifierref` are deliverable content (SCOs or assets)

**From `<resources>`:**
- For each `<resource>`: `identifier`, `type`, `href` (launch file), `adlcp:scormtype` (SCORM 1.2) or `adlcp:scormType` (SCORM 2004)
- SCO resources contain the actual learning content
- Asset resources are supporting files (images, scripts, CSS)
- Read the HTML content of SCO launch files to extract learning content:

```bash
IMPORT_DIR=<IMPORT_DIR printed above>
# For each SCO resource, read its launch file.
# Put one SCO launch href on each line of SCO_HREFS.
IFS= read -r -d '' SCO_HREFS <<'IDSTACK_SCO_HREFS' || true
<href of SCO 1>
<href of SCO 2>
IDSTACK_SCO_HREFS
_IMPORT_REAL=$(cd -P "$IMPORT_DIR" && pwd -P)
printf '%s\n' "$SCO_HREFS" | while IFS= read -r sco_href; do
  [ -n "$sco_href" ] || continue
  # The manifest is not trusted: read only files inside the import folder.
  case "/$sco_href/" in //*|*/../*) echo "SCO_HREF_SKIPPED: $sco_href"; continue ;; esac
  [ -f "$IMPORT_DIR/$sco_href" ] || continue
  # The package can contain symlinks: refuse a symlink, and a folder outside the import folder.
  _SCO_DIR=$(cd -P "$(dirname "$IMPORT_DIR/$sco_href")" && pwd -P)
  case "$_SCO_DIR/" in "$_IMPORT_REAL"/*) ;; *) echo "SCO_HREF_SKIPPED: $sco_href"; continue ;; esac
  [ -L "$IMPORT_DIR/$sco_href" ] && { echo "SCO_HREF_SKIPPED: $sco_href"; continue; }
  echo "=== SCO: $sco_href ==="
  cat "$IMPORT_DIR/$sco_href"
done
```

**From `<metadata>` (if present):**
- Course title, description, keywords
- Schema version

### E6. Map to course structure

From the parsed manifest, construct the course structure:

1. **Course title:** From `<metadata>` or the root organization title
2. **Modules:** Each top-level `<item>` with children becomes a module
3. **Content items:** Leaf `<item>` elements become module items
4. **Learning objectives:** Search SCO HTML content for objective-like statements
   ("By the end of...", "Students will...", "Learners will be able to...")
5. **Assessments:** Look for quiz/assessment patterns in SCO content (question banks,
   score tracking via SCORM API calls in JavaScript)
6. **Sequencing (SCORM 2004 only):** If `<imsss:sequencing>` elements exist, extract
   prerequisite relationships and flow control rules

**Articulate-specific parsing:** If the manifest contains `articulate` or `rise` in
metadata or resource identifiers, note the authoring tool. Articulate packages often
structure content as: one SCO per lesson, with a `story.html` or `index.html` launch
file. Rise packages use a flat structure with a single SCO.

### E7. Cleanup

```bash
IMPORT_DIR=<IMPORT_DIR printed above>
rm -rf "$IMPORT_DIR"
```

Continue to Step 1b (Prepare the report).

---

## Step 1b: Prepare the report

All of the input paths come to this step after they extract the course structure.
idstack adds each section to the import report as a draft. The user approves each section.

**Start the report.** In this command, replace `<project name>` with the course title from the import. Replace `<mode>` with the source and the source LMS, for example `cartridge from canvas`. The source is one of `cartridge`, `paste`, `canvas-api`, `pdf` or `scorm`. The source LMS is one of `canvas`, `blackboard`, `moodle`, `d2l`, `rise`, `storyline` or `unknown`. Then run the command.

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
# Compute the course slug from this session's course title and prepare the export folder.
# Do not read project_name from the manifest here. Step 6 writes it, so on a first import
# the manifest has no name yet and the report lands in exports/untitled-course/.
IFS= read -r _PROJECT_NAME <<'IDSTACK_PROJECT_NAME'
<project name>
IDSTACK_PROJECT_NAME
_SLUG=$("$_IDSTACK/scripts/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
[ "$_SLUG" = "project-name" ] && { echo "PROJECT_NAME_NOT_SET: replace <project name> with the course title and run this command again."; exit 1; }
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/course-import.md"
mkdir -p "$_EXPORT_DIR"
echo "Report template: $_IDSTACK/templates/report.md.tmpl"
echo "Report rules: $_IDSTACK/templates/report-format.md"
echo "Evidence list: $_IDSTACK/evidence/references.md"
echo "Report path: $_REPORT_PATH"
if [ -x "$_IDSTACK/scripts/idstack-report-section" ] && command -v python3 >/dev/null 2>&1; then "$_IDSTACK/scripts/idstack-report-section" init "$_REPORT_PATH" --skill course-import --title "Course Import Report" --project "$_PROJECT_NAME" --mode "<mode>"; else echo "REPORT_SECTION_MISSING: $_IDSTACK"; fi
```

Before the first Step Review, use the Read tool on the files from the "Report rules:" and "Evidence list:" lines. The `templates/` and `evidence/` paths are in the idstack plugin folder, not in the course project.

**Step review:** do the Step Review in the preamble. Section: `## Imported structure`. Columns: `ID | Module | Items | Objectives | Assessments | Activities | Pages | Rubrics`.

Write one row for each module, with the IDs `M-1`, `M-2` and so on. Write the number of items, objectives, assessments, activities and discussions, content pages and rubrics in each module. Put a page or a rubric that is in no module in a row with the ID `M-0` and the module name `No module`.

Write a last row with the ID `TOTAL` and the totals. In the Module cell of that row, write the number of modules. For a SCORM package, write one sentence above the table with the SCORM version, the authoring tool and the number of SCOs and assets. If the user selects "Change a row", put the corrections of the user in the extracted structure. The next steps use the corrected structure.

---

## Step 2: Quick-Scan Quality Flags

After extracting course structure from ANY input method, scan for obvious quality
issues. This is NOT a full /idstack:course-quality-review. This is a quick triage that
flags problems visible in the structural data alone.

**Structural flags:**
- Count modules vs modules with stated objectives. Flag if < 50% have objectives:
  "⚠ {X} of {Y} modules have no stated learning objectives [Alignment-1] [T5]"
- Count assessments with rubrics vs without. Flag if < 25% have rubrics:
  "⚠ {X} of {Y} assessments have no rubric [Assessment-8] [T1]"
- Check for discussion/collaborative activities. Flag if zero:
  "⚠ No discussion or collaborative activities found — social presence gap risk
  [Online-15] [T4]"
- Check for accessibility info. Flag if none:
  "⚠ No accessibility information found for course materials [Access-1] [T5]"
- Check for learner support resources. Flag if none:
  "⚠ idstack found no learner support section (tutoring, office hours, tech support)
  [Online-3] [T5]"

**Alignment flags:**
- If objectives exist AND assessments exist but no clear mapping between them:
  "⚠ The course has objectives and assessments, but idstack found no alignment matrix between them
  [Alignment-1] [T5]"
- If all assessments are the same type (e.g., all quizzes):
  "⚠ All {X} assessments are {type}. idstack recommends different assessment types for different
  Bloom's levels [Assessment-10] [T1]"

**Assessment feedback flags:**
- If quizzes are auto-graded with no indication of elaborated feedback:
  "⚠ idstack found auto-graded assessments. Elaborated feedback (that explains WHY) increases
  learning more than correctness-only feedback [Assessment-8] [T1]"

**Step review:** do the Step Review in the preamble. Section: `## Import quality triage`. Columns: `ID | Flag | Severity | Justification | Evidence`.

Write one row for each flag, with the IDs `Q-1`, `Q-2` and so on. Write the Severity as `critical`, `warning` or `info`. Use the citation that the list above gives for the flag. A flag with no citation, for example "interactive element not captured in PDF", goes in the Limitations section. Before the table, write one sentence: these flags are quick observations from the course structure, not a full review.

If idstack found zero flags, do not do this Step Review. Tell the user: "idstack found no structural problems in the import. Run
/idstack:course-quality-review for a deeper analysis." Write this result in the Summary.

---

## Step 3: Auto-Map Modules to Task Analysis

For each module extracted from the course, infer a task analysis entry. The goal
is to pre-populate the `needs_analysis.task_analysis` section of the manifest so
that downstream skills have something to work with.

For each module:

1. **Description:** Rewrite the module title as a performance-oriented task
   statement. "Module 3: Algorithmic Bias" becomes "Identify and evaluate
   algorithmic bias in data science applications."

2. **Frequency:** Estimate based on module position and content:
   - Early foundational modules → skills used daily/weekly
   - Applied/project modules → skills used weekly/monthly
   - Specialized/capstone modules → skills used monthly/rarely

3. **Criticality:** Estimate based on assessment weight (if available) and topic:
   - Core skills with heavy assessment weight → high
   - Supporting skills → medium
   - Enrichment/optional topics → low

4. **Difficulty:** Estimate based on Bloom's level (if objectives available):
   - Remember/Understand → low
   - Apply/Analyze → medium
   - Evaluate/Create → high

Assign task IDs: T-1, T-2, T-3, etc.

**Step review:** do the Step Review in the preamble. Section: `## Inferred task analysis`. Columns: `ID | Task | Source module | Frequency | Criticality | Difficulty | Justification | Evidence`.

Write one row for each task. In the Source module cell, write the module ID from the Imported structure section. Cite `[Needs-8] [T3]` for the task analysis.

Before the table, write two sentences. The estimates come from the module structure. The user can change each estimate that is not correct for the course. If the user selects "Change a row", use the new estimate of the user.

---

## Step 4: Bloom's Level Inference

For any learning objectives or outcomes found during import, pre-classify them
using the revised Bloom's taxonomy.

For each objective:

1. **Extract the action verb** — identify the primary verb in the objective
2. **Classify knowledge dimension:**
   - Factual (terminology, specific details)
   - Conceptual (categories, principles, theories)
   - Procedural (techniques, methods, criteria for use)
   - Metacognitive (self-knowledge, strategic planning)

3. **Classify cognitive process:**
   - Remember (recognize, recall)
   - Understand (interpret, exemplify, classify, summarize, infer, compare, explain)
   - Apply (execute, implement)
   - Analyze (differentiate, organize, attribute)
   - Evaluate (check, critique)
   - Create (generate, plan, produce)

4. **Confidence level:**
   - High: verb maps clearly to one Bloom's level
   - Ambiguous: verb could map to multiple levels (e.g., "analyze", "demonstrate")
     Mark as "check with /idstack:learning-objectives" [Alignment-12] [T4]

5. **Set alignment_status to "imported-unverified"** — the user should run
   /idstack:learning-objectives to verify and check bidirectional alignment

Assign ILO IDs: ILO-1, ILO-2, etc.

**Step review:** do the Step Review in the preamble. Section: `## Bloom's classification`. Columns: `ID | Objective | Knowledge | Process | Confidence | Justification | Evidence`.

Write one row for each objective. Write the Confidence as `high` or `ambiguous`. Cite `[Alignment-7] [T4]` for a high-confidence row and `[Alignment-12] [T4]` for an ambiguous row. Before the table, write one sentence: all classifications have the status "imported-unverified", and `/idstack:learning-objectives` checks the Bloom's levels and the alignment with activities and assessments.

If the import found no objectives, do not do this Step Review. Write this result in the Limitations section.

---

## Step 5: Findings and Report

**Step review:** do the Step Review in the preamble. Section: `## Findings`. Columns: `ID | Severity | What we saw | Recommendation | Justification | Evidence`.

Use the finding IDs `import-1`, `quality-1`, `bloom-1` and so on. The findings come from the approved import quality flags, missing rubrics, missing objectives, alignment that is broken on arrival, and ambiguous Bloom's classifications.

**Step review:** do the Step Review in the preamble. Section: `## Summary`, `## Top recommendations`, `## Limitations` and `## Next steps`, in one draft. Columns: `ID | Action | Justification | Evidence` for Top recommendations.

- **Top recommendations:** three to five actions from the approved findings, with the IDs `R-1`, `R-2` and so on. Put the action with the most effect first.
- **Summary:** two or three sentences. Tell what came in: the number of modules, objectives, assessments, activities and discussions, pages and rubrics. Tell the number of quality flags. Then tell the most important thing for the designer, for example "The structure of the import is clean, but the course has few objectives." or "8 of 12 modules have no rubric."
- **Limitations:** the quality triage uses the course structure only, and it is not a full review. The import reads a maximum of 10 resource files from a cartridge and the first 50 pages of a PDF. Interactive elements (Storyline, flashcards) do not show in a PDF. The Canvas token stays in `.idstack/canvas.env` on the user's computer. idstack does not write it to the manifest or the report. The import can miss data in SCORM packages that have non-standard manifest extensions. Add each flag that has no citation.
- **Next steps:** run `/idstack:course-quality-review` for the full evidence-based audit. Run `/idstack:learning-objectives` to check the Bloom's classification and the alignment in the two directions. Run `/idstack:needs-analysis` to add the organizational context and the learner profile that idstack cannot get from the course structure.

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

## Step 6: Write Manifest

Create or update the project manifest with one atomic call to `scripts/idstack-manifest-merge`.
course-import adds fields to sections that other skills also write (`context`,
`needs_analysis`, `learning_objectives`), and it owns `import_metadata`. The merge tool
replaces whole sections, so for each co-owned section: read the existing section from the
manifest (if any), add the imported fields to it, and pass the full merged section.

Write each payload with the Write tool first, as the flat section contents with no
enclosing section key: `.idstack/.context-payload.json`, `.idstack/.needs_analysis-payload.json`,
`.idstack/.learning_objectives-payload.json` and `.idstack/.import_metadata-payload.json`. Then:

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
IFS= read -r _PROJECT_NAME <<'IDSTACK_PROJECT_NAME'
<project name>
IDSTACK_PROJECT_NAME
"$_IDSTACK/scripts/idstack-manifest-merge" --create --set project_name="$_PROJECT_NAME" \
  --section context --payload .idstack/.context-payload.json \
  --section needs_analysis --payload .idstack/.needs_analysis-payload.json \
  --section learning_objectives --payload .idstack/.learning_objectives-payload.json \
  --section import_metadata --payload .idstack/.import_metadata-payload.json \
  && rm -f .idstack/.context-payload.json .idstack/.needs_analysis-payload.json \
           .idstack/.learning_objectives-payload.json .idstack/.import_metadata-payload.json
```

`--create` makes a canonical manifest first if `.idstack/project.json` does not
exist yet (the standalone case). It never replaces a manifest that exists. If any payload is malformed, the tool
writes nothing.

**CRITICAL — Manifest Integrity Rules:**
1. PRESERVE what other skills wrote in the co-owned sections (especially
   needs_analysis from /idstack:needs-analysis). Import ADDS to these sections, does not
   replace them.
2. If learning_objectives already has data and the user chose "merge," combine
   imported ILOs with existing ones (use new ILO IDs that don't conflict).
3. Include the COMPLETE section structure from the schema below. Do not omit fields.
4. Before writing, verify each payload is valid JSON.
5. **NEVER write the Canvas API token to the manifest, the report, or any file other than `.idstack/canvas.env`.**

**Fields populated by /idstack:course-import:**

- `project_name` — from course title. Use the text that you put in place of `<project name>` in Step 1b.
- `context.modality` — inferred from course structure (async=online, sync sessions=hybrid)
- `context.timeline` — from term/date info if available
- `context.available_tech` — from detected resource types (LMS, video, discussions, etc.)
- `needs_analysis.task_analysis.job_tasks` — from module-to-task mapping (Step 3)
- `learning_objectives.ilos` — from Bloom's inference (Step 4)

- `learning_objectives.alignment_matrix` — partial, from detected objective-assessment links

Use only the approved rows of the report. `job_tasks` has the approved `T-` rows. `ilos` has the approved `ILO-` rows, with the status "imported-unverified". The `items_imported` counts come from the `TOTAL` row of the approved Imported structure section (`rubrics` from its Rubrics column). Write 0 for a count that the table does not have. `quality_flags` is the number of approved rows in the Import quality triage section.

**Import metadata:** The `import_metadata` payload (flat, with no enclosing `import_metadata` key):

```json
{
  "source": "cartridge|paste|canvas-api|pdf|scorm",
  "report_path": "<set to $_REPORT_PATH from the Step 1b bash block — e.g. .idstack/exports/<course-slug>/course-import.md>",
  "imported_at": "ISO-8601",
  "source_lms": "canvas|blackboard|moodle|d2l|rise|storyline|unknown",
  "source_cartridge": "<file name of the cartridge or package, or empty>",
  "source_size_bytes": 0,
  "schema": "<cartridge or SCORM schema version, or empty>",
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
}
```

Write the manifest, then confirm. Write the message as Markdown text, not in a code block, so that the link works:

"The import is complete: {N} modules, {M} learning objectives, {P} assessments and {F} quality flags.
Read the report: <the Report path, written as a link as the Report Links section of the preamble tells you>.
Next step: `/idstack:course-quality-review`."

Do not repeat the counts by type, the quality flags or the list of next steps in the
chat. The Summary, Imported structure and Next steps sections of the report have them.

---

## Manifest Schema Reference

The idstack manifest lives at `.idstack/project.json`. Schema version: **1.4**.

This is the canonical schema. Every skill writes to its own section using the shapes documented here; **all other sections must be preserved verbatim**. There is one source of truth — this file. If the schema ever needs to change, edit `templates/manifest-schema.md`, run `scripts/idstack-gen-skills`, and bump `LATEST_VERSION` in `scripts/idstack-migrate` with a migration step.

### Two outputs per skill: JSON manifest + Markdown report

Every skill that produces findings emits **both**:

- a **JSON section** in this manifest (system state — read by other skills, the pipeline orchestrator, and `scripts/idstack-status`), and
- a **Markdown report** at `.idstack/exports/<course-slug>/<skill>.md` (the human view — read by the instructional designer).

The Markdown report follows the skeleton in `templates/report.md.tmpl` and the content contract in `templates/report-format.md` (observation → evidence → why-it-matters → recommendation, with severity and evidence tier on every finding). The skill writes the report's relative path back into its own section's `report_path` field so other skills can find it. (`scripts/idstack-status` discovers reports independently by globbing `.idstack/exports/<course-slug>/*.md`, so the dashboard survives a stale `report_path`.)

`<course-slug>` is derived from the top-level `project_name` field via `scripts/idstack-slugify` (rule: NFKD-fold, lowercase, kebab-case, ASCII-safe; empty input → `untitled-course`). The slug is computed deterministically — skills don't cache it in the manifest. All exports for a course — per-skill Markdown reports, the pipeline dashboard at `index.md`, and LMS packages (`course-export.imscc`, `scorm-export.zip`) — live under the same `.idstack/exports/<course-slug>/` folder so the deliverable is self-describing when zipped, emailed, or handed off.

`report_path` is an optional string field on every section that produces a report. It is a path relative to the project root (typically `.idstack/exports/<course-slug>/<skill>.md`). Empty string means the skill hasn't run yet, or ran in a mode that didn't produce a report. Renaming a course's `project_name` changes the slug, which moves future exports to a new folder; older folders are left in place.

### Two ways to write to the manifest

**1. Recommended — `scripts/idstack-manifest-merge`:** write only your sections, the tool merges atomically.

```bash
# Run this in a block that starts with your skill's own idstack resolve lines,
# so $_IDSTACK is set. Pass your skill's section on stdin (a heredoc), not a /tmp file:
"$_IDSTACK/scripts/idstack-manifest-merge" --create --section red_team_audit --payload - <<'PAYLOAD'
{ ...your section's JSON... }
PAYLOAD
```

(Skills also read this file raw, so it carries no `IDSTACK_RESOLVE` placeholder
and no copy of the resolve lines.)

The merge tool replaces only the named top-level sections, preserves every other section, updates the top-level `updated` timestamp, validates JSON on read, and rejects unknown sections. When there is no manifest, `--create` first makes one with `scripts/idstack-migrate --init`. That manifest is at the current schema version and has every top-level section, but a section can lack fields until its skill writes it. Repeat `--section`/`--payload` to write several sections in one atomic write, and use `--set project_name=<value>` for the top-level name. Use this in preference to inlining the full manifest in `Edit` operations.

**2. Fallback — manual full-manifest write:** if the merge tool is unavailable for some reason, Read the full manifest, modify only your section, Write back. Preserve all other sections verbatim. Use the full schema below as reference.

### Top-level fields

| Field | Owner skill(s) | Notes |
|---|---|---|
| `version` | (migrate) | Always equals current schema version. Auto-managed by `scripts/idstack-migrate`. |
| `project_name` | needs-analysis, course-import | `scripts/idstack-migrate --init` writes `""`. needs-analysis and course-import write it with `--set project_name=<v>` on every run, so the last of them to run sets the name and the export folder. In audit-existing mode, needs-analysis reuses the name that course-import wrote. Other skills do not write it. |
| `created` | (any, once) | ISO-8601 timestamp of first creation. Don't overwrite. |
| `updated` | (any) | ISO-8601 of last write. Updated automatically by `scripts/idstack-manifest-merge`. |
| `context` | needs-analysis, course-import | Modality, timeline, class size, etc. Edited by skills that learn new context. |
| `needs_analysis` | needs-analysis, course-import | Org context, task analysis, learner profile, training justification. |
| `learning_objectives` | learning-objectives, course-import, assessment-design | ILOs, alignment matrix, expertise-reversal flags. assessment-design reads the section, adds its fields and writes the whole section. In Mode 2 (no ILOs), and in Mode 3 when its step 0 asked for the objectives, it also writes the `ilos` that it classified. |
| `assessments` | assessment-design | Items (each with its rubric and, in Mode 1 and Mode 2, its feedback strategy), formative checkpoints and the feedback quality score (Mode 1 and Mode 2), and audit notes (Mode 3). No skill writes `assessment_strategy`, `feedback_plan` or the top-level `rubrics[]`. Mode 3 reads `assessments.rubrics` if it exists. |
| `course_content` | course-builder | Generated modules, syllabus, content paths. |
| `import_metadata` | course-import | Source, source LMS, import time, items imported, and the count of approved quality flags. The flag details are in the course-import report. |
| `export_metadata` | course-export | Export destination, items exported, readiness check. |
| `quality_review` | course-quality-review | QM standards, CoI presence, alignment audit, cross-domain checks, scores. No skill writes `review_history`. `scripts/idstack-migrate` adds it as `[]`, and a /idstack:course-quality-review write replaces the whole section, so the field and its contents are removed. The timeline (`.idstack/timeline.jsonl`) keeps the score of each review. |
| `red_team_audit` | red-team | Confidence score, dimensions, findings (with stable ids), top actions. |
| `accessibility_review` | accessibility-review | WCAG / UDL scores, violations, recommendations, quick wins. |
| `preferences` | (user, by hand) | Verbosity, export format, preferred LMS, auto-advance. `scripts/idstack-migrate` writes the defaults. No skill writes this section; the preamble reads `verbosity`. |

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

**`learning_objectives.alignment_matrix.ilo_to_assessment`** — same shape. `/idstack:learning-objectives` writes arrays of assessment titles. `/idstack:assessment-design` replaces them with arrays of assessment IDs (`"A-1"`). A skill that reads this map must accept both.

**`learning_objectives.alignment_matrix.gaps[]`** — `/idstack:assessment-design` writes each item as the object below. `/idstack:learning-objectives` writes each item as a string that describes the gap. A skill that reads `gaps[]` must accept both forms.
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
  "objective": "Analyze competitive forces in...",
  "knowledge_dimension": "factual|conceptual|procedural|metacognitive",
  "cognitive_process": "remember|understand|apply|analyze|evaluate|create"
}
```
`/idstack:course-import` can also add `"confidence": "high|ambiguous"` and `"alignment_status": "imported-unverified"`. `/idstack:learning-objectives` checks these items again. `/idstack:assessment-design` Mode 2, and Mode 3 when its step 0 asked for the objectives, write items in the same shape.

**`assessments.items[]`** — `/idstack:assessment-design` writes each item (`/idstack:course-import` does not write this array):
```json
{
  "id": "A-1",
  "title": "Module 1 Quiz",
  "type": "quiz|essay|project|case-study|peer-review|portfolio|presentation",
  "format": "formative|summative",
  "aligned_ilos": ["ILO-1", "ILO-3"],
  "rubric": {
    "criteria": [
      { "name": "Criterion name", "weight": 40,
        "levels": { "exceeds": "...", "meets": "...", "approaching": "...", "below": "..." } }
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
```
The audit of an imported course (Mode 3) also adds `"alignment_status": "weak|moderate|strong"`.

**`assessments.rubrics[]`** — each item:
```json
{
  "id": "rubric-1",
  "title": "SM Project Rubric",
  "criteria": [{"name": "...", "blooms_level": "...", "weight": 0}],
  "applies_to": ["A-3"]
}
```

**`import_metadata.quality_flag_details[]`** — each item. No skill fills this array. `scripts/idstack-migrate` creates it empty, or fills it when it moves a legacy `_import_quality_flags` root field. `/idstack:course-import` writes it as an empty array, which replaces any details that `scripts/idstack-migrate` moved there, and writes the count in `quality_flags`. The flag details are in its report (Import quality triage section):
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

**`quality_review.qm_standards.<standard>.findings[]`**, **`quality_review.coi_presence.<presence>.findings[]`** and **`quality_review.alignment_audit.findings[]`** — each item is a plain string. `/idstack:course-quality-review` writes one short finding sentence per item, for example `"findings": ["Syllabus has no course-level objectives."]`. **`quality_review.cross_domain_checks.<check>.flags[]`** has no fixed item shape. The skill writes a list of flags, or `[]` when the check found nothing. The severity and evidence tier of quality-review findings are in `quality_review.recommendations[]` and `quality_review.quick_wins[]`, not in these arrays.

### Mode field — design-new vs audit-existing

`needs_analysis.mode` and `course_content.mode` record which operating mode the corresponding skill ran in. Trigger: `needs_analysis.mode` is `audit-existing` when `import_metadata.source` is `cartridge`, `scorm` or `canvas-api` and `import_metadata.items_imported.modules > 0`. `course_content.mode` is `gap-fill` when `import_metadata.source` is one of those values and `import_metadata.items_imported.modules > 0` or `course_content.modules` is non-empty. assessment-design's Mode 3 uses the same source values with `import_metadata.items_imported.assessments > 0`, `assessments.items` or `course_content.assessments`. `assessments.mode` is in the schema, but `/idstack:assessment-design` does not write it. The skill records its mode (Mode 1, Mode 2 or Mode 3) only in the report's header metadata line under the title, as `mode: Mode N` (`idstack-report-section init --mode`).

Allowed values per skill:
- `needs_analysis.mode`: `"design-new"` or `"audit-existing"`
- `assessments.mode`: not written by the current skill. The report records the mode: `"Mode 1"` = full upstream data, `"Mode 2"` = ILOs-from-scratch, `"Mode 3"` = audit existing assessments
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
  "source": "red-team:alignment-3 | quality-review:<short form of the recommendation's finding text> | user-request",
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
{"skill":"course-import","event":"completed"}
IDSTACK_EVENT
"$_IDSTACK/scripts/idstack-timeline-log" "$_EVENT"
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

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
{"skill":"course-import","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}
IDSTACK_LEARNING
"$_IDSTACK/scripts/idstack-learnings" log "$_LEARNING"
```
