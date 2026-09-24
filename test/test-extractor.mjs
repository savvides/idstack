import assert from 'node:assert';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { createDocument, installChrome, installFetch, loadContentScript, resetGlobals } from './extension-harness.mjs';

// The shipped content script: a classic script, loaded exactly as Chrome gets it.
const { detectPageType, extractContentFromDOM, extractPageContent } = loadContentScript('content/extractor.js');
const page = (html, url) => ({ url, document: createDocument(html) });

// Test 1: Canvas Assignment fixture
const canvasAssignmentHTML = `
  <html>
    <head><title>Module 3: Enzymes Assignment</title></head>
    <body>
      <div id="assignment_show">
        <h1 class="title">Enzymes Lab Analysis</h1>
        <div class="description user_content">
          <p>Read chapter 4 and answer the 5 review questions.</p>
        </div>
      </div>
    </body>
  </html>
`;
const domAssignment = page(canvasAssignmentHTML, 'https://canvas.instructure.com/courses/101/assignments/202');
const extractedAssignment = extractContentFromDOM(domAssignment.document, domAssignment.url);

assert.strictEqual(extractedAssignment.pageType, 'Canvas Assignment');
assert.strictEqual(extractedAssignment.title, 'Enzymes Lab Analysis');
assert.ok(extractedAssignment.content.includes('Read chapter 4'));
assert.strictEqual(extractedAssignment.wordCount, 9);

// Test 2: Canvas Syllabus fixture
const canvasSyllabusHTML = `
  <html>
    <head><title>Course Syllabus - CS 101</title></head>
    <body>
      <h1 class="page-title">CS 101 Syllabus</h1>
      <div id="syllabusContainer">
        <p>This course covers algorithms and data structures.</p>
      </div>
    </body>
  </html>
`;
const domSyllabus = page(canvasSyllabusHTML, 'https://canvas.instructure.com/courses/101/assignments/syllabus');
const extractedSyllabus = extractContentFromDOM(domSyllabus.document, domSyllabus.url);

assert.strictEqual(extractedSyllabus.pageType, 'Canvas Syllabus');
assert.strictEqual(extractedSyllabus.title, 'CS 101 Syllabus');
assert.ok(extractedSyllabus.content.includes('algorithms and data structures'));

// Test 3: Canvas Modules fixture
const canvasModulesHTML = `
  <html>
    <head><title>Course Modules - BIO 200</title></head>
    <body>
      <h1 class="page-title">BIO 200 Modules</h1>
      <div id="modules">
        <span class="module-item-title">Week 1: Cellular Respiration</span>
        <span class="module-item-title">Lab 1: Measuring Oxygen Uptake</span>
      </div>
    </body>
  </html>
`;
const domModules = page(canvasModulesHTML, 'https://canvas.instructure.com/courses/101/modules');
const extractedModules = extractContentFromDOM(domModules.document, domModules.url);

assert.strictEqual(extractedModules.pageType, 'Canvas Modules');
assert.strictEqual(extractedModules.title, 'BIO 200 Modules');
assert.ok(extractedModules.content.includes('Week 1: Cellular Respiration'));
assert.ok(extractedModules.content.includes('Lab 1: Measuring Oxygen Uptake'), 'Modules must read every item title, not just the first');

// A course home in Modules view: no /modules in the URL, and Canvas's container is #context_modules.
const domCourseHome = page(`<html><head><title>BIO 200</title></head><body><div id="context_modules"><span class="module-item-title">Week 1: Cellular Respiration</span><span class="module-item-title">Lab 1: Measuring Oxygen Uptake</span></div></body></html>`, 'https://canvas.instructure.com/courses/101');
const extractedCourseHome = extractContentFromDOM(domCourseHome.document, domCourseHome.url);
assert.strictEqual(extractedCourseHome.pageType, 'Canvas Modules', 'course home in Modules view is a Modules page');
assert.ok(extractedCourseHome.content.includes('Lab 1: Measuring Oxygen Uptake'), 'course home Modules view reads every item title');

// Test 4: Canvas Rubrics fixture
const canvasRubricsHTML = `
  <html>
    <head><title>Course Rubrics</title></head>
    <body>
      <h1 class="page-title">Grading Criteria</h1>
      <div id="rubrics">
        <p>Criteria 1: Clarity of argument (10 pts)</p>
      </div>
    </body>
  </html>
`;
const domRubrics = page(canvasRubricsHTML, 'https://canvas.instructure.com/courses/101/rubrics');
const extractedRubrics = extractContentFromDOM(domRubrics.document, domRubrics.url);

assert.strictEqual(extractedRubrics.pageType, 'Canvas Rubric');
assert.strictEqual(extractedRubrics.title, 'Grading Criteria');
assert.ok(extractedRubrics.content.includes('Criteria 1'), 'rubric text must be read without a document.body fallback');

// Test 5: Canvas Generic LMS Page
const canvasGenericHTML = `
  <html>
    <head><title>Course Overview</title></head>
    <body>
      <h1 class="page-title">Welcome to PHY 101</h1>
      <div class="show-content user_content">
        <p>General introduction to physics principles.</p>
      </div>
    </body>
  </html>
`;
const domGeneric = page(canvasGenericHTML, 'https://canvas.instructure.com/courses/101/pages/overview');
const extractedGeneric = extractContentFromDOM(domGeneric.document, domGeneric.url);

assert.strictEqual(extractedGeneric.pageType, 'Canvas LMS Page');
assert.strictEqual(extractedGeneric.title, 'Welcome to PHY 101');
assert.ok(extractedGeneric.content.includes('physics principles'));

// Test 6: Google Docs fixture
const gdocHTML = `
  <html>
    <head><title>Instructional Design Principles - Google Docs</title></head>
    <body>
      <div class="kix-appview-editor">
        <p>Course Outline: 1. Assessment Design 2. Cognitive Load Management</p>
      </div>
    </body>
  </html>
`;
const domGdoc = page(gdocHTML, 'https://docs.google.com/document/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit');
const extractedGdoc = extractContentFromDOM(domGdoc.document, domGdoc.url);

assert.strictEqual(extractedGdoc.pageType, 'Google Doc Syllabus');
assert.ok(extractedGdoc.content.includes('Assessment Design'));

// Test 7: Generic Web Page fixture
const webHTML = `
  <html>
    <head><title>Open Courseware Syllabus</title></head>
    <body>
      <main>
        <h1>Introduction to Machine Learning</h1>
        <p>Course schedule and grading policy.</p>
      </main>
    </body>
  </html>
`;
const domWeb = page(webHTML, 'https://ocw.mit.edu/syllabus/intro-ml');
const extractedWeb = extractContentFromDOM(domWeb.document, domWeb.url);

assert.strictEqual(extractedWeb.pageType, 'Web Syllabus / Course Page');
assert.strictEqual(extractedWeb.title, 'Open Courseware Syllabus');
assert.ok(extractedWeb.content.includes('Machine Learning'));

// Test 8: Content length cap at 15000 characters
const longText = 'word '.repeat(4000); // 20,000 characters
const longHTML = `<html><head><title>Long Document</title></head><body><main><p>${longText}</p></main></body></html>`;
const domLong = page(longHTML, 'https://example.com/long');
const extractedLong = extractContentFromDOM(domLong.document, domLong.url);

assert.strictEqual(extractedLong.content.length, 15000, 'Content should be capped at 15000 chars');

// Test 9: detectPageType helper directly
assert.strictEqual(detectPageType('https://canvas.instructure.com/courses/1/assignments/2', { querySelector: (s) => s === '#assignment_show' ? {} : null }), 'Canvas Assignment');
assert.strictEqual(detectPageType('https://docs.google.com/document/d/123', {}), 'Google Doc Syllabus');
assert.strictEqual(detectPageType('https://harvard.edu/syllabus', {}), 'Web Syllabus / Course Page');

// Test 10: executeScript({ files }) contract. The side panel injects the shipped
// extractor.js and reads the script's completion value as the InjectionResult.
// It re-injects on every refresh into the same isolated world, so a second run
// must work too (a top-level let/const/class would throw on redeclaration).
const extractorUrl = new URL('../extension/content/extractor.js', import.meta.url);
const extractorSrc = readFileSync(extractorUrl, 'utf8');
const h = installChrome();
const isolatedWorld = vm.createContext({
  URL,
  chrome: h.chrome,
  document: domAssignment.document,
  window: { location: { href: domAssignment.url } }
});
for (const run of ['first', 'second']) {
  // extractPageContent is async; Chrome awaits a Promise completion value.
  const injected = await vm.runInContext(extractorSrc, isolatedWorld, { filename: extractorUrl.pathname });
  assert.ok(injected && injected.pageType === 'Canvas Assignment', `${run} injection must evaluate to the extraction payload`);
  assert.strictEqual(injected.title, 'Enzymes Lab Analysis');
}
assert.strictEqual(h.listeners.message.length, 0, 'extractor must not register a persistent runtime.onMessage listener');
resetGlobals();

// Test 12: student-record pages are refused, and Canvas never falls back to the whole page (F11)
const studentRecordHTML = `
  <html>
    <head><title>Jane Doe: BIO 200</title></head>
    <body>
      <div id="content" role="main">
        <h1>Jane Doe</h1>
        <p>Jane Doe jane.doe@example.edu Section 01 Final grade 72%</p>
      </div>
    </body>
  </html>
`;
for (const url of [
  'https://canvas.instructure.com/courses/101/gradebook',
  'https://canvas.instructure.com/courses/101/gradebook/speed_grader?assignment_id=5',
  'https://canvas.instructure.com/courses/101/grades/7',
  'https://canvas.instructure.com/courses/101/users/7',
  'https://canvas.instructure.com/courses/101/groups',
  'https://canvas.instructure.com/courses/101/discussion_topics/9',
  'https://canvas.instructure.com/courses/101/assignments/5/submissions/7',
  'https://canvas.instructure.com/conversations',
  // Canvas on a custom domain outside /courses/N is not detected as Canvas; the guard still applies.
  'https://canvas.example.edu/conversations',
  'https://canvas.example.edu/groups/12',
  'https://canvas.example.edu/users/7',
  'https://canvas.example.edu/accounts/1/users'
]) {
  const r = extractContentFromDOM(createDocument(studentRecordHTML), url);
  assert.strictEqual(r.content, '', `${url}: student-record page must not be read`);
  assert.ok(r.emptyReason, `${url}: must say why nothing was read`);
  assert.ok(!JSON.stringify(r).includes('Jane Doe'), `${url}: student name leaked into the payload`);
}

// An unlisted Canvas view gets '' rather than the whole page.
const quizHistoryUrl = 'https://canvas.instructure.com/courses/101/quizzes/5/history?quiz_submission_id=3';
assert.strictEqual(extractContentFromDOM(createDocument(studentRecordHTML), quizHistoryUrl).content, '', 'Canvas must not fall back to document.body');

// Custom-domain Canvas course pages are Canvas (no [role=main] or body read).
const customCourseUrl = 'https://canvas.example.edu/courses/101/quizzes/5/history?quiz_submission_id=3';
const extractedCustomCourse = extractContentFromDOM(createDocument(studentRecordHTML), customCourseUrl);
assert.ok(extractedCustomCourse.pageType.startsWith('Canvas'), 'custom-domain /courses/N URLs are Canvas');
assert.strictEqual(extractedCustomCourse.content, '', 'custom-domain Canvas must not fall back to the whole page');

// Non-Canvas /courses/<slug> sites keep generic extraction.
const ocwUrl = 'https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/pages/syllabus/';
const extractedOcw = extractContentFromDOM(createDocument(webHTML), ocwUrl);
assert.strictEqual(extractedOcw.pageType, 'Web Syllabus / Course Page', 'non-numeric /courses/ URLs are not Canvas');
assert.ok(extractedOcw.content.includes('Machine Learning'));

// No URL at all (url defaults to '' outside a page): the guard must not throw
// (new URL('') does) and must not refuse the page.
let extractedNoUrl;
assert.doesNotThrow(() => { extractedNoUrl = extractContentFromDOM(createDocument(webHTML), ''); }, 'an empty url must not throw');
assert.notStrictEqual(extractedNoUrl.title, 'Student records page', 'an empty url is not a student-record page');
assert.ok(extractedNoUrl.content.includes('Machine Learning'), 'an empty url falls through to generic extraction');

// Test 13: Google Docs text comes from the doc's plain-text export, never the editor
// DOM, which holds no document text (F7). extractPageContent reads window, document and fetch.
const docsEditorHTML = `<html><head><title>BIO 200 Syllabus - Google Docs</title></head><body><div id="docs-menubar">File Edit View Insert Format Tools Extensions Help</div><div class="kix-appview-editor">Turn on screen reader support. To enable screen reader support, press Ctrl+Alt+Z</div></body></html>`;
const docUrl = 'https://docs.google.com/document/u/1/d/1AbC_dEf-GhIjKlMnOpQrStUvWxYz0123456789abcd/edit?tab=t.0';
globalThis.window = { location: { href: docUrl } };
globalThis.document = createDocument(docsEditorHTML);
const docFetches = installFetch(() => new Response('﻿BIO 200 Syllabus\nLearning objectives: analyze enzyme kinetics.', { headers: { 'content-type': 'text/plain; charset=utf-8' } }));
const exported = await extractPageContent();
assert.deepStrictEqual(docFetches.map((c) => c.url), ['https://docs.google.com/document/u/1/d/1AbC_dEf-GhIjKlMnOpQrStUvWxYz0123456789abcd/export?format=txt'], 'Docs text must be fetched from the plain-text export');
assert.strictEqual(docFetches[0].init.credentials, undefined, "the export fetch must keep fetch's default credentials mode");
assert.ok(exported.content.startsWith('BIO 200 Syllabus'), 'Docs text must come from the export, BOM stripped');
assert.strictEqual(exported.wordCount, 8);
assert.strictEqual(exported.emptyReason, undefined);

installFetch(() => new Response('<html></html>', { status: 403, headers: { 'content-type': 'text/html; charset=utf-8' } }));
const refused = await extractPageContent();
assert.strictEqual(refused.content, '', 'a refused export must not fall back to the editor DOM');
assert.ok(refused.emptyReason, 'a refused export must say why nothing was read');

// Signed out, the export answers 200 with an HTML sign-in page.
installFetch(() => new Response('<html><body>Sign in to continue to Docs</body></html>', { headers: { 'content-type': 'text/html; charset=utf-8' } }));
const signIn = await extractPageContent();
assert.strictEqual(signIn.content, '', 'an HTML sign-in page must not be audited as the document');
assert.ok(signIn.emptyReason, 'an HTML export answer must say why nothing was read');

// Published /d/e/ docs render their text in the DOM and have no export.
globalThis.window = { location: { href: 'https://docs.google.com/document/d/e/2PACX-1vTabc/pub' } };
globalThis.document = createDocument('<html><head><title>Syllabus</title></head><body><div id="contents"><p>Week 1 readings.</p></div></body></html>');
const pubFetches = installFetch(() => { throw new Error('published docs must not be fetched'); });
const published = await extractPageContent();
assert.strictEqual(pubFetches.length, 0, 'published docs are read from the DOM, not fetched');
assert.ok(published.content.includes('Week 1 readings'));
resetGlobals();

console.log('✅ Task 3 extractor tests passed.');
