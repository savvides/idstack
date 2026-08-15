const assert = require('assert');
const { EVIDENCE_DOMAINS, TIER_METADATA, buildAuditPrompt } = require('../extension/shared/prompts.cjs');

assert.ok(EVIDENCE_DOMAINS.length >= 10, 'Should include all core idstack research domains');
assert.ok(TIER_METADATA.T1, 'Tier 1 metadata must exist');
assert.strictEqual(TIER_METADATA.T1.label, 'Meta-analysis');

const prompt = buildAuditPrompt({
  title: 'Biology 101 - Cell Division Assignment',
  pageType: 'assignment',
  content: 'Students will list the phases of mitosis and take a 5-question multiple choice quiz.'
});

assert.ok(prompt.includes('Biology 101'), 'Prompt should include content title');
assert.ok(prompt.includes("Bloom's"), "Prompt should require Bloom's classification");
assert.ok(prompt.includes('JSON'), 'Prompt should enforce JSON format');

console.log('✅ Task 2 prompt engine tests passed.');
