const assert = require('assert');
const { renderAuditHTML } = require('../extension/sidepanel/renderer-helper.cjs');

// Test 1: Full mock audit data rendering
const mockData = {
  summary: {
    bloomsLevel: 'Analyze',
    alignmentScore: 'Strong',
    keyTakeaway: 'Great constructive alignment between rubric and lab analysis.'
  },
  findings: [
    {
      severity: 'suggestion',
      tier: 'T1',
      citation: '[Assessment-8] Elaborated Feedback',
      observation: 'Rubric uses generic grading bands.',
      evidence: 'Elaborated criteria increase metacognitive monitoring.',
      recommendation: 'Add milestone descriptions for each level.'
    },
    {
      severity: 'critical',
      tier: 'T2',
      citation: '[Alignment-3] Direct Assessment',
      observation: 'Objectives not measured in final quiz.',
      evidence: 'Direct assessment ensures learning outcome achievement.',
      recommendation: 'Align quiz items with analysis objectives.'
    }
  ],
  improvedDraft: {
    title: 'Rewritten Rubric Matrix',
    content: '| Criterion | Exemplary | Developing |\n|---|---|---|'
  }
};

const rendered = renderAuditHTML(mockData);

// Check summary rendering
assert.ok(rendered.includes('Analyze'), "Must render Bloom's level");
assert.ok(rendered.includes('Strong'), "Must render alignment score");
assert.ok(rendered.includes('Great constructive alignment between rubric and lab analysis.'), "Must render key takeaway");

// Check findings count & citations
assert.ok(rendered.includes('Evidence-Based Findings (2)'), 'Must render correct findings count heading');
assert.ok(rendered.includes('[Assessment-8]'), 'Must render citation for finding 1');
assert.ok(rendered.includes('[Alignment-3]'), 'Must render citation for finding 2');

// Check tier badges & severity classes
assert.ok(rendered.includes('tier-badge tier-t1'), 'Must include tier-t1 badge');
assert.ok(rendered.includes('tier-badge tier-t2'), 'Must include tier-t2 badge');
assert.ok(rendered.includes('severity-suggestion'), 'Must include severity-suggestion class');
assert.ok(rendered.includes('severity-critical'), 'Must include severity-critical class');

// Check observation, evidence, recommendation
assert.ok(rendered.includes('Rubric uses generic grading bands.'), 'Must render observation');
assert.ok(rendered.includes('Elaborated criteria increase metacognitive monitoring.'), 'Must render evidence');
assert.ok(rendered.includes('Add milestone descriptions for each level.'), 'Must render recommendation');

// Check improved draft & 1-click copy button
assert.ok(rendered.includes('Rewritten Rubric Matrix'), 'Must render improved draft title');
assert.ok(rendered.includes('copy-improved-btn'), 'Must include 1-click copy button');
assert.ok(rendered.includes('| Criterion | Exemplary | Developing |'), 'Must include draft content in pre/code block');

// Check feedback & re-audit controls
assert.ok(rendered.includes('feedback-btn'), 'Must include feedback voting buttons');
assert.ok(rendered.includes('re-audit-btn'), 'Must include re-audit button');

// Test 2: Empty findings list rendering
const emptyData = {
  summary: {
    bloomsLevel: 'Remember',
    alignmentScore: 'Developing',
    keyTakeaway: 'Basic knowledge check.'
  },
  findings: [],
  improvedDraft: {
    title: 'No Changes Needed',
    content: 'Content is aligned.'
  }
};
const emptyRendered = renderAuditHTML(emptyData);
assert.ok(emptyRendered.includes('Evidence-Based Findings (0)'), 'Must handle 0 findings gracefully');
assert.ok(emptyRendered.includes('Remember'), 'Must render Bloom\'s level for empty findings data');

// Test 3: Null / undefined resilience
assert.strictEqual(renderAuditHTML(null), '', 'Must return empty string for null data');
assert.strictEqual(renderAuditHTML(undefined), '', 'Must return empty string for undefined data');

// Test 4: Partial data resilience
const partialData = {
  summary: {
    bloomsLevel: 'Evaluate',
    alignmentScore: 'Moderate',
    keyTakeaway: 'Evaluation needs more rubric detail.'
  }
};
const partialRendered = renderAuditHTML(partialData);
assert.ok(partialRendered.includes('Evaluate'), 'Must handle missing findings and improvedDraft');
assert.ok(partialRendered.includes('Evidence-Based Findings (0)'), 'Must default findings to 0');

console.log('✅ Task 6 renderer tests passed.');
