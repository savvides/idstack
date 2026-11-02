---
name: course-export
description: |
  Export course content to an LMS. Generates IMS Common Cartridge files (.imscc) for
  Canvas, Blackboard, Moodle, and D2L, a SCORM 1.2 package, or pushes directly to Canvas
  through the REST API. Reads the /idstack:course-builder output and the idstack
  manifest. Use when asked to export, package, upload, or publish a course to an LMS or
  to Canvas. (idstack)
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
  not write a Top recommendations section. Then run the finish command with
  `--stopped` after `finish "<path>"`. Do not do a Step Review for a score section
  that has no data: `--stopped` writes a note in it. This includes an error, a
  missing file, and a user who stops the skill.
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

**Skill-specific manifest check:** If the manifest `export_metadata` section already has data,
ask the user: "You ran this skill previously. Do you want to update the results or start again?"

# Course Export — IMS Common Cartridge & Canvas API

You are a course export partner. Your job is to take the content generated by
/idstack:course-builder and package it for import into any Learning Management System.
You are the last mile between generated course content and a live course that
students can access.

Three export paths:
1. **IMS Common Cartridge (.imscc)** — Universal format. Works with every major
   LMS: Canvas, Blackboard, Moodle, D2L/Brightspace. You generate a standards-
   compliant package file that the instructional designer imports through their
   LMS admin interface. Zero API credentials needed.
2. **Canvas REST API** — Canvas-specific, richest integration. Pushes modules,
   pages, assignments, and discussions directly to a Canvas course instance.
   Requires an access token. Results appear immediately in Canvas.
3. **SCORM 1.2 package (.zip)** — Standard e-learning format. You generate a
   SCORM ZIP that the instructional designer uploads to an LMS or a SCORM
   player. Zero API credentials needed.

The output IS the course. You are not generating a spec, a plan, or a description
of what the course should contain. You are generating the actual importable
course content: HTML pages, assignment definitions, quiz questions, and the
manifest that ties them together. The instructional designer should be able to
import your output and have a functioning course shell ready for review.

You read from two sources:
- The `.idstack/course-content/` directory, where /idstack:course-builder writes its
  generated files (syllabus, module content, assessments, rubrics)
- The `.idstack/project.json` manifest, which contains the course structure,
  learning objectives, and alignment data from upstream skills

## Evidence Tier Key

Every recommendation includes its evidence tier in brackets:
- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

When multiple tiers apply, cite the strongest.

---

## Course Content Inputs

The shared preamble above already ran the manifest existence check
(`MANIFEST_EXISTS` / `NO_MANIFEST`) and this skill's re-run question.

Before starting the export, verify that generated course content exists:

```bash
if [ -d ".idstack/course-content" ]; then
  echo "CONTENT_EXISTS"
  ls -la .idstack/course-content/
else
  echo "NO_CONTENT"
fi
```

**If NO_MANIFEST or NO_CONTENT:**
Tell the user: "idstack must have generated course content to export. Run `/idstack:course-builder`
first to generate your syllabus, modules, and assessments. The builder reads
your manifest and produces the files I package for your LMS."

**If MANIFEST_EXISTS but no `course_content` section:**
Check whether `.idstack/course-content/` has files. If it does, proceed using
the files directly. If not, nudge for /idstack:course-builder.

---

## Prepare Course Export Folder

Every artifact this skill produces — the Markdown report, the LMS package — lands
under `.idstack/exports/<course-slug>/`, alongside the per-skill reports
produced by the rest of the pipeline. Compute the slug and prepare the folder
now, then reuse `$_EXPORT_DIR` throughout the workflow:

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
# Course-slug-based export folder. Required before any artifact write.
_SLUG=$("$_IDSTACK/bin/idstack-slugify" --from-manifest 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/course-export.md"
mkdir -p "$_EXPORT_DIR"
echo "Report template: $_IDSTACK/templates/report.md.tmpl"
echo "Report rules: $_IDSTACK/templates/report-format.md"
echo "Evidence list: $_IDSTACK/evidence/references.md"
echo "Course export folder: $_EXPORT_DIR"
echo "Report path: $_REPORT_PATH"
if [ -x "$_IDSTACK/bin/idstack-report-section" ] && command -v python3 >/dev/null 2>&1; then "$_IDSTACK/bin/idstack-report-section" init "$_REPORT_PATH" --skill course-export --title "Course Export Report"; else echo "REPORT_SECTION_MISSING: $_IDSTACK"; fi
```

Before the first Step Review, use the Read tool on the files from the "Report rules:" and "Evidence list:" lines.

All subsequent paths (`.imscc`, SCORM `.zip`, Markdown report) write into
`$_EXPORT_DIR`, never directly into `.idstack/`. The folder becomes the
canonical, self-describing deliverable — open `index.md` to navigate, or
zip the whole folder to hand to a stakeholder.

---

## Pre-Export Readiness Check

Before you start the export, run the readiness dashboard:

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
"$_IDSTACK/bin/idstack-status" --readiness
```

**Step review:** do the Step Review in the preamble. Section: `## Readiness`. Columns: `ID | Check | Value | Threshold | Status`.

Write one row for each line of the readiness output. R-1 is the quality review, R-2 is the red team audit, R-3 is the accessibility review and R-4 is the verdict. Copy the values, the thresholds and the status from the output.

The verdict changes the question of the Step Review:

- **READY TO EXPORT:** Ask the usual question of the Step Review.
- **NOT-READY or INCOMPLETE:** After the append command (step 4 of the Step Review), the Readiness section is in the report as a draft. Ask one question with AskUserQuestion. This question replaces the usual question. Ask: "The readiness check found problems. Do you approve this section and export the course?" The options and their descriptions are "Approve and export" ("Keep this section and make the package"), "Correct the problems first" ("Stop the export now") and "Change a row" ("Tell me the row ID and the change"). If the verdict is INCOMPLETE, write the second option as "Run those skills first".
- If the user selects "Approve and export", run the approve command (step 8 of the Step Review). Continue the export only if the output starts with `SECTION_APPROVED`.
- If the user selects "Change a row", do step 7 of the Step Review. Then ask this question again.
- If the user selects "Correct the problems first" or "Run those skills first", run the approve command of the Step Review for the Readiness section. Then do the last Step Review (see "Generate Export Report"), with its append and approve commands. In the Summary, tell that the export stopped before the package and give the verdict. Do not write a Top recommendations section. Then run the finish command and stop this skill. Tell the user which skills to run, from the verdict line.

The readiness check gives advice only. The user can always export the course.

---

## Writing Standard Check (course content)

If the course content is not in English, do not run this check. Go to "Export Format Selection". If the course content is in English, run the ASD-STE100 checker on it before you make a package or send content to Canvas. This check only shows problems. Do not change the course files. The designer wrote this text or gave approval to it.

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
if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-ste-check" ".idstack/course-content"; fi
```

1. If the output is `STE_CHECK_UNAVAILABLE` or starts with `STE_CHECK_MISSING:`, do step 5 or step 6 of "How to use the standard" in the preamble. Continue the export.
2. If the checker shows no problems, continue the export.
3. If the checker shows problems, tell the user only the number of problems and the files with problems. Then use AskUserQuestion with two alternatives: "Continue the export" and "Stop the export to correct the content".
4. If the user selects "Stop the export to correct the content", do the last Step Review (see "Generate Export Report"), with its append and approve commands. In the Summary, tell that the export stopped before the package because the course content has writing problems. Do not write a Top recommendations section. Then run the finish command and stop this skill. Tell the user to correct the files in `.idstack/course-content/` and then run `/idstack:course-export` again.
5. If the checker shows an error, tell the user which files the checker did not read. Then continue with the steps above for the problems that it shows.

The package files (HTML pages, XML files and quiz text) get no file check. When you write text for the package, for example quiz questions, quiz feedback or item titles, obey the "Writing Standard (ASD-STE100)" section of the preamble.

---

## Export Format Selection

Ask the user how they want to export. Use AskUserQuestion:

"How do you want to export your course?"

Options:
- **A) IMS Common Cartridge (.imscc)** — Universal format. Import into Canvas,
  Blackboard, Moodle, D2L. No API credentials needed. Produces a single file
  you upload through your LMS admin interface.
- **B) Canvas API** — Push directly to a Canvas course. Modules, pages,
  assignments, and discussions appear immediately. Requires a Canvas access
  token and course ID.
- **C) SCORM 1.2 package (.zip)** — Standard e-learning format. Works with every
  LMS, every authoring tool, and every corporate training platform. Produces a
  SCORM-compliant ZIP you upload to any LMS or host on any SCORM player.

---

## Export Plan

Do this step after the path reads the course content (A1, B3 or C1). Do it before you write a package file or send a request that changes Canvas.

**Step review:** do the Step Review in the preamble. Section: `## Export plan`. Columns: `ID | Item type | Count | Conversion | Justification | Evidence`.

Write one row for each item type that the selected path exports, with IDs `EP-1`, `EP-2` and so on. In the Conversion cell, write what idstack makes from the Markdown, for example "HTML page", "QTI quiz with elaborated feedback" or "Canvas assignment, not published".

Use these citations. For the syllabus, use `[Online-2] [T4]`. For module pages with their heading structure, use `[Access-1] [T5]`. For assignments with their rubric in the description, use `[Assessment-19] [T1]`. For quizzes with elaborated feedback, use `[Assessment-10] [T1]`. For discussions, use `[Online-18] [T1]`.

Export only the item types in the approved rows. If the user removes a row, do not write files or send Canvas requests for that item type.

---

## Path A: IMS Common Cartridge Export

### A1. Read Course Content Files

Read all files in `.idstack/course-content/`:

```bash
find .idstack/course-content/ -type f | sort
```

Read each file to understand the content structure. Expect files like:
- `syllabus.md` — Course syllabus
- `module-01.md`, `module-02.md`, etc. — Module content pages
- `assessment-01.md`, `assessment-02.md`, etc. — Assignment and quiz specs
- `rubric-01.md`, `rubric-02.md`, etc. — Rubric definitions
- `discussion-01.md`, `discussion-02.md`, etc. — Discussion prompts

Also read the manifest to get the course title, module structure, and ILO
alignment data. The manifest provides the organizational spine; the content
files provide the body.

Then do the "Export Plan" step. Go to A2 only after the user approves the plan.

### A2. Generate imsmanifest.xml

The manifest XML defines the course structure for the LMS. Generate it following
the IMS Common Cartridge 1.3 specification:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest identifier="idstack-export-{uuid}"
  xmlns="http://www.imsglobal.org/xsd/imsccv1p3/imscp_v1p1"
  xmlns:lom="http://ltsc.ieee.org/xsd/LOM">
  <metadata>
    <schema>IMS Common Cartridge</schema>
    <schemaversion>1.3.0</schemaversion>
    <lom:lom>
      <lom:general>
        <lom:title><lom:string>{course title}</lom:string></lom:title>
      </lom:general>
    </lom:lom>
  </metadata>
  <organizations>
    <organization identifier="org-1" structure="rooted-hierarchy">
      <item identifier="root">
        <!-- One item per module -->
        <item identifier="mod-1" identifierref="res-mod-1">
          <title>{Module 1 Title}</title>
          <!-- Nested items for module content -->
          <item identifier="mod-1-page-1" identifierref="res-mod-1-page-1">
            <title>{Page Title}</title>
          </item>
          <item identifier="mod-1-assign-1" identifierref="res-mod-1-assign-1">
            <title>{Assignment Title}</title>
          </item>
        </item>
        <!-- Repeat for each module -->
      </item>
    </organization>
  </organizations>
  <resources>
    <!-- Web content resources (module pages) -->
    <resource identifier="res-mod-1-page-1" type="webcontent"
              href="modules/mod-1-page-1.html">
      <file href="modules/mod-1-page-1.html"/>
    </resource>
    <!-- Assignment resources -->
    <resource identifier="res-mod-1-assign-1" type="assignment_xmlv1p0"
              href="assignments/assign-1.xml">
      <file href="assignments/assign-1.xml"/>
    </resource>
    <!-- Quiz resources (QTI) -->
    <resource identifier="res-mod-1-quiz-1" type="imsqti_xmlv1p2/imscc_xmlv1p0/assessment"
              href="quizzes/quiz-1.xml">
      <file href="quizzes/quiz-1.xml"/>
    </resource>
    <!-- Discussion resources -->
    <resource identifier="res-mod-1-disc-1" type="imsdt_xmlv1p0"
              href="discussions/disc-1.xml">
      <file href="discussions/disc-1.xml"/>
    </resource>
  </resources>
</manifest>
```

Key rules for manifest generation:
- Every content item in `<organizations>` must have a matching `<resource>` entry
- `identifierref` in organization items must match `identifier` in resources
- Generate a UUID for the manifest identifier (use `uuidgen` or equivalent)
- Use descriptive, slugified identifiers: `mod-1-page-1`, not `item-47`
- Include the syllabus as the first resource in the first module or as a
  standalone item at the root level

### A3. Convert Markdown to HTML

For each `.md` file in course-content, convert to clean HTML suitable for LMS
import. You do this conversion directly — no external tools needed.

**Conversion rules:**
- Convert all markdown formatting: headings, bold, italic, lists, links, tables,
  code blocks, blockquotes
- Wrap in a minimal HTML document structure:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>{page title}</title>
</head>
<body>
  {converted content}
</body>
</html>
```

- Use inline styles only for essential formatting. Do not reference external
  CSS — it will not transfer to the LMS. Keep styling minimal and semantic.
  The LMS applies its own theme.
- Preserve heading hierarchy: `# ` becomes `<h1>`, `## ` becomes `<h2>`, etc.
- Convert markdown tables to HTML `<table>` elements with basic borders:
  `<table style="border-collapse: collapse; width: 100%;"> ...`
- Convert markdown links to HTML `<a>` tags
- Convert code blocks to `<pre><code>` elements
- Convert images to `<img>` tags (if image files exist in course-content,
  include them in the package)

Save converted HTML files in the export directory structure:
- `modules/mod-{N}-page-{M}.html` for module content pages
- `syllabus.html` for the syllabus

### A4. Generate Assignment XML

For each assessment identified in the course content, generate the appropriate
XML format.

**For essay, project, and upload-type assessments — assignment XML:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<assignment identifier="assign-{id}"
  xmlns="http://www.imsglobal.org/xsd/imscc_extensions/assignment">
  <title>{title}</title>
  <text texttype="text/html">{description HTML}</text>
  <gradable points_possible="{points}">{grading type}</gradable>
  <submission_formats>
    <format type="online_text_entry"/>
    <format type="online_upload"/>
  </submission_formats>
</assignment>
```

Include rubric criteria in the description HTML if a rubric file exists for the
assessment. Format the rubric as an HTML table within the `<text>` element so
it is visible to both instructors and students after import.

**For quiz-type assessments — QTI XML (IMS Question & Test Interoperability):**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<questestinterop xmlns="http://www.imsglobal.org/xsd/ims_qtiasiv1p2">
  <assessment ident="quiz-{id}" title="{title}">
    <section ident="section-1">
      <!-- Multiple choice question -->
      <item ident="q-1" title="{question title}">
        <presentation>
          <material>
            <mattext texttype="text/html">{question text}</mattext>
          </material>
          <response_lid ident="resp-1" rcardinality="Single">
            <render_choice>
              <response_label ident="opt-a">
                <material>
                  <mattext>{option A text}</mattext>
                </material>
              </response_label>
              <response_label ident="opt-b">
                <material>
                  <mattext>{option B text}</mattext>
                </material>
              </response_label>
              <response_label ident="opt-c">
                <material>
                  <mattext>{option C text}</mattext>
                </material>
              </response_label>
              <response_label ident="opt-d">
                <material>
                  <mattext>{option D text}</mattext>
                </material>
              </response_label>
            </render_choice>
          </response_lid>
        </presentation>
        <resprocessing>
          <outcomes>
            <decvar maxvalue="1" minvalue="0" varname="SCORE" vartype="Decimal"/>
          </outcomes>
          <respcondition continue="No">
            <conditionvar>
              <varequal respident="resp-1">{correct option ident}</varequal>
            </conditionvar>
            <setvar action="Set" varname="SCORE">1</setvar>
            <displayfeedback feedbacktype="Response" linkrefid="correct"/>
          </respcondition>
        </resprocessing>
        <itemfeedback ident="correct">
          <flow_mat>
            <material>
              <mattext texttype="text/html">{feedback explaining why}</mattext>
            </material>
          </flow_mat>
        </itemfeedback>
      </item>
      <!-- Repeat for each question -->
    </section>
  </assessment>
</questestinterop>
```

**Quiz generation notes:**
- Generate questions from the assessment description, rubric criteria, and
  learning objectives mapped in the alignment matrix
- Include elaborated feedback for each question — not just "correct/incorrect"
  but explaining WHY the answer is right. Elaborated feedback produces
  significantly larger learning gains [Assessment-8] [T1]
- Quiz question generation is best-effort. The instructional designer should
  review and edit questions in the LMS after import. Flag this clearly:
  "idstack generated the quiz questions from your assessment specs. Review each
  question in your LMS before you publish the quiz to students."
- Support these question types: multiple choice, true/false, short answer
  (essay type in QTI)

**For discussion-type activities — discussion topic XML:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<topic xmlns="http://www.imsglobal.org/xsd/imsccv1p3/imsdt_v1p3">
  <title>{title}</title>
  <text texttype="text/html">{discussion prompt HTML}</text>
</topic>
```

### A5. Package as ZIP

Each Bash call runs in a new shell. Thus each block below sets its own paths.
The staging folder is in the course export folder, so the Write tool writes
inside the project.

First, make the staging folder. Replace `<export folder>` with the folder from
the "Course export folder:" line, then run the command:

```bash
_EXPORT_DIR="<export folder>"
_STAGE="$_EXPORT_DIR/.imscc-staging"
rm -rf "$_STAGE"
mkdir -p "$_STAGE/modules" "$_STAGE/assignments" "$_STAGE/quizzes" "$_STAGE/discussions"
echo "Staging folder: $_STAGE"
```

Then write each file into the staging folder with the Write tool:

- `imsmanifest.xml` at the root of the staging folder
- module HTML files in `modules/`
- assignment XML files in `assignments/`
- quiz QTI XML files in `quizzes/`
- discussion XML files in `discussions/`
- `syllabus.html` at the root of the staging folder

Write each file individually. Make sure that each file is correctly formed
before you make the package.

Then make the package. Replace `<export folder>` again, then run the command:

```bash
_EXPORT_DIR="<export folder>"
_STAGE="$_EXPORT_DIR/.imscc-staging"
_OUT="$(cd "$_EXPORT_DIR" && pwd)/course-export.imscc"
[ -f "$_STAGE/imsmanifest.xml" ] || { echo "PACKAGE_FAILED: $_STAGE/imsmanifest.xml is missing"; exit 1; }
rm -f "$_OUT"
( cd "$_STAGE" && zip -qr "$_OUT" . ) || { echo "PACKAGE_FAILED: zip error. The staging folder is still at $_STAGE"; exit 1; }
[ -s "$_OUT" ] || { echo "PACKAGE_FAILED: $_OUT is empty"; exit 1; }
rm -rf "$_STAGE"
echo "Export saved to $_EXPORT_DIR/course-export.imscc"
```

If the output starts with `PACKAGE_FAILED`, tell the user the error. Do not say
that the export is complete.

Do the Step Review of "Export Contents" with one row
for `course-export.imscc` and the status "failed: <error>". Then do the last Step Review (see "Generate Export Report"), with its append and approve commands. In the Summary, tell that the export failed and give the error. Do not write a Top recommendations section. Then run the finish command and stop this skill.

### A6. Verify the Package

Replace `<export folder>` with the folder from the "Course export folder:" line,
then run the command:

```bash
_EXPORT_DIR="<export folder>"
# Verify it's a valid zip
file "$_EXPORT_DIR/course-export.imscc"
# List contents
unzip -l "$_EXPORT_DIR/course-export.imscc"
# Count items
echo "---"
echo "Module pages: $(unzip -l "$_EXPORT_DIR/course-export.imscc" | grep 'modules/' | wc -l)"
echo "Assignments: $(unzip -l "$_EXPORT_DIR/course-export.imscc" | grep 'assignments/' | wc -l)"
echo "Quizzes: $(unzip -l "$_EXPORT_DIR/course-export.imscc" | grep 'quizzes/' | wc -l)"
echo "Discussions: $(unzip -l "$_EXPORT_DIR/course-export.imscc" | grep 'discussions/' | wc -l)"
```

Do not show this output in the chat. From it, collect the data for the rows of
"Export Contents": the package size and the number of module pages,
assignments, quizzes and discussions. Keep the package path
`.idstack/exports/<course-slug>/course-export.imscc` for the closing message.

---

## Path B: Canvas API Push

### B1. Get Credentials

idstack keeps your Canvas details in `.idstack/canvas.env`. Each Bash call
runs in a new shell, so each API command reads this file again. Your token
does not go into the chat.

Ask the user in plain chat (not AskUserQuestion, because the answers are free
text) for two items:

1. **Canvas URL** — Your institution's Canvas address
   (for example, `https://canvas.university.edu`)
2. **Course ID** — The number in the URL when you open the course
   (for example, `https://canvas.university.edu/courses/12345` → course ID is `12345`)
   Use an existing empty course shell, or create a new course first in Canvas.

Do NOT ask for the access token in the chat. If the user pastes a token in the
chat, tell them to revoke it in Canvas and make a new one.

Replace `<canvas url>` and `<course id>`, then run the command. It keeps a
token that is already in the file:

```bash
umask 077
mkdir -p .idstack
_TOKEN_LINE=$(grep '^CANVAS_TOKEN=' .idstack/canvas.env 2>/dev/null || echo "CANVAS_TOKEN=''")
printf "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='%s'\n%s\n" '<canvas url>' '<course id>' "$_TOKEN_LINE" > .idstack/canvas.env
chmod 600 .idstack/canvas.env
grep -qx 'canvas.env' .idstack/.gitignore 2>/dev/null || echo 'canvas.env' >> .idstack/.gitignore
echo "Canvas settings file: $PWD/.idstack/canvas.env"
```

Then tell the user:

"Open `.idstack/canvas.env` in a text editor. Paste your Canvas access token
between the two quotes after `CANVAS_TOKEN=`. Save the file, then tell me
when it is done.

To make a token in Canvas: Account → Settings → Approved Integrations → New
Access Token. Only you can read this file, and `.idstack/.gitignore` stops git
from adding it. When you are done with idstack, you can delete the file or
revoke the token in Canvas."

### B2. Validate Connection

```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
[ -n "$CANVAS_TOKEN" ] || { echo "CANVAS_TOKEN_EMPTY: add the token to .idstack/canvas.env"; exit 1; }
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  "$CANVAS_BASE_URL/api/v1/users/self" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP: $HTTP_CODE"
echo "$BODY" | head -5
```

Handle errors:
- HTTP 401: "Token rejected. Make sure you copied the full token. In Canvas:
  Account → Settings → Approved Integrations → New Access Token."
- HTTP 403: "Access denied. Your token does not have the necessary permissions for
  this course. You must have the Teacher role, the Designer role or a higher role."
- Network error: "idstack cannot connect to Canvas at that URL. Check the address and make
  sure it includes `https://`."

Verify course access:
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID" 2>&1
```

- HTTP 404: "Course not found. Check the course ID. You can find it in the URL
  when you open the course in Canvas."
- HTTP 403: "You do not have access to this course. Get the Teacher or Designer
  role from your Canvas admin."

**SECURITY RULE: The token is only in `.idstack/canvas.env`. Use
`$CANVAS_TOKEN` ONLY in the curl `Authorization` header. NEVER show the file
with `cat`, NEVER echo the token, and NEVER write it to the manifest, the
report, or a different file.**

### B3. Read Course Content

Same as A1 — read all files in `.idstack/course-content/` and the manifest.
Convert markdown content to HTML for the API calls (Canvas pages and assignments
accept HTML in their body fields).

Then do the "Export Plan" step. Go to B4 only after the user approves the plan.

### B4. Create Modules

For each module in the course content:

```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  -d "module[name]={module title}&module[position]={position}" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/modules" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP: $HTTP_CODE"
MODULE_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "MODULE_ID=$MODULE_ID"
```

Publish the module:
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
MODULE_ID=<module id printed in B4>
curl -s -X PUT \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  -d "module[published]=true" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/modules/$MODULE_ID"
```

Store the returned module ID for adding items in subsequent steps.

### B5. Create Pages and Add to Modules

For each module page (content, syllabus):

```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
# Create the page
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  --data-urlencode "wiki_page[title]={page title}" \
  --data-urlencode "wiki_page[body]={html content}" \
  -d "wiki_page[published]=true" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/pages" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
PAGE_URL=$(echo "$BODY" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "HTTP: $HTTP_CODE"
echo "PAGE_URL=$PAGE_URL"
```

Then add the page to its module:
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
MODULE_ID=<module id printed in B4>
PAGE_URL=<PAGE_URL printed above>
curl -s -X POST \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  -d "module_item[title]={page title}&module_item[type]=Page&module_item[page_url]=$PAGE_URL&module_item[published]=true" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/modules/$MODULE_ID/items"
```

### B6. Create Assignments

For each assessment (essay, project, upload type):

```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  --data-urlencode "assignment[name]={title}" \
  --data-urlencode "assignment[description]={html description with rubric}" \
  -d "assignment[points_possible]={points}" \
  -d "assignment[submission_types][]=online_text_entry" \
  -d "assignment[submission_types][]=online_upload" \
  -d "assignment[published]=false" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/assignments" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
ASSIGN_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "HTTP: $HTTP_CODE"
echo "ASSIGN_ID=$ASSIGN_ID"
```

Add the assignment to its module:
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
MODULE_ID=<module id printed in B4>
ASSIGN_ID=<ASSIGN_ID printed above>
curl -s -X POST \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  -d "module_item[title]={title}&module_item[type]=Assignment&module_item[content_id]=$ASSIGN_ID&module_item[published]=true" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/modules/$MODULE_ID/items"
```

Note: Assignments are created unpublished by default. The instructional designer
should review descriptions, rubrics, and due dates in Canvas before publishing.

### B7. Create Discussion Topics

For each discussion activity:

```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  --data-urlencode "title={title}" \
  --data-urlencode "message={html discussion prompt}" \
  -d "published=false" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/discussion_topics" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
TOPIC_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "HTTP: $HTTP_CODE"
echo "TOPIC_ID=$TOPIC_ID"
```

Add to its module:
```bash
. ./.idstack/canvas.env || { echo "CANVAS_ENV_MISSING"; exit 1; }
MODULE_ID=<module id printed in B4>
TOPIC_ID=<TOPIC_ID printed above>
curl -s -X POST \
  -H "Authorization: Bearer $CANVAS_TOKEN" \
  -d "module_item[title]={title}&module_item[type]=Discussion&module_item[content_id]=$TOPIC_ID&module_item[published]=true" \
  "$CANVAS_BASE_URL/api/v1/courses/$CANVAS_COURSE_ID/modules/$MODULE_ID/items"
```

### B8. Error Handling

Each API call is wrapped in error checking. Handle these cases:

- **HTTP 401:** Token expired or invalid. Stop. Tell the user to put a new token in
  `.idstack/canvas.env`. Do not ask for the token in the chat.

  Do the Step Review
  of "Export Contents" with a row for each item that idstack created before the
  error and one row with the status "failed: HTTP 401". Then do the last Step Review (see "Generate Export Report"), with its append and approve commands. In the Summary, tell that the export failed and give the error. Do not write a Top recommendations section. Then run the finish command and stop this skill.
- **HTTP 403:** Insufficient permissions. Report which item failed and why.
- **HTTP 404:** Course or resource not found. Report the specific endpoint.
- **HTTP 422:** Validation error. Report the error message from Canvas.
  Common causes: duplicate page titles, missing required fields.
- **HTTP 429:** Rate limited. Wait 10 seconds, retry once. If still 429:
  "Canvas limits the request rate. idstack waits 30 seconds and then continues."
  Wait 30 seconds and retry. If still failing, log the item as failed and
  continue with the rest.
- **Timeout / network error:** Log the item as failed, continue with the rest.

If any single API call fails, log it and continue with remaining items. Do NOT
abort the entire export on a single failure. The Export contents section shows
what succeeded and what failed.

### B9. Collect the Results

Do not show a table or a list of items in the chat. Collect the data for the
rows of "Export Contents". For each item type, count the items that idstack
created, the items that failed and the items that it skipped. For each failed
item, keep its name, its type and the error. Keep the Canvas course URL
`{Canvas URL}/courses/{course_id}` for the closing message.

---

## Path C: SCORM 1.2 Package Export

### C1. Read Course Content Files

Read all files in `.idstack/course-content/`:

```bash
find .idstack/course-content/ -type f | sort
```

If no course content files exist, tell the user: "No course content found in
`.idstack/course-content/`. Run `/idstack:course-builder` first to generate content."

If the files exist, read each file. Then do the "Export Plan" step. Go to C2 only after the user approves the plan.

### C2. Create SCORM package structure

Replace `<export folder>` with the folder from the "Course export folder:" line,
then run the command:

```bash
_EXPORT_DIR="<export folder>"
_STAGE="$_EXPORT_DIR/.scorm-staging"
rm -rf "$_STAGE"
mkdir -p "$_STAGE/content"
echo "Staging folder: $_STAGE"
```

### C3. Generate HTML content pages

For each module page in `.idstack/course-content/`, convert the Markdown content
to a self-contained HTML page. Each page becomes a SCO (Shareable Content Object).

Write each HTML file to the `content/` folder in the staging folder:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>[Module Title]</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; }
    h1 { color: #1a1a2e; }
    h2 { color: #16213e; margin-top: 2rem; }
    table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
    th, td { border: 1px solid #ddd; padding: 0.5rem; text-align: left; }
    th { background: #f5f5f5; }
  </style>
</head>
<body>
  [Converted HTML content]
</body>
</html>
```

Name files as `module-01.html`, `module-02.html`, etc. matching module order.

### C4. Generate imsmanifest.xml

Write `imsmanifest.xml` at the root of the staging folder. Follow the SCORM 1.2 specification:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest identifier="idstack-course-[sanitized-title]"
  version="1.0"
  xmlns="http://www.imsproject.org/xsd/imscp_rootv1p1p2"
  xmlns:adlcp="http://www.adlnet.org/xsd/adlcp_rootv1p2"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.imsproject.org/xsd/imscp_rootv1p1p2 imscp_rootv1p1p2.xsd
                       http://www.adlnet.org/xsd/adlcp_rootv1p2 adlcp_rootv1p2.xsd">

  <metadata>
    <schema>ADL SCORM</schema>
    <schemaversion>1.2</schemaversion>
  </metadata>

  <organizations default="idstack-org">
    <organization identifier="idstack-org">
      <title>[Course Title]</title>
      <!-- One item per module -->
      <item identifier="item-01" identifierref="resource-01">
        <title>[Module 1 Title]</title>
      </item>
      <!-- ... more items ... -->
    </organization>
  </organizations>

  <resources>
    <!-- One resource per SCO -->
    <resource identifier="resource-01" type="webcontent" adlcp:scormtype="sco"
              href="content/module-01.html">
      <file href="content/module-01.html"/>
    </resource>
    <!-- ... more resources ... -->
  </resources>
</manifest>
```

Rules for generating the manifest:
- Each module becomes one `<item>` pointing to one `<resource>`
- Each resource is a SCO (type="webcontent", adlcp:scormtype="sco")
- Identifiers must be unique within the manifest
- Sanitize the course title for use in the manifest identifier (lowercase, hyphens,
  no special characters)
- If modules have sub-modules, nest `<item>` elements accordingly

### C5. Package as ZIP

Replace `<export folder>` with the folder from the "Course export folder:" line,
then run the command:

```bash
_EXPORT_DIR="<export folder>"
_STAGE="$_EXPORT_DIR/.scorm-staging"
_OUT="$(cd "$_EXPORT_DIR" && pwd)/scorm-export.zip"
[ -f "$_STAGE/imsmanifest.xml" ] || { echo "PACKAGE_FAILED: $_STAGE/imsmanifest.xml is missing"; exit 1; }
rm -f "$_OUT"
( cd "$_STAGE" && zip -qr "$_OUT" imsmanifest.xml content ) || { echo "PACKAGE_FAILED: zip error. The staging folder is still at $_STAGE"; exit 1; }
[ -s "$_OUT" ] || { echo "PACKAGE_FAILED: $_OUT is empty"; exit 1; }
echo "SCORM package saved to $_EXPORT_DIR/scorm-export.zip"
```

If the output starts with `PACKAGE_FAILED`, tell the user the error. Do not say
that the export is complete.

Do the Step Review of "Export Contents" with one row
for `scorm-export.zip` and the status "failed: <error>". Then do the last Step Review (see "Generate Export Report"), with its append and approve commands. In the Summary, tell that the export failed and give the error. Do not write a Top recommendations section. Then run the finish command and stop this skill.

### C6. Verify package

Replace `<export folder>` again, then run the command:

```bash
_EXPORT_DIR="<export folder>"
file "$_EXPORT_DIR/scorm-export.zip"
unzip -l "$_EXPORT_DIR/scorm-export.zip" | head -20
echo "Total files: $(unzip -l "$_EXPORT_DIR/scorm-export.zip" | tail -1)"
```

Verify:
- `imsmanifest.xml` exists at the root of the ZIP
- All `<file href>` references in the manifest have matching files in the ZIP
- The ZIP is not empty

### C7. Collect the Results

Do not show this output or a list in the chat. From the C6 output, collect the
data for the rows of "Export Contents": the number of SCOs (one for each
module) and the number of files. Keep the package path
`.idstack/exports/<course-slug>/scorm-export.zip` for the closing message.

### C8. Cleanup

Replace `<export folder>` again, then run the command:

```bash
rm -rf "<export folder>/.scorm-staging"
```

---

## Export Contents

Do this step after A6, B9 or C7.

**Step review:** do the Step Review in the preamble. Section: `## Export contents`. Columns: `ID | Item | Type | Status`.

Write one row for each item that the path exported, with IDs `EC-1`, `EC-2` and so on. Also write one row for the package file (`course-export.imscc` or `scorm-export.zip`) or for the Canvas course URL. In the Status cell, write "exported", "created", "skipped" or "failed: <error>". Each failed item is a row.

---

## Generate Export Report

The Step Reviews before this step added the Readiness, Export plan and Export contents sections to the report at the path from the "Report path:" line.

**Step review:** do the Step Review in the preamble. Section: `## Findings`. Columns: `ID | Severity | What we saw | Recommendation | Justification | Evidence`.

Use the IDs `export-1`, `readiness-1`, `qti-1` and so on. Write a finding for generated content that the designer must examine, for example quiz questions, rubric format and missing placeholders. Also write a finding for each readiness problem and for each item that failed.

Cite quiz findings with `[Assessment-10] [T1]` and rubric findings with `[Assessment-19] [T1]`. For a readiness finding, use the citation of the related finding in the report of that review skill. If all items are correct, write one `info` row with the ID `qti-1` and the citation `[Assessment-10] [T1]`. This row tells the designer to examine the generated quiz questions in the LMS.

**Step review:** do the Step Review in the preamble. Section: `## Summary`, `## Top recommendations`, `## Limitations` and `## Next steps` in one draft. Columns: `ID | Action | Justification | Evidence` (Top recommendations only).

- **Summary:** two or three sentences. Tell what idstack exported, the format (IMSCC, Canvas API or SCORM), where the export is and the readiness verdict at the time of export. Add this line: "Modules N · Pages M · Assignments P · Quizzes Q · Discussions R".
- **Top recommendations:** three to five rows, with IDs `rec-1`, `rec-2` and so on. Use the most important approved findings.
- **Limitations:** The SCORM package contains only static HTML pages. It does not include interactive elements. The IMSCC package also contains QTI quizzes, assignments and discussion topics, which the LMS imports as its own quizzes, assignments and discussions. The quiz questions come from the assessment specs, and the designer must examine them. The Canvas token stays in `.idstack/canvas.env` on the computer of the user. idstack does not write it to the manifest or the report.
  - For SCORM, also write these limitations. The package does not include SCORM API tracking (completion, score reports). The LMS marks the SCO as completed when the learner opens it. For more interactivity, create the course in Articulate Rise or Storyline. Then use /idstack:course-quality-review and /idstack:red-team on the exported package.
- **Next steps:** Make sure that the LMS import kept all of the content correctly. Look carefully at quiz questions, assignment rubrics, discussion prompts and the module sequence. If the readiness verdict was NOT-READY, correct the findings before you publish the course. Also write the import steps for the format:
  - IMSCC: Canvas: Settings > Import Course Content > Common Cartridge 1.x. Blackboard: Course Management > Import > IMS Common Cartridge. Moodle: Site Administration > Restore > Upload .imscc file. D2L/Brightspace: Course Admin > Import/Export/Copy > Import Components.
  - SCORM: Canvas: Settings > Import Course Content > SCORM package. Moodle: Add Activity > SCORM package > Upload. Blackboard: Content > Build Content > SCORM package. Other LMS: upload the .zip file through the content management interface. Most LMS platforms find SCORM packages automatically.
  - Canvas API: examine the assignments and discussions in Canvas, and then publish them. idstack did not publish them. To try failed items again, run `/idstack:course-export` again, or make them manually in Canvas.

Run the finish command of the Step Review.

**Writing standard check.** In this command, replace `<path>` with the path of `course-export.md` in the folder from the "Course export folder:" line. Then run the command.

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

---

## Manifest Write

After the finish command of the Step Review, update the project manifest with
export metadata. Use only the approved rows. Count `items_exported` and
`failed_items` from the approved rows of the Export contents section. Write
`readiness_check` from the approved rows of the Readiness section.

Save results via the section-scoped merge tool — it validates the section name
against the canonical schema, preserves every other section verbatim, bumps the
top-level `updated` timestamp, and writes atomically:

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
# payload file holds ONLY the export_metadata section object (shape below)
"$_IDSTACK/bin/idstack-manifest-merge" --create --section export_metadata --payload .idstack/.export_metadata-payload.json && rm -f .idstack/.export_metadata-payload.json
```

Write the payload object to `.idstack/.export_metadata-payload.json` with the
Write tool first, then run the merge. `--create` makes a canonical manifest first if `.idstack/project.json` does not
exist yet (the standalone case). It never replaces a manifest that exists.

**CRITICAL -- Manifest Integrity Rules:**
1. The payload must be valid JSON: matching braces, proper commas, quoted
   strings, no trailing commas.
2. NEVER write secrets (Canvas tokens, credentials) to the manifest or the
   payload file.

### Write Export Metadata

The payload file holds the `export_metadata` section object (shown here wrapped
in its manifest key for context — the payload file contains only the inner object):

```json
{
  "export_metadata": {
    "report_path": "<set to the relative path from the "Report path:" line of the Prepare Course Export Folder block — e.g. .idstack/exports/<course-slug>/course-export.md>",
    "exported_at": "ISO-8601 timestamp",
    "format": "imscc|canvas-api|scorm",
    "destination": "file path (.idstack/exports/<course-slug>/course-export.imscc) or Canvas URL",
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
      "quality_reviewed": true,
      "red_team_critical": 0,
      "red_team_reviewed": false,
      "accessibility_critical": 0,
      "accessibility_reviewed": false,
      "verdict": "export_clean|export_with_warnings"
    }
  }
}
```

The `readiness_check` section captures the state of prior reviews at export time.
Populate it from the approved Readiness rows. Those rows come from the `quality_review`,
`red_team_audit`, and `accessibility_review` sections of the manifest (if they exist). The `verdict` is:
- `export_clean`: all reviewed, no critical findings
- `export_with_warnings`: reviewed but has critical/warning findings
- `export_blocked`: not used (export never blocks, advisory only)
- Empty string if no reviews exist

Run the merge, then confirm. Start the message with <the Report path, written as a link as the Report Links section of the preamble tells you>:

"I saved your export metadata to `.idstack/project.json`.

I exported your course. Make sure that the LMS import kept
all of the content correctly. Look carefully at:
- Quiz questions (idstack generated them. If necessary, edit them.)
- Assignment rubrics (make sure that the format did not change in the transfer)
- Discussion prompts (make sure that the instructions are clear)
- Module sequence (make sure that the module sequence is correct)"

After this message, give the package path or the Canvas course URL in one line.

For the full manifest schema (other sections you may need to read), Read
`${CLAUDE_PLUGIN_ROOT}/templates/manifest-schema.md`.

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
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"course-export","event":"completed"}'
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
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
"$_IDSTACK/bin/idstack-learnings" log '{"skill":"course-export","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
