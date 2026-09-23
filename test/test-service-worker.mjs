import assert from 'node:assert';
import { installChrome, installFetch, jsonResponse, importFresh, resetGlobals } from './extension-harness.mjs';
import { saveSettings, getAuditHistory } from '../extension/shared/storage.js';

const payload = { url: 'https://canvas.instructure.com/courses/1/assignments/2', title: 'Enzymes Lab', pageType: 'Canvas Assignment', content: 'Read chapter 4 and answer the review questions.' };
const llmReply = (obj) => jsonResponse({ candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] } }] });

// Each scenario loads a fresh service worker against a fresh chrome stub. The
// key goes through saveSettings so the test does not care which storage area holds it.
async function loadWorker({ apiKey, fetchHandler } = {}) {
  const h = installChrome();
  if (apiKey) await saveSettings({ apiKey });
  h.fetchCalls = installFetch(fetchHandler || (async (url) => { throw new Error('unexpected fetch ' + url); }));
  await importFresh('background/service-worker.js');
  assert.strictEqual(h.listeners.message.length, 1, 'worker registers one runtime.onMessage listener');
  return h;
}

// RUN_AUDIT with no API key: demo result, saved to history, no network.
let h = await loadWorker();
let res = await h.dispatch({ action: 'RUN_AUDIT', payload });
assert.ok(res, 'RUN_AUDIT replies (the listener must return true to keep the channel open)');
assert.strictEqual(res.success, true);
assert.ok(res.data.summary && Array.isArray(res.data.findings), 'demo audit has the result shape');
assert.strictEqual(h.fetchCalls.length, 0, 'demo mode makes no network calls');
assert.strictEqual((await getAuditHistory())[0].title, 'Enzymes Lab');

// RUN_AUDIT with a key: one model call, parsed JSON returned.
h = await loadWorker({ apiKey: 'k', fetchHandler: async () => llmReply({ summary: { bloomsLevel: 'Apply' }, findings: [] }) });
res = await h.dispatch({ action: 'RUN_AUDIT', payload });
assert.strictEqual(res.success, true);
assert.strictEqual(res.data.summary.bloomsLevel, 'Apply');
assert.strictEqual(h.fetchCalls.length, 1);
assert.ok(h.fetchCalls[0].url.startsWith('https://generativelanguage.googleapis.com/'));
assert.ok(JSON.parse(h.fetchCalls[0].init.body).contents[0].parts[0].text.includes('Enzymes Lab'), 'prompt carries the page');

// Model API failure surfaces as { success: false }, not a hang.
h = await loadWorker({ apiKey: 'k', fetchHandler: async () => new Response('quota exceeded', { status: 429 }) });
res = await h.dispatch({ action: 'RUN_AUDIT', payload });
assert.strictEqual(res.success, false);
assert.match(res.error, /429/);

// CRAWL_AND_AUDIT_COURSE: crawls the Canvas API, audits, records the course URL.
// The course has syllabus text, so it is not an empty course.
h = await loadWorker({ fetchHandler: async (url) => url.includes('include[]=syllabus_body')
  ? jsonResponse({ name: 'Biology 101', syllabus_body: '<p>Objectives</p>' })
  : jsonResponse([]) });
res = await h.dispatch({ action: 'CRAWL_AND_AUDIT_COURSE', payload: { origin: 'https://canvas.instructure.com', courseId: '12' } });
assert.ok(res, 'CRAWL_AND_AUDIT_COURSE replies (the listener must return true)');
assert.strictEqual(res.success, true);
assert.strictEqual(res.courseData.title, 'Biology 101');
assert.strictEqual((await getAuditHistory())[0].url, 'https://canvas.instructure.com/courses/12');

// Unknown actions get no reply and do not hold the channel open.
assert.strictEqual(await h.dispatch({ action: 'NOT_A_REAL_ACTION' }), undefined);

resetGlobals();
console.log('✅ Service worker routing tests passed.');
