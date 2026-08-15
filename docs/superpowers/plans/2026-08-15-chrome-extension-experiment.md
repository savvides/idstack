# idstack Chrome Extension Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a frictionless Manifest V3 Chrome Extension that brings idstack's evidence-based course design audits into Canvas LMS, Google Docs, and web browsers via Chrome's native Side Panel.

**Architecture:** A Chrome Manifest V3 extension featuring a DOM content extractor for Canvas and web pages, a Side Panel user interface matching the `DESIGN.md` publication aesthetic, and a background service worker dispatching structured audit requests to Gemini 3.7 Flash with T1–T5 evidence citations.

**Tech Stack:** Chrome Extensions API (Manifest V3, Side Panel API, Content Scripts, Service Worker), Vanilla JavaScript (ES Modules), Vanilla CSS (matching `DESIGN.md` tokens), Node.js test runner for unit tests.

## Global Constraints

- **Design System:** Strictly follow `DESIGN.md` (Source Serif 4, Public Sans, JetBrains Mono, Ivory `#faf8f3`, Raised `#ffffff`, Text `#1a1815`, hairline borders `#e6e0d2`, T1–T5 palette).
- **Zero Framework Overhead:** Pure HTML/CSS/JavaScript without bundlers or build steps so the extension can be loaded directly unpacked in developer mode.
- **Privacy & FERPA:** Do not store student or course data permanently on third-party servers.
- **T1–T5 Research Grounding:** All audit suggestions must tie back to the 108 studies and 11 research domains in `evidence/references.md`.

---

### Task 1: Scaffolding, Manifest V3 & Icon Assets

**Files:**
- Create: `extension/manifest.json`
- Create: `extension/icons/icon-16.png`
- Create: `extension/icons/icon-48.png`
- Create: `extension/icons/icon-128.png`
- Create: `extension/shared/storage.js`
- Test: `test/test-manifest.js`

**Interfaces:**
- Produces: `getSettings()`, `saveSettings(settings)`, `getAuditHistory()`, `saveAuditResult(result)` in `extension/shared/storage.js`.

- [ ] **Step 1: Write test for manifest validity and storage helper**

Create `test/test-manifest.js`:
```javascript
const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Test manifest.json
const manifestPath = path.join(__dirname, '../extension/manifest.json');
assert.ok(fs.existsSync(manifestPath), 'manifest.json must exist');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

assert.strictEqual(manifest.manifest_version, 3);
assert.strictEqual(manifest.name, 'idstack — Evidence-Based Course Design');
assert.ok(manifest.permissions.includes('sidePanel'));
assert.ok(manifest.permissions.includes('storage'));
assert.ok(manifest.permissions.includes('activeTab'));

console.log('✅ Task 1 manifest checks passed.');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-manifest.js`  
Expected: FAIL with "manifest.json must exist"

- [ ] **Step 3: Implement `manifest.json`, icon generation script, and `storage.js`**

Create `extension/manifest.json`:
```json
{
  "manifest_version": 3,
  "name": "idstack — Evidence-Based Course Design",
  "version": "1.0.0",
  "description": "Evidence-based instructional design co-pilot for Canvas LMS, Google Docs, and course web pages.",
  "icons": {
    "16": "icons/icon-16.png",
    "48": "icons/icon-48.png",
    "128": "icons/icon-128.png"
  },
  "action": {
    "default_title": "Open idstack Course Co-Pilot"
  },
  "side_panel": {
    "default_path": "sidepanel/index.html"
  },
  "background": {
    "service_worker": "background/service-worker.js",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": [
        "*://*.instructure.com/*",
        "*://canvas.*.edu/*",
        "*://docs.google.com/document/*",
        "<all_urls>"
      ],
      "js": ["content/extractor.js"],
      "run_at": "document_idle"
    }
  ],
  "permissions": [
    "sidePanel",
    "storage",
    "activeTab",
    "scripting"
  ]
}
```

Create `extension/shared/storage.js`:
```javascript
/**
 * idstack storage helper for Chrome sync and local storage.
 */
export async function getSettings() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(['apiKey', 'apiEndpoint', 'autoAudit'], (result) => {
      resolve({
        apiKey: result.apiKey || '',
        apiEndpoint: result.apiEndpoint || 'https://api.idstack.org/v1/audit',
        autoAudit: result.autoAudit ?? false
      });
    });
  });
}

export async function saveSettings(settings) {
  return new Promise((resolve) => {
    chrome.storage.sync.set(settings, () => resolve(true));
  });
}

export async function getAuditHistory() {
  return new Promise((resolve) => {
    chrome.storage.local.get(['auditHistory'], (result) => {
      resolve(result.auditHistory || []);
    });
  });
}

export async function saveAuditResult(entry) {
  return new Promise((resolve) => {
    chrome.storage.local.get(['auditHistory'], (result) => {
      const history = result.auditHistory || [];
      history.unshift({
        ...entry,
        timestamp: new Date().toISOString()
      });
      // Keep last 20 audits
      chrome.storage.local.set({ auditHistory: history.slice(0, 20) }, () => resolve(true));
    });
  });
}
```

Generate SVG/PNG icons in `extension/icons/` using a small canvas generator script or standalone PNG buffer.

- [ ] **Step 4: Run test to verify it passes**

Run: `node test/test-manifest.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add extension/manifest.json extension/icons/ extension/shared/storage.js test/test-manifest.js
git commit -m "feat(extension): scaffold manifest v3 and storage helpers"
```

---

### Task 2: Evidence Base & Prompt Generation Engine

**Files:**
- Create: `extension/shared/evidence-base.js`
- Create: `extension/shared/prompts.js`
- Test: `test/test-prompts.js`

**Interfaces:**
- Consumes: None
- Produces: `EVIDENCE_DOMAINS`, `TIER_METADATA`, `buildAuditPrompt(contextPayload)`

- [ ] **Step 1: Write test for prompt generator and evidence metadata**

Create `test/test-prompts.js`:
```javascript
const assert = require('assert');
const { EVIDENCE_DOMAINS, TIER_METADATA, buildAuditPrompt } = require('../extension/shared/prompts.cjs');

assert.ok(EVIDENCE_DOMAINS.length >= 10, 'Should include all core idstack research domains');
assert.ok(TIER_METADATA.T1, 'Tier 1 metadata must exist');
assert.strictEqual(TIER_METADATA.T1.label, 'Meta-analysis');

const prompt = buildAuditPrompt({
  title: 'Biology 101 - Cell Division Assignment',
  pageType: 'assignment',
  content: 'Students will list the phases of mitosis and take a 5-question multiple choice quiz.'
});

assert.ok(prompt.includes('Biology 101'), 'Prompt should include content title');
assert.ok(prompt.includes("Bloom's"), "Prompt should require Bloom's classification");
assert.ok(prompt.includes('JSON'), 'Prompt should enforce JSON format');

console.log('✅ Task 2 prompt engine tests passed.');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-prompts.js`  
Expected: FAIL with module not found

- [ ] **Step 3: Implement `evidence-base.js` and `prompts.js`**

Create `extension/shared/evidence-base.js`:
```javascript
export const TIER_METADATA = {
  T1: { label: 'Meta-analysis', description: 'Systematic reviews / meta-analyses with large effect sizes', color: '#1d4e89' },
  T2: { label: 'Controlled trial', description: 'Peer-reviewed empirical randomized or quasi-experimental studies', color: '#007791' },
  T3: { label: 'Observational', description: 'Correlational, cohort, or longitudinal learning studies', color: '#588157' },
  T4: { label: 'Case study', description: 'Single-institution or discipline-specific qualitative studies', color: '#c97a22' },
  T5: { label: 'Expert guidance', description: 'Established instructional design frameworks (QM, OLC, Bloom)', color: '#6c757d' }
};

export const EVIDENCE_DOMAINS = [
  { code: 'Assessment', name: 'Assessment & Feedback', keyStudies: ['Hattie & Timperley (2007) [T1]', 'Black & Wiliam (1998) [T1]'] },
  { code: 'Alignment', name: 'Constructive Alignment', keyStudies: ['Biggs (1996) [T1]', 'Anderson & Krathwohl (2001) [T5]'] },
  { code: 'Cognitive', name: 'Cognitive Load & Multimedia', keyStudies: ['Sweller (1988) [T1]', 'Mayer (2009) [T1]'] },
  { code: 'Accessibility', name: 'Universal Design for Learning & A11y', keyStudies: ['CAST UDL Guidelines (2018) [T5]', 'WCAG 2.1 AA [T5]'] },
  { code: 'Active', name: 'Active Learning & Desirable Difficulties', keyStudies: ['Freeman et al. (2014) [T1]', 'Bjork & Bjork (2011) [T1]'] }
];
```

Create `extension/shared/prompts.js`:
```javascript
import { EVIDENCE_DOMAINS, TIER_METADATA } from './evidence-base.js';

export function buildAuditPrompt({ title, pageType, content }) {
  return `You are idstack, an evidence-based instructional design co-pilot.
Your mission is to audit the provided course page/document and give rigorous, research-backed recommendations.

Target Document Title: "${title || 'Untitled Course Page'}"
Detected Document Type: ${pageType || 'Course Content'}

Document Content:
"""
${content.slice(0, 10000)}
"""

Please audit this material against peer-reviewed instructional design evidence:
1. Classify learning objectives or implied cognitive depth using Bloom's Revised Taxonomy (Remember, Understand, Apply, Analyze, Evaluate, Create).
2. Check Constructive Alignment: Do activities and assessments match the stated or necessary cognitive depth?
3. Flag Cognitive Load, Elaborated Feedback gaps, and Accessibility considerations.
4. Rate each recommendation with an evidence tier [T1] to [T5].
5. Provide a ready-to-use, improved version (rewritten rubric, upgraded learning outcome verbs, or enhanced prompt).

You MUST respond strictly with valid JSON conforming to this schema:
{
  "summary": {
    "bloomsLevel": "Remember | Understand | Apply | Analyze | Evaluate | Create",
    "alignmentScore": "Strong | Moderate | Weak",
    "keyTakeaway": "1-2 sentence executive summary of findings"
  },
  "findings": [
    {
      "severity": "critical | warning | suggestion",
      "tier": "T1 | T2 | T3 | T4 | T5",
      "citation": "[Domain-Code] Short Citation",
      "observation": "What is present in the current material",
      "evidence": "What peer-reviewed research indicates",
      "recommendation": "Specific actionable suggestion"
    }
  ],
  "improvedDraft": {
    "title": "Improved Rubric / Learning Objective / Assignment Prompt",
    "content": "Full markdown text ready for the instructor to copy-paste into Canvas"
  }
}`;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node test/test-prompts.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add extension/shared/evidence-base.js extension/shared/prompts.js test/test-prompts.js
git commit -m "feat(extension): add evidence base and structured prompt templates"
```

---

### Task 3: Content Extractor for Canvas LMS, Google Docs & Generic Web

**Files:**
- Create: `extension/content/extractor.js`
- Test: `test/test-extractor.js`

**Interfaces:**
- Consumes: Page DOM
- Produces: `extractPageContent() -> { title, pageType, url, content, wordCount }`

- [ ] **Step 1: Write test for DOM extraction logic using JSDOM**

Create `test/test-extractor.js`:
```javascript
const assert = require('assert');
const { JSDOM } = require('jsdom');
const { extractContentFromDOM } = require('../extension/content/extractor-core.cjs');

// Test Canvas Assignment fixture
const canvasHTML = `
  <html>
    <head><title>Module 3: Enzymes Assignment</title></head>
    <body>
      <div id="assignment_show">
        <h1 class="title">Enzymes Lab Analysis</h1>
        <div class="description user_content">
          <p>Read chapter 4 and answer the 5 review questions.</p>
        </div>
      </div>
    </body>
  </html>
`;
const dom = new JSDOM(canvasHTML, { url: 'https://canvas.instructure.com/courses/101/assignments/202' });
const extracted = extractContentFromDOM(dom.window.document, dom.window.location.href);

assert.strictEqual(extracted.pageType, 'Canvas Assignment');
assert.strictEqual(extracted.title, 'Enzymes Lab Analysis');
assert.ok(extracted.content.includes('Read chapter 4'));

console.log('✅ Task 3 extractor tests passed.');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-extractor.js`  
Expected: FAIL

- [ ] **Step 3: Implement `extractor.js` and common extractor module**

Create `extension/content/extractor.js`:
```javascript
/**
 * Injected content script to extract course content from Canvas, Google Docs, and web pages.
 */
function detectPageType(url, document) {
  if (url.includes('instructure.com') || url.includes('/courses/')) {
    if (document.querySelector('#assignment_show')) return 'Canvas Assignment';
    if (document.querySelector('#syllabusContainer') || url.includes('/assignments/syllabus')) return 'Canvas Syllabus';
    if (document.querySelector('#modules') || url.includes('/modules')) return 'Canvas Modules';
    if (document.querySelector('#rubrics')) return 'Canvas Rubric';
    return 'Canvas LMS Page';
  }
  if (url.includes('docs.google.com/document')) return 'Google Doc Syllabus';
  return 'Web Syllabus / Course Page';
}

function extractPageContent() {
  const url = window.location.href;
  const pageType = detectPageType(url, document);
  let title = document.title || 'Course Document';
  let content = '';

  if (pageType.startsWith('Canvas')) {
    const heading = document.querySelector('#assignment_show .title, .page-title, h1');
    if (heading) title = heading.innerText.trim();

    const mainBody = document.querySelector('#assignment_show .description.user_content, .show-content.user_content, #syllabusContainer, .module-item-title');
    content = mainBody ? mainBody.innerText.trim() : document.body.innerText.trim();
  } else if (pageType === 'Google Doc Syllabus') {
    const kixApp = document.querySelector('.kix-appview-editor');
    content = kixApp ? kixApp.innerText.trim() : document.body.innerText.trim();
  } else {
    // General web page extraction
    const article = document.querySelector('main, article, [role="main"]');
    content = article ? article.innerText.trim() : document.body.innerText.trim();
  }

  return {
    url,
    title,
    pageType,
    content: content.slice(0, 15000),
    wordCount: content.split(/\s+/).filter(Boolean).length
  };
}

// Listen for messages from Side Panel
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'EXTRACT_CONTENT') {
    const data = extractPageContent();
    sendResponse(data);
  }
  return true;
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node test/test-extractor.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add extension/content/ test/test-extractor.js
git commit -m "feat(extension): implement DOM extractor for Canvas and web syllabi"
```

---

### Task 4: Background Service Worker & Gemini API Engine

**Files:**
- Create: `extension/background/service-worker.js`
- Test: `test/test-service-worker.js`

**Interfaces:**
- Consumes: `buildAuditPrompt()`, `getSettings()`, `saveAuditResult()`
- Produces: Chrome message listener for `RUN_AUDIT`

- [ ] **Step 1: Write test for API request dispatch & JSON sanitization**

Create `test/test-service-worker.js`:
```javascript
const assert = require('assert');
const { parseAuditResponse } = require('../extension/background/parser-helper.cjs');

const rawGeminiResponse = "```json\n{\n  \"summary\": {\n    \"bloomsLevel\": \"Remember\",\n    \"alignmentScore\": \"Moderate\",\n    \"keyTakeaway\": \"Quiz focuses only on memorization.\"\n  },\n  \"findings\": [],\n  \"improvedDraft\": {\n    \"title\": \"Analysis Prompt\",\n    \"content\": \"Compare and contrast\"\n  }\n}\n```";

const parsed = parseAuditResponse(rawGeminiResponse);
assert.strictEqual(parsed.summary.bloomsLevel, 'Remember');
assert.strictEqual(parsed.improvedDraft.title, 'Analysis Prompt');

console.log('✅ Task 4 response parser tests passed.');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-service-worker.js`  
Expected: FAIL

- [ ] **Step 3: Implement `service-worker.js` and parsing logic**

Create `extension/background/service-worker.js`:
```javascript
import { buildAuditPrompt } from '../shared/prompts.js';
import { getSettings, saveAuditResult } from '../shared/storage.js';

// Setup side panel behavior on action click
chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch((err) => console.error(err));

function cleanJsonResponse(rawText) {
  let cleaned = rawText.trim();
  if (cleaned.startsWith('```json')) cleaned = cleaned.replace(/^```json/, '');
  if (cleaned.startsWith('```')) cleaned = cleaned.replace(/^```/, '');
  if (cleaned.endsWith('```')) cleaned = cleaned.replace(/```$/, '');
  return JSON.parse(cleaned.trim());
}

async function callGeminiApi(apiKey, prompt) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.2
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`AI API error (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) throw new Error('Empty response from AI model.');

  return cleanJsonResponse(rawText);
}

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'RUN_AUDIT') {
    (async () => {
      try {
        const settings = await getSettings();
        const prompt = buildAuditPrompt(request.payload);
        
        // Use user's key if provided, or default endpoint
        let auditResult;
        if (settings.apiKey) {
          auditResult = await callGeminiApi(settings.apiKey, prompt);
        } else {
          // Fallback demo mock or proxy endpoint
          auditResult = await callGeminiApi('YOUR_DEFAULT_API_KEY_OR_PROXY', prompt);
        }

        await saveAuditResult({
          url: request.payload.url,
          title: request.payload.title,
          pageType: request.payload.pageType,
          result: auditResult
        });

        sendResponse({ success: true, data: auditResult });
      } catch (err) {
        sendResponse({ success: false, error: err.message });
      }
    })();
    return true; // async reply
  }
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node test/test-service-worker.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add extension/background/ test/test-service-worker.js
git commit -m "feat(extension): implement background worker and API request engine"
```

---

### Task 5: Side Panel UI Structure & Publication Styling (`DESIGN.md`)

**Files:**
- Create: `extension/sidepanel/index.html`
- Create: `extension/sidepanel/sidepanel.css`
- Test: `test/test-sidepanel-dom.js`

**Interfaces:**
- Produces: HTML structure with `#ready-state`, `#loading-state`, `#results-state`, `#settings-drawer`.

- [ ] **Step 1: Write test asserting key UI elements and DESIGN.md color tokens**

Create `test/test-sidepanel-dom.js`:
```javascript
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const html = fs.readFileSync(path.join(__dirname, '../extension/sidepanel/index.html'), 'utf8');
const css = fs.readFileSync(path.join(__dirname, '../extension/sidepanel/sidepanel.css'), 'utf8');

assert.ok(html.includes('id="audit-btn"'), 'Audit button must exist in HTML');
assert.ok(html.includes('id="results-container"'), 'Results container must exist');
assert.ok(css.includes('--bg: #faf8f3'), 'CSS must include ivory background token from DESIGN.md');
assert.ok(css.includes('Source Serif 4'), 'CSS must use Source Serif 4 typography');
assert.ok(css.includes('JetBrains Mono'), 'CSS must use JetBrains Mono for citations');

console.log('✅ Task 5 side panel DOM and CSS token tests passed.');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-sidepanel-dom.js`  
Expected: FAIL

- [ ] **Step 3: Implement `index.html` and `sidepanel.css`**

Create `extension/sidepanel/index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>idstack — Course Co-Pilot</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500&family=Public+Sans:wght@400;500;600&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;1,8..60,400&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="sidepanel.css">
</head>
<body>
  <header class="app-header">
    <div class="brand">
      <span class="logo">idstack</span>
      <span class="badge-version">v1.0</span>
    </div>
    <button id="settings-toggle" class="icon-btn" title="Settings & Privacy">⚙</button>
  </header>

  <main class="content-body">
    <!-- Ready State -->
    <section id="ready-state" class="state-panel active">
      <div class="context-card">
        <div class="page-meta">
          <span id="page-type-tag" class="chip">Detecting page...</span>
          <h2 id="page-title" class="page-heading">Loading page title...</h2>
        </div>
        <p class="summary-hint">Audit constructive alignment, Bloom's classification, and cognitive load with peer-reviewed evidence.</p>
        <button id="audit-btn" class="primary-btn">
          <span class="btn-text">Audit Page with Evidence</span>
        </button>
      </div>
    </section>

    <!-- Loading State -->
    <section id="loading-state" class="state-panel">
      <div class="loader-box">
        <div class="spinner"></div>
        <p id="loader-status" class="loader-status-text">Analyzing course structure...</p>
      </div>
    </section>

    <!-- Results State -->
    <section id="results-state" class="state-panel">
      <div id="results-container"></div>
    </section>

    <!-- Settings Drawer -->
    <section id="settings-drawer" class="drawer">
      <div class="drawer-header">
        <h3>Settings & Privacy</h3>
        <button id="close-settings" class="icon-btn">✕</button>
      </div>
      <div class="drawer-body">
        <div class="form-group">
          <label for="api-key-input">Gemini / Claude API Key (Optional BYOK)</label>
          <input type="password" id="api-key-input" placeholder="AIzaSy... or sk-ant-..." />
          <p class="help-text">Leave blank to use the standard free demo tier.</p>
        </div>
        <button id="save-settings-btn" class="secondary-btn">Save Settings</button>
        <hr class="divider" />
        <div class="privacy-note">
          <h4>Privacy & FERPA Commitment</h4>
          <p>idstack processes only curriculum and assignment text. No student PII is ever collected, retained, or used for model training.</p>
        </div>
      </div>
    </section>
  </main>

  <script type="module" src="sidepanel.js"></script>
</body>
</html>
```

Create `extension/sidepanel/sidepanel.css`:
```css
:root {
  --bg: #faf8f3;
  --raised: #ffffff;
  --ink: #1a1815;
  --ink-soft: #3a352e;
  --ink-muted: #6b6358;
  --rule: #e6e0d2;
  --rule-strong: #d4cdb9;

  --tier-t1: #1d4e89;
  --tier-t2: #007791;
  --tier-t3: #588157;
  --tier-t4: #c97a22;
  --tier-t5: #6c757d;

  --severity-critical: #a62626;
  --severity-warning: #c25e00;
  --severity-suggestion: #2b7a4b;

  --font-display: 'Source Serif 4', Georgia, serif;
  --font-ui: 'Public Sans', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}

* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  background-color: var(--bg);
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 15px;
  line-height: 1.6;
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid var(--rule);
  background: var(--raised);
}

.brand .logo {
  font-family: var(--font-display);
  font-weight: 600;
  font-size: 18px;
  letter-spacing: -0.02em;
}

.badge-version {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--ink-muted);
  margin-left: 6px;
}

.state-panel { display: none; padding: 16px; }
.state-panel.active { display: block; }

.context-card, .finding-card, .improved-box {
  background: var(--raised);
  border: 1px solid var(--rule);
  border-radius: 4px;
  padding: 16px;
  margin-bottom: 16px;
}

.chip {
  font-family: var(--font-mono);
  font-size: 11px;
  background: #ede8dc;
  padding: 2px 6px;
  border-radius: 3px;
  color: var(--ink-soft);
}

.primary-btn {
  width: 100%;
  padding: 10px 16px;
  background: var(--ink);
  color: #ffffff;
  font-family: var(--font-ui);
  font-weight: 600;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  margin-top: 12px;
}

.primary-btn:hover { background: #333; }

.tier-badge {
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 3px;
  color: #ffffff;
}

.tier-t1 { background: var(--tier-t1); }
.tier-t2 { background: var(--tier-t2); }
.tier-t3 { background: var(--tier-t3); }
.tier-t4 { background: var(--tier-t4); }
.tier-t5 { background: var(--tier-t5); }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node test/test-sidepanel-dom.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add extension/sidepanel/index.html extension/sidepanel/sidepanel.css test/test-sidepanel-dom.js
git commit -m "feat(extension): create sidepanel UI template and publication design system"
```

---

### Task 6: Side Panel Controller, Rendering & 1-Click Clipboard Actions

**Files:**
- Create: `extension/sidepanel/sidepanel.js`
- Test: `test/test-sidepanel-logic.js`

**Interfaces:**
- Consumes: Extracted DOM payload, `RUN_AUDIT` message, `storage.js`
- Produces: Rendered summary cards, finding lists with evidence tags, 1-click clipboard copy, and feedback handlers.

- [ ] **Step 1: Write test for result HTML builder**

Create `test/test-sidepanel-logic.js`:
```javascript
const assert = require('assert');
const { renderAuditHTML } = require('../extension/sidepanel/renderer-helper.cjs');

const mockData = {
  summary: {
    bloomsLevel: 'Analyze',
    alignmentScore: 'Strong',
    keyTakeaway: 'Great constructive alignment between rubric and lab analysis.'
  },
  findings: [
    {
      severity: 'suggestion',
      tier: 'T1',
      citation: '[Assessment-8] Elaborated Feedback',
      observation: 'Rubric uses generic grading bands.',
      evidence: 'Elaborated criteria increase metacognitive monitoring.',
      recommendation: 'Add milestone descriptions for each level.'
    }
  ],
  improvedDraft: {
    title: 'Rewritten Rubric Matrix',
    content: '| Criterion | Exemplary | Developing |\n|---|---|---|'
  }
};

const rendered = renderAuditHTML(mockData);
assert.ok(rendered.includes('Analyze'), "Must render Bloom's level");
assert.ok(rendered.includes('[Assessment-8]'), 'Must render citation');
assert.ok(rendered.includes('copy-improved-btn'), 'Must include 1-click copy button');

console.log('✅ Task 6 renderer tests passed.');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-sidepanel-logic.js`  
Expected: FAIL

- [ ] **Step 3: Implement `sidepanel.js`**

Create `extension/sidepanel/sidepanel.js`:
```javascript
import { getSettings, saveSettings } from '../shared/storage.js';

let activePayload = null;

async function refreshActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.id) return;

  try {
    const response = await chrome.tabs.sendMessage(tab.id, { action: 'EXTRACT_CONTENT' });
    if (response) {
      activePayload = response;
      document.getElementById('page-type-tag').textContent = response.pageType;
      document.getElementById('page-title').textContent = response.title;
    }
  } catch (err) {
    document.getElementById('page-type-tag').textContent = 'Web Page';
    document.getElementById('page-title').textContent = tab.title || 'Current Tab';
    activePayload = {
      url: tab.url,
      title: tab.title,
      pageType: 'Web Page',
      content: ''
    };
  }
}

function showState(stateName) {
  document.querySelectorAll('.state-panel').forEach(el => el.classList.remove('active'));
  document.getElementById(`${stateName}-state`).classList.add('active');
}

function renderResults(data) {
  const container = document.getElementById('results-container');
  
  const findingsHTML = data.findings.map(f => `
    <div class="finding-card severity-${f.severity}">
      <div class="finding-header">
        <span class="tier-badge tier-${f.tier.toLowerCase()}">${f.tier}</span>
        <span class="citation">${f.citation}</span>
      </div>
      <p class="finding-obs"><strong>Observation:</strong> ${f.observation}</p>
      <p class="finding-evi"><strong>Evidence:</strong> ${f.evidence}</p>
      <p class="finding-rec"><strong>Recommendation:</strong> ${f.recommendation}</p>
    </div>
  `).join('');

  container.innerHTML = `
    <div class="context-card summary-card">
      <div class="score-row">
        <span class="chip">Bloom's: <strong>${data.summary.bloomsLevel}</strong></span>
        <span class="chip">Alignment: <strong>${data.summary.alignmentScore}</strong></span>
      </div>
      <p class="key-takeaway">${data.summary.keyTakeaway}</p>
    </div>

    <h3 class="section-title">Evidence-Based Findings (${data.findings.length})</h3>
    <div class="findings-list">${findingsHTML}</div>

    <div class="improved-box">
      <div class="improved-header">
        <h4>${data.improvedDraft.title}</h4>
        <button id="copy-improved-btn" class="secondary-btn">📋 Copy to Clipboard</button>
      </div>
      <pre class="improved-content"><code>${data.improvedDraft.content}</code></pre>
    </div>

    <div class="feedback-row">
      <span>Was this audit helpful?</span>
      <button class="feedback-btn" data-vote="up">👍</button>
      <button class="feedback-btn" data-vote="down">👎</button>
      <button id="re-audit-btn" class="link-btn">Audit Another Page</button>
    </div>
  `;

  document.getElementById('copy-improved-btn').addEventListener('click', () => {
    navigator.clipboard.writeText(data.improvedDraft.content);
    const btn = document.getElementById('copy-improved-btn');
    btn.textContent = '✓ Copied!';
    setTimeout(() => { btn.textContent = '📋 Copy to Clipboard'; }, 2000);
  });

  document.getElementById('re-audit-btn').addEventListener('click', () => {
    showState('ready');
    refreshActiveTab();
  });

  document.querySelectorAll('.feedback-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.target.parentElement.innerHTML = '<em>Thank you for your feedback!</em>';
    });
  });

  showState('results');
}

document.getElementById('audit-btn').addEventListener('click', async () => {
  if (!activePayload) await refreshActiveTab();
  showState('loading');

  chrome.runtime.sendMessage({ action: 'RUN_AUDIT', payload: activePayload }, (response) => {
    if (response && response.success) {
      renderResults(response.data);
    } else {
      alert(`Audit failed: ${response?.error || 'Unknown error'}`);
      showState('ready');
    }
  });
});

// Init
refreshActiveTab();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node test/test-sidepanel-logic.js`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add extension/sidepanel/sidepanel.js test/test-sidepanel-logic.js
git commit -m "feat(extension): add sidepanel controller and 1-click clipboard integration"
```

---

### Task 7: Verification, Smoke Testing & Integration into Root Suite

**Files:**
- Create: `test/test-extension.sh`
- Modify: `test/smoke-test.sh`
- Modify: `README.md`

- [ ] **Step 1: Create automated extension test runner script**

Create `test/test-extension.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> Running idstack Chrome Extension test suite..."
node test/test-manifest.js
node test/test-prompts.js
node test/test-extractor.js
node test/test-service-worker.js
node test/test-sidepanel-dom.js
node test/test-sidepanel-logic.js

echo "==> All Chrome Extension tests passed!"
```

- [ ] **Step 2: Make `test/test-extension.sh` executable and run it**

Run: `chmod +x test/test-extension.sh && ./test/test-extension.sh`  
Expected: PASS with 6/6 test suites passing.

- [ ] **Step 3: Integrate into `test/smoke-test.sh` and update `README.md` with Chrome Extension section**

Update `README.md` to include quick-start instructions for loading the extension unpacked into Chrome.

- [ ] **Step 4: Run full project smoke test**

Run: `./test/smoke-test.sh`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add test/test-extension.sh test/smoke-test.sh README.md
git commit -m "test(extension): integrate chrome extension test suite into smoke tests"
```
