const fs = require('fs');
const path = require('path');
const assert = require('assert');

const htmlPath = path.join(__dirname, '../extension/sidepanel/index.html');
const cssPath = path.join(__dirname, '../extension/sidepanel/sidepanel.css');

assert.ok(fs.existsSync(htmlPath), 'index.html must exist');
assert.ok(fs.existsSync(cssPath), 'sidepanel.css must exist');

const html = fs.readFileSync(htmlPath, 'utf8');
const css = fs.readFileSync(cssPath, 'utf8');

// HTML structure assertions
assert.ok(html.includes('id="ready-state"'), 'Ready state panel must exist');
assert.ok(html.includes('id="loading-state"'), 'Loading state panel must exist');
assert.ok(html.includes('id="results-state"'), 'Results state panel must exist');
assert.ok(html.includes('id="settings-drawer"'), 'Settings drawer must exist');
assert.ok(html.includes('id="audit-btn"'), 'Audit button must exist in HTML');
assert.ok(html.includes('id="results-container"'), 'Results container must exist');
assert.ok(html.includes('id="settings-toggle"'), 'Settings toggle button must exist');
assert.ok(html.includes('id="page-type-tag"'), 'Page type tag must exist');
assert.ok(html.includes('id="page-title"'), 'Page title heading must exist');
assert.ok(html.includes('id="loader-status"'), 'Loader status text must exist');

// Typography and external font loading
assert.ok(html.includes('Source+Serif+4') || html.includes('Source Serif 4'), 'HTML must load Source Serif 4');
assert.ok(html.includes('Public+Sans') || html.includes('Public Sans'), 'HTML must load Public Sans');
assert.ok(html.includes('JetBrains+Mono') || html.includes('JetBrains Mono'), 'HTML must load JetBrains Mono');

// CSS Token assertions from DESIGN.md
assert.ok(css.includes('--bg: #faf8f3'), 'CSS must include ivory background token (#faf8f3) from DESIGN.md');
assert.ok(css.includes('--raised: #ffffff'), 'CSS must include raised surface token (#ffffff) from DESIGN.md');
assert.ok(css.includes('--ink: #1a1815'), 'CSS must include primary ink token (#1a1815) from DESIGN.md');
assert.ok(css.includes('--rule: #e6e0d2'), 'CSS must include hairline rule token (#e6e0d2) from DESIGN.md');
assert.ok(css.includes('--rule-strong: #d4cdb9'), 'CSS must include stronger divider token (#d4cdb9) from DESIGN.md');

// Canonical Tier Tokens from DESIGN.md
assert.ok(css.includes('#2f7a4a'), 'CSS must use canonical T1 color #2f7a4a');
assert.ok(css.includes('#2864a8'), 'CSS must use canonical T2 color #2864a8');
assert.ok(css.includes('#a87726'), 'CSS must use canonical T3 color #a87726');
assert.ok(css.includes('#b35a1f'), 'CSS must use canonical T4 color #b35a1f');
assert.ok(css.includes('#6b6b6b'), 'CSS must use canonical T5 color #6b6b6b');

// CSS font family variables
assert.ok(css.includes('Source Serif 4'), 'CSS must use Source Serif 4 typography');
assert.ok(css.includes('Public Sans'), 'CSS must use Public Sans typography');
assert.ok(css.includes('JetBrains Mono'), 'CSS must use JetBrains Mono for citations');

// Error Card Styles
assert.ok(css.includes('.error-card'), 'CSS must include .error-card class');
assert.ok(css.includes('.error-actions'), 'CSS must include .error-actions class');

// Course Audit Button & Progress Bar in HTML
assert.ok(html.includes('id="audit-course-btn"'), 'audit-course-btn must exist in index.html');
assert.ok(html.includes('id="crawl-progress-card"'), 'crawl-progress-card must exist in index.html');
assert.ok(html.includes('id="crawl-status-text"'), 'crawl-status-text must exist in index.html');
assert.ok(html.includes('https://aistudio.google.com/app/apikey'), 'Link to free Google AI Studio key must exist in Settings');

// Progress Card & Help Link Styles
assert.ok(css.includes('.progress-card'), 'CSS must include .progress-card class');
assert.ok(css.includes('.progress-bar-container'), 'CSS must include .progress-bar-container class');
assert.ok(css.includes('.progress-bar-fill'), 'CSS must include .progress-bar-fill class');
assert.ok(css.includes('.help-link'), 'CSS must include .help-link class');

// Dossier UI Elements & Styles
assert.ok(html.includes('id="dossier-toggle-btn"'), 'dossier-toggle-btn must exist in header');
assert.ok(html.includes('id="dossier-count"'), 'dossier-count element must exist');
assert.ok(html.includes('id="add-to-dossier-btn"'), 'add-to-dossier-btn must exist');
assert.ok(html.includes('id="export-single-md-btn"'), 'export-single-md-btn must exist');
assert.ok(html.includes('id="dossier-drawer"'), 'dossier-drawer must exist');
assert.ok(html.includes('id="export-dossier-md-btn"'), 'export-dossier-md-btn must exist in dossier drawer');
assert.ok(html.includes('id="copy-dossier-md-btn"'), 'copy-dossier-md-btn must exist in dossier drawer');
assert.ok(html.includes('id="clear-dossier-btn"'), 'clear-dossier-btn must exist in dossier drawer');

assert.ok(css.includes('.dossier-pill'), 'CSS must include .dossier-pill class');
assert.ok(css.includes('.result-actions-bar'), 'CSS must include .result-actions-bar class');
assert.ok(css.includes('.dossier-list'), 'CSS must include .dossier-list class');
assert.ok(css.includes('.dossier-item'), 'CSS must include .dossier-item class');
assert.ok(css.includes('.dossier-delete-btn'), 'CSS must include .dossier-delete-btn class');

console.log('✅ Side panel DOM, progress bar, and CSS token tests passed.');


