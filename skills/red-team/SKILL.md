---
name: red-team
description: |
  Adversarial course design audit across 5 dimensions: alignment stress test, evidence
  verification, cognitive load analysis, learner persona simulation, and prerequisite
  chain integrity. Produces a confidence score (0-100). Runs in a clean-context
  sub-agent, so the build history does not change the result. Use when asked to
  stress-test, red-team, or do a pre-launch check of a course design. (idstack)
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

**Skill-specific manifest check:** If the manifest `red_team_audit` section already has data,
ask the user: "You ran this skill previously. Do you want to update the results or start again?"

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

The sub-agent (the **orchestrator**) does the full audit. It writes the findings to `.idstack/.red-team-findings.json` and returns a short summary. The parent (this skill) adds each findings table to the report at `.idstack/exports/<course-slug>/red-team.md` as a draft. The user reads each table in the report and approves it. The parent also applies fixes, because it knows the course structure.

---

## Workflow

1. **Pre-flight**: confirm scope and focus
2. **Spawn orchestrator**: clean-context sub-agent does the audit and writes the findings file
3. **Review the findings**: the user approves each findings table, the per-dimension summary and the confidence score
4. **Triage**: ask which severity bucket to address
5. **Apply fixes**: parent edits course files in-context, then the user approves the fixes table
6. **Complete the report**: the closing Step Review, then the finish command
7. **Update manifest**: parent writes `red_team_audit` section from the approved rows

No automatic re-verification. If the user wants to confirm fixes hold, they re-run `/idstack:red-team`.

---

### Step 1: Pre-flight

The preamble above already ran the manifest check. Now confirm scope.

**Determine course inputs:**
- If `MANIFEST_EXISTS`: the orchestrator will read all sections (`needs_analysis`, `learning_objectives`, `assessments`, `course_content`, `quality_review`, `accessibility_review`).
- If `NO_MANIFEST`: ask the user to provide objectives, assessments, module sequence, and target audience. Capture answers as a brief block to pass to the orchestrator. Standalone mode reduces precision on Dimensions 1 (alignment) and 5 (prerequisites).

**Ask one focus question** via AskUserQuestion:

> "Do you want a full sweep, or a red-team audit with one focus?"

Options:
- **Full sweep (recommended)** — all 5 dimensions at equal depth
- **Assessment gaming** — bias depth toward Dimension 1 (alignment)
- **Cognitive overload** — bias depth toward Dimension 3 (cognitive load)
- **Persona accessibility** — bias depth toward Dimension 4 (personas)

AskUserQuestion takes a maximum of 4 options. Put this in the question text: "For
evidence accuracy, select Other and type `evidence`." If the user types `evidence`,
bias depth toward Dimension 2 (evidence).

Save the user's choice as `FOCUS` for the orchestrator brief.

### Step 2: Spawn the red-team orchestrator

Use the **Agent tool** with `subagent_type=general-purpose`. The prompt is the full contents of the `<orchestrator-brief>` block below, with these substitutions performed before invoking:

- `{{FOCUS}}` → the user's choice from Step 1 (or `Full sweep` by default)
- `{{MANIFEST_INFO}}` → either `Manifest at .idstack/project.json — read it directly.` or, in standalone mode, the captured course information from Step 1
- `{{COURSE_FILES_HINT}}` → if the manifest has `course_content.content_dir`, set this to that path; otherwise `Look under .idstack/course-content/ for generated course files.`

Put a copy of the "Writing Standard (ASD-STE100)" section of the preamble at the end of the prompt. The orchestrator cannot see the preamble.

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

Run this command. It prints the path of the evidence list.

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
echo "Evidence list: $_IDSTACK/evidence/references.md"
```

Use the Read tool on the file from the "Evidence list:" line. Use only the codes in that file, with the tier that the file gives for each code.

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

The "Writing Standard (ASD-STE100)" section is at the end of this prompt. Put a copy of it in each sub-agent prompt. The sub-agents cannot see it.

---

## Dimension Briefs

### Dimension 1 — Alignment Stress Test

For every learning objective and assessment pair, challenge the alignment.

**Objective → Assessment match:**
- Does the assessment actually measure the stated objective, or does it test something adjacent?
- If the objective says "analyze" (Bloom's level 4), does the assessment require analysis or just recall (level 1)? Flag Bloom's level mismatches.
  [Alignment-14] [T1] — retrieval practice and Bloom's levels interact.
  [Alignment-7] [T4] — measurable verbs alone cannot guarantee correct Bloom's classification.
  [Alignment-12] [T4] — internal assumptions of revised Bloom's taxonomy require probing.
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
- If WebSearch is unavailable, set `"mode": "limited"` in the findings file and add this text to `limitations`: "the currency check must have internet access."

### Dimension 3 — Cognitive Load Analysis

Estimate cognitive load per module using proxy measures.

**Limitation:** the manifest contains structure, not the actual content learners see. These are proxies based on structural indicators. Add this limitation to `limitations`.

**Proxy indicators:**
- Number of new concepts introduced per module (flag if >7).
  [CogLoad-4] [T5] — intrinsic load increases with element interactivity.
  [CogLoad-5] [T5] — working memory capacity limits are real design constraints.
  [CogLoad-6] [T2] — working memory resource depletion compounds across tasks.
- Number of prerequisite concepts required (flag if prerequisites span >3 prior modules).
  [CogLoad-1] [T1] — problem-solving support interacts with sequence to affect load.
- Assessment complexity relative to objective Bloom's level.
  [CogLoad-16] [T1] — format affects cognitive load independently of content.
- Module sequencing: are related concepts spaced or massed?
  [CogLoad-17] [T2] — sequencing significantly affects learning outcomes.
  [CogLoad-13] [T5] — five strategies for optimizing instructional materials.

**Expertise reversal check:**
- Are scaffolds present that would hurt expert learners?
  [CogLoad-19] [T5] — expertise reversal effect.
  [CogLoad-11] [T5] — digital/online learning amplifies cognitive load concerns.
- Are there adaptive elements that adjust based on learner expertise?
  [Learner-16] [T1] — differentiated instruction produces measurable gains.
  [Learner-18] [T5] — personalized adaptive learning framework.

### Dimension 4 — Learner Persona Simulation

Simulate 4 learner personas walking through the course.

**Limitation:** simulation operates on structural/metadata signals, not actual content text. Content-level analysis (e.g., detecting idioms that challenge ESL learners) requires the actual course materials. Add this limitation to `limitations`.

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
  [Learner-11] [T4] — data-based differentiation responds to individual learner state.

**Persona C — ESL Learner** (language complexity, cultural references)
- Are key terms defined when first introduced?
  [Access-4] [T4] — universal instructional design includes clear vocabulary introduction.
- Are instructions clear without idiomatic expressions?
  [CogLoad-11] [T5] — extraneous load from language complexity compounds online.
- Are cultural references universal or region-specific?
  [Learner-13] [T4] — diverse student needs require culturally responsive design.
- Is reading level appropriate? (Flag if above Flesch-Kincaid grade 10 for ESL audiences.)
  [Learner-2] [T4] — differentiated instruction varies with language proficiency.

**Persona D — Learner with Accessibility Needs**
- Do assessments offer alternative formats (extended time, alternative submission)?
  [Access-3] [T5] — UDL 3.0 requires multiple means of action and expression.
  [Access-6] [T3] — universal design for instruction supports flexible assessment.
- Are multimedia elements accessible (captions, transcripts, alt text)?
  [Access-1] [T5] — WCAG 2.1 requires text alternatives for non-text content.
  [Access-5] [T3] — universal design includes multimedia accessibility.
- Can the course be navigated with keyboard only?
  [Access-1] [T5] — WCAG 2.1 keyboard accessibility.
  [Access-2] [T5] — WCAG 2.2 extends keyboard navigation standards.

**Per-persona checklist (evaluate for every module):**
1. Can this persona access the content? [Access-4] [T4]
2. Does this persona have the prerequisite knowledge? [CogLoad-1] [T1]
3. Is the cognitive load appropriate for this persona's expertise level? [CogLoad-19] [T5]
4. Does the assessment format work for this persona? [Assessment-8] [T1]
5. Is the feedback practical for this persona? [Assessment-9] [T5]

### Dimension 5 — Prerequisite Chain Integrity

Trace prerequisite dependencies across all modules.

**Check for:**
- Circular dependencies (A requires B requires A).
  [CogLoad-17] [T2] — circular paths make valid sequencing impossible.
- Missing prerequisites (module assumes knowledge not taught earlier).
  [CogLoad-1] [T1] — problem-solving support must match prerequisite state.
  [Alignment-10] [T4] — high challenge without high support undermines learning.
- Orphaned content (nothing depends on it, no prerequisites).
  [Alignment-1] [T5] — every component must serve the objective chain.
- Ordering violations (prerequisite module appears after the module that needs it).
  [CogLoad-17] [T2] — sequencing violations create impossible learning paths.
  [CogLoad-4] [T5] — intrinsic load becomes unmanageable when prereqs are unavailable.

---

## Output

Do not write the report. The parent writes it.

Write the findings to `.idstack/.red-team-findings.json` with the Write tool. Use this shape:

```json
{
  "mode": "full|limited",
  "dimensions": [
    {
      "dimension": "Alignment",
      "score": "pass|warning|critical",
      "rows": [
        {
          "id": "alignment-1",
          "severity": "critical|warning|info",
          "what_we_saw": "Objective 3 has no assessment.",
          "recommendation": "idstack recommends that you add an assessment for Objective 3.",
          "justification": "Each objective must have an assessment that measures it.",
          "evidence": "[Alignment-2] [T5]"
        }
      ]
    }
  ],
  "limitations": []
}
```

Obey these rules for the file:

- Write one item in `dimensions` for each of the five dimensions, in this order: `Alignment`, `Evidence`, `Cognitive load`, `Personas`, `Prerequisites`.
- The score of a dimension is `critical` if it has a critical row. It is `warning` if it has a warning row. Else it is `pass`.
- Give each row a stable id of the form `<dimension>-<n>`. Use these prefixes: `alignment`, `evidence`, `cogload`, `persona`, `prereq`. The parent uses the ids when it applies fixes.
- Put the critical rows first, then the warning rows, then the info rows.
- Write the severity in lowercase: `critical`, `warning` or `info`.
- In `what_we_saw`, name the module, objective or assessment.
- Write the recommendation as "idstack recommends that you ..." or "You can ...".
- Write the justification as one sentence. Tell why the finding is important for the learners of this course.
- In `evidence`, write only the citation, for example `[Alignment-14] [T1]`. Use a code from the "Evidence list:" file, with the tier that the file gives. When more than one tier applies, cite the strongest.
- If you cannot cite a finding, do not put it in `rows`. Put its text in `limitations`.
- In `limitations`, write what this audit could not examine. Examples are the text of the content, the behavior of real learners and the settings of the LMS.
- Write all text in the file as the "Writing Standard (ASD-STE100)" section at the end of this prompt tells you.

## Return value

After you write the file, return ONLY a short executive summary (≤200 words) to the parent:
- Severity counts
- Top 1 critical finding (one line)
- JSON path: `.idstack/.red-team-findings.json`

Do NOT return the findings inline. The parent reads the file.

</orchestrator-brief>

### Step 3: Review the findings

After the orchestrator returns:

1. Read the file at the JSON path that the orchestrator returned. If the file does not exist or is not valid JSON, tell the user and stop.
2. Show the user the executive summary in your own words: severity counts and the top critical finding.
3. Run this command. It starts the report.

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
_REPORT_PATH="$_EXPORT_DIR/red-team.md"
mkdir -p "$_EXPORT_DIR"
echo "Report template: $_IDSTACK/templates/report.md.tmpl"
echo "Report rules: $_IDSTACK/templates/report-format.md"
echo "Evidence list: $_IDSTACK/evidence/references.md"
echo "Report path: $_REPORT_PATH"
if [ -x "$_IDSTACK/bin/idstack-report-section" ] && command -v python3 >/dev/null 2>&1; then "$_IDSTACK/bin/idstack-report-section" init "$_REPORT_PATH" --skill red-team --title "Red Team Audit" --mode "<mode>" --reserve "Confidence score"; else echo "REPORT_SECTION_MISSING: $_IDSTACK"; fi
```

In the command, replace `<mode>` with the `mode` value from the JSON file, then ` · focus: `, then the FOCUS value. An example is `full · focus: Full sweep`.

Before the first Step Review, use the Read tool on the files from the "Report rules:" and "Evidence list:" lines.

Do one Step Review for each dimension, in the order of the JSON file. Use the rows of that dimension. If a dimension has no rows, do not do its Step Review. The Per-dimension summary shows the score `pass` for it.

**Step review:** do the Step Review in the preamble. Section: `## Dimension: Alignment`. Columns: `ID | Severity | Issue | Fix | Justification | Evidence`.

**Step review:** do the Step Review in the preamble. Section: `## Dimension: Evidence`. Columns: `ID | Severity | Issue | Fix | Justification | Evidence`.

**Step review:** do the Step Review in the preamble. Section: `## Dimension: Cognitive load`. Columns: `ID | Severity | Issue | Fix | Justification | Evidence`.

**Step review:** do the Step Review in the preamble. Section: `## Dimension: Personas`. Columns: `ID | Severity | Issue | Fix | Justification | Evidence`.

**Step review:** do the Step Review in the preamble. Section: `## Dimension: Prerequisites`. Columns: `ID | Severity | Issue | Fix | Justification | Evidence`.

Copy the cells from the JSON rows: `what_we_saw` goes in Issue and `recommendation` goes in Fix. When the user selects "Change a row", change only the cells that the user names. The `## Findings` section in Step 6 collects the approved rows of all five dimensions.

**Step review:** do the Step Review in the preamble. Section: `## Per-dimension summary`. Columns: `ID | Dimension | Score | Top issue | Justification | Evidence`.

Write one row for each of the five dimensions, with the IDs `D-1` to `D-5`. Calculate the score from the approved rows of the dimension. The score is `critical` if the dimension has an approved critical row. It is `warning` if it has an approved warning row. Else it is `pass`.

In the Top issue cell, write the first approved row of the dimension, or "No problem found". In the Evidence cell, use the citation of that row. For a dimension with no rows, cite the first code in the brief of that dimension.

**Step review:** do the Step Review in the preamble. Section: `## Confidence score`. Columns: `ID | Component | Score | Justification | Evidence`.

Calculate the confidence score from the approved findings only:

- Start at 100
- Deduct per finding:
  - Critical = -15
  - Warning = -5
  - Info = -1
- Floor at 0

Severity weights reflect that structural misalignment and cognitive overload are the strongest predictors of learner failure: [Alignment-14] [T1], [CogLoad-6] [T2].

Contextualize:
- 80+ "High confidence" — minor issues only
- 60-79 "Moderate confidence, changes necessary" — several design gaps
- 40-59 "Low confidence, important gaps" — multiple problem dimensions
- <40 "New design necessary" — structural issues across most dimensions

Write one row for each severity, with the count and the deduction, for example `Critical findings: 2 x -15`. Then write one row for the confidence score and its band. Cite `[Alignment-14] [T1] [CogLoad-6] [T2]` in each row. This section replaces the "Confidence score" placeholder of the report.

### Step 4: Triage — choose fix scope

Ask one AskUserQuestion:

> "Which findings do you want to correct?"

Options:
- **Critical only (recommended)** — highest-impact fixes, smallest scope
- **Critical + Warning** — broader cleanup
- **All findings** — Info findings also. This can be many changes.
- **Skip — review report manually** — no changes. You read the report.

If the user chooses **Skip**, jump straight to Step 6.

### Step 5: Apply fixes in-context

For each approved finding in the chosen severity bucket, in order of severity:

1. Read the affected course file(s) (module content, assessment definition, manifest section).
2. Apply the fix via Edit. Do not tell the user about each fix in the chat. The user examines all the fixes in the `## Fixes applied` section.
3. Track the finding id in `fixes_applied`. If you decide a finding is not applicable in context (e.g., requires re-running `/idstack:assessment-design`), record it in `fixes_deferred` with a one-line reason.

Do not spawn additional sub-agents for fixes. The parent has the relevant context to edit course files directly.

If the user selects "Change a row" or "Remove a row" in the Step Review of the `## Fixes applied` section, remove that change from the course file. Then write the Status of the row as `deferred`, and move the finding id from `fixes_applied` to `fixes_deferred`.

**Writing standard check.** Run this command one time for each course file that you edited in this step. Replace `<path>` with the path of the file. Do not run it on `.idstack/project.json`.

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

For the result, do the steps in "How to use the standard" in the "Writing Standard (ASD-STE100)" section of the preamble. Change only the sentences that you wrote or changed in this step. Do not change the other text in the file. Do the check a maximum of three times. If the checker shows problems only in sentences that you did not write or change, the check of that file is complete. Tell the user one time that these lines had problems before your changes.

**Step review:** do the Step Review in the preamble. Section: `## Fixes applied`. Columns: `ID | Change | File | Status | Justification | Evidence`.

Write one row for each finding in `fixes_applied` and `fixes_deferred`. Use the finding id as the ID. Write the Status as `applied` or `deferred`. For a deferred row, write the reason in the Change cell. Copy the Justification and Evidence cells from the approved finding row. If the user selected **Skip**, or if no finding was in the selected bucket, do not do this Step Review.

### Step 6: Complete the report

**Step review:** do the Step Review in the preamble. Section: `## Findings`. Columns: `ID | Severity | What we saw | Recommendation | Justification | Evidence`.

Put the approved rows of the five Dimension sections in one table. Put the `critical` rows first, then `warning`, then `info`. Copy Issue to What we saw and Fix to Recommendation. Do not change the other cells. If no dimension has an approved row, do not do this Step Review.

**Step review:** do the Step Review in the preamble. Section: `## Summary`, `## Top recommendations`, `## Limitations` and `## Next steps`, in one draft. Columns of Top recommendations: `ID | Action | Justification | Evidence`.

- **Summary:** 2–3 sentences. Lead with the confidence score (0–100) and the band ("High confidence" / "Moderate confidence, changes necessary" / "Low confidence, important gaps" / "New design necessary"). Include the one-line scoreboard: "Confidence XX/100 · Critical N · Warning N · Info N". Use the counts of the approved findings.
- **Top recommendations:** the 3 changes that would most improve the score. Give each row the ID `R-1` to `R-3`. Name the finding id in the Action cell. Use the citation of that finding.
- **Limitations:** the `limitations` text from the JSON file. Add the text that you put in Limitations during the Step Reviews.
- **Next steps:** If the confidence score is less than 60, recommend re-running `/idstack:learning-objectives` or `/idstack:assessment-design`. If it is 60 or more, recommend `/idstack:course-export`. The score does not change after the fixes in this run. To get a new score, run `/idstack:red-team` again.

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

### Step 7: Update manifest

Save results to `.idstack/project.json` via `bin/idstack-manifest-merge`, which replaces only
the `red_team_audit` section, preserves every other section verbatim, validates JSON, and
atomically updates the top-level `updated` timestamp. Use only the approved rows of the
report. Calculate `confidence_score`, `findings_summary` and each dimension `score` from the
approved findings. Set `report_path` to the path from the "Report path:" line.

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
"$_IDSTACK/bin/idstack-manifest-merge" --create --section red_team_audit --payload - <<'PAYLOAD'
{
  "updated": "<ISO-8601 timestamp>",
  "confidence_score": 0,
  "focus": "Full sweep",
  "report_path": "<set to the path from the Report path: line — e.g. .idstack/exports/<course-slug>/red-team.md>",
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

`fixes_deferred[]` — each item: `{"id": "alignment-3", "reason": "One-line reason — for example, the fix needs a new run of /idstack:assessment-design"}`.

The merge tool exits non-zero (and prints a diagnostic on stderr) if the payload is malformed,
the manifest is corrupt, or the section name is misspelled — never silently overwriting.
`--create` makes a canonical manifest first if `.idstack/project.json` does not
exist yet (the standalone case). It never replaces a manifest that exists.

**Fallback (if `bin/idstack-manifest-merge` is unavailable):** Read the full manifest, modify
only the `red_team_audit` section, Write back. Preserve all other sections verbatim. The
canonical schema for reference is in `${CLAUDE_PLUGIN_ROOT}/templates/manifest-schema.md`.

After the manifest write, delete the findings file:

```bash
rm -f .idstack/.red-team-findings.json
```

### Step 8: Final summary to user

Two sentences:
- "Confidence: X/100. I made N changes and deferred M changes. The report is at <the Report path, written as a link as the Report Links section of the preamble tells you>."
- If the confidence score is less than 60, recommend re-running `/idstack:learning-objectives` or `/idstack:assessment-design`. If it is 60 or more, recommend `/idstack:course-export`. To get a new score after the fixes, run `/idstack:red-team` again.

If the user wants to verify fixes hold, they can re-run `/idstack:red-team` — that's deliberately manual to avoid token costs of automatic re-verification.

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
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"red-team","event":"completed"}'
```

Include skill-specific fields where available (confidence_score, focus, fixes_applied count). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior, import format issue, course structure pattern), also log it as a learning:

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
"$_IDSTACK/bin/idstack-learnings" log '{"skill":"red-team","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
