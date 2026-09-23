import assert from 'node:assert';
import { createDocument, installChrome, loadContentScript, resetGlobals } from './extension-harness.mjs';

// The shipped content script: a classic script, loaded exactly as Chrome gets it.
const { detectPageType, extractContentFromDOM } = loadContentScript('content/extractor.js');
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
      </div>
    </body>
  </html>
`;
const domModules = page(canvasModulesHTML, 'https://canvas.instructure.com/courses/101/modules');
const extractedModules = extractContentFromDOM(domModules.document, domModules.url);

assert.strictEqual(extractedModules.pageType, 'Canvas Modules');
assert.strictEqual(extractedModules.title, 'BIO 200 Modules');
assert.ok(extractedModules.content.includes('Week 1: Cellular Respiration'));

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

// Test 10: Chrome Runtime onMessage listener handling
const h = installChrome();
globalThis.window = { location: { href: domAssignment.url } };
globalThis.document = domAssignment.document;
loadContentScript('content/extractor.js');

assert.strictEqual(h.listeners.message.length, 1, 'chrome.runtime.onMessage listener should be registered');
const responseData = await h.dispatch({ action: 'EXTRACT_CONTENT' });
assert.ok(responseData, 'Response data must be returned on EXTRACT_CONTENT action');
assert.strictEqual(responseData.pageType, 'Canvas Assignment');
assert.strictEqual(responseData.title, 'Enzymes Lab Analysis');
resetGlobals();

console.log('✅ Task 3 extractor tests passed.');
