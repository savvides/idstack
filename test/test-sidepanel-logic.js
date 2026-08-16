const assert = require('assert');
const { renderAuditHTML, escapeHtml } = require('../extension/sidepanel/renderer-helper.cjs');

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

// Test 5: escapeHtml unit tests
assert.strictEqual(escapeHtml('<script>alert("xss")</script>'), '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;');
assert.strictEqual(escapeHtml("Tom & Jerry's"), 'Tom &amp; Jerry&#039;s');
assert.strictEqual(escapeHtml(null), '');
assert.strictEqual(escapeHtml(undefined), '');

// Test 6: HTML Entity Escaping in all dynamic interpolations
const unsafeData = {
  summary: {
    bloomsLevel: '<img src=x onerror=alert(1)>',
    alignmentScore: '<b onmouseover=alert(2)>100%</b>',
    keyTakeaway: '<script>evil()</script> & "quotes"'
  },
  findings: [
    {
      severity: 'warning',
      tier: 'T1',
      citation: '<a href="javascript:alert(3)">[Cite-1]</a>',
      observation: 'Raw <tag> in observation & "quotes"',
      evidence: '<svg onload=alert(4)> in evidence',
      recommendation: '<iframe src=evil.com> in recommendation'
    }
  ],
  improvedDraft: {
    title: '<h1 onclick=alert(5)>Unsafe Title</h1>',
    content: '<script>doBadThings()</script>'
  }
};

const renderedUnsafe = renderAuditHTML(unsafeData);
assert.ok(!renderedUnsafe.includes('<script>'), 'Must escape script tags');
assert.ok(!renderedUnsafe.includes('<img src=x'), 'Must escape img tags');
assert.ok(!renderedUnsafe.includes('<svg onload='), 'Must escape svg tags');
assert.ok(!renderedUnsafe.includes('<iframe'), 'Must escape iframe tags');
assert.ok(renderedUnsafe.includes('&lt;script&gt;evil()&lt;/script&gt; &amp; &quot;quotes&quot;'), 'Must escape keyTakeaway properly');
assert.ok(renderedUnsafe.includes('&lt;a href=&quot;javascript:alert(3)&quot;&gt;[Cite-1]&lt;/a&gt;'), 'Must escape citation properly');
assert.ok(renderedUnsafe.includes('&lt;tag&gt; in observation &amp; &quot;quotes&quot;'), 'Must escape observation properly');
assert.ok(renderedUnsafe.includes('&lt;h1 onclick=alert(5)&gt;Unsafe Title&lt;/h1&gt;'), 'Must escape improvedDraft title properly');

// Test 7: Rendering Course-Wide Alignment Matrix
const courseResult = {
  summary: { bloomsLevel: 'Analyze', alignmentScore: 'High (88%)', keyTakeaway: 'Strong alignment.' },
  findings: [{ tier: 'T1', severity: 'info', citation: '[Test-1]', observation: 'Good', evidence: 'Meta-analysis', recommendation: 'Keep it' }],
  improvedDraft: { title: 'Course Alignment Matrix', content: '| Week | Outcome |' }
};
const renderedCourse = renderAuditHTML(courseResult);
assert.ok(renderedCourse.includes('Course Alignment Matrix'));
assert.ok(renderedCourse.includes('High (88%)'));

// Test 8: Dossier Item Rendering in Drawer
const { renderDossierListHTML } = require('../extension/sidepanel/renderer-helper.cjs');
assert.strictEqual(typeof renderDossierListHTML, 'function', 'renderDossierListHTML must be a function');
const listHtml = renderDossierListHTML([
  { id: '1', title: 'Week 1 Quiz', pageType: 'Assignment', result: { summary: { bloomsLevel: 'Remember', alignmentScore: 'Low' } } }
]);
assert.ok(listHtml.includes('Week 1 Quiz'), 'Must render item title');
assert.ok(listHtml.includes('Assignment'), 'Must render item page type');
assert.ok(listHtml.includes('data-dossier-id="1"'), 'Must include data-dossier-id attribute');

// Empty and edge cases
assert.ok(renderDossierListHTML([]).includes('No items in dossier yet'), 'Must handle empty array gracefully');
assert.ok(renderDossierListHTML(null).includes('No items in dossier yet'), 'Must handle null gracefully');
assert.ok(renderDossierListHTML(undefined).includes('No items in dossier yet'), 'Must handle undefined gracefully');

// HTML Entity Escaping in Dossier List
const unsafeDossier = [
  {
    id: 'xss-1',
    title: '<script>alert(1)</script>',
    pageType: '<img src=x>',
    result: { summary: { bloomsLevel: '<b>Bold</b>', alignmentScore: '<i>Italic</i>' } }
  }
];
const escapedDossierHtml = renderDossierListHTML(unsafeDossier);
assert.ok(!escapedDossierHtml.includes('<script>'), 'Must escape script tags in dossier title');
assert.ok(!escapedDossierHtml.includes('<img src=x>'), 'Must escape img tags in dossier page type');
assert.ok(escapedDossierHtml.includes('&lt;script&gt;alert(1)&lt;/script&gt;'), 'Must properly escape characters in dossier title');

console.log('✅ Side panel renderer, escaping, course matrix & dossier tests passed.');


