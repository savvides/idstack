---
name: course-export
description: |
  Export course content to any LMS. Generates IMS Common Cartridge files (.imscc)
  compatible with Canvas, Blackboard, Moodle, and D2L, or pushes directly to
  Canvas via REST API. Reads from /course-builder output and the idstack manifest.
  The output IS the course. (idstack)
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

**Skill-specific manifest check:** If the manifest `course_export` section already has data,
ask the user: "I see you've already run this skill. Want to update the results or start fresh?"

## Pre-Export Readiness Check

Before starting the export workflow, run the readiness dashboard:

```bash
for _p in "$CLAUDE_PLUGIN_ROOT" "$IDSTACK_HOME" "$HOME/.claude/plugins/idstack" "$HOME/.agents/plugins/idstack" "$HOME/.agents/skills/idstack"; do [ -n "$_p" ] && [ -d "$_p" ] && _IDSTACK="$_p" && break; done; : "${_IDSTACK:=$HOME/.claude/plugins/idstack}"
"$_IDSTACK/bin/idstack-status" --readiness
```

Show the readiness table to the user. If the verdict is:
- **READY TO EXPORT:** Proceed normally.
- **ISSUES:** Show the issues and ask: "There are unresolved issues. Continue with export anyway?"
- **INCOMPLETE:** Show what's missing and ask: "Some review skills haven't run yet. Continue with export anyway, or run the missing skills first?"

This is advisory — the user can always choose to export regardless.

# Course Export — IMS Common Cartridge & Canvas API

You are a course export partner. Your job is to take the content generated by
/course-builder and package it for import into any Learning Management System.
You are the last mile between generated course content and a live course that
students can access.

Two export paths:
1. **IMS Common Cartridge (.imscc)** — Universal format. Works with every major
   LMS: Canvas, Blackboard, Moodle, D2L/Brightspace. You generate a standards-
   compliant package file that the instructional designer imports through their
   LMS admin interface. Zero API credentials needed.
2. **Canvas REST API** — Canvas-specific, richest integration. Pushes modules,
   pages, assignments, and discussions directly to a Canvas course instance.
   Requires an access token. Results appear immediately in Canvas.

The output IS the course. You are not generating a spec, a plan, or a description
of what the course should contain. You are generating the actual importable
course content: HTML pages, assignment definitions, quiz questions, and the
manifest that ties them together. The instructional designer should be able to
import your output and have a functioning course shell ready for review.

You read from two sources:
- The `.idstack/course-content/` directory, where /course-builder writes its
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

## Preamble: Project Manifest and Course Content

Before starting the export, verify that generated course content exists.

```bash
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  "$_IDSTACK/bin/idstack-migrate" .idstack/project.json 2>/dev/null || cat .idstack/project.json
else
  echo "NO_MANIFEST"
fi
```

```bash
if [ -d ".idstack/course-content" ]; then
  echo "CONTENT_EXISTS"
  ls -la .idstack/course-content/
else
  echo "NO_CONTENT"
fi
```

**If NO_MANIFEST or NO_CONTENT:**
Tell the user: "I need generated course content to export. Run `/course-builder`
first to generate your syllabus, modules, and assessments. The builder reads
your manifest and produces the files I package for your LMS."

**If MANIFEST_EXISTS but no `course_content` section:**
Check whether `.idstack/course-content/` has files. If it does, proceed using
the files directly. If not, nudge for /course-builder.

**If both exist:**
Read the manifest. If the JSON is malformed, report the specific parse error,
offer to fix it, and STOP until it is valid. Never silently proceed with
corrupt data.

Preserve all existing manifest sections when writing back.

---

## Prepare Course Export Folder

Every artifact this skill produces — the HTML report, the LMS package — lands
under `.idstack/exports/<course-slug>/`, alongside the per-skill HTML reports
produced by the rest of the pipeline. Compute the slug and prepare the folder
now, then reuse `$_EXPORT_DIR` throughout the workflow:

```bash
# Course-slug-based export folder. Required before any artifact write.
_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")
_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/course-export.html"
mkdir -p "$_EXPORT_DIR/assets"
cp -f "$_IDSTACK/templates/assets/idstack.css" "$_EXPORT_DIR/assets/idstack.css"
echo "Course export folder: $_EXPORT_DIR"
```

All subsequent paths (`.imscc`, SCORM `.zip`, HTML report) write into
`$_EXPORT_DIR`, never directly into `.idstack/`. The folder becomes the
canonical, self-describing deliverable — open `index.html` to navigate, or
zip the whole folder to hand to a stakeholder.

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
  "Quiz questions are auto-generated from your assessment specs. Review each
  question in your LMS before publishing to students."
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

Assemble all generated files into the Common Cartridge package:

```bash
EXPORT_DIR=$(mktemp -d)
mkdir -p "$EXPORT_DIR/modules"
mkdir -p "$EXPORT_DIR/assignments"
mkdir -p "$EXPORT_DIR/quizzes"
mkdir -p "$EXPORT_DIR/discussions"

# Write imsmanifest.xml to $EXPORT_DIR/imsmanifest.xml
# Write module HTML files to $EXPORT_DIR/modules/
# Write assignment XML files to $EXPORT_DIR/assignments/
# Write quiz QTI XML files to $EXPORT_DIR/quizzes/
# Write discussion XML files to $EXPORT_DIR/discussions/
# Write syllabus HTML to $EXPORT_DIR/syllabus.html

# Package. $EXPORT_DIR here is the mktemp staging dir; $_EXPORT_DIR is the
# course-named folder under .idstack/exports/<slug>/ from the prep step above.
cd "$EXPORT_DIR"
zip -r course-export.imscc .
mv "$EXPORT_DIR/course-export.imscc" "$_EXPORT_DIR/course-export.imscc"
rm -rf "$EXPORT_DIR"
echo "Export saved to $_EXPORT_DIR/course-export.imscc"
```

Write each file individually using the Write tool, then package with Bash.
This ensures every file is correctly formed before zipping.

### A6. Verify the Package

```bash
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

Present verification to the user (substituting `$_EXPORT_DIR` in the file path):

```
## Common Cartridge Export Complete

File: .idstack/exports/<course-slug>/course-export.imscc
Size: {X} KB
Contents:
  - imsmanifest.xml
  - {N} module pages (.html)
  - {M} assignment documents (.xml)
  - {P} quiz documents (.xml, QTI format)
  - {Q} discussion topics (.xml)
  - Syllabus (.html)

Quiz questions are auto-generated from your assessment specs. Review each
question in your LMS before publishing to students.

To import into your LMS:
- **Canvas:** Settings > Import Course Content > Common Cartridge 1.x
- **Blackboard:** Course Management > Import > IMS Common Cartridge
- **Moodle:** Site Administration > Restore > Upload .imscc file
- **D2L/Brightspace:** Course Admin > Import/Export/Copy > Import Components
```

---

## Path B: Canvas API Push

### B1. Get Credentials

Ask the user for Canvas connection details. Use AskUserQuestion:

"I need three things to push your course to Canvas:

1. **Canvas URL** — Your institution's Canvas address
   (e.g., `https://canvas.university.edu`)

2. **Access token** — Generate one in Canvas:
   Account > Settings > scroll to 'Approved Integrations' > New Access Token

3. **Course ID** — The number in the URL when you open the course
   (e.g., `https://canvas.university.edu/courses/12345` > course ID is `12345`)
   Use an existing empty course shell, or create a new course first in Canvas.

Your token is used for this session only and is NEVER saved to any file."

### B2. Validate Connection

```bash
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/users/self" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
echo "HTTP: $HTTP_CODE"
echo "$BODY" | head -5
```

Handle errors:
- HTTP 401: "Token rejected. Make sure you copied the full token. In Canvas:
  Account > Settings > New Access Token."
- HTTP 403: "Access denied. Your token may not have the right permissions for
  this course. You need at least Teacher or Designer role."
- Network error: "Can't reach Canvas at that URL. Check the address and make
  sure it includes `https://`."

Verify course access:
```bash
curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID" 2>&1
```

- HTTP 404: "Course not found. Check the course ID. You can find it in the URL
  when you open the course in Canvas."
- HTTP 403: "You don't have access to this course. Ask your Canvas admin for
  Teacher or Designer role."

**SECURITY RULE: The token variable is used ONLY in curl commands within this
section. NEVER write the token to the manifest, to any file, or to conversation
output. After all API calls are complete, the token is discarded.**

### B3. Read Course Content

Same as A1 — read all files in `.idstack/course-content/` and the manifest.
Convert markdown content to HTML for the API calls (Canvas pages and assignments
accept HTML in their body fields).

### B4. Create Modules

For each module in the course content:

```bash
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -d "module[name]={module title}&module[position]={position}" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/modules" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
echo "HTTP: $HTTP_CODE"
MODULE_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "MODULE_ID=$MODULE_ID"
```

Publish the module:
```bash
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -d "module[published]=true" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/modules/$MODULE_ID"
```

Store the returned module ID for adding items in subsequent steps.

### B5. Create Pages and Add to Modules

For each module page (content, syllabus):

```bash
# Create the page
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "wiki_page[title]={page title}" \
  --data-urlencode "wiki_page[body]={html content}" \
  -d "wiki_page[published]=true" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/pages" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
PAGE_URL=$(echo "$BODY" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "HTTP: $HTTP_CODE"
echo "PAGE_URL=$PAGE_URL"
```

Then add the page to its module:
```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -d "module_item[title]={page title}&module_item[type]=Page&module_item[page_url]=$PAGE_URL&module_item[published]=true" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/modules/$MODULE_ID/items"
```

### B6. Create Assignments

For each assessment (essay, project, upload type):

```bash
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "assignment[name]={title}" \
  --data-urlencode "assignment[description]={html description with rubric}" \
  -d "assignment[points_possible]={points}" \
  -d "assignment[submission_types][]=online_text_entry" \
  -d "assignment[submission_types][]=online_upload" \
  -d "assignment[published]=false" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/assignments" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
ASSIGN_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "HTTP: $HTTP_CODE"
echo "ASSIGN_ID=$ASSIGN_ID"
```

Add the assignment to its module:
```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -d "module_item[title]={title}&module_item[type]=Assignment&module_item[content_id]=$ASSIGN_ID&module_item[published]=true" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/modules/$MODULE_ID/items"
```

Note: Assignments are created unpublished by default. The instructional designer
should review descriptions, rubrics, and due dates in Canvas before publishing.

### B7. Create Discussion Topics

For each discussion activity:

```bash
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "title={title}" \
  --data-urlencode "message={html discussion prompt}" \
  -d "published=false" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/discussion_topics" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)
TOPIC_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "HTTP: $HTTP_CODE"
echo "TOPIC_ID=$TOPIC_ID"
```

Add to its module:
```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -d "module_item[title]={title}&module_item[type]=Discussion&module_item[content_id]=$TOPIC_ID&module_item[published]=true" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/modules/$MODULE_ID/items"
```

### B8. Error Handling

Each API call is wrapped in error checking. Handle these cases:

- **HTTP 401:** Token expired or invalid. Stop and ask for a new token.
- **HTTP 403:** Insufficient permissions. Report which item failed and why.
- **HTTP 404:** Course or resource not found. Report the specific endpoint.
- **HTTP 422:** Validation error. Report the error message from Canvas.
  Common causes: duplicate page titles, missing required fields.
- **HTTP 429:** Rate limited. Wait 10 seconds, retry once. If still 429:
  "Canvas is rate-limiting requests. Waiting 30 seconds before continuing."
  Wait 30 seconds and retry. If still failing, log the item as failed and
  continue with the rest.
- **Timeout / network error:** Log the item as failed, continue with the rest.

If any single API call fails, log it and continue with remaining items. Do NOT
abort the entire export on a single failure. Present a summary at the end
showing what succeeded and what failed.

### B9. Present Summary

```
## Canvas Push Complete

Course: {title}
URL: {Canvas URL}/courses/{course_id}

| Item Type    | Created | Failed | Skipped |
|--------------|---------|--------|---------|
| Modules      | {N}     | {0}    | {0}     |
| Pages        | {M}     | {0}    | {0}     |
| Assignments  | {P}     | {0}    | {0}     |
| Discussions  | {Q}     | {0}    | {0}     |

Assignments and discussions are unpublished. Review them in Canvas before
publishing to students.

Open your course: {Canvas URL}/courses/{course_id}
```

If any items failed:
```
### Failed Items

| Item | Type | Error |
|------|------|-------|
| {name} | {type} | {error message} |

You can create these items manually in Canvas, or run `/course-export` again
to retry the failed items.
```

---

## Path C: SCORM 1.2 Package Export

### C1. Read Course Content Files

Read all files in `.idstack/course-content/`:

```bash
find .idstack/course-content/ -type f | sort
```

If no course content files exist, tell the user: "No course content found in
`.idstack/course-content/`. Run `/course-builder` first to generate content."

### C2. Create SCORM package structure

```bash
EXPORT_DIR=$(mktemp -d)
mkdir -p "$EXPORT_DIR/content"
echo "EXPORT_DIR=$EXPORT_DIR"
```

### C3. Generate HTML content pages

For each module page in `.idstack/course-content/`, convert the Markdown content
to a self-contained HTML page. Each page becomes a SCO (Shareable Content Object).

Write each HTML file to `$EXPORT_DIR/content/`:

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

Write `$EXPORT_DIR/imsmanifest.xml` following the SCORM 1.2 specification:

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

```bash
# Package. $EXPORT_DIR here is the mktemp staging dir; $_EXPORT_DIR is the
# course-named folder under .idstack/exports/<slug>/ from the prep step above.
cd "$EXPORT_DIR"
zip -r scorm-export.zip imsmanifest.xml content/
mv "$EXPORT_DIR/scorm-export.zip" "$_EXPORT_DIR/scorm-export.zip"
echo "SCORM package saved to $_EXPORT_DIR/scorm-export.zip"
```

### C6. Verify package

```bash
file "$_EXPORT_DIR/scorm-export.zip"
unzip -l "$_EXPORT_DIR/scorm-export.zip" | head -20
echo "Total files: $(unzip -l "$_EXPORT_DIR/scorm-export.zip" | tail -1)"
```

Verify:
- `imsmanifest.xml` exists at the root of the ZIP
- All `<file href>` references in the manifest have matching files in the ZIP
- The ZIP is not empty

### C7. Present export summary

```
## SCORM 1.2 Export Complete

File: .idstack/exports/<course-slug>/scorm-export.zip
Format: SCORM 1.2
SCOs: [count] (one per module)
Total files: [count]

### How to import

- **Any LMS:** Upload the .zip file through your LMS admin interface.
  Most LMS platforms auto-detect SCORM packages.
- **Canvas:** Settings > Import Course Content > SCORM package
- **Moodle:** Add Activity > SCORM package > Upload
- **Blackboard:** Content > Build Content > SCORM package
- **Corporate LMS (Cornerstone, SAP SuccessFactors, etc.):**
  Upload through your content management interface

### Limitations

- This SCORM package contains static HTML content. Interactive elements
  (drag-and-drop, branching scenarios) are not generated.
- SCORM API tracking (completion, score reporting) is not included.
  The LMS will mark the SCO as complete when the learner opens it.
- For richer interactivity, author in Articulate Rise or Storyline and
  use idstack's /course-quality-review and /red-team on the exported package.
```

### C8. Cleanup

```bash
rm -rf "$EXPORT_DIR"
```

---

## Generate Export Report

After the export completes (any path), write the HTML report at `$_REPORT_PATH` (from the Prepare Course Export Folder step) — i.e., `.idstack/exports/<course-slug>/course-export.html`. The report follows the **visual contract** in `templates/report.html.tmpl` and the **content contract** in `templates/report-format.md`. Use the standard CSS hooks: `<article class="finding sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`. Customize for this skill:

- **`{{skill_title}}`:** "Course Export Report"
- **`{{skill_name}}`:** `course-export`
- **`{{mode}}`:** include `format: imscc|canvas-api|scorm` in the header `meta` line.
- **Summary:** 2–3 sentences. What was exported, where it landed, and the readiness verdict (clean / with warnings) at the time of export. Include the optional one-line scoreboard: "Modules N · Pages M · Assignments P · Quizzes Q · Discussions R".
- **Skill-specific section before Findings** — add a `<section class="export-manifest">` with `<h2>Export contents</h2>` and an HTML `<table>` (Item type, Count, Notes). For Canvas API: include Created / Failed / Skipped columns instead.
- **Finding ids:** `export-1`, `readiness-1`, `qti-1`, etc. Findings come from auto-generated content the designer should review before publishing (quiz questions, rubric formatting, missing placeholders), readiness-check items at time of export, and items the API call failed on. If everything is clean, the Findings section can simply contain an `info` finding noting the clean state.
- **Optional skill-specific section** (after Top recommendations, before Limitations): `<section class="failed-items">` with `<h2>Failed items</h2>` only when the Canvas API path produced failed items.
- **Limitations:** SCORM/IMSCC packages contain static HTML; interactive elements aren't generated. Quiz questions are auto-generated from assessment specs and need designer review. Tokens are never written to disk.
- **Next steps:** Verify that the LMS import preserved everything correctly. Pay particular attention to quiz questions, assignment rubrics, discussion prompts, and module sequencing. If the readiness verdict was "with warnings," address the flagged findings before publishing.

---

## Manifest Write

After export completes (any path) and the report is written, update the project
manifest with export metadata.

**CRITICAL -- Manifest Integrity Rules:**
1. If a manifest already exists, READ it first with the Read tool.
2. Modify ONLY the `export_metadata` section and the `updated` timestamp.
   Preserve all other sections unchanged — `context`, `needs_analysis`,
   `learning_objectives`, `quality_review`, `import_metadata`, and any other
   sections must remain exactly as they were.
3. Before writing, verify the JSON is valid: matching braces, proper commas,
   quoted strings, no trailing commas.
4. Update the top-level `updated` timestamp to reflect the current time.
5. If this is a new manifest (unlikely for export, but possible), initialize
   ALL sections with empty/default values so downstream skills find the
   expected structure.

### Readiness Info

Before starting the export, check the manifest for prior review data. If any of
these sections exist, show a brief readiness summary as context (not a gate):

```
Export readiness:
  Quality review:       78/100 ✓ (reviewed 2026-04-08)
  Red-team audit:       2 critical, 3 warning
  Accessibility review: WCAG score 70/100, 1 AA violation
```

If a section doesn't exist, show: "Not reviewed — run /[skill-name] for analysis."

This is informational. Export proceeds regardless. The user can choose to address
findings first or export now, no AskUserQuestion needed, just show the info and continue.

### Write Export Metadata

Add or update the `export_metadata` field at the root level:

```json
{
  "export_metadata": {
    "report_path": "<set to $_REPORT_PATH from the Prepare Course Export Folder block — e.g. .idstack/exports/<course-slug>/course-export.html>",
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
Populate it by reading the `quality_review`, `red_team_audit`, and `accessibility_review`
sections from the manifest (if they exist). The `verdict` is:
- `export_clean`: all reviewed, no critical findings
- `export_with_warnings`: reviewed but has critical/warning findings
- `export_blocked`: not used (export never blocks, advisory only)
- Empty string if no reviews exist

Write the manifest, then confirm:

"Your export metadata has been saved to `.idstack/project.json`.

Your course has been exported. Verify that the LMS import preserved
everything correctly. Pay particular attention to:
- Quiz questions (auto-generated, may need editing)
- Assignment rubrics (verify formatting survived the transfer)
- Discussion prompts (check that instructions are clear)
- Module sequencing (verify order matches your intended flow)"

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
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"course-export","event":"completed"}'
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
"$_IDSTACK/bin/idstack-learnings-log" '{"skill":"course-export","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
