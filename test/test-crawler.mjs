import assert from 'node:assert';
import { crawlCanvasCourse, stripHtml } from '../extension/background/canvas-crawler.js';
import { getDemoCourseAuditResult } from '../extension/background/parser-helper.js';

// Fake Canvas that behaves like the real API under session-cookie auth: clean
// JSON bodies (Canvas stopped prefixing while(1); in Aug 2019, canvas-lms
// commit 485acb0a05), list endpoints paginated through a Link header, and JSON
// error bodies on 4xx. The previous fake served one clean page and never
// failed, which is how a crawler that audited a truncated or empty assignment
// list passed green.
const ORIGIN = 'https://canvas.test';
const COURSE_URL = `${ORIGIN}/api/v1/courses/12345?include[]=syllabus_body`;
const PAGE1_URL = `${ORIGIN}/api/v1/courses/12345/assignments?per_page=50`;
const pageUrl = (n) => (n === 1 ? PAGE1_URL : `${ORIGIN}/api/v1/courses/12345/assignments?page=${n}&per_page=50`);
// Canvas sends rel="current" and rel="first" on every page, rel="next" on all but the last.
const linkFor = (n, last) => [`<${pageUrl(n)}>; rel="current"`]
  .concat(n < last ? [`<${pageUrl(n + 1)}>; rel="next"`] : [], [`<${PAGE1_URL}>; rel="first"`])
  .join(',');
const assignmentsFrom = (first, count) => Array.from({ length: count }, (_, i) => ({
  name: `Assignment ${first + i}`, description: '<p>Analyze enzyme kinetics</p>', points_possible: 10
}));
const COURSE = { body: { name: 'Biology 101: Cell Systems', syllabus_body: '<p>Welcome to Biology 101. Objectives: Analyze cellular metabolism.</p>' } };

function canvasFetch(routes) {
  const calls = [];
  const fetchImpl = async (url, options = {}) => {
    calls.push({ url, credentials: options.credentials });
    const route = typeof routes === 'function' ? routes(url) : routes[url];
    if (!route) throw new TypeError(`Failed to fetch ${url}`);
    const headers = { 'Content-Type': 'application/json; charset=utf-8' };
    if (route.link) headers.Link = route.link;
    return new Response(JSON.stringify(route.body), { status: route.status || 200, headers });
  };
  return { fetchImpl, calls };
}

// Test 1: HTML tag stripping
assert.strictEqual(stripHtml('<p>Hello <strong>World</strong> &amp; Students<br></p>'), 'Hello World & Students');

// Test 2: an 80-assignment course is read across both pages
{
  const { fetchImpl, calls } = canvasFetch({
    [COURSE_URL]: COURSE,
    [PAGE1_URL]: { body: assignmentsFrom(1, 50), link: linkFor(1, 2) },
    [pageUrl(2)]: { body: assignmentsFrom(51, 30), link: linkFor(2, 2) }
  });
  const courseData = await crawlCanvasCourse(ORIGIN, '12345', fetchImpl);
  assert.strictEqual(courseData.title, 'Biology 101: Cell Systems');
  assert.ok(courseData.syllabus.includes('Analyze cellular metabolism'));
  assert.ok(calls.every((c) => c.credentials === 'include'), 'every Canvas GET must send session cookies');
  assert.strictEqual(courseData.assignments.length, 80, 'crawler must follow Link rel="next"');
  assert.strictEqual(courseData.assignments[0].description, 'Analyze enzyme kinetics');
  assert.strictEqual(courseData.assignments[79].title, 'Assignment 80');
}

// Test 3: a failed assignments fetch is fatal, never an empty list the LLM
// reads as "this course has no assessments"
{
  const { fetchImpl } = canvasFetch({
    [COURSE_URL]: COURSE,
    [PAGE1_URL]: { status: 403, body: { errors: [{ message: 'user not authorized to perform that action' }] } }
  });
  await assert.rejects(crawlCanvasCourse(ORIGIN, '12345', fetchImpl), /Failed to fetch Canvas assignments \(403\)/);
}

// Test 4: a network failure on page 2 is fatal, not a silent 50-item list
{
  const { fetchImpl } = canvasFetch({
    [COURSE_URL]: COURSE,
    [PAGE1_URL]: { body: assignmentsFrom(1, 50), link: linkFor(1, 2) }
  });
  await assert.rejects(crawlCanvasCourse(ORIGIN, '12345', fetchImpl), /Failed to fetch/);
}

// Test 5: page cap. The fake course is FINITE (12 pages) so a crawler without
// the cap returns 600 items and fails here instead of looping until OOM.
{
  const { fetchImpl, calls } = canvasFetch((url) => {
    if (url === COURSE_URL) return COURSE;
    for (let n = 1; n <= 12; n++) {
      if (url === pageUrl(n)) return { body: assignmentsFrom((n - 1) * 50 + 1, 50), link: linkFor(n, 12) };
    }
    return null;
  });
  await assert.rejects(crawlCanvasCourse(ORIGIN, '12345', fetchImpl), /more than 500 assignments/);
  assert.strictEqual(calls.filter((c) => c.url.includes('/assignments')).length, 10);
}

// Test 6: Demo Course Audit Fallback
const demoResult = getDemoCourseAuditResult({ title: 'Biology 101: Cell Systems' });
assert.ok(demoResult.summary.keyTakeaway.includes('Course-Level Demo'));
assert.ok(demoResult.findings.length >= 2);
assert.ok(demoResult.improvedDraft.title.includes('Matrix'));

console.log('✅ Task 2 Canvas crawler tests passed.');
