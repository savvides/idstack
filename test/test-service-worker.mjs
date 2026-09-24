import assert from 'node:assert';
import { installChrome, installFetch, jsonResponse, importFresh, resetGlobals } from './extension-harness.mjs';
import { saveSettings, getAuditHistory } from '../extension/shared/storage.js';

// A real but short Canvas prompt (13 words): the worker must still audit it.
const TEXT = 'Post a reflection on chapter four and reply to two peers by Friday.';
const payload = { url: 'https://canvas.instructure.com/courses/1/assignments/2', title: 'Enzymes Lab', pageType: 'Canvas Assignment', content: TEXT };
const llmReply = (obj) => jsonResponse({ candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] } }] });
const VALID = {
  summary: { bloomsLevel: 'Apply', alignmentScore: 'Strong', keyTakeaway: 'k' },
  findings: [{ severity: 'info', tier: 'T1', citation: 'c', observation: 'o', evidence: 'e', recommendation: 'r' }],
  improvedDraft: { title: 't', content: 'c' }
};

// One spy for the whole file: it records every AbortSignal.timeout the worker
// asks for and, when a scenario sets timeouts.fire, returns a signal that has
// already timed out. Node unrefs the real timer, so nothing waits 25 s.
const realTimeout = AbortSignal.timeout;
const timeouts = { requested: [], fire: false };
AbortSignal.timeout = (ms) => {
  timeouts.requested.push(ms);
  return timeouts.fire ? AbortSignal.abort(new DOMException('signal timed out', 'TimeoutError')) : realTimeout.call(AbortSignal, ms);
};

// Each scenario loads a fresh service worker against a fresh chrome stub. The
// key goes through saveSettings so the test does not care which storage area holds it.
async function loadWorker({ apiKey, fetchHandler } = {}) {
  Object.assign(timeouts, { requested: [], fire: false });
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

// A refused audit replies with an error and is never saved to history.
async function assertRejected(res, pattern) {
  assert.strictEqual(res?.success, false, `expected an error, got ${String(JSON.stringify(res)).slice(0, 120)}`);
  assert.match(res.error, pattern);
  assert.deepStrictEqual(await getAuditHistory(), [], 'a refused audit must not be saved to history');
}
const modelCalls = (h) => h.fetchCalls.filter((c) => new URL(c.url).host === 'generativelanguage.googleapis.com');

// F7: a page with no readable text (restricted tab, PDF viewer) or a lone
// Modules item title never reaches the model, with or without a key.
for (const [content, apiKey] of [['', 'k'], ['  \n ', undefined], ['Week 1 Reading', 'k']]) {
  h = await loadWorker({ apiKey, fetchHandler: async () => llmReply(VALID) });
  await assertRejected(await h.dispatch({ action: 'RUN_AUDIT', payload: { ...payload, content } }), /too little readable text/);
  assert.strictEqual(h.fetchCalls.length, 0, `page content ${JSON.stringify(content)} must not be sent to the model`);
}

// F7: the extractor's or panel's reason for not reading a page is what the user sees.
const reason = 'idstack does not read student-record pages such as the Gradebook.';
h = await loadWorker({ apiKey: 'k', fetchHandler: async () => llmReply(VALID) });
res = await h.dispatch({ action: 'RUN_AUDIT', payload: { ...payload, content: '', emptyReason: reason } });
await assertRejected(res, /Gradebook/);
assert.strictEqual(res.error, reason, 'the payload emptyReason is the error shown');
assert.strictEqual(h.fetchCalls.length, 0);

// F7, course path: no syllabus text and no assignments is an audit of nothing.
h = await loadWorker({ apiKey: 'k', fetchHandler: async (url) => url.includes('include[]=syllabus_body')
  ? jsonResponse({ name: 'Sandbox', syllabus_body: '' })
  : url.includes('/assignments') ? jsonResponse([]) : llmReply(VALID) });
res = await h.dispatch({ action: 'CRAWL_AND_AUDIT_COURSE', payload: { origin: 'https://canvas.instructure.com', courseId: '12' } });
await assertRejected(res, /no syllabus text and no assignments/);
assert.strictEqual(modelCalls(h).length, 0, 'an empty course must not be sent to the model');

// F10 transport: the key travels in a header, not the URL, and the model fetch
// is bounded below Chrome's 30 s cutoff for an extension fetch.
h = await loadWorker({ apiKey: 'k', fetchHandler: async () => llmReply(VALID) });
res = await h.dispatch({ action: 'RUN_AUDIT', payload });
assert.strictEqual(res.success, true, JSON.stringify(res));
assert.deepStrictEqual(res.data, VALID);
assert.deepStrictEqual((await getAuditHistory())[0].result, VALID);
assert.strictEqual(h.fetchCalls.length, 1);
const [call] = h.fetchCalls;
assert.ok(call.url.startsWith('https://generativelanguage.googleapis.com/'));
assert.ok(!call.url.includes('key='), `API key must not be in the URL: ${call.url}`);
assert.strictEqual(call.init.headers['x-goog-api-key'], 'k', 'API key travels in the x-goog-api-key header');
assert.strictEqual(timeouts.requested.length, 1, 'model fetch must be bounded by AbortSignal.timeout');
assert.ok(timeouts.requested[0] > 0 && timeouts.requested[0] < 30000, `timeout ${timeouts.requested[0]}ms must beat Chrome's 30 s fetch cutoff`);
assert.ok(call.init.signal instanceof AbortSignal && !call.init.signal.aborted, 'the timeout signal must reach fetch');

// F10: a timed-out model call is explained, not saved. Chrome before 124
// rejects it with AbortError, so the worker must check the signal, not the name.
h = await loadWorker({ apiKey: 'k', fetchHandler: async () => { throw new DOMException('The user aborted a request.', 'AbortError'); } });
timeouts.fire = true;
await assertRejected(await h.dispatch({ action: 'RUN_AUDIT', payload }), /did not respond within 25 seconds/);
// Control: any other network error passes through unchanged.
h = await loadWorker({ apiKey: 'k', fetchHandler: async () => { throw new TypeError('Failed to fetch'); } });
await assertRejected(await h.dispatch({ action: 'RUN_AUDIT', payload }), /^Failed to fetch$/);

// F9: model output the renderer or dossier compiler cannot handle is refused before it is saved.
for (const bad of [{ findings: { 0: {} } }, { findings: [null] }, { findings: [{ tier: 1 }] }, { findings: [{ severity: 2 }] }, 'not an object']) {
  h = await loadWorker({ apiKey: 'k', fetchHandler: async () => llmReply(bad) });
  await assertRejected(await h.dispatch({ action: 'RUN_AUDIT', payload }), /audit format/);
}

resetGlobals();
console.log('✅ Service worker routing tests passed.');
