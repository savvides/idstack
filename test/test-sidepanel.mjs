import assert from 'node:assert';
import { installChrome, installDocument, importFresh, flush, resetGlobals } from './extension-harness.mjs';
import { saveSettings } from '../extension/shared/storage.js';

const COURSE_ROOT = 'https://canvas.instructure.com/courses/42';
const ASSIGNMENT = 'https://canvas.instructure.com/courses/42/assignments/7';
const CUSTOM_ROOT = 'https://canvas.asu.edu/courses/42';

// Loads a fresh side panel against the shipped index.html and a stubbed chrome
// whose active tab is `url` and whose extractor injection returns a payload.
async function openPanel(url, { apiKey, ...chromeOpts } = {}) {
  const document = installDocument();
  const h = installChrome({
    tabs: [{ id: 7, url, title: 'Tab title', active: true }],
    onExecuteScript: async () => [{ frameId: 0, result: { url, title: 'Extracted title', pageType: 'Canvas Assignment', content: 'Some content' } }],
    ...chromeOpts
  });
  if (apiKey) await saveSettings({ apiKey });
  await importFresh('sidepanel/sidepanel.js');
  await flush();
  return { h, document, $: (id) => document.getElementById(id) };
}

// Course root: course-audit button shown, tag says so. There is no declarative
// content script: the panel injects the shipped extractor and reads the
// script's completion value.
let p = await openPanel(COURSE_ROOT);
assert.deepStrictEqual(p.h.calls.executed, [{ target: { tabId: 7 }, files: ['content/extractor.js'] }], 'the panel injects the shipped extractor into the active tab');
assert.strictEqual(p.$('audit-course-btn').style.display, 'block', 'course audit offered on a course root');
assert.strictEqual(p.$('page-type-tag').textContent, 'Canvas Course Root');
assert.strictEqual(p.$('page-title').textContent, 'Extracted title', 'page title comes from the injection result');

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

// F4: the course crawl needs host access to the Canvas site. permissions.request
// needs the click's user gesture, so it must run before the handler's first
// await: it has already been called when click() returns.
p = await openPanel(CUSTOM_ROOT);
p.$('audit-course-btn').click();
assert.deepStrictEqual(p.h.calls.permissionRequests, [{ origins: ['https://canvas.asu.edu/*'] }], 'site permission is requested synchronously inside the click');
await flush();
const crawl = p.h.sent.find((m) => m.action === 'CRAWL_AND_AUDIT_COURSE');
assert.ok(crawl, 'with the site permission granted, the course crawl is sent');
assert.deepStrictEqual(crawl.payload, { origin: 'https://canvas.asu.edu', courseId: '42' });

// Permission denied: no crawl, and the error card says why.
p = await openPanel(CUSTOM_ROOT, { onPermissionRequest: () => false });
p.$('audit-course-btn').click();
await flush();
assert.ok(!p.h.sent.some((m) => m.action === 'CRAWL_AND_AUDIT_COURSE'), 'no course crawl without the site permission');
assert.ok(p.document.querySelector('.error-msg').textContent.includes('https://canvas.asu.edu'), 'the error names the site idstack needs');

// The worker announces an icon click (activeTab now covers the tab): re-read it.
const injectionsBefore = p.h.calls.executed.length;
await p.h.dispatch({ action: 'TAB_ACCESS_GRANTED' });
await flush();
assert.strictEqual(p.h.calls.executed.length, injectionsBefore + 1, 'TAB_ACCESS_GRANTED re-reads the tab');

// A tab switched to without an icon click: Chrome hides its url and title and
// the injection fails. The header says how to grant access, and an audit sends
// the reason along so the worker shows it instead of auditing an empty page.
p = await openPanel(undefined, { tabs: [{ id: 12, active: true }], onExecuteScript: undefined });
assert.match(p.$('page-title').textContent, /idstack toolbar icon/, 'an unreadable tab tells the user how to grant access');
p.$('audit-btn').click();
await flush();
const unreadable = p.h.sent.find((m) => m.action === 'RUN_AUDIT');
assert.ok(unreadable, 'the audit request is still sent, so the worker can explain the refusal');
assert.strictEqual(unreadable.payload.content, '');
assert.match(unreadable.payload.emptyReason || '', /toolbar icon/, 'an unreadable tab is sent with the reason it could not be read');

resetGlobals();
console.log('✅ Side panel state tests passed.');
