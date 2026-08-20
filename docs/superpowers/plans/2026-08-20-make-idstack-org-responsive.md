# Responsive Design for idstack.org Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make idstack.org (`docs/index.html`) fully responsive, fluid, and touch-friendly across all device form factors (320px mobile up to 4K ultra-wide), eliminating mobile layout bottlenecks, cramped multi-column grids, and clipped navigation.

**Architecture:** Refactor CSS in `docs/index.html` using modern fluid primitives (`clamp()`, responsive CSS grids, flex wrapping, safe area insets), replace rigid multi-column layouts with adaptive breakpoints (single-column mobile pipeline flow, flexible CTA buttons, touch-ergonomic install blocks and footer signup), ensure all topbar links remain accessible and touch-friendly on mobile viewports, and introduce automated responsive assertion tests in `test/test-responsive-landing.js` integrated into `test/smoke-test.sh`.

**Tech Stack:** HTML5, CSS3 (CSS Grid, Flexbox, Fluid Typography, CSS Custom Properties, Safe Area Insets), Node.js for automated DOM/CSS verification, Bash.

---

### Task 1: Create Automated Responsive Test Suite

**Files:**
- Create: `test/test-responsive-landing.js`
- Modify: `test/smoke-test.sh:315-325`

- [ ] **Step 1: Write the failing test suite for responsive landing page invariants**

Create `test/test-responsive-landing.js`:
```javascript
#!/usr/bin/env node
/**
 * test-responsive-landing.js
 * Validates responsive design, CSS media queries, fluid units, and mobile ergonomics in docs/index.html.
 */

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const landingPath = path.join(repoRoot, 'docs', 'index.html');

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  PASS: ${message}`);
    passed++;
  } else {
    console.error(`  FAIL: ${message}`);
    failed++;
  }
}

console.log('idstack responsive landing page test');
console.log(`  target: ${landingPath}\n`);

if (!fs.existsSync(landingPath)) {
  console.error(`FAIL: ${landingPath} does not exist`);
  process.exit(1);
}

const html = fs.readFileSync(landingPath, 'utf8');

// 1. Viewport meta tag
assert(
  html.includes('<meta name="viewport" content="width=device-width, initial-scale=1.0">') ||
  html.includes('<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">'),
  'viewport meta tag is properly configured'
);

// 2. Fluid spacing tokens
assert(
  /--pad-x:\s*clamp\(/.test(html) && /--pad-y:\s*clamp\(/.test(html),
  'root spacing uses fluid clamp() for padding'
);

// 3. Fluid typography
assert(
  /font-size:\s*clamp\(/.test(html),
  'typography leverages fluid font-size clamps'
);

// 4. Safe area insets
assert(
  html.includes('safe-area-inset-left') || html.includes('safe-area-inset-right') || html.includes('--pad-x'),
  'layout respects horizontal safe area padding'
);

// 5. Responsive navigation — does not hide primary section links on mobile
assert(
  !html.includes('.nav-links a:nth-child(2),\n      .nav-links a:nth-child(3) { display: none; }') &&
  !html.includes('.nav-links a:nth-child(2), .nav-links a:nth-child(3) { display: none; }'),
  'navigation keeps all section links reachable across screen sizes without ad-hoc nth-child hiding'
);

// 6. Pipeline grid responsive breakpoints — must support 1-column mobile layout (<= 480px or <= 500px)
const hasSingleColPipeline =
  /@media\s*\([^{}]*max-width:\s*(480|500|540)px[^{}]*\)\s*\{[^}]*\.pipeline-flow\s*\{[^}]*grid-template-columns:\s*(1fr|repeat\(1,\s*1fr\)|minmax\(0,\s*1fr\))/s.test(html) ||
  /\.pipeline-flow\s*\{[^}]*grid-template-columns:\s*repeat\(auto-fit/s.test(html);
assert(
  hasSingleColPipeline,
  'pipeline flow switches to single column on narrow mobile screens (<= 480px/500px)'
);

// 7. Pipeline aside top-alignment for mobile readability
assert(
  /\.pipeline-aside\s*\{[^}]*align-items:\s*flex-start/s.test(html),
  'pipeline aside items align to top (flex-start) for multi-line description wrapping'
);

// 8. CTA mobile full-width / wrapping support
const hasCtaMobileStyles =
  /@media\s*\([^{}]*max-width:\s*(480|500|640)px[^{}]*\)\s*\{[^}]*\.btn-chrome/s.test(html) ||
  /\.btn-chrome\s*\{[^}]*justify-content:\s*center/s.test(html);
assert(
  hasCtaMobileStyles,
  'CTA actions support full-width centered buttons on mobile viewports'
);

// 9. Install block touch & overflow scrolling
assert(
  /\.install-block code\s*\{[^}]*overflow-x:\s*auto/s.test(html) &&
  /\.install-pill code\s*\{[^}]*overflow-x:\s*auto/s.test(html),
  'install code snippets have horizontal overflow scrolling'
);

// 10. Footer signup form mobile stacking
assert(
  /@media\s*\([^{}]*max-width:\s*(420|480|500)px[^{}]*\)\s*\{[^}]*\.footer-signup\s*\{[^}]*flex-direction:\s*column/s.test(html),
  'footer signup form stacks vertically on mobile screens'
);

// 11. Touch targets (buttons, inputs, copy buttons have adequate minimum heights)
assert(
  /\.copy-btn\s*\{[^}]*min-height:\s*(32|36|40|44)px/s.test(html),
  'copy buttons define accessible minimum touch heights'
);

// 12. Output panel responsive stacking
assert(
  /@media\s*\([^{}]*max-width:\s*(880|900|960)px[^{}]*\)\s*\{[^}]*\.output-pair\s*\{[^}]*grid-template-columns:\s*1fr/s.test(html),
  'output preview pair stacks to single column on tablet/mobile screens'
);

// 13. Dark-only invariant preserved
assert(
  html.includes('--bg:           #0a0a0f;') || html.includes('--bg: #0a0a0f;'),
  'dark background invariant preserved'
);

// 14. Gradient text solid fallback preserved (no bare color: transparent)
assert(
  !/[^-]color:\s*transparent/.test(html),
  'gradient text keeps solid color fallback (no bare color: transparent)'
);

console.log(`\nResults: ${passed}/${passed + failed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
```

- [ ] **Step 2: Make the test script executable and run it to verify initial failures**

Run:
```bash
chmod +x test/test-responsive-landing.js
node test/test-responsive-landing.js
```
Expected: FAIL with multiple responsive criteria failing on current `docs/index.html` (e.g. single column pipeline, nav nth-child hiding, pipeline aside flex-start).

- [ ] **Step 3: Hook the responsive test into `test/smoke-test.sh`**

In `test/smoke-test.sh` around line 315, add:
```bash
# Responsive landing page test
if [ -x "$IDSTACK_DIR/test/test-responsive-landing.js" ]; then
  check "responsive landing page tests pass" "node '$IDSTACK_DIR/test/test-responsive-landing.js'"
fi
```

- [ ] **Step 4: Commit test harness**

```bash
git add test/test-responsive-landing.js test/smoke-test.sh
git commit -m "test: add automated responsive landing page test suite"
```

---

### Task 2: Layout Primitives, Fluid Spacing, and Responsive Navigation

**Files:**
- Modify: `docs/index.html:5, 62-212`

- [ ] **Step 1: Update viewport meta tag and root fluid spacing variables**

In `docs/index.html`:
Update line 5:
```html
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
```

In `docs/index.html` `:root` styling (around lines 100-104):
```css
      --max:    1120px;
      --prose:  62ch;
      --pad-x:  clamp(1rem, 3.5vw, 2rem);
      --pad-y:  clamp(2.75rem, 5.5vw, 5.5rem);
```

Add safe area padding variables and global image/overflow rules:
```css
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    img, svg {
      max-width: 100%;
      height: auto;
      display: inline-block;
      vertical-align: middle;
    }
```

- [ ] **Step 2: Refactor Topbar & Navigation to be fully responsive without hiding links**

Replace `.topbar`, `.nav`, `.brand`, `.brand-beta`, `.nav-links` rules (around lines 158-212) in `docs/index.html` with:
```css
    /* ──────────────────────────────────────────────
       Topbar
       ────────────────────────────────────────────── */
    .topbar {
      position: sticky;
      top: 0;
      z-index: 50;
      background: color-mix(in srgb, var(--bg) 88%, transparent);
      backdrop-filter: saturate(160%) blur(10px);
      -webkit-backdrop-filter: saturate(160%) blur(10px);
      border-bottom: 1px solid var(--rule);
    }
    .nav {
      display: flex;
      align-items: center;
      justify-content: space-between;
      max-width: var(--max);
      margin: 0 auto;
      padding: 0.85rem var(--pad-x);
      padding-left: max(var(--pad-x), env(safe-area-inset-left));
      padding-right: max(var(--pad-x), env(safe-area-inset-right));
      gap: 1rem;
      flex-wrap: wrap;
    }
    .brand {
      font-family: var(--font-display);
      font-size: clamp(1.2rem, 3vw, 1.35rem);
      font-weight: 600;
      color: var(--ink);
      text-decoration: none;
      letter-spacing: -0.01em;
      display: inline-flex;
      align-items: baseline;
      flex-shrink: 0;
    }
    .brand:hover { text-decoration: none; }
    .brand-beta {
      font-family: var(--font-ui);
      font-size: 0.62rem;
      font-weight: 700;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      color: var(--accent);
      margin-left: 0.35rem;
      vertical-align: super;
    }
    .nav-links {
      display: flex;
      align-items: center;
      gap: clamp(0.75rem, 2.5vw, 1.5rem);
      flex-wrap: wrap;
    }
    .nav-links a {
      color: var(--ink-soft);
      text-decoration: none;
      font-size: clamp(0.82rem, 1.8vw, 0.93rem);
      padding: 0.25rem 0;
      transition: color 0.15s ease;
      white-space: nowrap;
    }
    .nav-links a:hover { color: var(--ink); }

    @media (max-width: 480px) {
      .nav { padding-top: 0.65rem; padding-bottom: 0.65rem; gap: 0.6rem; }
      .nav-links { gap: 0.85rem; }
    }
```

- [ ] **Step 3: Run responsive test to verify navigation checks pass**

Run:
```bash
node test/test-responsive-landing.js
```

- [ ] **Step 4: Commit**

```bash
git add docs/index.html
git commit -m "style(web): make navigation and layout primitives fluid and responsive"
```

---

### Task 3: Responsive Hero, CTA Actions, and Install Blocks

**Files:**
- Modify: `docs/index.html:252-446, 729-805`

- [ ] **Step 1: Refactor Hero typography, CTA row, install pills, and buttons**

Update `.hero`, `.hero h1`, `.hero .lede`, `.hero-meta`, `.install-pill`, `.copy-btn`, `.cta-row`, `.cta-actions`, `.btn-chrome`, `.cta-or`, `.cta-secondary` in `docs/index.html`:
```css
    /* ──────────────────────────────────────────────
       Hero — single column, generous whitespace
       ────────────────────────────────────────────── */
    .hero {
      max-width: var(--max);
      margin: 0 auto;
      padding: clamp(2.5rem, 6vw, 5.5rem) var(--pad-x) clamp(2.25rem, 5vw, 4.5rem);
      padding-left: max(var(--pad-x), env(safe-area-inset-left));
      padding-right: max(var(--pad-x), env(safe-area-inset-right));
    }
    .hero-text { max-width: 56rem; }

    .hero h1 {
      font-size: clamp(1.85rem, 5.2vw, 3.4rem);
      font-weight: 600;
      letter-spacing: -0.022em;
      line-height: 1.1;
      margin-bottom: 1.25rem;
      text-wrap: balance;
      overflow-wrap: break-word;
      max-width: 22ch;
      color: var(--accent-start);
      background: var(--accent-gradient);
      -webkit-background-clip: text;
      background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .hero .lede {
      font-size: clamp(0.98rem, 1.6vw, 1.15rem);
      color: var(--ink-soft);
      line-height: 1.6;
      max-width: var(--prose);
      margin-bottom: 1.75rem;
    }

    .hero-meta {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 0.45rem 0.65rem;
      font-size: clamp(0.74rem, 1.4vw, 0.78rem);
      letter-spacing: 0.03em;
      color: var(--ink-muted);
      margin-bottom: 1.25rem;
    }
    .hero-meta .dot {
      width: 4px; height: 4px; border-radius: 50%;
      background: var(--ink-muted);
      display: inline-block;
      flex-shrink: 0;
    }

    .install-pill {
      display: flex;
      align-items: center;
      gap: 0.6rem;
      background: var(--accent-soft);
      border: 1px solid var(--accent-start);
      border-radius: 2px;
      padding: 0.5rem 0.55rem 0.5rem 0.8rem;
      width: 100%;
      max-width: 640px;
      overflow: hidden;
    }
    .install-pill .prompt {
      color: var(--accent);
      font-family: var(--font-mono);
      font-weight: 600;
      flex-shrink: 0;
    }
    .install-pill code {
      background: transparent;
      border: none;
      padding: 0;
      color: var(--ink);
      font-size: clamp(0.76rem, 1.6vw, 0.83rem);
      flex: 1 1 0;
      min-width: 0;
      overflow-x: auto;
      white-space: nowrap;
      scrollbar-width: thin;
      -webkit-overflow-scrolling: touch;
    }
    .copy-btn {
      background: transparent;
      border: 1px solid var(--rule);
      border-radius: 2px;
      padding: 0.4rem 0.75rem;
      min-height: 36px;
      color: var(--ink-soft);
      font-family: var(--font-ui);
      font-weight: 600;
      font-size: 0.78rem;
      cursor: pointer;
      flex-shrink: 0;
      transition: border-color 0.15s, color 0.15s;
    }
    .copy-btn:hover { color: var(--ink); border-color: var(--rule-strong); }
    .copy-btn:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    .copy-btn[data-copied="true"] { color: var(--tier-1); border-color: var(--tier-1); }

    .cta-row {
      display: flex;
      flex-direction: column;
      gap: 0.85rem;
      align-items: stretch;
      max-width: 640px;
    }
    .cta-actions {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      flex-wrap: wrap;
    }
    .btn-chrome {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 0.55rem;
      background: #2563eb;
      color: #ffffff;
      font-family: var(--font-ui);
      font-weight: 600;
      font-size: 0.88rem;
      padding: 0.6rem 1rem;
      min-height: 40px;
      border-radius: 2px;
      text-decoration: none;
      transition: background 0.15s ease;
      flex-shrink: 0;
    }
    .btn-chrome:hover {
      background: #1d4ed8;
      color: #ffffff;
      text-decoration: none;
    }
    .btn-chrome:focus-visible {
      outline: 2px solid var(--accent);
      outline-offset: 2px;
    }
    .btn-chrome .btn-badge {
      font-size: 0.72rem;
      background: rgba(255, 255, 255, 0.22);
      padding: 0.1rem 0.4rem;
      border-radius: 2px;
      font-weight: 500;
    }
    .cta-or {
      font-size: 0.82rem;
      color: var(--ink-muted);
      font-family: var(--font-ui);
    }
    .cta-secondary {
      font-size: 0.92rem;
      color: var(--ink-muted);
      text-decoration: none;
      align-self: flex-start;
      padding: 0.2rem 0;
    }
    .cta-secondary:hover { color: var(--ink); text-decoration: underline; }

    @media (max-width: 480px) {
      .cta-actions { flex-direction: column; align-items: stretch; gap: 0.6rem; }
      .btn-chrome { width: 100%; }
      .cta-or { text-align: center; }
    }
```

- [ ] **Step 2: Refactor Install section cards and code blocks**

Update `.install-tracks`, `.install-track-card`, `.install-track-header`, `.install-block` (around lines 729-805) in `docs/index.html`:
```css
    /* ──────────────────────────────────────────────
       Install
       ────────────────────────────────────────────── */
    .install-tracks {
      display: grid;
      grid-template-columns: 1fr;
      gap: 1.5rem;
      max-width: 760px;
    }
    .install-track-card {
      background: var(--raised);
      border: 1px solid var(--rule);
      border-radius: 2px;
      padding: clamp(1rem, 3.5vw, 1.75rem);
    }
    .install-track-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 0.6rem 0.75rem;
      flex-wrap: wrap;
      margin-bottom: 0.85rem;
    }
    .install-track-header h3 {
      font-family: var(--font-display);
      font-size: clamp(1.05rem, 2.5vw, 1.18rem);
      font-weight: 600;
      margin: 0;
    }
    .track-badge {
      font-family: var(--font-mono);
      font-size: 0.75rem;
      letter-spacing: 0.03em;
      color: var(--accent);
      background: var(--accent-soft);
      padding: 0.15rem 0.5rem;
      border-radius: 2px;
      border: 1px solid color-mix(in srgb, var(--accent) 30%, transparent);
      white-space: nowrap;
    }
    .install-track-card .btn-chrome {
      margin-top: 1rem;
    }

    .install-block {
      display: flex;
      align-items: center;
      gap: 0.6rem;
      background: var(--raised);
      border: 1px solid var(--rule);
      border-radius: 2px;
      padding: 0.65rem 0.65rem 0.65rem 0.95rem;
      max-width: 760px;
      width: 100%;
      overflow: hidden;
    }
    .install-block .prompt {
      color: var(--accent);
      font-family: var(--font-mono);
      font-weight: 600;
      flex-shrink: 0;
    }
    .install-block code {
      background: transparent;
      border: none;
      padding: 0;
      color: var(--ink);
      font-size: clamp(0.78rem, 1.8vw, 0.88rem);
      flex: 1 1 0;
      min-width: 0;
      overflow-x: auto;
      white-space: nowrap;
      scrollbar-width: thin;
      -webkit-overflow-scrolling: touch;
    }

    .install-prose {
      font-size: clamp(0.9rem, 1.6vw, 0.95rem);
      color: var(--ink-soft);
      max-width: var(--prose);
      margin-top: 0.85rem;
    }
```

- [ ] **Step 3: Run responsive test suite**

Run:
```bash
node test/test-responsive-landing.js
```

- [ ] **Step 4: Commit**

```bash
git add docs/index.html
git commit -m "style(web): make hero, CTA actions, and install blocks fully responsive"
```

---

### Task 4: Responsive Grid Upgrades for Evidence, Pipeline, Output, and Footer

**Files:**
- Modify: `docs/index.html:448-726, 844-959`

- [ ] **Step 1: Refactor Evidence legend and cards for fluid multi-column & mobile readability**

Update `.evidence-legend`, `.evidence-legend-item`, `.evidence-grid`, `.evidence-card` styling in `docs/index.html`:
```css
    /* ──────────────────────────────────────────────
       Evidence — tier legend + per-domain cards
       ────────────────────────────────────────────── */
    .evidence-legend {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem clamp(1rem, 3vw, 1.75rem);
      margin-bottom: 2.25rem;
      padding-bottom: 1.25rem;
      border-bottom: 1px solid var(--rule);
      font-family: var(--font-ui);
      font-size: clamp(0.82rem, 1.8vw, 0.88rem);
      color: var(--ink-soft);
    }
    .evidence-legend-item {
      display: inline-flex;
      align-items: baseline;
      gap: 0.45rem;
      flex-wrap: wrap;
    }
    .evidence-legend-item strong {
      font-family: var(--font-mono);
      font-weight: 600;
      color: var(--ink);
      letter-spacing: 0.02em;
    }
    .evidence-legend-dot {
      display: inline-block;
      width: 0.6rem;
      height: 0.6rem;
      border-radius: 50%;
      transform: translateY(1px);
      flex-shrink: 0;
    }
    .evidence-legend-dot.t1 { background: var(--tier-1); }
    .evidence-legend-dot.t2 { background: var(--tier-2); }
    .evidence-legend-dot.t3 { background: var(--tier-3); }
    .evidence-legend-dot.t4 { background: var(--tier-4); }
    .evidence-legend-dot.t5 { background: var(--tier-5); }

    .evidence-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: 0;
    }
    @media (min-width: 768px) {
      .evidence-grid {
        grid-template-columns: 1fr 1fr;
        column-gap: clamp(2rem, 4vw, 3rem);
      }
    }

    .evidence-card {
      padding: 1.25rem 0;
      border-bottom: 1px solid var(--rule);
    }
    .evidence-card:last-child { border-bottom: none; }

    .evidence-card-title {
      font-family: var(--font-display);
      font-size: clamp(1.05rem, 2vw, 1.12rem);
      font-weight: 600;
      letter-spacing: -0.01em;
      color: var(--ink);
      margin-bottom: 0.55rem;
    }

    .evidence-card-body {
      font-family: var(--font-body);
      font-size: clamp(0.92rem, 1.6vw, 0.98rem);
      line-height: 1.55;
      color: var(--ink-soft);
      max-width: var(--prose);
      margin-bottom: 0.7rem;
    }

    .evidence-card-meta {
      font-family: var(--font-ui);
      font-size: 0.8rem;
      color: var(--ink-muted);
      letter-spacing: 0.02em;
    }
    .evidence-card-meta .meta-sep {
      display: inline-block;
      width: 3px;
      height: 3px;
      border-radius: 50%;
      background: var(--ink-muted);
      vertical-align: middle;
      margin: 0 0.5rem;
      transform: translateY(-1px);
    }
    .evidence-card-meta .meta-tier {
      font-family: var(--font-mono);
      letter-spacing: 0.04em;
    }

    .evidence-foot {
      margin-top: 2rem;
      font-size: clamp(0.88rem, 1.6vw, 0.92rem);
      color: var(--ink-muted);
      max-width: var(--prose);
    }
```

- [ ] **Step 2: Refactor Pipeline flow to include single-column mobile breakpoint and top-aligned asides**

Update `.pipeline-flow`, `.pipeline-node`, `.pipeline-aside-row`, `.pipeline-aside` in `docs/index.html`:
```css
    /* ──────────────────────────────────────────────
       Pipeline
       ────────────────────────────────────────────── */
    .pipeline-canvas {
      display: grid;
      gap: 1.5rem;
    }

    .pipeline-track-label {
      font-family: var(--font-ui);
      font-size: 0.72rem;
      font-weight: 700;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--ink-muted);
    }
    .pipeline-track-label .track-mono {
      font-family: var(--font-mono);
      letter-spacing: 0;
      text-transform: none;
      color: var(--accent);
    }

    .pipeline-flow {
      list-style: none;
      display: grid;
      grid-template-columns: repeat(8, minmax(0, 1fr));
      gap: 0.6rem;
      counter-reset: step;
    }
    @media (max-width: 1080px) {
      .pipeline-flow { grid-template-columns: repeat(4, minmax(0, 1fr)); }
    }
    @media (max-width: 640px) {
      .pipeline-flow { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }
    @media (max-width: 480px) {
      .pipeline-flow { grid-template-columns: 1fr; }
    }

    .pipeline-node {
      counter-increment: step;
      position: relative;
      background: var(--raised);
      border: 1px solid var(--rule);
      border-radius: 0;
      padding: 0.85rem 0.85rem 0.85rem 0.85rem;
      cursor: default;
      transition: border-color 0.15s, transform 0.15s;
    }
    .pipeline-node:hover,
    .pipeline-node:focus-within {
      border-color: var(--accent);
      transform: translateY(-1px);
    }
    .pipeline-node:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    .pipeline-node .node-num {
      position: absolute;
      top: 0.6rem;
      right: 0.6rem;
      font-family: var(--font-mono);
      font-size: 0.7rem;
      color: var(--ink-muted);
    }
    .pipeline-node .node-num::before { content: counter(step); }
    .pipeline-node .node-label {
      display: block;
      font-family: var(--font-mono);
      font-size: 0.78rem;
      color: var(--accent);
      margin-bottom: 0.3rem;
      word-break: break-word;
      padding-right: 1.5rem;
    }
    .pipeline-node .node-desc {
      font-size: 0.78rem;
      color: var(--ink-muted);
      line-height: 1.4;
    }

    .pipeline-aside-row {
      display: flex;
      flex-wrap: wrap;
      gap: 1.25rem 2rem;
      padding-top: 1.25rem;
      border-top: 1px dashed var(--rule);
      font-size: 0.88rem;
      color: var(--ink-muted);
    }
    .pipeline-aside {
      display: flex;
      align-items: flex-start;
      gap: 0.65rem;
    }
    .pipeline-aside .aside-tag {
      font-family: var(--font-mono);
      font-size: 0.78rem;
      color: var(--accent);
      border: 1px solid var(--rule);
      padding: 0.18em 0.5em;
      border-radius: 2px;
      background: var(--raised);
      flex-shrink: 0;
      margin-top: 0.1rem;
    }

    .pipeline-foot {
      margin-top: 1.75rem;
      font-size: clamp(0.9rem, 1.6vw, 0.95rem);
      color: var(--ink-soft);
      max-width: var(--prose);
    }
```

- [ ] **Step 3: Refactor Output panels and Footer components**

Update `.output-pair`, `.output-panel`, `.output-body`, `.output-json`, `.footer`, `.footer-top`, `.footer-links`, `.footer-signup` in `docs/index.html`:
```css
    /* ──────────────────────────────────────────────
       Output pair (markdown / json)
       ────────────────────────────────────────────── */
    .output-pair {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
    }
    @media (max-width: 880px) {
      .output-pair { grid-template-columns: 1fr; }
    }
    .output-panel {
      background: var(--raised);
      border: 1px solid var(--rule);
      border-radius: 0;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .output-header {
      padding: 0.55rem 0.85rem;
      border-bottom: 1px solid var(--rule);
      background: color-mix(in srgb, var(--bg) 50%, transparent);
      font-family: var(--font-mono);
      font-size: 0.74rem;
      color: var(--ink-muted);
      letter-spacing: 0.02em;
      overflow-x: auto;
      white-space: nowrap;
    }
    .output-body {
      padding: clamp(0.9rem, 2.5vw, 1.25rem);
      font-size: clamp(0.88rem, 1.6vw, 0.92rem);
      line-height: 1.6;
      color: var(--ink-soft);
    }
    .output-body h3 {
      font-family: var(--font-display);
      font-size: clamp(0.95rem, 2vw, 1rem);
      font-weight: 600;
      letter-spacing: -0.005em;
      color: var(--ink);
      margin-bottom: 0.85rem;
      display: flex;
      flex-wrap: wrap;
      gap: 0.4rem;
      align-items: center;
    }
    .output-body p { margin-bottom: 0.7rem; }
    .output-body p:last-child { margin-bottom: 0; }
    .output-body strong { color: var(--ink); font-weight: 600; }
    .output-json {
      font-family: var(--font-mono);
      font-size: clamp(0.72rem, 1.6vw, 0.78rem);
      line-height: 1.55;
      white-space: pre;
      overflow-x: auto;
      scrollbar-width: thin;
      -webkit-overflow-scrolling: touch;
      color: var(--ink-soft);
      padding: clamp(0.9rem, 2.5vw, 1.25rem);
    }
    .output-json .key   { color: var(--accent); }
    .output-json .str   { color: var(--tier-2); }
    .output-json .punct { color: var(--ink-muted); }
    .output-foot {
      margin-top: 1.5rem;
      font-size: clamp(0.88rem, 1.6vw, 0.92rem);
      color: var(--ink-muted);
      max-width: var(--prose);
    }

    /* ──────────────────────────────────────────────
       Footer
       ────────────────────────────────────────────── */
    .footer {
      max-width: var(--max);
      margin: 0 auto;
      padding: 2.5rem var(--pad-x) max(3rem, env(safe-area-inset-bottom));
      padding-left: max(var(--pad-x), env(safe-area-inset-left));
      padding-right: max(var(--pad-x), env(safe-area-inset-right));
      border-top: 1px solid var(--rule);
      font-size: 0.88rem;
    }
    .footer-top {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 1.5rem 2rem;
      align-items: start;
    }
    @media (max-width: 720px) {
      .footer-top { grid-template-columns: 1fr; gap: 1.25rem; }
    }
    .footer-brand {
      font-family: var(--font-display);
      font-size: 1rem;
      color: var(--ink-soft);
      margin-bottom: 0.4rem;
    }
    .footer-brand strong {
      color: var(--ink);
      font-weight: 600;
    }
    .footer-tag {
      color: var(--ink-muted);
      font-size: 0.82rem;
    }
    .footer-links {
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem 1.25rem;
    }
    .footer-links a {
      color: var(--ink-soft);
      text-decoration: none;
      padding: 0.2rem 0;
    }
    .footer-links a:hover { color: var(--ink); text-decoration: underline; }

    .footer-signup {
      margin-top: 1.75rem;
      display: flex;
      flex-wrap: wrap;
      align-items: stretch;
      max-width: 460px;
      gap: 0;
    }
    @media (max-width: 480px) {
      .footer-signup { flex-direction: column; gap: 0.5rem; }
      .footer-signup input[type="email"] { border-right: 1px solid var(--rule); border-radius: 2px; min-height: 42px; }
      .footer-signup button { border-radius: 2px; min-height: 42px; width: 100%; }
    }
    .footer-signup label {
      position: absolute;
      width: 1px; height: 1px;
      overflow: hidden;
      clip: rect(0 0 0 0);
      white-space: nowrap;
    }
    .footer-signup input[type="email"] {
      flex: 1;
      padding: 0.55rem 0.85rem;
      font-family: var(--font-ui);
      font-size: 0.9rem;
      background: var(--raised);
      color: var(--ink);
      border: 1px solid var(--rule);
      border-right: none;
      border-radius: 2px 0 0 2px;
      outline: none;
    }
    .footer-signup input[type="email"]:focus { border-color: var(--accent); }
    .footer-signup input[type="email"]::placeholder { color: var(--ink-muted); }
    .footer-signup button {
      padding: 0.55rem 1rem;
      font-family: var(--font-ui);
      font-size: 0.85rem;
      font-weight: 700;
      color: #f5f5fb;
      background: var(--accent-gradient);
      border: 1px solid var(--rule);
      border-radius: 0 2px 2px 0;
      cursor: pointer;
    }
    .footer-signup button:hover { opacity: 0.92; }
    .footer-signup button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    .signup-note {
      margin-top: 0.55rem;
      font-size: 0.82rem;
      color: var(--ink-muted);
      min-height: 1.2em;
    }
    .signup-note.success { color: var(--tier-1); }
    .signup-note.error   { color: var(--severity-critical-fg); }
```

- [ ] **Step 4: Run the responsive test suite and doc checkers**

Run:
```bash
node test/test-responsive-landing.js
python3 test/check-doc-accuracy.py .
python3 test/check-evidence-cards.py .
```
Expected: All 14 assertions in `test/test-responsive-landing.js` pass, doc accuracy and evidence cards pass.

- [ ] **Step 5: Commit**

```bash
git add docs/index.html
git commit -m "style(web): enhance responsive grid layouts for pipeline, evidence, output, and footer"
```

---

### Task 5: Comprehensive Verification Across Test Suites

**Files:**
- Test: `test/test-responsive-landing.js`
- Test: `test/smoke-test.sh`
- Test: `test/integration-test.sh`
- Test: `test/test-extension.sh`
- Test: `test/mutation-test.sh`

- [ ] **Step 1: Run responsive test suite standalone**

Run:
```bash
node test/test-responsive-landing.js
```
Expected: 14/14 PASS, 0 FAIL.

- [ ] **Step 2: Run smoke test suite**

Run:
```bash
./test/smoke-test.sh
```
Expected: All smoke test checks pass with 0 failures.

- [ ] **Step 3: Run integration, extension, and component test suites**

Run:
```bash
./test/integration-test.sh
./test/test-extension.sh
for t in test/test-*.sh; do bash "$t"; done
```
Expected: All test suites pass cleanly.

- [ ] **Step 4: Run mutation test suite to verify no regressions in test invariants**

Run:
```bash
./test/mutation-test.sh
```
Expected: All 24 mutation checks caught and verified.

- [ ] **Step 5: Commit any final test adjustments and verify git status**

Run:
```bash
git status
```
Expected: Working tree clean.
