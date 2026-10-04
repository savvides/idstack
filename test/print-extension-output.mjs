// Print the fixed text that the shipped extension shows, so that smoke-test can
// send it through bin/idstack-ste-check. Usage: node test/print-extension-output.mjs markdown|html
// The name does not start with "test-", so test/test-extension.sh does not run it as a test.
import { getDemoAuditResult, getDemoCourseAuditResult } from '../extension/background/parser-helper.js';
import { autoCorrectNeuromyth } from '../extension/shared/consensus-client.js';
import { compileSingleAuditToMarkdown, compileDossierToMarkdown } from '../extension/shared/dossier-compiler.js';
import { renderAuditHTML, renderDossierListHTML } from '../extension/sidepanel/renderer-helper.js';
import { crawlCanvasCourse } from '../extension/background/canvas-crawler.js';
import { saveSettings } from '../extension/shared/storage.js';
import fs from 'node:fs';
import { installChrome, installDocument, installFetch, jsonResponse, importFresh, loadContentScript, createDocument, flush, resetGlobals } from './extension-harness.mjs';

const MYTHS = ['learning_styles', 'hemisphere_learning', 'ten_percent_brain', 'dales_cone_percentages'];

const page = getDemoAuditResult({ title: 'Lab 1', pageType: 'Canvas Assignment' });
const course = getDemoCourseAuditResult({ title: 'Biology 101' });
const corrected = {
  summary: { bloomsLevel: 'Apply (Level 3)', alignmentScore: 'Moderate (70%)', keyTakeaway: 'The page has a neuromyth.' },
  findings: MYTHS.map((type) => autoCorrectNeuromyth({
    severity: 'warning', tier: 'T1', citation: '[Learner-1] Learning styles',
    observation: 'The page has a neuromyth.', evidence: '', recommendation: '',
  }, type)),
};
// A partial model reply: every fallback label shows.
const sparse = { summary: {}, findings: [{}] };
const items = [page, course, corrected].map((result, i) => ({
  id: `item-${i}`, title: `Item ${i + 1}`, pageType: 'Canvas Assignment',
  url: 'https://canvas.example.edu/courses/1', timestamp: '2026-01-01T00:00:00Z', result,
})).concat([{ id: 'item-sparse', timestamp: '2026-01-01T00:00:00Z', result: sparse }]);

// The error messages that the side panel shows in its error card.
async function errorMessages() {
  const out = [];
  const reject = async (promise) => { try { await promise; } catch (e) { out.push(e.message); } };
  const canvas = (course, assignments) => async (url) => {
    const body = url.includes('/assignments') ? assignments : course;
    return typeof body === 'number' ? { ok: false, status: body } : { ok: true, status: 200, headers: { get: () => null }, json: async () => body };
  };
  await reject(crawlCanvasCourse(null, '1'));
  await reject(crawlCanvasCourse('https://canvas.test', '1', canvas(404, [])));
  await reject(crawlCanvasCourse('https://canvas.test', '1', canvas({}, 403)));
  // Every page links to a next page, so the crawl reaches its page cap.
  await reject(crawlCanvasCourse('https://canvas.test', '1', async (url) => ({ ok: true, status: 200, headers: { get: () => `<${url}&n>; rel="next"` }, json: async () => [{}] })));

  const { extractContentFromDOM, extractPageContent } = loadContentScript('content/extractor.js');
  out.push(extractContentFromDOM(createDocument('<html></html>'), 'https://canvas.test/courses/1/gradebook').emptyReason);
  globalThis.window = { location: { href: 'https://docs.google.com/document/d/abc/edit' } };
  globalThis.document = createDocument('<html></html>');
  installFetch(async () => ({ ok: false, status: 403, headers: { get: () => '' } }));
  out.push((await extractPageContent()).emptyReason);

  const h = installChrome();
  await importFresh('background/service-worker.js');
  const payload = { title: 'T', content: 'one two three four five six seven eight nine ten eleven' };
  out.push((await h.dispatch({ action: 'RUN_AUDIT', payload: { ...payload, content: '' } })).error);
  out.push((await h.dispatch({ action: 'CRAWL_AND_AUDIT_COURSE', payload: { origin: 'http://x', courseId: '1' } })).error);
  installFetch(async (url) => jsonResponse(url.includes('/assignments') ? [] : { name: 'C', syllabus_body: '' }));
  out.push((await h.dispatch({ action: 'CRAWL_AND_AUDIT_COURSE', payload: { origin: 'https://canvas.test', courseId: '1' } })).error);
  await saveSettings({ apiKey: 'k' });
  installFetch(async () => jsonResponse({ candidates: [{ content: { parts: [{ text: '{"findings": null}' }] } }] }));
  out.push((await h.dispatch({ action: 'RUN_AUDIT', payload })).error);
  // A model call that times out.
  const timeout = AbortSignal.timeout;
  AbortSignal.timeout = () => AbortSignal.abort();
  installFetch(async () => { throw new DOMException('aborted', 'AbortError'); });
  out.push((await h.dispatch({ action: 'RUN_AUDIT', payload })).error);
  AbortSignal.timeout = timeout;
  // A model call that fails (the body is a neutral fixture, not a real reply) and one that sends no text.
  installFetch(async () => ({ ok: false, status: 429, text: async () => '{}' }));
  out.push((await h.dispatch({ action: 'RUN_AUDIT', payload })).error);
  installFetch(async () => jsonResponse({ candidates: [] }));
  out.push((await h.dispatch({ action: 'RUN_AUDIT', payload })).error);
  resetGlobals();
  // A path that stops giving its message must fail here, not print "undefined".
  if (out.length !== 13 || !out.every(Boolean)) throw new Error(`expected 13 error messages, got ${JSON.stringify(out)}`);
  return out;
}

// The side panel on a tab that it cannot read: the page title, the loading text
// and the error card that shows the reason.
async function sidePanelText() {
  const document = installDocument();
  let reply;
  const h = installChrome({ tabs: [{ id: 1, active: true }], onRuntimeMessage: () => new Promise((resolve) => { reply = resolve; }) });
  await importFresh('sidepanel/sidepanel.js');
  await flush();
  document.getElementById('audit-btn').click();
  await flush();
  const out = [`<h2>${document.getElementById('page-title').textContent}</h2>`, `<p>${document.getElementById('loader-status').textContent}</p>`];
  reply({ success: false, error: h.sent[0].payload.emptyReason });
  await flush();
  const card = document.querySelectorAll('.error-card h4, .error-card p, .error-card button');
  if (card.length !== 4) throw new Error(`expected the error card heading, message and 2 buttons, got ${card.length} elements`);
  for (const el of card) {
    out.push(`<${el.tagName.toLowerCase()}>${el.textContent}</${el.tagName.toLowerCase()}>`);
  }
  resetGlobals();
  return out;
}

const mode = process.argv[2];
if (mode === 'markdown') {
  // The export puts idstack's own header lines and notes in '>' blocks. The checker skips those as quotations.
  // Remove the marker and start a new paragraph, so that the checker reads each line.
  const unquote = (md) => md.replace(/^> ?/gm, '\n');
  console.log(unquote(items.map(compileSingleAuditToMarkdown).join('\n\n')));
  console.log(unquote(compileDossierToMarkdown(items, 'Biology 101')));
  console.log(unquote(compileDossierToMarkdown([], 'Biology 101')));
} else if (mode === 'html') {
  console.log([page, course, corrected, sparse].map(renderAuditHTML).join('\n'));
  console.log(renderDossierListHTML(items));
  console.log(renderDossierListHTML([]));
  for (const message of await errorMessages()) console.log(`<p class="error-msg">${message}</p>`);
  console.log((await sidePanelText()).join('\n'));
  // The fixed strings that the side panel and service worker show only on paths
  // that the code above does not run: button labels, loader steps and fallbacks.
  const LITERAL = /(?:textContent = |innerHTML = |renderError\(|new Error\(|\|\| )(['"`])((?:(?!\1)[^\\]|\\.)+)\1/g;
  for (const f of ['../extension/sidepanel/sidepanel.js', '../extension/background/service-worker.js']) {
    const src = fs.readFileSync(new URL(f, import.meta.url), 'utf8');
    for (const m of src.matchAll(LITERAL)) console.log(`<p>${m[2].replace(/\\(.)/g, '$1')}</p>`);
  }
} else {
  console.error('usage: node test/print-extension-output.mjs markdown|html');
  process.exit(2);
}
