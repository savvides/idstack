# Canvas Full-Course Crawler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the idstack Chrome Extension to automatically navigate and audit an entire Canvas LMS course in the background via the Canvas REST API, evaluating full-course constructive alignment with zero IT setup.

**Architecture:** Detect Canvas course root URLs (`/courses/:id`) in the content script; trigger background API fetching via the service worker using active session cookies (`/api/v1/courses/:id?include[]=syllabus_body` and `/api/v1/courses/:id/assignments`); clean and aggregate course data with a 40k character cap; pass to a course-level prompt engine evaluating constructive alignment across modules; display real-time crawl progress and render scholarly T1–T5 course audit findings in the Side Panel.

**Tech Stack:** Chrome Extension Manifest V3 (Side Panel, Background Service Worker, Content Scripts, Storage API), Vanilla JavaScript (ES modules + CommonJS test companions), Vanilla CSS adhering to `DESIGN.md`.

## Global Constraints

- **Design System:** Strictly follow `DESIGN.md` (Source Serif 4, Public Sans, JetBrains Mono, `#faf8f3` ivory background, `#ffffff` card surfaces, `#1a1815` ink, canonical T1–T5 palette: T1 `#2f7a4a`, T2 `#2864a8`, T3 `#a87726`, T4 `#b35a1f`, T5 `#6b6b6b`).
- **Zero Build Overhead:** Pure Vanilla JS and CSS without bundlers, webpack, or npm runtime dependencies.
- **Privacy & FERPA:** Only extract syllabus, assignment descriptions, and rubrics. Never touch student rosters, submissions, or grades.
- **Free Tier Onboarding:** Provide direct link to Google AI Studio for free Gemini API keys, plus a rich demo fallback mode for instant testing without an API key.
- **T1–T5 Research Grounding:** All course audit prompts ground alignment ratings in `evidence/references.md` (Biggs constructive alignment, Bloom's taxonomy, Hattie feedback, Sweller cognitive load).

---

### Task 1: Canvas Course Root Detection & Course Prompt Engine

**Files:**
- Modify: `extension/content/extractor-core.js`
- Modify: `extension/content/extractor-core.cjs`
- Modify: `extension/shared/prompts.js`
- Modify: `extension/shared/prompts.cjs`
- Test: `test/test-extractor.js`
- Test: `test/test-prompts.js`

**Interfaces:**
- Produces: `detectCourseContext(url, docTitle)` returning `{ isCourseRoot: boolean, courseId: string|null, origin: string|null }`
- Produces: `buildCourseAuditPrompt(courseData)` returning structured prompt string requiring JSON course alignment evaluation.

- [ ] **Step 1: Write failing tests for course root detection and course prompt builder**

Add to `test/test-extractor.js`:
```javascript
// Test: Canvas Course Root Detection
const { detectCourseContext } = require('../extension/content/extractor-core.cjs');
const rootCtx = detectCourseContext('https://canvas.instructure.com/courses/987654', 'Biology 101');
assert.strictEqual(rootCtx.isCourseRoot, true);
assert.strictEqual(rootCtx.courseId, '987654');
assert.strictEqual(rootCtx.origin, 'https://canvas.instructure.com');

const subpageCtx = detectCourseContext('https://canvas.instructure.com/courses/987654/assignments/123', 'Lab 1');
assert.strictEqual(subpageCtx.isCourseRoot, false);
assert.strictEqual(subpageCtx.courseId, '987654');
```

Add to `test/test-prompts.js`:
```javascript
const { buildCourseAuditPrompt } = require('../extension/shared/prompts.cjs');
assert.strictEqual(typeof buildCourseAuditPrompt, 'function');
const coursePrompt = buildCourseAuditPrompt({
  title: 'Biology 101',
  syllabus: 'Course objectives and grading policy...',
  assignments: [
    { title: 'Quiz 1', description: 'Recall cell parts', points: 10 },
    { title: 'Final Project', description: 'Design an experiment', points: 100 }
  ]
});
assert.ok(coursePrompt.includes('Biology 101'));
assert.ok(coursePrompt.includes('Constructive Alignment'));
assert.ok(coursePrompt.includes('courseAudit'));
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-extractor.js && node test/test-prompts.js`
Expected: FAIL with `detectCourseContext is not a function` or `buildCourseAuditPrompt is not a function`.

- [ ] **Step 3: Implement minimal code in extractor-core and prompts**

In `extension/content/extractor-core.js` and `.cjs`:
```javascript
export function detectCourseContext(url, docTitle) {
  if (!url) return { isCourseRoot: false, courseId: null, origin: null };
  try {
    const parsedUrl = new URL(url);
    const match = parsedUrl.pathname.match(/\/courses\/(\d+)(?:\/)?$/);
    const anyCourseMatch = parsedUrl.pathname.match(/\/courses\/(\d+)/);
    return {
      isCourseRoot: !!match,
      courseId: anyCourseMatch ? anyCourseMatch[1] : null,
      origin: parsedUrl.origin
    };
  } catch (e) {
    return { isCourseRoot: false, courseId: null, origin: null };
  }
}
```

In `extension/shared/prompts.js` and `.cjs`:
```javascript
export function buildCourseAuditPrompt(courseData) {
  const assignmentsSummary = (courseData.assignments || [])
    .map((a, i) => `Assignment ${i+1}: ${a.title} (${a.points || 0} pts)\nDescription: ${(a.description || '').slice(0, 500)}`)
    .join('\n\n');

  return `You are an expert instructional designer and cognitive scientist using the idstack evidence base.
Perform a full-course constructive alignment audit for the following course:

COURSE TITLE: ${courseData.title || 'Canvas Course'}
SYLLABUS & LEARNING OBJECTIVES:
${(courseData.syllabus || 'No syllabus provided').slice(0, 8000)}

COURSE ASSIGNMENTS & ASSESSMENTS (${(courseData.assignments || []).length} items):
${assignmentsSummary.slice(0, 20000)}

Evaluate whether the assessment system constructively aligns with stated learning outcomes (Biggs 1996 [T2], Liou et al. 2023 [T2]).
Identify cognitive load bottlenecks (Sweller 2011 [T1]), scaffolding gaps (Wood et al. 1976 [T2]), and formative feedback quality (Wisniewski et al. 2020 [T1]).

Respond with ONLY a valid JSON object matching this schema:
{
  "summary": {
    "bloomsLevel": "Overall Cognitive Demand (e.g. Apply / Analyze)",
    "alignmentScore": "High (90%) | Moderate (70%) | Low (40%)",
    "keyTakeaway": "1-2 sentence executive summary of course-wide curriculum alignment."
  },
  "findings": [
    {
      "severity": "critical" | "warning" | "info",
      "tier": "T1" | "T2" | "T3" | "T4" | "T5",
      "citation": "[Domain-ID] Citation Name",
      "observation": "What was identified across the course syllabus and assignments.",
      "evidence": "Author (Year) [Tier description]: Empirical finding.",
      "recommendation": "Concrete actionable curriculum fix."
    }
  ],
  "improvedDraft": {
    "title": "Course Alignment & Scaffolding Matrix",
    "content": "Markdown formatted course roadmap and revised assessment scaffolding."
  }
}`;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `node test/test-extractor.js && node test/test-prompts.js`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add extension/content/extractor-core.* extension/shared/prompts.* test/test-extractor.js test/test-prompts.js
git commit -m "feat(extension): add canvas course root detector and course-level audit prompt builder"
```

---

### Task 2: Canvas Background Crawler Engine & Demo Fallback

**Files:**
- Create: `extension/background/canvas-crawler.js`
- Create: `extension/background/canvas-crawler.cjs`
- Modify: `extension/background/parser-helper.js`
- Modify: `extension/background/parser-helper.cjs`
- Modify: `extension/background/service-worker.js`
- Create: `test/test-crawler.js`
- Modify: `test/test-service-worker.js`

**Interfaces:**
- Produces: `crawlCanvasCourse(origin, courseId, fetchImpl)` returning aggregated course object `{ title, syllabus, assignments: [{ title, description, points }] }`
- Produces: `getDemoCourseAuditResult(payload)` returning realistic course-wide audit result for demo mode.
- Consumes: `buildCourseAuditPrompt`, `callLlmApi`, `saveAuditResult`.

- [ ] **Step 1: Write failing test in `test/test-crawler.js`**

Create `test/test-crawler.js`:
```javascript
const assert = require('assert');
const { crawlCanvasCourse, stripHtml } = require('../extension/background/canvas-crawler.cjs');
const { getDemoCourseAuditResult } = require('../extension/background/parser-helper.cjs');

// Test 1: HTML Tag Stripping
const clean = stripHtml('<p>Hello <strong>World</strong> &amp; Students<br></p>');
assert.strictEqual(clean, 'Hello World & Students');

// Test 2: Mock Canvas Crawler
const mockFetch = async (url) => {
  if (url.includes('include[]=syllabus_body')) {
    return {
      ok: true,
      json: async () => ({
        name: 'Biology 101: Cell Systems',
        syllabus_body: '<p>Welcome to Biology 101. Objectives: Analyze cellular metabolism.</p>'
      })
    };
  }
  if (url.includes('/assignments')) {
    return {
      ok: true,
      json: async () => [
        { name: 'Quiz 1', description: '<p>Recall organelles</p>', points_possible: 10 },
        { name: 'Lab Report 1', description: '<p>Analyze enzyme kinetics</p>', points_possible: 50 }
      ]
    };
  }
  throw new Error('Not found: ' + url);
};

(async () => {
  const courseData = await crawlCanvasCourse('https://canvas.instructure.com', '12345', mockFetch);
  assert.strictEqual(courseData.title, 'Biology 101: Cell Systems');
  assert.ok(courseData.syllabus.includes('Analyze cellular metabolism'));
  assert.strictEqual(courseData.assignments.length, 2);
  assert.strictEqual(courseData.assignments[0].title, 'Quiz 1');
  assert.strictEqual(courseData.assignments[0].description, 'Recall organelles');

  // Test 3: Demo Course Audit Fallback
  const demoResult = getDemoCourseAuditResult({ title: 'Biology 101: Cell Systems' });
  assert.ok(demoResult.summary.keyTakeaway.includes('Course-Level Demo'));
  assert.ok(demoResult.findings.length >= 2);
  assert.ok(demoResult.improvedDraft.title.includes('Matrix'));

  console.log('✅ Task 2 Canvas crawler tests passed.');
})();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-crawler.js`
Expected: FAIL with `Cannot find module '../extension/background/canvas-crawler.cjs'`.

- [ ] **Step 3: Implement `canvas-crawler.js`, `canvas-crawler.cjs`, and demo helper**

Create `extension/background/canvas-crawler.js` and `.cjs`:
```javascript
export function stripHtml(html) {
  if (!html) return '';
  return html
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

export async function crawlCanvasCourse(origin, courseId, fetchImpl = fetch) {
  if (!origin || !courseId) {
    throw new Error('Canvas origin and courseId are required for course crawling.');
  }

  // 1. Fetch Course details & syllabus
  const courseUrl = `${origin}/api/v1/courses/${courseId}?include[]=syllabus_body`;
  const courseRes = await fetchImpl(courseUrl);
  if (!courseRes.ok) {
    throw new Error(`Failed to fetch Canvas course info (${courseRes.status})`);
  }
  const courseJson = await courseRes.json();

  // 2. Fetch Assignments list (up to 50)
  const assignmentsUrl = `${origin}/api/v1/courses/${courseId}/assignments?per_page=50`;
  let assignments = [];
  try {
    const assignRes = await fetchImpl(assignmentsUrl);
    if (assignRes.ok) {
      const assignJson = await assignRes.json();
      if (Array.isArray(assignJson)) {
        assignments = assignJson.map((a) => ({
          title: a.name || 'Untitled Assignment',
          description: stripHtml(a.description || '').slice(0, 1000),
          points: a.points_possible || 0,
          dueAt: a.due_at || null
        }));
      }
    }
  } catch (e) {
    console.warn('Could not fetch assignments list:', e);
  }

  return {
    title: courseJson.name || courseJson.course_code || 'Canvas Course',
    syllabus: stripHtml(courseJson.syllabus_body || ''),
    assignments
  };
}
```

In `extension/background/parser-helper.js` and `.cjs`:
```javascript
export function getDemoCourseAuditResult(payload = {}) {
  const title = payload.title || 'Sample Canvas Course';
  return {
    summary: {
      bloomsLevel: 'Analyze & Evaluate (Levels 4-5)',
      alignmentScore: 'Moderate (74%)',
      keyTakeaway: `[Course-Level Demo] Full-course audit for "${title}". Alignment gaps identified between week 1-4 recall quizzes and week 12 analytical capstone.`
    },
    findings: [
      {
        severity: 'critical',
        tier: 'T2',
        citation: '[Alignment-3] Direct Constructive Alignment',
        observation: 'Modules 1-6 assess solely lower-order factual recall, while the final course project demands high-order synthesis without intermediate scaffolding.',
        evidence: 'Biggs (1996) & Liou et al. (2023) [T2 controlled trial]: Abrupt jumps in cognitive demand without progressive assessment scaffolding increase failure rates.',
        recommendation: 'Introduce mid-semester milestone case studies in Module 4 to bridge the gap between quizzes and the final capstone.'
      },
      {
        severity: 'warning',
        tier: 'T1',
        citation: '[Cognitive-2] Cognitive Load & Spaced Practice',
        observation: 'Major assignment deadlines are clustered in Week 14-15 with no spaced formative checkpoints.',
        evidence: 'Carpenter et al. (2022) [T1 meta-analysis, d=0.61]: Distributing assessments across spaced intervals produces significantly higher long-term retention.',
        recommendation: 'Redistribute submission checkpoints into 3 progressive deliverables across weeks 6, 10, and 14.'
      },
      {
        severity: 'info',
        tier: 'T1',
        citation: '[Assessment-8] Formative Rubric Transparency',
        observation: 'Syllabus grading policy lacks explicit performance criteria for collaborative group deliverables.',
        evidence: 'Wisniewski et al. (2020) [T1 meta-analysis]: Pre-distribution of analytic rubrics with milestone criteria boosts student self-regulation and achievement.',
        recommendation: 'Publish the multi-tier analytic grading rubric during the initial module launch.'
      }
    ],
    improvedDraft: {
      title: 'Course-Wide Constructive Alignment Matrix',
      content: `### Course Alignment Matrix: ${title}

| Week / Module | Intended Learning Outcome | Formative Checkpoint [T1] | Summative Assessment [T2] |
| :--- | :--- | :--- | :--- |
| **Weeks 1-3** | Foundational Cell Structure | Spaced Knowledge Check (10 pts) | Module 1 Synthesis Quiz |
| **Weeks 4-7** | Enzyme Kinetics & Modeling | Case Problem Milestone 1 [T2] | Lab Protocol Analysis |
| **Weeks 8-11** | Experimental Troubleshooting | Peer Review Protocol [T1] | Milestone 2 Experimental Draft |
| **Weeks 12-15**| Autonomous Investigation | Scaffolded Capstone Consult | Final Research Capstone |`
    }
  };
}
```

In `extension/background/service-worker.js`:
Add message handler for `CRAWL_AND_AUDIT_COURSE` calling `crawlCanvasCourse`, `buildCourseAuditPrompt`, and saving results.

- [ ] **Step 4: Run test to verify it passes**

Run: `node test/test-crawler.js && node test/test-service-worker.js`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add extension/background/canvas-crawler.* extension/background/parser-helper.* extension/background/service-worker.js test/test-crawler.js test/test-service-worker.js
git commit -m "feat(extension): implement Canvas background course crawler and demo course audit engine"
```

---

### Task 3: Side Panel UI: Course Audit Mode, Progress Bar & Free Key Link

**Files:**
- Modify: `extension/sidepanel/index.html`
- Modify: `extension/sidepanel/sidepanel.css`
- Modify: `extension/sidepanel/sidepanel.js`
- Modify: `extension/sidepanel/renderer-helper.js`
- Modify: `extension/sidepanel/renderer-helper.cjs`
- Test: `test/test-sidepanel-dom.js`
- Test: `test/test-sidepanel-logic.js`

**Interfaces:**
- Produces: Dynamic UI switching between "Audit Page with Evidence" (single page) and "Audit Entire Course" (course root).
- Produces: Animated step-by-step progress indicator (`#crawl-progress-card`).
- Produces: Direct link to Google AI Studio in settings drawer (`#get-api-key-link`).

- [ ] **Step 1: Write failing tests in `test/test-sidepanel-dom.js` and `test/test-sidepanel-logic.js`**

Add to `test/test-sidepanel-dom.js`:
```javascript
// Test: Course Audit Button & Progress Bar in HTML
assert.ok(html.includes('id="audit-course-btn"'), 'audit-course-btn must exist in index.html');
assert.ok(html.includes('id="crawl-progress-card"'), 'crawl-progress-card must exist in index.html');
assert.ok(html.includes('id="crawl-status-text"'), 'crawl-status-text must exist in index.html');
assert.ok(html.includes('https://aistudio.google.com/app/apikey'), 'Link to free Google AI Studio key must exist in Settings');
```

Add to `test/test-sidepanel-logic.js`:
```javascript
// Test: Rendering Course-Wide Alignment Matrix
const { renderAuditHTML } = require('../extension/sidepanel/renderer-helper.cjs');
const courseResult = {
  summary: { bloomsLevel: 'Analyze', alignmentScore: 'High (88%)', keyTakeaway: 'Strong alignment.' },
  findings: [{ tier: 'T1', severity: 'info', citation: '[Test-1]', observation: 'Good', evidence: 'Meta-analysis', recommendation: 'Keep it' }],
  improvedDraft: { title: 'Course Alignment Matrix', content: '| Week | Outcome |' }
};
const rendered = renderAuditHTML(courseResult);
assert.ok(rendered.includes('Course Alignment Matrix'));
assert.ok(rendered.includes('High (88%)'));
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-sidepanel-dom.js && node test/test-sidepanel-logic.js`
Expected: FAIL due to missing DOM elements and free key link.

- [ ] **Step 3: Update `index.html`, `sidepanel.css`, and `sidepanel.js`**

In `extension/sidepanel/index.html`:
- Add `#audit-course-btn` button (hidden by default unless on course root).
- Add `#crawl-progress-card` with progress bar and status text.
- Add `<a id="get-api-key-link" href="https://aistudio.google.com/app/apikey" target="_blank">Get your free Google AI Studio key &rarr;</a>` under the API key input.

In `extension/sidepanel/sidepanel.css`:
- Add styling for `.progress-card`, `.progress-bar-container`, `.progress-bar-fill`, and `.help-link`.

In `extension/sidepanel/sidepanel.js`:
- Check `detectCourseContext(tab.url)` in `refreshActiveTab()`.
- If `isCourseRoot` is true, show `#audit-course-btn` alongside `#audit-btn`.
- Add click handler for `#audit-course-btn` that triggers `CRAWL_AND_AUDIT_COURSE`, updates progress text ("Gathering syllabus...", "Fetching assignments...", "Analyzing alignment..."), and renders the final course audit.

- [ ] **Step 4: Run tests to verify they pass**

Run: `node test/test-sidepanel-dom.js && node test/test-sidepanel-logic.js`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add extension/sidepanel/ test/test-sidepanel-*
git commit -m "feat(extension): add course audit UI, crawl progress indicator, and free API key link"
```

---

### Task 4: Test Integration, Smoke Suite & README Documentation

**Files:**
- Modify: `test/test-extension.sh`
- Modify: `test/smoke-test.sh`
- Modify: `README.md`

**Interfaces:**
- Produces: Integrated test suite running all 7 extension test scripts.
- Produces: Updated user-facing instructions in README on how to use the full-course Canvas crawler and free API key.

- [ ] **Step 1: Update `test/test-extension.sh` to include `test/test-crawler.js`**

In `test/test-extension.sh`:
```bash
node "$REPO_ROOT/test/test-crawler.js"
```

- [ ] **Step 2: Run `test/test-extension.sh` and `test/smoke-test.sh`**

Run: `./test/test-extension.sh`
Expected: 7/7 suites pass.

Run: `./test/smoke-test.sh`
Expected: 356+/356+ tests pass with 0 failures.

- [ ] **Step 3: Update `README.md`**

Add a subsection under Chrome Extension detailing:
- "Audit Entire Course" from the Canvas course homepage.
- Background session extraction without developer tokens.
- Getting a free Google AI Studio API key.

- [ ] **Step 4: Commit changes**

```bash
git add test/test-extension.sh test/smoke-test.sh README.md
git commit -m "feat(extension): integrate course crawler tests into smoke suite and update readme"
```

---

## Execution Choice

Plan complete and saved to `docs/superpowers/plans/2026-08-15-course-crawler.md`. Two execution options:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
