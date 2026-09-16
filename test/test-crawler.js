const assert = require('assert');
const { crawlCanvasCourse, stripHtml } = require('../extension/background/canvas-crawler.cjs');
const { getDemoCourseAuditResult } = require('../extension/background/parser-helper.cjs');

// Test 1: HTML Tag Stripping
const clean = stripHtml('<p>Hello <strong>World</strong> &amp; Students<br></p>');
assert.strictEqual(clean, 'Hello World & Students');

// Test 2: Mock Canvas Crawler
let fetchOptionsPassed = [];
const mockFetch = async (url, options) => {
  if (options) fetchOptionsPassed.push(options);
  if (url.includes('include[]=syllabus_body')) {
    return {
      ok: true,
      json: async () => ({
        name: 'Biology 101: Cell Systems',
        syllabus_body: '<p>Welcome to Biology 101. Objectives: Analyze cellular metabolism.</p>'
      })
    };
  }
  if (url.includes('/assignments')) {
    return {
      ok: true,
      json: async () => [
        { name: 'Quiz 1', description: '<p>Recall organelles</p>', points_possible: 10 },
        { name: 'Lab Report 1', description: '<p>Analyze enzyme kinetics</p>', points_possible: 50 }
      ]
    };
  }
  throw new Error('Not found: ' + url);
};

(async () => {
  const originalFetch = global.fetch;
  global.fetch = mockFetch;

  const courseData = await crawlCanvasCourse('https://canvas.instructure.com', '12345');
  assert.strictEqual(courseData.title, 'Biology 101: Cell Systems');
  assert.ok(fetchOptionsPassed.every(opt => opt && opt.credentials === 'include'), 'fetchImpl must include credentials');
  assert.ok(courseData.syllabus.includes('Analyze cellular metabolism'));
  assert.strictEqual(courseData.assignments.length, 2);
  assert.strictEqual(courseData.assignments[0].title, 'Quiz 1');
  assert.strictEqual(courseData.assignments[0].description, 'Recall organelles');

  // Test 2.5: Missing Error Path Test for crawlCanvasCourse
  let caughtError1 = false;
  try {
    await crawlCanvasCourse(null, '12345');
  } catch (err) {
    caughtError1 = true;
    assert.strictEqual(err.message, 'Canvas origin and courseId are required for course crawling.');
  }
  assert.ok(caughtError1, 'Should throw error when origin is missing');

  let caughtError2 = false;
  try {
    await crawlCanvasCourse('https://canvas.instructure.com', null);
  } catch (err) {
    caughtError2 = true;
    assert.strictEqual(err.message, 'Canvas origin and courseId are required for course crawling.');
  }
  assert.ok(caughtError2, 'Should throw error when courseId is missing');

  // Test 3: Demo Course Audit Fallback
  const demoResult = getDemoCourseAuditResult({ title: 'Biology 101: Cell Systems' });
  assert.ok(demoResult.summary.keyTakeaway.includes('Course-Level Demo'));
  assert.ok(demoResult.findings.length >= 2);
  assert.ok(demoResult.improvedDraft.title.includes('Matrix'));

  // Test 4: Error Path Test for course fetch failure
  const mockFailedFetch = async (url) => {
    return {
      ok: false,
      status: 404
    };
  };

  let errorThrown = false;
  try {
    global.fetch = mockFailedFetch;
    await crawlCanvasCourse('https://canvas.instructure.com', 'invalid-id');
  } catch (err) {
    errorThrown = true;
    assert.strictEqual(err.message, 'Failed to fetch Canvas course info (404)');
  }
  assert.ok(errorThrown, 'Expected an error to be thrown for failed fetch');
  global.fetch = originalFetch;

  console.log('✅ Task 2 Canvas crawler tests passed.');
})();
