import assert from 'node:assert';
import { compileDossierToMarkdown, compileSingleAuditToMarkdown } from '../extension/shared/dossier-compiler.js';

// Test 1: Single Audit Markdown Compilation
const singleItem = {
  title: 'Lab 1: Enzymes',
  pageType: 'Canvas Assignment',
  url: 'https://canvas.instructure.com/courses/123/assignments/456',
  timestamp: '2026-08-16T10:00:00Z',
  result: {
    summary: {
      bloomsLevel: 'Analyze (Level 4)',
      alignmentScore: 'Moderate (75%)',
      keyTakeaway: 'Focus on rubric transparency.'
    },
    findings: [
      {
        severity: 'warning',
        tier: 'T1',
        citation: '[Assessment-8] Formative Feedback',
        observation: 'Rubric lacks milestone descriptors.',
        evidence: 'Wisniewski et al. (2020) [T1]: Rubrics boost self-regulation.',
        recommendation: 'Add milestone criteria.'
      }
    ],
    improvedDraft: {
      title: 'Improved Lab Rubric',
      content: '| Criterion | Proficient | Novice |\n| --- | --- | --- |'
    }
  }
};

const singleMd = compileSingleAuditToMarkdown(singleItem);
assert.ok(singleMd.includes('# idstack Instructional Design Audit: Lab 1: Enzymes'));
assert.ok(singleMd.includes('**Bloom\'s Demand:** Analyze (Level 4)'));
assert.ok(singleMd.includes('Wisniewski et al. (2020)'));
assert.ok(singleMd.includes('Improved Lab Rubric'));

// Test 2: Multi-Audit Dossier Compilation
const dossierItems = [
  singleItem,
  {
    title: 'Course Syllabus',
    pageType: 'Canvas Syllabus',
    url: 'https://canvas.instructure.com/courses/123/syllabus',
    timestamp: '2026-08-16T09:30:00Z',
    result: {
      summary: {
        bloomsLevel: 'Understand (Level 2)',
        alignmentScore: 'High (90%)',
        keyTakeaway: 'Clear policy structure.'
      },
      findings: [
        {
          severity: 'info',
          tier: 'T2',
          citation: '[Alignment-3] Direct Constructive Alignment',
          observation: 'Objectives align with module outcomes.',
          evidence: 'Biggs (1996) [T2]: Clear alignment supports deep learning.',
          recommendation: 'Maintain alignment across quizzes.'
        }
      ],
      improvedDraft: {
        title: 'Revised Objectives',
        content: '- Analyze core enzyme mechanisms.'
      }
    }
  }
];

const dossierMd = compileDossierToMarkdown(dossierItems, 'Biology 101: Cell Systems');
assert.ok(dossierMd.includes('# idstack Course Audit Dossier: Biology 101: Cell Systems'));
assert.ok(dossierMd.includes('**Total Audited Materials:** 2 components'));
assert.ok(dossierMd.includes('## Section 1: Lab 1: Enzymes'));
assert.ok(dossierMd.includes('## Section 2: Course Syllabus'));
assert.ok(dossierMd.includes('Wisniewski et al. (2020)'));
assert.ok(dossierMd.includes('Biggs (1996)'));

// Test 3: Edge cases (empty or null inputs)
assert.strictEqual(compileSingleAuditToMarkdown(null), '');
assert.strictEqual(compileSingleAuditToMarkdown({}), '');
const emptyDossierMd = compileDossierToMarkdown([], 'Empty Course');
assert.ok(emptyDossierMd.includes('*No audit materials in dossier.*'));
const nullDossierMd = compileDossierToMarkdown(null);
assert.ok(nullDossierMd.includes('*No audit materials in dossier.*'));

console.log('✅ Task 1 Dossier compiler tests passed.');
