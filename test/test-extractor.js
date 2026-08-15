const assert = require('assert');

// Support JSDOM if available, or fallback to built-in DOM mock for standalone node environments
let JSDOM;
try {
  JSDOM = require('jsdom').JSDOM;
} catch {
  class MockElement {
    constructor(tagName = 'div', attrs = {}, text = '') {
      this.tagName = tagName.toLowerCase();
      this.attrs = attrs;
      this.children = [];
      this._text = text;
    }
    get innerText() {
      if (this.children.length > 0) {
        return this.children.map(c => typeof c === 'string' ? c : c.innerText).join(' ').trim();
      }
      return this._text.trim();
    }
    get textContent() {
      return this.innerText;
    }
    querySelector(selector) {
      const selectors = selector.split(',').map(s => s.trim());
      for (const sel of selectors) {
        const found = this._querySingle(sel);
        if (found) return found;
      }
      return null;
    }
    _querySingle(selector) {
      const parts = selector.split(/\s+/);
      let current = [this];
      for (const part of parts) {
        const next = [];
        for (const el of current) {
          next.push(...el._findDescendants(part));
        }
        current = next;
        if (current.length === 0) return null;
      }
      return current[0] || null;
    }
    _findDescendants(part) {
      const results = [];
      const check = (el) => {
        if (el !== this) {
          let match = true;
          if (part.startsWith('#')) {
            if (el.attrs.id !== part.slice(1)) match = false;
          } else if (part.startsWith('.')) {
            const requiredClasses = part.split('.').filter(Boolean);
            const elClasses = (el.attrs.class || '').split(/\s+/).filter(Boolean);
            if (!requiredClasses.every(cls => elClasses.includes(cls))) match = false;
          } else if (part.startsWith('[')) {
            const m = part.match(/\[([a-zA-Z0-9_-]+)(?:="([^"]*)")?\]/);
            if (m) {
              const [, attrName, attrVal] = m;
              if (attrVal !== undefined) {
                if (el.attrs[attrName] !== attrVal) match = false;
              } else {
                if (!(attrName in el.attrs)) match = false;
              }
            }
          } else {
            if (el.tagName !== part.toLowerCase()) match = false;
          }
          if (match) results.push(el);
        }
        for (const child of el.children) {
          if (typeof child !== 'string') check(child);
        }
      };
      check(this);
      return results;
    }
  }

  function parseHtmlToTree(html) {
    const root = new MockElement('root');
    const stack = [root];
    const tagRegex = /<(\/)?([a-zA-Z0-9]+)([^>]*)>|([^<]+)/g;
    let match;

    while ((match = tagRegex.exec(html)) !== null) {
      const [full, isClose, tagName, attrStr, text] = match;
      if (text) {
        const trimmed = text.trim();
        if (trimmed) {
          const current = stack[stack.length - 1];
          current.children.push(trimmed);
        }
      } else if (tagName) {
        if (isClose) {
          if (stack.length > 1 && stack[stack.length - 1].tagName === tagName.toLowerCase()) {
            stack.pop();
          }
        } else {
          const attrs = {};
          if (attrStr) {
            const attrRegex = /([a-zA-Z0-9_-]+)(?:=["']([^"']*)["'])?/g;
            let attrMatch;
            while ((attrMatch = attrRegex.exec(attrStr)) !== null) {
              attrs[attrMatch[1]] = attrMatch[2] || '';
            }
          }
          const el = new MockElement(tagName, attrs);
          stack[stack.length - 1].children.push(el);
          if (!['meta', 'link', 'img', 'br', 'hr', 'input'].includes(tagName.toLowerCase())) {
            stack.push(el);
          }
        }
      }
    }
    return root;
  }

  class SimpleJSDOM {
    constructor(html, { url = 'http://localhost' } = {}) {
      const tree = parseHtmlToTree(html);
      const titleEl = tree.querySelector('title');
      const titleText = titleEl ? titleEl.innerText : '';
      const bodyEl = tree.querySelector('body') || tree;

      this.window = {
        location: { href: url },
        document: {
          title: titleText,
          body: bodyEl,
          querySelector: (sel) => tree.querySelector(sel)
        }
      };
    }
  }
  JSDOM = SimpleJSDOM;
}

const { detectPageType, extractContentFromDOM, extractPageContent } = require('../extension/content/extractor-core.cjs');

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
const domAssignment = new JSDOM(canvasAssignmentHTML, { url: 'https://canvas.instructure.com/courses/101/assignments/202' });
const extractedAssignment = extractContentFromDOM(domAssignment.window.document, domAssignment.window.location.href);

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
const domSyllabus = new JSDOM(canvasSyllabusHTML, { url: 'https://canvas.instructure.com/courses/101/assignments/syllabus' });
const extractedSyllabus = extractContentFromDOM(domSyllabus.window.document, domSyllabus.window.location.href);

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
const domModules = new JSDOM(canvasModulesHTML, { url: 'https://canvas.instructure.com/courses/101/modules' });
const extractedModules = extractContentFromDOM(domModules.window.document, domModules.window.location.href);

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
const domRubrics = new JSDOM(canvasRubricsHTML, { url: 'https://canvas.instructure.com/courses/101/rubrics' });
const extractedRubrics = extractContentFromDOM(domRubrics.window.document, domRubrics.window.location.href);

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
const domGeneric = new JSDOM(canvasGenericHTML, { url: 'https://canvas.instructure.com/courses/101/pages/overview' });
const extractedGeneric = extractContentFromDOM(domGeneric.window.document, domGeneric.window.location.href);

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
const domGdoc = new JSDOM(gdocHTML, { url: 'https://docs.google.com/document/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit' });
const extractedGdoc = extractContentFromDOM(domGdoc.window.document, domGdoc.window.location.href);

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
const domWeb = new JSDOM(webHTML, { url: 'https://ocw.mit.edu/syllabus/intro-ml' });
const extractedWeb = extractContentFromDOM(domWeb.window.document, domWeb.window.location.href);

assert.strictEqual(extractedWeb.pageType, 'Web Syllabus / Course Page');
assert.strictEqual(extractedWeb.title, 'Open Courseware Syllabus');
assert.ok(extractedWeb.content.includes('Machine Learning'));

// Test 8: Content length cap at 15000 characters
const longText = 'word '.repeat(4000); // 20,000 characters
const longHTML = `<html><head><title>Long Document</title></head><body><main><p>${longText}</p></main></body></html>`;
const domLong = new JSDOM(longHTML, { url: 'https://example.com/long' });
const extractedLong = extractContentFromDOM(domLong.window.document, domLong.window.location.href);

assert.strictEqual(extractedLong.content.length, 15000, 'Content should be capped at 15000 chars');

// Test 9: detectPageType helper directly
assert.strictEqual(detectPageType('https://canvas.instructure.com/courses/1/assignments/2', { querySelector: (s) => s === '#assignment_show' ? {} : null }), 'Canvas Assignment');
assert.strictEqual(detectPageType('https://docs.google.com/document/d/123', {}), 'Google Doc Syllabus');
assert.strictEqual(detectPageType('https://harvard.edu/syllabus', {}), 'Web Syllabus / Course Page');

// Test 10: Chrome Runtime onMessage listener handling
let messageListener = null;
global.chrome = {
  runtime: {
    onMessage: {
      addListener: (fn) => {
        messageListener = fn;
      }
    }
  }
};
global.window = domAssignment.window;
global.document = domAssignment.window.document;

delete require.cache[require.resolve('../extension/content/extractor.js')];
require('../extension/content/extractor.js');

assert.ok(typeof messageListener === 'function', 'chrome.runtime.onMessage listener should be registered');
let responseData = null;
messageListener({ action: 'EXTRACT_CONTENT' }, {}, (data) => {
  responseData = data;
});
assert.ok(responseData, 'Response data must be returned on EXTRACT_CONTENT action');
assert.strictEqual(responseData.pageType, 'Canvas Assignment');
assert.strictEqual(responseData.title, 'Enzymes Lab Analysis');

// Clean up globals
delete global.chrome;
delete global.window;
delete global.document;

// Test 11: Canvas Course Root Detection
const { detectCourseContext } = require('../extension/content/extractor-core.cjs');
const rootCtx = detectCourseContext('https://canvas.instructure.com/courses/987654', 'Biology 101');
assert.strictEqual(rootCtx.isCourseRoot, true);
assert.strictEqual(rootCtx.courseId, '987654');
assert.strictEqual(rootCtx.origin, 'https://canvas.instructure.com');

const subpageCtx = detectCourseContext('https://canvas.instructure.com/courses/987654/assignments/123', 'Lab 1');
assert.strictEqual(subpageCtx.isCourseRoot, false);
assert.strictEqual(subpageCtx.courseId, '987654');

console.log('✅ Task 3 extractor tests passed.');
