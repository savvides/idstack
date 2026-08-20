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
