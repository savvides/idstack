---
name: course-import
description: |
  Universal course import from any LMS. Reads IMS Common Cartridge files,
  pasted course documents, or Canvas REST API. Maps course structure to the
  idstack manifest with quality flags, task analysis, and Bloom's classification.
  Works with Canvas, Blackboard, Moodle, and D2L. (idstack)
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

**Skill-specific manifest check:** If the manifest `course_import` section already has data,
ask the user: "I see you've already run this skill. Want to update the results or start fresh?"

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

- Well-planned, well-designed courses enhance learning outcomes [Online-13] [T1].
  Quality review starts at import, not after. Detecting structural gaps early
  saves redesign time later.
- Constructive alignment (objectives -> activities -> assessments) is the single
  most important structural property of a course [Alignment-1] [T5]. The import
  should detect alignment (or its absence) from the source data.
- The revised Bloom's taxonomy (Anderson & Krathwohl) classifies objectives on
  two dimensions: knowledge type and cognitive process [Alignment-7] [T3].
  Pre-classification during import saves time for /learning-objectives.

## Evidence Tier Key

Every recommendation and flag includes its evidence tier:
- [T1] RCTs, meta-analyses with learning outcome measures
- [T2] Quasi-experimental with appropriate controls
- [T3] Systematic reviews (synthesis of mixed evidence)
- [T4] Observational / pre-post without comparison groups
- [T5] Expert opinion, literature reviews, theoretical frameworks

---

## Preamble: Project Manifest

Before starting the import, check for an existing project manifest.

```bash
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  "$_IDSTACK/bin/idstack-migrate" .idstack/project.json 2>/dev/null || cat .idstack/project.json
else
  echo "NO_MANIFEST"
fi
```

**If MANIFEST_EXISTS:**
- Read the manifest. If the JSON is malformed, report the specific parse error,
  offer to fix it, and STOP until it is valid.
- Check which sections have data:
  - If `needs_analysis` has data from /needs-analysis: note it. You will PRESERVE
    this data. Import adds to task_analysis and learner_profile, does not replace.
  - If `learning_objectives` has data from /learning-objectives: ask the user
    "You already have learning objectives in your manifest. Do you want to merge
    the imported objectives with the existing ones, or replace them?"
- Preserve all sections you don't write to.

**If NO_MANIFEST:**
- You will create the manifest at the end of this skill's workflow.

---

## Step 1: Input Selection

Ask the user how they want to import their course. Use AskUserQuestion:

"How do you want to import your course?"

Options:
- A) **IMS Common Cartridge file (.imscc)** — Universal format. Export from Canvas,
     Blackboard, Moodle, or D2L. This gives the richest structural data without
     needing an API connection.
- B) **Paste course documents** — Copy and paste your syllabus, module outline,
     or assignment descriptions. Zero friction, works with any course.
- C) **Canvas API** — Connect directly to Canvas with an access token. Pulls the
     live course structure including rubrics and outcomes.
- D) **PDF or document file** — Upload a PDF exported from Articulate Rise,
     Storyline, or any authoring tool. Also works with Word docs, course packets,
     and syllabus PDFs. Provide the file path and the AI reads it directly.
- E) **SCORM package (.zip)** — Import a SCORM 1.2 or 2004 package exported from
     Articulate Rise, Storyline, Adobe Captivate, Lectora, iSpring, or any
     SCORM-compliant authoring tool. Extracts course structure from imsmanifest.xml.

---

## Path A: IMS Common Cartridge Import

### A1. Get the file path

Ask: "Where is your .imscc file? Provide the file path (drag and drop the file
into this window to paste the path)."

### A2. Validate and extract

```bash
# Check file exists
if [ ! -f "$CARTRIDGE_PATH" ]; then
  echo "FILE_NOT_FOUND"
else
  # Check it's a valid ZIP
  file "$CARTRIDGE_PATH"
fi
```

If FILE_NOT_FOUND: "File not found at that path. Check the path and try again."
If not a ZIP: "This doesn't look like a Common Cartridge file. It should be a
.imscc file exported from your LMS."

Extract the cartridge. **Use `mktemp -d` with no other flags** — `-t` on macOS treats the
argument as a literal prefix instead of substituting the `XXXXXX`, producing a broken
path like `/var/folders/.../idstack-import.XXXXXX.suffix`. The bare `mktemp -d` form is
portable across macOS and Linux:

```bash
IMPORT_DIR=$(mktemp -d)
unzip -q "$CARTRIDGE_PATH" -d "$IMPORT_DIR" 2>&1
echo "IMPORT_DIR=$IMPORT_DIR"
ls "$IMPORT_DIR/"
```

### A3. Find and read the manifest

```bash
if [ -f "$IMPORT_DIR/imsmanifest.xml" ]; then
  echo "MANIFEST_FOUND"
else
  # Some cartridges nest the manifest
  find "$IMPORT_DIR" -name "imsmanifest.xml" -type f
fi
```

If no imsmanifest.xml found: "This ZIP doesn't contain an IMS manifest. Is this
a Common Cartridge export? Try re-exporting from your LMS."

Read the manifest XML:

```bash
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
  - `imsqti_xmlv2p1` or `imsqti_xmlv1p2` → quizzes/assessments
  - `imsbasiclti_xmlv1p0` → external tool integrations
  - `imsdt_xmlv1p0` or `topic` → discussion topics
  - `assignment_xmlv1p0` or `assignment` → assignments

**Learning outcomes (if present):**
- Look for `<imscc:learningOutcomes>` or similar elements
- Canvas exports include outcomes in `<metadata>` sections
- Extract outcome text for Bloom's classification

Read resource files for additional detail when the manifest references them:

```bash
# Read assignment details, quiz content, etc.
ls "$IMPORT_DIR"/*.xml "$IMPORT_DIR"/**/*.xml 2>/dev/null | head -20
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
rm -rf "$IMPORT_DIR"
```

Continue to Step 2 (Quality Flags).

---

## Path B: Paste Documents Import

### B1. Get the documents

Ask: "Paste your course documents below. This could be a syllabus, module outline,
assignment list, or course description. The more detail you provide, the better I
can map your course structure.

Paste the content and I'll extract the structure."

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

### B3. Confirm extracted structure

Present the extracted structure for confirmation:

```
## Extracted Course Structure

**Title:** [extracted title]
**Modules found:** [count]

| # | Module | Items | Objectives | Assessments |
|---|--------|-------|------------|-------------|
| 1 | [name] | [count] | [count] | [count] |
| 2 | [name] | [count] | [count] | [count] |
...

**Learning objectives found:** [count]
**Assessments found:** [count]
**Activities found:** [count]

Does this look right? If I missed anything or got something wrong, let me know.
```

If the user corrects something, incorporate the corrections.

Continue to Step 2 (Quality Flags).

---

## Path D: PDF / Document File Import

### D1. Get the file path

Ask: "Where is your PDF or document file? Provide the file path (drag and drop the
file into this window to paste the path).

This works with PDFs exported from Articulate Rise, Storyline, Adobe Captivate,
or any authoring tool. Also works with Word documents, course packets, and syllabus PDFs."

### D2. Read the file

Use the Read tool to read the file at the provided path. The Read tool can read
PDFs directly (multimodal).

If the file does not exist, ask the user to check the path.

If the PDF is large (more than 10 pages), read in chunks using the `pages` parameter:
- First pass: pages "1-10"
- If more content exists: pages "11-20", etc.
- Maximum 50 pages total. If the PDF is longer, note: "Reading first 50 pages.
  If important content is after page 50, let me know which pages to focus on."

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
Flag these as "interactive element not captured in PDF" in the import quality triage.

### D4. Confirm extracted structure

Present the extracted structure for confirmation (same format as Path B, Step B3).

If the user corrects something, incorporate the corrections.

Continue to Step 2 (Quality Flags).

---

## Path C: Canvas REST API Import

### C1. Get credentials

Ask: "I need two things to connect to Canvas:

1. **Canvas URL** — Your institution's Canvas address
   (e.g., `https://canvas.university.edu`)

2. **Access token** — Generate one in Canvas:
   Account → Settings → scroll to 'Approved Integrations' → New Access Token

3. **Course ID** — The number in the URL when you open the course
   (e.g., `https://canvas.university.edu/courses/12345` → course ID is `12345`)

Your token is used for this session only and is NEVER saved to any file."

### C2. Validate connection

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
  Account → Settings → New Access Token."
- HTTP 403: "Access denied. Your token may not have the right permissions."
- Network error: "Can't reach Canvas at that URL. Check the address."

### C3. Fetch course data

**SECURITY RULE: The token variable is used ONLY in curl commands within this
section. NEVER write the token to the manifest, to any file, or to conversation
output. After all API calls are complete, the token is discarded.**

Fetch in this order (each is a separate curl call):

**Course info:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID" | head -200
```

**Modules with items:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/modules?include[]=items&per_page=50"
```

**Assignments:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/assignments?per_page=50"
```

**Pages (first page only for structure):**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/pages?per_page=50"
```

**Discussion topics:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/discussion_topics?per_page=50"
```

**Outcomes (if available):**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/outcome_groups?per_page=50"
```

For each outcome group found, fetch individual outcomes:
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/courses/$COURSE_ID/outcome_groups/$GROUP_ID/outcomes?per_page=50"
```

**Pagination:** If a response includes a `Link` header with `rel="next"`, follow
it for up to 10 pages (500 items max per endpoint). After 500 items, stop and note
"Partial import: course has more items than the import limit."

**Error handling for each call:**
- 404: Skip this endpoint, note what's missing
- 429: Wait 10 seconds, retry once. If still 429: "Canvas is rate-limiting.
  Wait a minute and try `/course-import` again."
- Timeout: "Canvas didn't respond for [endpoint]. Continuing with what we have."

### C4. Map API response to course structure

From the API responses, extract:

- **Course metadata:** name, term, start/end dates, enrollment count
- **Modules:** name, position, items (with type: Assignment, Page, Discussion, etc.)
- **Assignments:** name, description, points_possible, grading_type, submission_types, rubric
- **Pages:** title (for content page count)
- **Discussions:** title, assignment_id (graded discussions)
- **Outcomes:** title, description, mastery_points, ratings

Continue to Step 2 (Quality Flags).

---

## Path E: SCORM Package Import

### E1. Get the file path

Ask: "Where is your SCORM package (.zip)? Provide the file path (drag and drop the
file into this window to paste the path).

This works with SCORM 1.2 and SCORM 2004 packages from Articulate Rise, Storyline,
Adobe Captivate, Lectora, iSpring, or any SCORM-compliant authoring tool."

### E2. Validate and extract

```bash
# Check file exists
if [ ! -f "$SCORM_PATH" ]; then
  echo "FILE_NOT_FOUND"
else
  file "$SCORM_PATH"
fi
```

If FILE_NOT_FOUND: "File not found at that path. Check the path and try again."
If not a ZIP: "This doesn't look like a SCORM package. It should be a .zip file
exported from your authoring tool."

Extract the package:

```bash
IMPORT_DIR=$(mktemp -d)
unzip -q "$SCORM_PATH" -d "$IMPORT_DIR" 2>&1
echo "IMPORT_DIR=$IMPORT_DIR"
ls "$IMPORT_DIR/"
```

### E3. Find and read the manifest

```bash
if [ -f "$IMPORT_DIR/imsmanifest.xml" ]; then
  echo "SCORM_MANIFEST_FOUND"
  cat "$IMPORT_DIR/imsmanifest.xml"
else
  echo "NO_SCORM_MANIFEST"
fi
```

If NO_SCORM_MANIFEST: "No imsmanifest.xml found in this ZIP. This may not be a valid
SCORM package. Try exporting again from your authoring tool, or use Path D (PDF import)
instead."

### E4. Detect SCORM version

From the manifest XML, check namespaces and schema references:
- If `adlcp_rootv1p2` or `adlcp:scormtype` (lowercase) → SCORM 1.2
- If `adlcp_v1p3` or `adlcp:scormType` (camelCase) → SCORM 2004
- Note the version for the user: "Detected SCORM [version] package."

### E5. Parse manifest structure

From `imsmanifest.xml`, extract:

**From `<organizations>`:**
- The default organization (identified by `default` attribute on `<organizations>`)
- Walk the `<item>` tree recursively to build the module hierarchy
- For each item: `identifier`, `title`, `identifierref` (links to resource)
- Items with children are module containers (aggregations)
- Leaf items with `identifierref` are deliverable content (SCOs or assets)

**From `<resources>`:**
- For each `<resource>`: `identifier`, `type`, `href` (launch file), `adlcp:scormType`
- SCO resources contain the actual learning content
- Asset resources are supporting files (images, scripts, CSS)
- Read the HTML content of SCO launch files to extract learning content:

```bash
# For each SCO resource, read its launch file
for sco_href in $SCO_HREFS; do
  if [ -f "$IMPORT_DIR/$sco_href" ]; then
    echo "=== SCO: $sco_href ==="
    cat "$IMPORT_DIR/$sco_href"
  fi
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

### E7. Confirm extracted structure

Present the extracted structure for confirmation:

```
## Extracted Course Structure (SCORM [version])

**Title:** [extracted title]
**Authoring tool:** [detected or unknown]
**Modules found:** [count]
**SCOs:** [count] | **Assets:** [count]

| # | Module | Items | Objectives | Assessments |
|---|--------|-------|------------|-------------|
| 1 | [name] | [count] | [count] | [count] |
| 2 | [name] | [count] | [count] | [count] |
...

**Learning objectives found:** [count]
**Assessments found:** [count]

Does this look right? If I missed anything or got something wrong, let me know.
```

If the user corrects something, incorporate the corrections.

### E8. Cleanup

```bash
rm -rf "$IMPORT_DIR"
```

Continue to Step 2 (Quality Flags).

---

## Step 2: Quick-Scan Quality Flags

After extracting course structure from ANY input method, scan for obvious quality
issues. This is NOT a full /course-quality-review. This is a quick triage that
flags problems visible in the structural data alone.

**Structural flags:**
- Count modules vs modules with stated objectives. Flag if < 50% have objectives:
  "⚠ {X} of {Y} modules have no stated learning objectives"
- Count assessments with rubrics vs without. Flag if < 25% have rubrics:
  "⚠ {X} of {Y} assessments have no rubric [Assessment-8] [T1]"
- Check for discussion/collaborative activities. Flag if zero:
  "⚠ No discussion or collaborative activities found — social presence gap risk
  [Online-15] [T2]"
- Check for accessibility info. Flag if none:
  "⚠ No accessibility information found for course materials"
- Check for learner support resources. Flag if none:
  "⚠ No learner support section detected (tutoring, office hours, tech support)"

**Alignment flags:**
- If objectives exist AND assessments exist but no clear mapping between them:
  "⚠ Objectives and assessments found but no alignment mapping detected"
- If all assessments are the same type (e.g., all quizzes):
  "⚠ All {X} assessments are {type} — consider varied assessment for different
  Bloom's levels [Assessment-10] [T1]"

**Assessment feedback flags:**
- If quizzes are auto-graded with no indication of elaborated feedback:
  "⚠ Auto-graded assessments detected. Elaborated feedback (explaining WHY) produces
  larger learning gains than correctness-only feedback [Assessment-8] [T1]"

Present the flags:

```
## Import Quality Triage

Found {N} flags during import:
{list each flag with ⚠ prefix}

These are quick observations from the course structure, not a full review.
Run /course-quality-review for an evidence-based audit with specific recommendations.
```

If zero flags: "No obvious structural issues detected during import. Run
/course-quality-review for a deeper analysis."

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

Present for user review:

```
## Inferred Task Analysis

I've mapped your {N} modules to task analysis entries. Please review and adjust:

| ID | Task | Frequency | Criticality | Difficulty |
|----|------|-----------|-------------|------------|
| T-1 | [performance statement] | [est.] | [est.] | [est.] |
...

These estimates are based on module structure. Edit any that don't match your
actual course context.
```

Ask the user to confirm or edit via AskUserQuestion.

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
     Mark as "verify with /learning-objectives" [Alignment-12] [T2]

5. **Set alignment_status to "imported-unverified"** — the user should run
   /learning-objectives to verify and check bidirectional alignment

Assign ILO IDs: ILO-1, ILO-2, etc.

Present for review:

```
## Imported Learning Objectives (Bloom's pre-classification)

| ID | Objective | Knowledge | Process | Status |
|----|-----------|-----------|---------|--------|
| ILO-1 | [text] | [dim] | [proc] | high confidence |
| ILO-2 | [text] | [dim] | [proc] | ambiguous — verify |
...

All classifications are marked "imported-unverified." Run /learning-objectives
to verify Bloom's levels and check alignment with activities and assessments.
```

---

## Step 5: Generate Import Report

Before writing the manifest, generate an HTML report so the designer has a single document about what came in and where the quality flags are. The report follows the **visual contract** in `templates/report.html.tmpl` and the **content contract** in `templates/report-format.md`.

```bash
# Compute the course slug from project_name and prepare the export folder.
_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")
_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
_REPORT_PATH="$_EXPORT_DIR/course-import.html"
mkdir -p "$_EXPORT_DIR/assets"
cp -f "$_IDSTACK/templates/assets/idstack.css" "$_EXPORT_DIR/assets/idstack.css"
echo "Report path: $_REPORT_PATH"
```

Write the HTML report at the path printed above (`.idstack/exports/<course-slug>/course-import.html`), following the structure of `templates/report.html.tmpl`. Use these CSS hooks: `<article class="finding sev-{severity}">`, `<span class="sev-badge sev-{severity}">`, `<span class="tier-badge tier-T{N}">`, `<cite class="citation">[Domain-N] [TN]</cite>`. Customize for this skill:

- **`{{skill_title}}`:** "Course Import Report"
- **`{{skill_name}}`:** `course-import`
- **`{{mode}}`:** include `source: cartridge|paste|canvas-api|pdf|scorm` and `source LMS: canvas|blackboard|moodle|d2l|rise|storyline|unknown` in the header `meta` line.
- **Summary:** 2–3 sentences. What came in (N modules, M objectives, P assessments), how many quality flags were raised, and the single most important thing the designer should know — e.g., "Import is structurally clean but objectives are sparse." or "Cartridge schema is valid but 8/12 modules are missing rubrics."
- **Skill-specific sections before Findings**:
  - `<section class="imported">` with `<h2>Imported</h2>` and an HTML `<table>` (Item, Count). Rows: Modules, Objectives, Assessments, Activities/discussions, Pages, Rubrics.
- **Finding ids:** `import-1`, `quality-1`, `bloom-1`, etc. Findings come from import quality flags, missing rubrics, missing objectives, alignment-already-broken-on-arrival, and Bloom's-inference low-confidence classifications.
- **Optional skill-specific section** (after Top recommendations, before Limitations): `<section class="blooms-classification">` with `<h2>Bloom's classification</h2>` and an HTML `<table>` (ILO ID, Statement (truncated), Bloom's level, Confidence). Note any low-confidence classifications the designer should verify.
- **Limitations:** structural metadata only — interactive elements (Storyline, flashcards) don't render in PDF; Canvas API auth tokens are never written to disk; SCORM packages with non-standard manifest extensions may have been parsed loosely.
- **Next steps** (use an `<ol>`):
  1. Run `/idstack:course-quality-review` for the full evidence-based audit.
  2. Run `/idstack:learning-objectives` to verify the Bloom's inference and check bidirectional alignment.
  3. Run `/idstack:needs-analysis` (in audit-existing mode) to add the organizational context and learner profile that can't be extracted from the cartridge.

---

## Step 6: Write Manifest

Create or update the project manifest.

**Why this skill uses the Write-tool fallback (not `bin/idstack-manifest-merge`):** course-import writes a top-level field (`project_name`), partial fields inside `context` (`modality`, `timeline`, `available_tech`), nested entries under `needs_analysis.task_analysis.job_tasks`, additions inside `learning_objectives.ilos` and `learning_objectives.alignment_matrix`, AND the `import_metadata` section. The merge tool only does whole-section replacement, which would clobber co-owned sections. So this skill goes through the Read-modify-Write fallback path described in `templates/manifest-schema.md`.

**CRITICAL — Manifest Integrity Rules:**
1. If a manifest already exists, READ it first.
2. PRESERVE sections populated by other skills (especially needs_analysis from
   /needs-analysis). Import ADDS to these sections, does not replace.
3. If learning_objectives already has data and the user chose "merge," combine
   imported ILOs with existing ones (use new ILO IDs that don't conflict).
4. Include the COMPLETE schema structure. Do not omit fields.
5. Before writing, verify the JSON is valid.
6. Update the `updated` timestamp.
7. **NEVER write the Canvas API token to the manifest or any file.**

**Fields populated by /course-import:**

- `project_name` — from course title
- `context.modality` — inferred from course structure (async=online, sync sessions=hybrid)
- `context.timeline` — from term/date info if available
- `context.available_tech` — from detected resource types (LMS, video, discussions, etc.)
- `needs_analysis.task_analysis.job_tasks` — from module-to-task mapping (Step 3)
- `learning_objectives.ilos` — from Bloom's inference (Step 4)
- `learning_objectives.alignment_matrix` — partial, from detected objective-assessment links

**Import metadata:** Set the top-level `import_metadata` section. Shown here in the context of the full manifest the Write tool will produce (the outer `import_metadata` key is the section's slot in the manifest, not a wrapper to nest inside the section itself):

```json
{
  "import_metadata": {
    "source": "cartridge|paste|canvas-api",
    "report_path": "<set to $_REPORT_PATH from the Step 5 bash block — e.g. .idstack/exports/<course-slug>/course-import.html>",
    "imported_at": "ISO-8601",
    "source_lms": "canvas|blackboard|moodle|d2l|unknown",
    "items_imported": {
      "modules": 0,
      "objectives": 0,
      "assessments": 0,
      "activities": 0,
      "pages": 0
    },
    "quality_flags": 0
  }
}
```

Write the manifest, then confirm:

```
## Import Complete

**Source:** {input method}
**Course:** {title}

**Imported:**
- {N} modules → {N} task analysis entries
- {M} learning objectives (Bloom's pre-classified)
- {P} assessments
- {Q} activities/discussions
- {R} content pages

**Quality triage:** {F} flags found

**Two artifacts:**
- **Read this:** `.idstack/exports/<course-slug>/course-import.html` — the import report
  with evidence-backed quality flags, the Bloom's classification table, and recommended
  next steps tied to specific findings. Open it in any browser; the folder is self-contained.
- System state: `.idstack/project.json` (the manifest — for downstream skills).

**Recommended next steps:**
1. `/course-quality-review` — Full evidence-based audit with QM standards and
   CoI presence analysis
2. `/learning-objectives` — Verify Bloom's classifications and check
   bidirectional alignment (objectives ↔ activities ↔ assessments)
3. `/needs-analysis` — Add organizational context and learner profile data
   that can't be extracted from the course structure alone
```

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
"$_IDSTACK/bin/idstack-timeline-log" '{"skill":"course-import","event":"completed"}'
```

Replace the JSON above with actual data from this session. Include skill-specific fields
where available (scores, counts, flags). Log synchronously (no background &).

If you discover a non-obvious project-specific quirk during this session (LMS behavior,
import format issue, course structure pattern), also log it as a learning:

```bash
"$_IDSTACK/bin/idstack-learnings-log" '{"skill":"course-import","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":8,"source":"observed"}'
```
