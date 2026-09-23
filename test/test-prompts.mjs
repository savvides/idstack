import assert from 'node:assert';
import { EVIDENCE_DOMAINS, TIER_METADATA, buildAuditPrompt, buildCourseAuditPrompt } from '../extension/shared/prompts.js';

assert.ok(EVIDENCE_DOMAINS.length >= 10, 'Should include all core idstack research domains');
assert.ok(TIER_METADATA.T1, 'Tier 1 metadata must exist');
assert.strictEqual(TIER_METADATA.T1.label, 'Meta-analysis');
assert.strictEqual(TIER_METADATA.T1.color, '#2f7a4a', 'T1 must match canonical DESIGN.md color');
assert.strictEqual(TIER_METADATA.T2.color, '#2864a8', 'T2 must match canonical DESIGN.md color');
assert.strictEqual(TIER_METADATA.T3.color, '#a87726', 'T3 must match canonical DESIGN.md color');
assert.strictEqual(TIER_METADATA.T4.color, '#b35a1f', 'T4 must match canonical DESIGN.md color');
assert.strictEqual(TIER_METADATA.T5.color, '#6b6b6b', 'T5 must match canonical DESIGN.md color');


const prompt = buildAuditPrompt({
  title: 'Biology 101 - Cell Division Assignment',
  pageType: 'assignment',
  content: 'Students will list the phases of mitosis and take a 5-question multiple choice quiz.'
});

assert.ok(prompt.includes('Biology 101'), 'Prompt should include content title');
assert.ok(prompt.includes("Bloom's"), "Prompt should require Bloom's classification");
assert.ok(prompt.includes('JSON'), 'Prompt should enforce JSON format');

assert.strictEqual(typeof buildCourseAuditPrompt, 'function');
const coursePrompt = buildCourseAuditPrompt({
  title: 'Biology 101',
  syllabus: 'Course objectives and grading policy...',
  assignments: [
    { title: 'Quiz 1', description: 'Recall cell parts', points: 10 },
    { title: 'Final Project', description: 'Design an experiment', points: 100 }
  ]
});
assert.ok(coursePrompt.includes('Biology 101'));
assert.ok(coursePrompt.includes('Constructive Alignment'));
assert.ok(coursePrompt.includes('courseAudit'));

// A long course: the crawler reads up to 500 assignments, and the prompt keeps
// a 20,000-char budget for them. It must list whole assignments and say how
// many it lists, not cut one mid-description under a header that counts all.
const longCoursePrompt = buildCourseAuditPrompt({
  title: 'Biology 101',
  syllabus: 'Objectives: Analyze cellular metabolism.',
  assignments: Array.from({ length: 80 }, (_, i) => ({ title: `Lab ${i + 1}`, description: 'd'.repeat(600), points: 10 }))
});
const assignmentsHeader = /COURSE ASSIGNMENTS & ASSESSMENTS \((\d+) items; (\d+) shown in full below\)/.exec(longCoursePrompt);
assert.ok(assignmentsHeader, 'course prompt header states the item count and how many are shown in full');
assert.strictEqual(assignmentsHeader[1], '80', 'the header counts every crawled assignment');
const listedBlocks = longCoursePrompt.match(/^Assignment \d+: .*\nDescription: .*$/gm) || [];
assert.strictEqual(listedBlocks.length, Number(assignmentsHeader[2]), 'the header states exactly how many assignments are listed');
assert.ok(listedBlocks.length > 0 && listedBlocks.length < 80, '80 long assignments exceed the budget, so only some are listed');
assert.ok(listedBlocks.every((b) => b.endsWith('\nDescription: ' + 'd'.repeat(500))), 'no assignment is cut mid-description');

console.log('✅ Task 2 prompt engine tests passed.');
