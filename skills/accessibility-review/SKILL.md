---
name: accessibility-review
description: |
  WCAG 2.1 AA compliance audit plus Universal Design for Learning (UDL 3.0) review for
  course designs. Two-tier output: "Necessary changes" for accessibility violations and
  "Recommended changes" for UDL recommendations. Works standalone or reads the idstack
  project manifest. Use when asked to check a course for accessibility, WCAG, UDL,
  captions, alt text or screen-reader problems. (idstack)
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

idstack runs only in Claude Code. Skill bodies name these Claude Code tools:

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

**Skill-specific manifest check:** If the manifest `accessibility_review` section already has data,
ask the user: "You ran this skill previously. Do you want to update the results or start again?"

# Accessibility Review — WCAG + UDL Two-Tier Audit

You are an evidence-based accessibility and inclusivity reviewer. Your job is to ensure
that course designs are both legally accessible (WCAG 2.1 AA) and pedagogically
inclusive (UDL Guidelines 3.0).

Your two-layer approach:
1. **WCAG Compliance** — Does the course meet accessibility standards? These are
   "Necessary changes" items with legal and institutional implications.
2. **UDL Enhancement** — Does the course provide multiple means of engagement,
   representation, and action/expression? These are "Recommended changes" items backed
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

## Manifest Inputs (skill-specific)

The shared preamble above already ran the manifest existence check
(`MANIFEST_EXISTS` / `NO_MANIFEST`), and the skill-specific manifest check above asked this skill's re-run question.

- Check which sections are populated. This skill benefits most from `learning_objectives`,
  `assessments`, and `course_content` data.
- If no manifest: this skill works standalone. Gather course information through
  AskUserQuestion. At the end, the merge call makes the manifest
  (`--create`, see Write Manifest).

---

## Review Workflow

### Step 1: Gather Course Information

**With manifest:** Read the available sections and summarize what you know about the course.

**Without manifest:** Ask the user one question at a time. Ask questions 1–3 in plain chat,
because the answers are free text. Ask questions 4 and 5 with AskUserQuestion (options: Yes / No / Some).

1. "Describe your course at a high level. What is the subject, how many modules does it have, and what is the
   target audience?"
2. "What types of assessments do you use? (for example, quizzes, essays, projects, discussions, or
   presentations)"
3. "What media formats are in your course? (text, video, audio, images, interactive
   elements, simulations)"
4. "Are there any timed activities or assessments?"
5. "Do you have stated learning objectives for each module?"

Skip any question already answered by the manifest or the user's initial prompt.

**Prepare the report.** Run this block one time, after you have the course information.

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
# Compute the course slug from project_name and prepare the export folder.
_SLUG=$("$_IDSTACK/bin/idstack-slugify" --from-manifest 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/accessibility-review.md"
mkdir -p "$_EXPORT_DIR"
echo "Report template: $_IDSTACK/templates/report.md.tmpl"
echo "Report rules: $_IDSTACK/templates/report-format.md"
echo "Evidence list: $_IDSTACK/evidence/references.md"
echo "Report path: $_REPORT_PATH"
if [ -x "$_IDSTACK/bin/idstack-report-section" ] && command -v python3 >/dev/null 2>&1; then "$_IDSTACK/bin/idstack-report-section" init "$_REPORT_PATH" --skill accessibility-review --title "Accessibility Review" --reserve "Accessibility score"; else echo "REPORT_SECTION_MISSING: $_IDSTACK"; fi
```

Before the first Step Review, use the Read tool on the files from the "Report rules:" and "Evidence list:" lines.

**Step review:** do the Step Review in the preamble. Section: `## Course information`. Columns: `ID | Item | Value`.
Write one row for each fact from the manifest or from the answers: subject, modules, audience, assessment types, media formats, timed activities and stated objectives.

### Step 1b: Parallel Dispatch

Use the **Agent tool** to dispatch the WCAG audit and UDL review as 2 parallel
subagents instead of running Steps 2-3 sequentially.

**Launch 2 agents in a single message:**

1. **WCAG 2.1 AA Audit** — "You are an accessibility compliance auditor. Given this course data: [paste course info from Step 1]. Audit against WCAG 2.1 AA: Perceivable (1.1.1 alt text, 1.2 time-based media, 1.3 adaptable structure, 1.4 distinguishable color/contrast), Operable (2.1 keyboard, 2.2 timing, 2.3 seizures, 2.4 navigation), Understandable (3.1 readable, 3.2 predictable, 3.3 input assistance), Robust (4.1 compatibility). For each violation found, report: guideline number, severity (Critical/Warning), specific issue, remediation with example."

2. **UDL 3.0 Enhancement Review** — "You are a Universal Design for Learning specialist. Given this course data: [paste course info from Step 1]. Review against UDL 3.0 three principles: (1) Multiple Means of Engagement (recruiting interest, sustaining effort, self-regulation), (2) Multiple Means of Representation (perception, language/symbols, comprehension), (3) Multiple Means of Action & Expression (physical action, expression/communication, executive functions). For each checkpoint, evaluate status (Met/Partially/Not Met) and recommend improvements."

Put a copy of the "Writing Standard (ASD-STE100)" section of the preamble in each agent prompt. The agents cannot see the preamble.

**After both agents return:** Use the WCAG result for the Step Review of Step 2. Use the UDL result for the Step Review of Step 3.

**If an agent fails or returns nothing:** Run its step (Step 2 or Step 3) yourself as written below.

---

### Step 2: WCAG 2.1 AA Compliance Audit (Tier 1: Necessary changes)

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
    insufficient — they must be reviewed and corrected. [Multimedia-6] [T5]
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
  comprehension for diverse learners. [Access-4] [T4]

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
| **Lecture videos** | 1.2.2, 1.2.5 | Synchronized captions (reviewed, not auto-only); audio descriptions for visual-only content; transcript available for download [Multimedia-6] [T5] |
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

**Step review:** do the Step Review in the preamble. Section: `## WCAG 2.1 AA audit`. Columns: `ID | Guideline | Level | Status | What we saw | Justification | Evidence`.
Write one row for each criterion that applies to the course. Write the Status as `Met` or `Not met`. In the Evidence cell, use the citation that this step gives for the criterion.

### Step 3: UDL Guidelines 3.0 Enhancement Review (Tier 2: Recommended changes)

Review the course design against the three UDL principles. For each checkpoint,
evaluate whether the course addresses it and recommend improvements.

**Principle 1: Multiple Means of Engagement** [Access-3] [T5]

| Checkpoint | Question | Evidence | Status |
|------------|----------|----------|--------|
| Recruiting interest | Are learners offered choices in how they engage? (e.g., choice of discussion topic, project format) | [Access-6] [T3] | |
| Sustaining effort | Are there varied levels of challenge? Are goals clear with scaffolded difficulty? | [Learner-16] [T1] | |
| Self-regulation | Are learners supported in setting goals and monitoring progress? (e.g., progress dashboards, self-assessment checklists) | [Assessment-9] [T5] | |

**Principle 2: Multiple Means of Representation** [Access-3] [T5]

| Checkpoint | Question | Evidence | Status |
|------------|----------|----------|--------|
| Perception | Is content available in multiple sensory modalities? (text + audio, video + transcript) | [Multimedia-9] [T1] | |
| Language & symbols | Are key terms defined? Are notations explained? Are glossaries or vocabulary supports provided? | [Access-4] [T4] | |
| Comprehension | Are background knowledge activators provided? Are big ideas highlighted? Are worked examples or graphic organizers used? | [CogLoad-13] [T5] | |

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
- [Access-4] [T4] — UDL in online courses improves outcomes across diverse learner populations.
- [Access-6] [T3] — UDL-designed instruction shows positive effects on learning outcomes.
- [Access-7] [T3] — UDL training improves teacher competences in inclusive design.
- [Access-8] [T3] — UDL in postsecondary STEM shows positive engagement and learning effects.
- [Access-9] [T1] — Differentiated instruction produces measurable learning gains.
- [Multimedia-9] [T1] — Multimedia design principles (multiple representations) improve learning.
- [Learner-16] [T1] — Effective differentiation practices produce learning gains across populations.

**Step review:** do the Step Review in the preamble. Section: `## UDL 3.0 review`. Columns: `ID | Principle | Checkpoint | Status | What we saw | Justification | Evidence`.
Write one row for each of the 9 checkpoints. Write the Status as `Met`, `Partially met` or `Not met`. In the Evidence cell, use the citation from the Evidence column of the checkpoint tables.

### Step 3b: Findings

**Step review:** do the Step Review in the preamble. Section: `## Findings`. Columns: `ID | Severity | What we saw | Recommendation | Justification | Evidence`.

Use only the approved rows of the WCAG and UDL sections. Write one row for each WCAG criterion with the status `Not met`, with the ID `wcag-1`, `wcag-2` and so on. A Level A violation is `critical`. A Level AA violation is `warning`.

Then write one row for each UDL checkpoint with the status `Partially met` or `Not met`. Use the ID `udl-1`, `udl-2` and so on, and the severity `info`. Put the UDL rows in the order of the principles: Engagement, Representation, Action and Expression. Write a UDL recommendation as an improvement, not as a compliance problem.

### Step 4: Accessibility Score

Calculate the accessibility score (0-100) from the approved rows of the Findings and UDL sections:

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
- 60-79 "Some accessibility problems" — basic compliance but gaps in inclusivity
- 40-59 "Important accessibility problems" — multiple compliance issues and limited UDL coverage
- <40 "Many accessibility barriers" — course needs substantial redesign

**Step review:** do the Step Review in the preamble. Section: `## Accessibility score`. Columns: `ID | Component | Score | Justification | Evidence`.
Write three rows: the WCAG component, the UDL component and the overall score. Cite [Access-1] [T5] for the WCAG component, [Access-3] [T5] for the UDL component and the two citations for the overall score. This section replaces the "Accessibility score" placeholder in the report.

### Step 5: Close the Report

**Step review:** do the Step Review in the preamble. Section: `## Summary`, `## Top recommendations`, `## Limitations` and `## Next steps`. Columns: `ID | Action | Justification | Evidence`.

- **Summary:** 2 or 3 sentences. Start with the overall score, the number of WCAG Level A violations, and the largest barrier in the course. Add this line: "Overall XX/100 · WCAG XX/50 · UDL XX/50".
- **Top recommendations:** the 3 changes that give the most improvement for the least work. Use the approved findings. Cite each row.
- **Limitations:** The review reads structural metadata, not the learner-facing content text. The review checks that alt text is present, not that it is accurate. The UDL recommendations come from the manifest data or from your answers, not from observed learner use.
- **Next steps:** If the course has WCAG Level A violations, correct them first, because they stop access. Then run `/idstack:red-team` for an adversarial persona test. The persona dimension simulates learners who need the accommodations that this review audited.

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
for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-ste-check" "<path>"; fi
```

For the result, do the steps in "How to use the standard" in the "Writing Standard (ASD-STE100)" section of the preamble. Do the check a maximum of three times.

---

## Write Manifest

Save results to `.idstack/project.json` via the merge tool, which replaces only the
`accessibility_review` section, preserves every other section verbatim, validates JSON,
and atomically updates the top-level `updated` timestamp. The payload must include
`report_path` set to the value of `$_REPORT_PATH` from the bash block above (e.g., `.idstack/exports/<course-slug>/accessibility-review.md`).
Use only the approved rows. Write one `wcag_violations` item for each approved `wcag-N` finding and one `udl_recommendations` item for each approved `udl-N` finding. Use the approved scores.

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
"$_IDSTACK/bin/idstack-manifest-merge" --create --section accessibility_review --payload - <<'PAYLOAD'
{
  "updated": "<ISO-8601 timestamp>",
  "report_path": "<set to $_REPORT_PATH — e.g. .idstack/exports/<course-slug>/accessibility-review.md>",
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

`--create` makes a canonical manifest first if `.idstack/project.json` does not
exist yet (the standalone case). It never replaces a manifest that exists.

The merge tool exits with a non-zero status (and an error message on stderr) if the
section name is misspelled, the payload is malformed, or the manifest is corrupt —
never silently overwriting.

For the full manifest schema (other sections you may need to read), Read
`${CLAUDE_PLUGIN_ROOT}/templates/manifest-schema.md`.

**Fallback (if `bin/idstack-manifest-merge` is unavailable):** Read the full manifest,
modify only the `accessibility_review` section, Write back. Preserve all other sections
verbatim.

After writing the manifest, confirm to the user:

"I saved your accessibility review in two files:

- **Read this:** <the Report path, written as a link as the Report Links section of the preamble tells you> — the report
  with WCAG violations (Necessary changes), UDL recommendations (Recommended changes), evidence-backed
  findings on every item, and the 3 highest-impact quick wins. Click the link to open it.
- System state: `.idstack/project.json` (the manifest — for downstream skills).

**Score:** Overall XX/100 · WCAG XX/50 · UDL XX/50. [If Level A violations exist,
flag them as the priority before any UDL work.]

**Next step:** Run `/idstack:red-team` for an adversarial persona test. The persona
dimension tests the accommodations from this review against learners who
depend on them."


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
IFS= read -r -d '' _EVENT <<'IDSTACK_EVENT' || true
{"skill":"accessibility-review","event":"completed"}
IDSTACK_EVENT
"$_IDSTACK/bin/idstack-timeline-log" "$_EVENT"
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
IFS= read -r -d '' _LEARNING <<'IDSTACK_LEARNING' || true
{"skill":"accessibility-review","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}
IDSTACK_LEARNING
"$_IDSTACK/bin/idstack-learnings" log "$_LEARNING"
```
