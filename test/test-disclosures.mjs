// What the side panel, PRIVACY.md and README.md say about the extension must
// match the shipped code. v3.5.0.0's panel promised no student data was "ever
// collected, retained, or used for model training", PRIVACY.md put the API key
// in chrome.storage.local and called the design FERPA-compliant, the settings
// called canned demo output a "free demo tier", and README said the course
// crawler reads modules, discussions and quizzes. Each fact below is taken from
// the shipped modules (storage areas, demo output, crawler requests, extractor
// refusals), never restated here.
import assert from 'node:assert';
import { readFileSync } from 'node:fs';
import { installChrome, loadContentScript, resetGlobals } from './extension-harness.mjs';
import { saveSettings, saveAuditResult, addToDossier } from '../extension/shared/storage.js';
import { getDemoAuditResult, getDemoCourseAuditResult } from '../extension/background/parser-helper.js';
import { crawlCanvasCourse } from '../extension/background/canvas-crawler.js';

const read = (rel) => readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8');
const html = read('extension/sidepanel/index.html');
const privacy = read('PRIVACY.md');
const readme = read('README.md');
const manifest = JSON.parse(read('extension/manifest.json'));
const DOCS = [['index.html', html], ['PRIVACY.md', privacy], ['README.md', readme]];

// Collect every disagreement so one run names them all.
const problems = new Set();
const check = (ok, msg) => { if (!ok) problems.add(msg); };

// 1. Storage: record which chrome.storage area each key really lands in, and
//    how many audits the history keeps.
const h = installChrome();
await saveSettings({ apiKey: 'k' });
for (let i = 0; i < 25; i++) await saveAuditResult({ url: `u${i}`, result: {} });
await addToDossier({ url: 'u', result: {} });
resetGlobals();
const areaOf = (key) => Object.keys(h.storage).find((a) => key in h.storage[a]);
for (const [key, label] of [['apiKey', /API key/i], ['auditHistory', /audit history/i], ['activeDossier', /dossier/i]]) {
  const lines = privacy.split('\n').filter((l) => label.test(l) && l.includes('chrome.storage.'));
  check(lines.length, `PRIVACY.md must say where ${key} is stored (code: chrome.storage.${areaOf(key)})`);
  for (const l of lines) check(l.includes(`chrome.storage.${areaOf(key)}`), `PRIVACY.md misstates where ${key} is stored (code: chrome.storage.${areaOf(key)}): ${l}`);
}
const kept = h.storage[areaOf('auditHistory')].auditHistory.length;
check(privacy.includes(`last ${kept} audit results`), `PRIVACY.md must disclose that the last ${kept} audit results are kept`);

// 2. Demo mode ignores the page. The docs must say so, and stop saying so if that changes.
const same = (f, a, b) => JSON.stringify(f(a)) === JSON.stringify(f(b));
const canned = same(getDemoAuditResult, { title: 'T', pageType: 'P', content: 'alpha' }, { title: 'T', pageType: 'P', content: 'omega' })
  && same(getDemoCourseAuditResult, { title: 'C', syllabus: 'a', assignments: [] }, { title: 'C', syllabus: 'b', assignments: [{ title: 'x' }] });
for (const [name, text] of DOCS) {
  check(text.includes('same sample findings') === canned, `${name}: demo-mode description disagrees with parser-helper.js (canned output: ${canned})`);
}

// 3. While the extension can reach Google's API, disclose what Google's free tier may do with submitted text.
const hosts = [...(manifest.host_permissions || []), ...(manifest.optional_host_permissions || [])];
if (hosts.some((host) => host.includes('generativelanguage.googleapis.com'))) {
  for (const [name, text] of [['index.html', html], ['PRIVACY.md', privacy]]) {
    check(text.includes('improve its products'), `${name} must disclose that Google's free tier may use submitted content to improve its products`);
  }
  check(/ai\.google\.dev\/\S*terms/.test(privacy), "PRIVACY.md must link to Google's terms for the API");
}

// 4. No absolute student-data promises and no compliance claims.
for (const [name, text] of DOCS) {
  check(!/\b(?:no|never|zero)\b[^.]*\b(?:PII|personally identifiable)/i.test(text), `${name} makes an absolute no-PII promise`);
  check(!/FERPA[- ]compli/i.test(text), `${name} claims FERPA compliance`);
}

// 5. README's crawler bullet may name only Canvas resources the shipped crawler requests.
const requested = [];
await crawlCanvasCourse('https://school.instructure.com', '1', async (url) => {
  requested.push(url);
  return { ok: true, status: 200, headers: { get: () => null }, json: async () => (/\/courses\/1(\?|$)/.test(url) ? {} : []) };
});
const bullet = readme.split('\n').find((l) => l.includes('Zero Developer Tokens Required'));
check(bullet, "README.md's course-crawler bullet (Zero Developer Tokens Required) is missing");
for (const [word, endpoint] of [[/\bsyllab/i, 'syllabus_body'], [/\bassignment/i, '/assignments'], [/\bmodule/i, '/modules'], [/\bdiscussion/i, '/discussion_topics'], [/\bquiz/i, '/quizzes']]) {
  if (bullet && word.test(bullet)) check(requested.some((u) => u.includes(endpoint)), `README.md's crawler bullet claims content the crawler never requests (${endpoint})`);
}

// 6. Each student-record page the docs say is not read must be refused: neither
//    its text nor its title may come back, even when every content selector
//    matches and on a custom Canvas domain, so the guard (not a missing
//    selector) is what holds.
const { extractContentFromDOM } = loadContentScript('content/extractor.js');
const secret = 'Jane Student 92%';
const el = { innerText: secret, textContent: secret };
const doc = { title: secret, querySelector: () => el, querySelectorAll: () => [el], body: el };
const note = (html.match(/<div class="privacy-note">([\s\S]*?)<\/div>/) || [])[1];
check(note, 'index.html has no privacy note');
const at = privacy.indexOf('## idstack Chrome Extension');
check(at >= 0, 'PRIVACY.md has no "## idstack Chrome Extension" section');
const policy = at >= 0 ? privacy.slice(at) : '';
for (const [word, url] of [
  [/Gradebook/, 'https://canvas.example.edu/courses/1/gradebook'],
  [/SpeedGrader/, 'https://canvas.example.edu/courses/1/gradebook/speed_grader?assignment_id=1'],
  [/\bgrades\b/, 'https://canvas.example.edu/courses/1/grades/7'],
  [/People/, 'https://canvas.example.edu/courses/1/users'],
  [/People/, 'https://canvas.example.edu/courses/1/users/42'],
  [/\bgroups\b/, 'https://canvas.example.edu/courses/1/groups'],
  [/\bsubmissions\b/, 'https://canvas.example.edu/courses/1/assignments/5/submissions/7'],
  [/Inbox/, 'https://canvas.example.edu/conversations'],
  [/\bdiscussion/i, 'https://canvas.example.edu/courses/1/discussion_topics/1'],
]) {
  for (const [name, text] of [['side-panel privacy note', note || ''], ['PRIVACY.md', policy]]) {
    if (!word.test(text)) continue;
    const r = extractContentFromDOM(doc, url);
    check(!JSON.stringify([r.title, r.content]).includes(secret), `${name} says ${word.source} pages are not read, but the extractor returned page text or title for ${url}`);
  }
}

assert.ok(problems.size === 0, `Extension disclosures disagree with the shipped code:\n  ${[...problems].join('\n  ')}`);
console.log('✅ Extension privacy and capability disclosures match the shipped code.');
