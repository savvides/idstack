/**
 * Helper to clean and parse JSON responses from LLM API.
 */
function cleanJsonResponse(rawText) {
  let cleaned = rawText.trim();
  if (cleaned.startsWith('```json')) cleaned = cleaned.replace(/^```json/, '');
  if (cleaned.startsWith('```')) cleaned = cleaned.replace(/^```/, '');
  if (cleaned.endsWith('```')) cleaned = cleaned.replace(/```$/, '');
  return JSON.parse(cleaned.trim());
}

function parseAuditResponse(rawText) {
  return cleanJsonResponse(rawText);
}

function getDemoAuditResult(payload = {}) {
  const title = (payload && payload.title) ? payload.title : 'Course Material';
  const pageType = (payload && payload.pageType) ? payload.pageType : 'Assignment / Syllabus';

  return {
    summary: {
      bloomsLevel: 'Analyze (Level 4)',
      alignmentScore: 'Moderate (78%)',
      keyTakeaway: `[Demo Mode] Sample audit for "${title}" (${pageType}). Entering an API key in Settings unlocks live audits on any page.`
    },
    findings: [
      {
        severity: 'warning',
        tier: 'T1',
        citation: '[Assessment-8] Formative Feedback Matrix',
        observation: 'Assessment rubric lacks descriptive performance criteria for intermediate mastery levels.',
        evidence: 'Wisniewski et al. (2020) [T1 meta-analysis, d=0.48]: Elaborated feedback and rubric transparency significantly boost student self-regulation and achievement.',
        recommendation: 'Add concrete performance descriptors and milestone criteria for each grade band instead of generic labels.'
      },
      {
        severity: 'critical',
        tier: 'T2',
        citation: '[Alignment-3] Direct Constructive Alignment',
        observation: 'Learning objectives target analytical synthesis, but evaluation instruments only test lower-order recall.',
        evidence: 'Biggs (1996) & Liou et al. (2023) [T2 controlled trial]: Constructive misalignment between stated objectives and assessment formats leads to superficial learning strategies.',
        recommendation: 'Incorporate authentic problem-solving prompts and case analysis rather than purely multiple-choice recall questions.'
      },
      {
        severity: 'info',
        tier: 'T1',
        citation: '[Cognitive-2] Cognitive Load & Chunking',
        observation: 'Task instructions present multiple complex requirements in a single unsegmented block.',
        evidence: 'Costley et al. (2023) [T1 meta-analysis]: Segmenting complex instructional tasks into structured sequential phases reduces extraneous cognitive load.',
        recommendation: 'Format multi-step assignment guidelines into sequenced checklists or distinct milestone stages.'
      }
    ],
    improvedDraft: {
      title: 'Improved Rubric Draft (idstack Recommended)',
      content: `### Revised Task & Assessment Rubric for: ${title}

> **Note:** This is a sample evidence-based draft generated in demo mode. Entering an API key in Settings unlocks live audits on any page.

#### Analytical Task Prompt
Analyze the core case scenario and formulate a structured recommendation addressing:
1. Primary contributing factors identified in the evidence base.
2. Direct trade-offs between proposed intervention strategies.
3. A measurable evaluation plan for validating outcomes.

#### Evaluation Rubric (Elaborated Criteria)
| Criterion | Exemplary (Proficient) | Developing | Novice |
| :--- | :--- | :--- | :--- |
| **Evidence Application [T1]** | Synthesizes 3+ relevant empirical sources with clear justification. | References 1-2 sources with partial justification. | Makes claims without empirical citations. |
| **Analytical Rigor [T2]** | Rigorously evaluates trade-offs and alternative hypotheses. | Identifies trade-offs but lacks systematic comparison. | Describes facts without evaluating trade-offs. |
| **Actionable Strategy [T1]** | Proposes concrete, measurable milestones with validation metrics. | Proposes general steps without measurable metrics. | Vague or non-actionable suggestions. |`
    }
  };
}

function getDemoCourseAuditResult(payload = {}) {
  const title = payload.title || 'Sample Canvas Course';
  return {
    summary: {
      bloomsLevel: 'Analyze & Evaluate (Levels 4-5)',
      alignmentScore: 'Moderate (74%)',
      keyTakeaway: `[Course-Level Demo] Full-course audit for "${title}". Alignment gaps identified between week 1-4 recall quizzes and week 12 analytical capstone.`
    },
    findings: [
      {
        severity: 'critical',
        tier: 'T2',
        citation: '[Alignment-3] Direct Constructive Alignment',
        observation: 'Modules 1-6 assess solely lower-order factual recall, while the final course project demands high-order synthesis without intermediate scaffolding.',
        evidence: 'Biggs (1996) & Liou et al. (2023) [T2 controlled trial]: Abrupt jumps in cognitive demand without progressive assessment scaffolding increase failure rates.',
        recommendation: 'Introduce mid-semester milestone case studies in Module 4 to bridge the gap between quizzes and the final capstone.'
      },
      {
        severity: 'warning',
        tier: 'T1',
        citation: '[Cognitive-2] Cognitive Load & Spaced Practice',
        observation: 'Major assignment deadlines are clustered in Week 14-15 with no spaced formative checkpoints.',
        evidence: 'Carpenter et al. (2022) [T1 meta-analysis, d=0.61]: Distributing assessments across spaced intervals produces significantly higher long-term retention.',
        recommendation: 'Redistribute submission checkpoints into 3 progressive deliverables across weeks 6, 10, and 14.'
      },
      {
        severity: 'info',
        tier: 'T1',
        citation: '[Assessment-8] Formative Rubric Transparency',
        observation: 'Syllabus grading policy lacks explicit performance criteria for collaborative group deliverables.',
        evidence: 'Wisniewski et al. (2020) [T1 meta-analysis]: Pre-distribution of analytic rubrics with milestone criteria boosts student self-regulation and achievement.',
        recommendation: 'Publish the multi-tier analytic grading rubric during the initial module launch.'
      }
    ],
    improvedDraft: {
      title: 'Course-Wide Constructive Alignment Matrix',
      content: `### Course Alignment Matrix: ${title}

| Week / Module | Intended Learning Outcome | Formative Checkpoint [T1] | Summative Assessment [T2] |
| :--- | :--- | :--- | :--- |
| **Weeks 1-3** | Foundational Cell Structure | Spaced Knowledge Check (10 pts) | Module 1 Synthesis Quiz |
| **Weeks 4-7** | Enzyme Kinetics & Modeling | Case Problem Milestone 1 [T2] | Lab Protocol Analysis |
| **Weeks 8-11** | Experimental Troubleshooting | Peer Review Protocol [T1] | Milestone 2 Experimental Draft |
| **Weeks 12-15**| Autonomous Investigation | Scaffolded Capstone Consult | Final Research Capstone |`
    }
  };
}

module.exports = {
  cleanJsonResponse,
  parseAuditResponse,
  getDemoAuditResult,
  getDemoCourseAuditResult
};

