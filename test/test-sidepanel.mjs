import assert from 'node:assert';
import { installChrome, installDocument, importFresh, flush, resetGlobals } from './extension-harness.mjs';
import { saveSettings } from '../extension/shared/storage.js';

const COURSE_ROOT = 'https://canvas.instructure.com/courses/42';
const ASSIGNMENT = 'https://canvas.instructure.com/courses/42/assignments/7';

// Loads a fresh side panel against the shipped index.html and a stubbed chrome
// whose active tab is `url` and whose content script answers EXTRACT_CONTENT.
async function openPanel(url, { apiKey, ...chromeOpts } = {}) {
  const document = installDocument();
  const h = installChrome({
    tabs: [{ id: 7, url, title: 'Tab title', active: true }],
    onTabMessage: async () => ({ url, title: 'Extracted title', pageType: 'Canvas Assignment', content: 'Some content' }),
    ...chromeOpts
  });
  if (apiKey) await saveSettings({ apiKey });
  await importFresh('sidepanel/sidepanel.js');
  await flush();
  return { h, document, $: (id) => document.getElementById(id) };
}

// Course root: course-audit button shown, tag says so.
let p = await openPanel(COURSE_ROOT);
assert.strictEqual(p.$('audit-course-btn').style.display, 'block', 'course audit offered on a course root');
assert.strictEqual(p.$('page-type-tag').textContent, 'Canvas Course Root');
assert.strictEqual(p.$('page-title').textContent, 'Extracted title');

// Assignment page: no course-audit button; single-page audit sends the extracted payload.
p = await openPanel(ASSIGNMENT, {
  apiKey: 'saved-key',
  local: { activeDossier: [{ id: 'x', title: 'Saved', result: {} }] },
  onRuntimeMessage: () => ({ success: true, data: { summary: { bloomsLevel: 'Analyze' }, findings: [] } })
});
assert.strictEqual(p.$('audit-course-btn').style.display, 'none');
assert.strictEqual(p.$('page-type-tag').textContent, 'Canvas Assignment');
assert.strictEqual(p.$('api-key-input').value, 'saved-key', 'saved key is preloaded');
assert.strictEqual(p.$('dossier-count').textContent, '1', 'badge shows dossier size');
p.$('audit-btn').click();
await flush();
assert.strictEqual(p.h.sent.length, 1);
assert.strictEqual(p.h.sent[0].action, 'RUN_AUDIT');
assert.strictEqual(p.h.sent[0].payload.title, 'Extracted title');
assert.ok(p.$('results-state').classList.contains('active'), 'results panel shown');
assert.ok(p.$('results-container').textContent.includes('Analyze'));

// Worker error: rendered escaped in the error card (checked by structure, not entity text).
p = await openPanel(ASSIGNMENT, { onRuntimeMessage: () => ({ success: false, error: '<b>quota</b>' }) });
p.$('audit-btn').click();
await flush();
const errorMsg = p.document.querySelector('.error-msg');
assert.ok(errorMsg.textContent.includes('quota'));
assert.strictEqual(errorMsg.querySelector('b'), null, 'worker error text is escaped, not parsed as HTML');

resetGlobals();
console.log('✅ Side panel state tests passed.');
