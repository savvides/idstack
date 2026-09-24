import assert from 'node:assert';
import { installChrome, installDocument, importFresh, flush, resetGlobals, clickErrors } from './extension-harness.mjs';

// Side panel state across tab switches, errors and clipboard failures (review
// F8, F14 and the panel side of F9). Each scenario loads the SHIPPED
// sidepanel.js against the shipped index.html and a stubbed chrome whose
// worker replies arrive only when the scenario sends them.

const RESULT = {
  summary: { bloomsLevel: 'Apply', alignmentScore: 'Strong', keyTakeaway: 'k' },
  findings: [{ severity: 'info', tier: 'T5', citation: '[Alignment-1]', observation: 'o', evidence: 'e', recommendation: 'r' }],
  improvedDraft: { title: 'Draft', content: 'draft body' }
};
const page = (title, url, pageType = 'Canvas Assignment') => ({ url, title, pageType, content: `body of ${title}` });
const A = page('Assignment A', 'https://x.instructure.com/courses/1/assignments/10');
const B = page('Assignment B', 'https://x.instructure.com/courses/1/assignments/20');
const C = page('Assignment C', 'https://x.instructure.com/courses/1/assignments/30');
const rejectingClipboard = { writeText: () => Promise.reject(new Error('Document is not focused.')) };

// payloads: tabId -> the extractor's result for that tab, or a function
// returning a promise for it (so the scenario decides when that injection settles).
async function loadPanel({ tab, payloads, clipboard = { writeText: async () => {} } }) {
  let currentTab = tab;
  const pending = []; // sendResponse of each message the worker has not answered yet
  const document = installDocument();
  const h = installChrome({
    tabs: () => [currentTab],
    onExecuteScript: async ({ target }) => {
      const p = payloads[target.tabId];
      return [{ frameId: 0, result: await (typeof p === 'function' ? p() : p) }];
    },
    onRuntimeMessage: () => new Promise((resolve) => pending.push(resolve))
  });
  // Node 21+ defines globalThis.navigator as a getter; assigning to it throws in a module.
  Object.defineProperty(globalThis, 'navigator', { value: { clipboard }, configurable: true, writable: true });
  await importFresh('sidepanel/sidepanel.js');
  await flush();
  return {
    h,
    document,
    $: (id) => document.getElementById(id),
    lastMessage: () => h.sent[h.sent.length - 1],
    // The worker answers the most recent message.
    reply: async (response) => { pending.pop()(response); await flush(); },
    switchTab: async (next) => {
      currentTab = next;
      h.listeners.tabActivated.forEach((fn) => fn({ tabId: next.id }));
      await flush();
    }
  };
}

const scenarios = {
  async 'result is labelled with the page that was sent (F8)'() {
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A, 2: B } });
    await p.$('audit-btn').click();
    await p.switchTab({ id: 2, url: B.url });
    await p.reply({ success: true, data: RESULT });
    await p.$('add-to-dossier-btn').click();
    const [item] = p.h.storage.local.activeDossier;
    assert.strictEqual(item.title, A.title);
    assert.strictEqual(item.url, A.url);
  },

  async 'course audit is labelled from response.courseData (F8)'() {
    const url = 'https://x.instructure.com/courses/123/modules';
    const p = await loadPanel({ tab: { id: 1, url }, payloads: { 1: page('Course Modules', url, 'Canvas Modules') } });
    await p.$('audit-course-btn').click();
    await flush();
    await p.reply({ success: true, data: RESULT, courseData: { title: 'BIO 101: Cell Biology' } });
    await p.$('add-to-dossier-btn').click();
    const [item] = p.h.storage.local.activeDossier;
    assert.deepStrictEqual([item.title, item.pageType, item.url],
      ['BIO 101: Cell Biology', 'Canvas Course (Full Audit)', 'https://x.instructure.com/courses/123']);
  },

  async 'a slow extraction reply for an old tab is dropped (F8)'() {
    let releaseB;
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A, 2: () => new Promise((r) => { releaseB = () => r(B); }), 3: C } });
    await p.switchTab({ id: 2, url: B.url });
    await p.switchTab({ id: 3, url: C.url });
    releaseB();
    await flush();
    assert.strictEqual(p.$('page-title').textContent, C.title);
    await p.$('audit-btn').click();
    assert.strictEqual(p.lastMessage().payload.title, C.title);
  },

  async 'a slow extraction failure for an old tab does not write its fallback (F8)'() {
    let failB;
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A, 2: () => new Promise((_, j) => { failB = () => j(new Error('Cannot access contents of the page.')); }), 3: C } });
    await p.switchTab({ id: 2, url: B.url, title: 'Tab B' });
    await p.switchTab({ id: 3, url: C.url });
    failB();
    await flush();
    assert.strictEqual(p.$('page-title').textContent, C.title);
  },

  async 'an error clears the previous result and hides the action bar until the next success (F14)'() {
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A } });
    await p.$('audit-btn').click();
    await p.reply({ success: true, data: RESULT });
    await p.$('re-audit-btn').click();
    await flush();
    await p.$('audit-btn').click();
    await p.reply({ success: false, error: 'AI API error (500)' });
    const bar = p.document.querySelector('.result-actions-bar');
    assert.strictEqual(bar.style.display, 'none');
    await p.$('add-to-dossier-btn').click();
    assert.strictEqual((p.h.storage.local.activeDossier || []).length, 0, 'Add to Dossier must not save the previous result');
    await p.$('error-retry-btn').click();
    await flush();
    await p.reply({ success: true, data: RESULT });
    assert.notStrictEqual(bar.style.display, 'none', 'action bar returns on the next success');
  },

  async 'Retry repeats the action that failed (F14)'() {
    const url = 'https://x.instructure.com/courses/123';
    const p = await loadPanel({ tab: { id: 1, url }, payloads: { 1: page('Home', url, 'Canvas LMS Page') } });
    await p.$('audit-course-btn').click();
    await flush();
    await p.reply({ success: false, error: 'Failed to fetch Canvas course info (401)' });
    await p.$('error-retry-btn').click();
    await flush();
    assert.strictEqual(p.h.sent.filter((m) => m.action === 'CRAWL_AND_AUDIT_COURSE').length, 2, 'Retry sends the course crawl again');
    assert.strictEqual(p.lastMessage().action, 'CRAWL_AND_AUDIT_COURSE');
  },

  async 'Retry after a switch to a non-course tab does not click the hidden course button (F14)'() {
    const url = 'https://x.instructure.com/courses/123';
    const blog = 'https://example.com/blog';
    const p = await loadPanel({ tab: { id: 1, url }, payloads: { 1: page('Home', url, 'Canvas LMS Page'), 2: page('Blog', blog, 'Web Page') } });
    await p.$('audit-course-btn').click();
    await flush();
    await p.reply({ success: false, error: 'Failed to fetch Canvas course info (401)' });
    await p.switchTab({ id: 2, url: blog });
    await p.$('error-retry-btn').click();
    await flush();
    assert.deepStrictEqual(p.h.calls.permissionRequests, [{ origins: ['https://x.instructure.com/*'] }],
      'Retry must not ask for access to the site now active');
    assert.strictEqual(p.h.sent.filter((m) => m.action === 'CRAWL_AND_AUDIT_COURSE').length, 1);
  },

  async 'a feedback vote keeps the Audit Another Page button (F14)'() {
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A } });
    await p.$('audit-btn').click();
    await p.reply({ success: true, data: RESULT });
    await p.document.querySelector('.feedback-btn').click();
    assert.ok(p.$('re-audit-btn'), '#re-audit-btn must survive a vote');
    assert.strictEqual(p.document.querySelectorAll('.feedback-btn').length, 0);
    assert.ok(p.document.querySelector('.feedback-row').textContent.includes('Thank you for your feedback!'));
  },

  async 'Copy to Clipboard reports a rejected write (F14)'() {
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A }, clipboard: rejectingClipboard });
    await p.$('audit-btn').click();
    await p.reply({ success: true, data: RESULT });
    const btn = p.$('copy-improved-btn');
    await btn.click();
    await flush();
    assert.strictEqual(btn.textContent, 'Copy failed');
  },

  async 'Copy Markdown reports a rejected write without rejecting the handler (F14)'() {
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A }, clipboard: rejectingClipboard });
    const before = clickErrors.length;
    const btn = p.$('copy-dossier-md-btn');
    await btn.click();
    await flush();
    assert.strictEqual(clickErrors.length, before, 'click handler must not reject');
    assert.strictEqual(btn.textContent, 'Copy failed');
  },

  async 'malformed findings still reach the results state (F9)'() {
    const p = await loadPanel({ tab: { id: 1, url: A.url }, payloads: { 1: A } });
    await p.$('audit-btn').click();
    await p.reply({ success: true, data: { summary: {}, findings: { 0: { tier: 1 } } } });
    assert.ok(p.$('results-state').classList.contains('active'));
  }
};

let failed = 0;
for (const [name, run] of Object.entries(scenarios)) {
  try {
    await run();
  } catch (err) {
    failed++;
    console.error(`not ok - ${name}\n  ${err.message.split('\n').join('\n  ')}`);
  }
}
assert.strictEqual(failed, 0, `${failed} side panel state scenario(s) failed`);
assert.deepStrictEqual(clickErrors, [], 'a click handler threw or rejected');
resetGlobals();
console.log('✅ Side panel labelling, stale refresh, error, retry, vote and clipboard tests passed.');
process.exit(0); // pending 2 s button-label timers would otherwise hold the process open
