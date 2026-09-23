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

console.log('✅ Course context detection tests passed.');
