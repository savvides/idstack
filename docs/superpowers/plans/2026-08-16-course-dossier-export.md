# Course Dossier & Compiled Markdown Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable instructional designers to collect course page audits incrementally into an active Course Dossier as they navigate Canvas/Docs, and compile the collection into a single structured institutional Markdown export (`.md`) or copy it to the clipboard.

**Architecture:** Extend `storage.js` with dossier CRUD methods in `chrome.storage.local`; implement `dossier-compiler.js` synthesizing multi-page audit data into a unified Markdown document with executive summaries, cross-module findings, and itemized drafts; add a persistent Dossier header pill, drawer manager, and export action buttons to the Side Panel UI following `DESIGN.md`.

**Tech Stack:** Chrome Extension Manifest V3 (Side Panel, Storage API), Vanilla JavaScript (ES modules + CommonJS test companions), Vanilla CSS adhering to `DESIGN.md`.

## Global Constraints

- **Design System:** Strictly follow `DESIGN.md` (Source Serif 4, Public Sans, JetBrains Mono, `#faf8f3` ivory background, `#ffffff` card surfaces, `#1a1815` ink, canonical T1–T5 palette: T1 `#2f7a4a`, T2 `#2864a8`, T3 `#a87726`, T4 `#b35a1f`, T5 `#6b6b6b`).
- **Zero Build Overhead:** Pure Vanilla JS and CSS without bundlers or npm runtime dependencies.
- **Privacy & FERPA:** Only store and export curriculum and assignment content. Never store student PII.
- **T1–T5 Research Grounding:** Exported findings clearly preserve empirical citations and research tiers from `evidence/references.md`.

---

### Task 1: Dossier Storage Helpers & Markdown Compiler Engine

**Files:**
- Modify: `extension/shared/storage.js`
- Create: `extension/shared/dossier-compiler.js`
- Create: `extension/shared/dossier-compiler.cjs`
- Create: `test/test-dossier-compiler.js`

**Interfaces:**
- Produces: `getDossier()`, `addToDossier(item)`, `removeFromDossier(id)`, `clearDossier()` in `storage.js`.
- Produces: `compileDossierToMarkdown(dossierItems, courseTitle)` returning full synthesized markdown string.
- Produces: `compileSingleAuditToMarkdown(auditItem)` returning single-page markdown string.

- [ ] **Step 1: Write failing tests in `test/test-dossier-compiler.js`**

Create `test/test-dossier-compiler.js`:
```javascript
const assert = require('assert');
const { compileDossierToMarkdown, compileSingleAuditToMarkdown } = require('../extension/shared/dossier-compiler.cjs');

// Test 1: Single Audit Markdown Compilation
const singleItem = {
  title: 'Lab 1: Enzymes',
  pageType: 'Canvas Assignment',
  url: 'https://canvas.instructure.com/courses/123/assignments/456',
  timestamp: '2026-08-16T10:00:00Z',
  result: {
    summary: {
      bloomsLevel: 'Analyze (Level 4)',
      alignmentScore: 'Moderate (75%)',
      keyTakeaway: 'Focus on rubric transparency.'
    },
    findings: [
      {
        severity: 'warning',
        tier: 'T1',
        citation: '[Assessment-8] Formative Feedback',
        observation: 'Rubric lacks milestone descriptors.',
        evidence: 'Wisniewski et al. (2020) [T1]: Rubrics boost self-regulation.',
        recommendation: 'Add milestone criteria.'
      }
    ],
    improvedDraft: {
      title: 'Improved Lab Rubric',
      content: '| Criterion | Proficient | Novice |\n| --- | --- | --- |'
    }
  }
};

const singleMd = compileSingleAuditToMarkdown(singleItem);
assert.ok(singleMd.includes('# idstack Instructional Design Audit: Lab 1: Enzymes'));
assert.ok(singleMd.includes('**Bloom\'s Demand:** Analyze (Level 4)'));
assert.ok(singleMd.includes('Wisniewski et al. (2020)'));
assert.ok(singleMd.includes('Improved Lab Rubric'));

// Test 2: Multi-Audit Dossier Compilation
const dossierItems = [
  singleItem,
  {
    title: 'Course Syllabus',
    pageType: 'Canvas Syllabus',
    url: 'https://canvas.instructure.com/courses/123/syllabus',
    timestamp: '2026-08-16T09:30:00Z',
    result: {
      summary: {
        bloomsLevel: 'Understand (Level 2)',
        alignmentScore: 'High (90%)',
        keyTakeaway: 'Clear policy structure.'
      },
      findings: [
        {
          severity: 'info',
          tier: 'T2',
          citation: '[Alignment-3] Direct Constructive Alignment',
          observation: 'Objectives align with module outcomes.',
          evidence: 'Biggs (1996) [T2]: Clear alignment supports deep learning.',
          recommendation: 'Maintain alignment across quizzes.'
        }
      ],
      improvedDraft: {
        title: 'Revised Objectives',
        content: '- Analyze core enzyme mechanisms.'
      }
    }
  }
];

const dossierMd = compileDossierToMarkdown(dossierItems, 'Biology 101: Cell Systems');
assert.ok(dossierMd.includes('# idstack Course Audit Dossier: Biology 101: Cell Systems'));
assert.ok(dossierMd.includes('Total Audited Materials: 2 components'));
assert.ok(dossierMd.includes('## Section 1: Lab 1: Enzymes'));
assert.ok(dossierMd.includes('## Section 2: Course Syllabus'));
assert.ok(dossierMd.includes('Wisniewski et al. (2020)'));
assert.ok(dossierMd.includes('Biggs (1996)'));

console.log('✅ Task 1 Dossier compiler tests passed.');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-dossier-compiler.js`
Expected: FAIL with `Cannot find module '../extension/shared/dossier-compiler.cjs'`.

- [ ] **Step 3: Implement `dossier-compiler.js`, `dossier-compiler.cjs`, and `storage.js` dossier methods**

Create `extension/shared/dossier-compiler.js` and `.cjs`:
```javascript
export function compileSingleAuditToMarkdown(item) {
  if (!item || !item.result) return '';
  const result = item.result;
  const title = item.title || 'Course Material';
  const pageType = item.pageType || 'Web Page';
  const url = item.url || '';
  const timestamp = item.timestamp ? new Date(item.timestamp).toLocaleString() : new Date().toLocaleString();

  let md = `# idstack Instructional Design Audit: ${title}\n\n`;
  md += `> **Audited Component:** ${pageType}  \n`;
  if (url) md += `> **Source URL:** [${url}](${url})  \n`;
  md += `> **Date:** ${timestamp}  \n`;
  md += `> **Evaluator:** idstack Evidence-Based Course Design Engine (Manifest V3)\n\n`;

  md += `## Executive Summary\n\n`;
  md += `- **Bloom's Demand:** ${result.summary?.bloomsLevel || 'N/A'}\n`;
  md += `- **Constructive Alignment:** ${result.summary?.alignmentScore || 'N/A'}\n`;
  md += `- **Key Takeaway:** ${result.summary?.keyTakeaway || 'No summary provided.'}\n\n`;

  if (Array.isArray(result.findings) && result.findings.length > 0) {
    md += `## Evidence-Based Findings & Recommendations\n\n`;
    result.findings.forEach((f, idx) => {
      md += `### ${idx + 1}. [${f.tier || 'T1'}] ${f.citation || 'Citation'}\n\n`;
      md += `- **Severity:** \`${(f.severity || 'info').toUpperCase()}\`\n`;
      md += `- **Observation:** ${f.observation || ''}\n`;
      md += `- **Empirical Evidence:** ${f.evidence || ''}\n`;
      md += `- **Actionable Recommendation:** ${f.recommendation || ''}\n\n`;
    });
  }

  if (result.improvedDraft && result.improvedDraft.content) {
    md += `## ${result.improvedDraft.title || 'Improved Draft & Alignment Matrix'}\n\n`;
    md += `${result.improvedDraft.content}\n\n`;
  }

  md += `---\n*Generated by [idstack](https://github.com/savvides/idstack) — Evidence-Based Course Design.*`;
  return md;
}

export function compileDossierToMarkdown(dossierItems, courseTitle = 'Canvas Course') {
  if (!Array.isArray(dossierItems) || dossierItems.length === 0) {
    return `# idstack Course Audit Dossier: ${courseTitle}\n\n*No audit materials in dossier.*`;
  }

  const timestamp = new Date().toLocaleString();
  let md = `# idstack Course Audit Dossier: ${courseTitle}\n\n`;
  md += `> **Course:** ${courseTitle}  \n`;
  md += `> **Total Audited Materials:** ${dossierItems.length} components  \n`;
  md += `> **Compiled Date:** ${timestamp}  \n`;
  md += `> **Engine:** idstack Evidence-Based Instructional Design Co-Pilot\n\n`;

  md += `## Table of Audited Materials\n\n`;
  md += `| # | Component Title | Type | Bloom's Demand | Alignment Score |\n`;
  md += `| :--- | :--- | :--- | :--- | :--- |\n`;
  dossierItems.forEach((item, idx) => {
    const s = item.result?.summary || {};
    md += `| ${idx + 1} | ${item.title || 'Untitled'} | ${item.pageType || 'Page'} | ${s.bloomsLevel || 'N/A'} | ${s.alignmentScore || 'N/A'} |\n`;
  });
  md += `\n---\n\n`;

  dossierItems.forEach((item, idx) => {
    md += `## Section ${idx + 1}: ${item.title || 'Component'}\n\n`;
    md += `> **Type:** ${item.pageType || 'Page'} | **Source:** ${item.url || 'N/A'}\n\n`;

    const r = item.result || {};
    md += `### Summary\n`;
    md += `- **Cognitive Demand:** ${r.summary?.bloomsLevel || 'N/A'}\n`;
    md += `- **Alignment Rating:** ${r.summary?.alignmentScore || 'N/A'}\n`;
    md += `- **Takeaway:** ${r.summary?.keyTakeaway || 'N/A'}\n\n`;

    if (Array.isArray(r.findings) && r.findings.length > 0) {
      md += `### Findings & Evidence\n\n`;
      r.findings.forEach((f, fIdx) => {
        md += `#### ${idx + 1}.${fIdx + 1} [${f.tier || 'T1'}] ${f.citation || 'Citation'}\n`;
        md += `- **Observation:** ${f.observation || ''}\n`;
        md += `- **Evidence:** ${f.evidence || ''}\n`;
        md += `- **Recommendation:** ${f.recommendation || ''}\n\n`;
      });
    }

    if (r.improvedDraft && r.improvedDraft.content) {
      md += `### ${r.improvedDraft.title || 'Revised Draft'}\n\n`;
      md += `${r.improvedDraft.content}\n\n`;
    }

    md += `---\n\n`;
  });

  md += `*Generated by [idstack](https://github.com/savvides/idstack) — Evidence-Based Course Design.*`;
  return md;
}
```

In `extension/shared/storage.js`:
Add `getDossier()`, `addToDossier(item)`, `removeFromDossier(id)`, `clearDossier()`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `node test/test-dossier-compiler.js`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add extension/shared/storage.js extension/shared/dossier-compiler.* test/test-dossier-compiler.js
git commit -m "feat(extension): implement dossier storage helpers and multi-audit markdown compiler"
```

---

### Task 2: Side Panel UI: Dossier Badge, Actions & Drawer

**Files:**
- Modify: `extension/sidepanel/index.html`
- Modify: `extension/sidepanel/sidepanel.css`
- Modify: `extension/sidepanel/sidepanel.js`
- Modify: `extension/sidepanel/renderer-helper.js`
- Modify: `extension/sidepanel/renderer-helper.cjs`
- Test: `test/test-sidepanel-dom.js`
- Test: `test/test-sidepanel-logic.js`

**Interfaces:**
- Produces: Header Dossier pill `#dossier-toggle-btn` showing active count.
- Produces: Results action bar `#add-to-dossier-btn` and `#export-single-md-btn`.
- Produces: Dossier drawer `#dossier-drawer` with item cards, delete buttons, "Download Compiled .md", and "Copy Markdown" buttons.

- [ ] **Step 1: Write failing tests in `test/test-sidepanel-dom.js` and `test/test-sidepanel-logic.js`**

Add to `test/test-sidepanel-dom.js`:
```javascript
// Test: Dossier UI Elements
assert.ok(html.includes('id="dossier-toggle-btn"'), 'dossier-toggle-btn must exist in header');
assert.ok(html.includes('id="dossier-count"'), 'dossier-count element must exist');
assert.ok(html.includes('id="add-to-dossier-btn"'), 'add-to-dossier-btn must exist');
assert.ok(html.includes('id="export-single-md-btn"'), 'export-single-md-btn must exist');
assert.ok(html.includes('id="dossier-drawer"'), 'dossier-drawer must exist');
assert.ok(html.includes('id="export-dossier-md-btn"'), 'export-dossier-md-btn must exist in dossier drawer');
assert.ok(html.includes('id="copy-dossier-md-btn"'), 'copy-dossier-md-btn must exist in dossier drawer');
assert.ok(html.includes('id="clear-dossier-btn"'), 'clear-dossier-btn must exist in dossier drawer');
```

Add to `test/test-sidepanel-logic.js`:
```javascript
// Test: Dossier Item Rendering in Drawer
const { renderDossierListHTML } = require('../extension/sidepanel/renderer-helper.cjs');
assert.strictEqual(typeof renderDossierListHTML, 'function');
const listHtml = renderDossierListHTML([
  { id: '1', title: 'Week 1 Quiz', pageType: 'Assignment', result: { summary: { bloomsLevel: 'Remember', alignmentScore: 'Low' } } }
]);
assert.ok(listHtml.includes('Week 1 Quiz'));
assert.ok(listHtml.includes('Assignment'));
assert.ok(listHtml.includes('data-dossier-id="1"'));
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-sidepanel-dom.js && node test/test-sidepanel-logic.js`
Expected: FAIL due to missing DOM elements and render helper.

- [ ] **Step 3: Update `index.html`, `sidepanel.css`, `sidepanel.js`, and `renderer-helper.js`**

In `extension/sidepanel/index.html`:
- Add `#dossier-toggle-btn` to header.
- Add `#add-to-dossier-btn` and `#export-single-md-btn` to results actions bar.
- Add `#dossier-drawer` section with list container, export, copy, and clear buttons.

In `extension/sidepanel/sidepanel.css`:
- Add styles for `.dossier-pill`, `.result-actions-bar`, `.dossier-list`, `.dossier-item`, and `.dossier-delete-btn`.

In `extension/sidepanel/sidepanel.js`:
- Wire up `updateDossierBadge()`.
- Add click listener for `#add-to-dossier-btn` saving current `activeAuditResult` to dossier with visual confirmation (`✓ Added to Dossier`).
- Add click listener for `#export-single-md-btn` downloading `idstack-audit-<title>.md`.
- Add click listener for `#export-dossier-md-btn` downloading `idstack-course-dossier-<title>.md`.
- Add click listener for `#copy-dossier-md-btn` copying compiled markdown to clipboard.
- Add click listener for `#clear-dossier-btn` clearing dossier list.

- [ ] **Step 4: Run tests to verify they pass**

Run: `node test/test-sidepanel-dom.js && node test/test-sidepanel-logic.js`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add extension/sidepanel/ test/test-sidepanel-*
git commit -m "feat(extension): add course dossier drawer, badge, and compiled markdown export UI"
```

---

### Task 3: Test Integration, Smoke Suite & README Documentation

**Files:**
- Modify: `test/test-extension.sh`
- Modify: `test/smoke-test.sh`
- Modify: `README.md`

**Interfaces:**
- Produces: Integrated test suite running all 8 extension test suites.
- Produces: User documentation detailing the Course Dossier and compiled Markdown export workflow.

- [ ] **Step 1: Update `test/test-extension.sh` to include `test/test-dossier-compiler.js`**

In `test/test-extension.sh`:
```bash
node "$REPO_ROOT/test/test-dossier-compiler.js"
```

- [ ] **Step 2: Run `test/test-extension.sh` and `test/smoke-test.sh`**

Run: `./test/test-extension.sh`
Expected: 8/8 suites pass.

Run: `./test/smoke-test.sh`
Expected: 356+/356+ tests pass with 0 failures.

- [ ] **Step 3: Update `README.md`**

Add documentation under Chrome Extension on:
- "Course Dossier" workflow: Auditing multiple pages across a course and accumulating findings.
- 1-Click compiled Markdown export (`.md`) and clipboard copying.

- [ ] **Step 4: Commit changes**

```bash
git add test/test-extension.sh test/smoke-test.sh README.md
git commit -m "feat(extension): integrate dossier compiler tests into smoke suite and update readme"
```

---

## Execution Choice

Plan complete and saved to `docs/superpowers/plans/2026-08-16-course-dossier-export.md`. Two execution options:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
