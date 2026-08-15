const assert = require('assert');
const { crawlCanvasCourse, stripHtml } = require('../extension/background/canvas-crawler.cjs');
const { getDemoCourseAuditResult } = require('../extension/background/parser-helper.cjs');

// Test 1: HTML Tag Stripping
const clean = stripHtml('<p>Hello <strong>World</strong> &amp; Students<br></p>');
assert.strictEqual(clean, 'Hello World & Students');

// Test 2: Mock Canvas Crawler
const mockFetch = async (url) => {
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
  const courseData = await crawlCanvasCourse('https://canvas.instructure.com', '12345', mockFetch);
  assert.strictEqual(courseData.title, 'Biology 101: Cell Systems');
  assert.ok(courseData.syllabus.includes('Analyze cellular metabolism'));
  assert.strictEqual(courseData.assignments.length, 2);
  assert.strictEqual(courseData.assignments[0].title, 'Quiz 1');
  assert.strictEqual(courseData.assignments[0].description, 'Recall organelles');

  // Test 3: Demo Course Audit Fallback
  const demoResult = getDemoCourseAuditResult({ title: 'Biology 101: Cell Systems' });
  assert.ok(demoResult.summary.keyTakeaway.includes('Course-Level Demo'));
  assert.ok(demoResult.findings.length >= 2);
  assert.ok(demoResult.improvedDraft.title.includes('Matrix'));

  console.log('✅ Task 2 Canvas crawler tests passed.');
})();
