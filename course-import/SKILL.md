---
name: idstack-course-import
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


## Preamble: Update Check

```bash
_IDSTACK="${IDSTACK_HOME:-~/.claude/skills/idstack}"
_UPD=$("$_IDSTACK/bin/idstack-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD"
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A newer version of idstack is available. Run `cd ${IDSTACK_HOME:-~/.claude/skills/idstack} && git pull && ./setup` to update. (The `./setup` step is required — it cleans up old symlinks.)" Then continue normally.

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

Extract the cartridge:

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

## Step 5: Write Manifest

Create or update the project manifest.

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

**Import metadata:** Add an `import_metadata` field at the root level:

```json
{
  "import_metadata": {
    "source": "cartridge|paste|canvas-api",
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

**Your manifest has been saved to `.idstack/project.json`.**

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

The complete manifest schema. Use this as the template when creating or validating
the manifest. All fields shown below must exist in the JSON.

```json
{
  "version": "1.0",
  "project_name": "",
  "created": "",
  "updated": "",
  "import_metadata": {
    "source": "",
    "imported_at": "",
    "source_lms": "",
    "items_imported": {
      "modules": 0,
      "objectives": 0,
      "assessments": 0,
      "activities": 0,
      "pages": 0
    },
    "quality_flags": 0
  },
  "context": {
    "modality": "",
    "timeline": "",
    "class_size": "",
    "institution_type": "",
    "available_tech": []
  },
  "needs_analysis": {
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
    "ilos": [],
    "alignment_matrix": {
      "ilo_to_activity": {},
      "ilo_to_assessment": {},
      "gaps": []
    },
    "expertise_reversal_flags": []
  },
  "quality_review": {
    "last_reviewed": "",
    "qm_standards": {
      "course_overview": {"status": "", "findings": []},
      "learning_objectives": {"status": "", "findings": []},
      "assessment": {"status": "", "findings": []},
      "instructional_materials": {"status": "", "findings": []},
      "learning_activities": {"status": "", "findings": []},
      "course_technology": {"status": "", "findings": []},
      "learner_support": {"status": "", "findings": []},
      "accessibility": {"status": "", "findings": []}
    },
    "coi_presence": {
      "teaching_presence": {"score": 0, "findings": []},
      "social_presence": {"score": 0, "findings": []},
      "cognitive_presence": {"score": 0, "findings": []}
    },
    "alignment_audit": {"findings": []},
    "overall_score": 0,
    "recommendations": []
  }
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
