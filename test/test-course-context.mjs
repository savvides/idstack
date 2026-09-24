import assert from 'node:assert';
import { detectCourseContext } from '../extension/content/extractor-core.js';

// The side panel imports this module (sidepanel.js L3); test that file, not the content script.
const rootCtx = detectCourseContext('https://canvas.instructure.com/courses/987654', 'Biology 101');
assert.strictEqual(rootCtx.isCourseRoot, true);
assert.strictEqual(rootCtx.courseId, '987654');
assert.strictEqual(rootCtx.origin, 'https://canvas.instructure.com');

const modulesCtx = detectCourseContext('https://canvas.instructure.com/courses/987654/modules', 'Modules');
assert.strictEqual(modulesCtx.isCourseRoot, true);
assert.strictEqual(modulesCtx.courseId, '987654');
assert.strictEqual(modulesCtx.origin, 'https://canvas.instructure.com');

const queryParamCtx = detectCourseContext('https://canvas.instructure.com/courses/987654/modules?view=feed', 'Modules Feed');
assert.strictEqual(queryParamCtx.isCourseRoot, true);
assert.strictEqual(queryParamCtx.courseId, '987654');

const subpageCtx = detectCourseContext('https://canvas.instructure.com/courses/987654/assignments/123', 'Lab 1');
assert.strictEqual(subpageCtx.isCourseRoot, false);
assert.strictEqual(subpageCtx.courseId, '987654');

// Edge cases from closed bot PR #100.
for (const bad of [null, 'invalid-url']) {
  assert.deepStrictEqual(detectCourseContext(bad), { isCourseRoot: false, courseId: null, origin: null }, `${bad} is not a course`);
}
const hashCtx = detectCourseContext('https://canvas.instructure.com/courses/987654#main');
assert.strictEqual(hashCtx.isCourseRoot, true, 'a fragment does not change the page');
assert.strictEqual(hashCtx.courseId, '987654');
assert.deepStrictEqual(detectCourseContext('https://example.com/other/123'), { isCourseRoot: false, courseId: null, origin: 'https://example.com' });
for (const url of ['https://canvas.instructure.com/courses/', 'https://canvas.instructure.com/courses/abc']) {
  const ctx = detectCourseContext(url);
  assert.strictEqual(ctx.isCourseRoot, false, `${url} has no numeric course id`);
  assert.strictEqual(ctx.courseId, null);
}

console.log('✅ Course context detection tests passed.');
