/**
 * Helper to clean and parse JSON responses from LLM API.
 */
export function cleanJsonResponse(rawText) {
  let cleaned = rawText.trim();
  if (cleaned.startsWith('```json')) cleaned = cleaned.replace(/^```json/, '');
  if (cleaned.startsWith('```')) cleaned = cleaned.replace(/^```/, '');
  if (cleaned.endsWith('```')) cleaned = cleaned.replace(/```$/, '');
  return JSON.parse(cleaned.trim());
}

export function parseAuditResponse(rawText) {
  return cleanJsonResponse(rawText);
}

export function getDemoAuditResult(payload = {}) {
  const title = (payload && payload.title) ? payload.title : 'Course Material';
  const pageType = (payload && payload.pageType) ? payload.pageType : 'Assignment / Syllabus';

  return {
    summary: {
      bloomsLevel: 'Analyze (Level 4)',
      alignmentScore: 'Moderate (78%)',
      keyTakeaway: `[Demo Mode] This is a sample audit for "${title}" (${pageType}). If you save a Google AI Studio API key in Settings, idstack audits the text of each page.`
    },
    findings: [
      {
        severity: 'warning',
        tier: 'T1',
        citation: '[Assessment-8] Formative Feedback Matrix',
        observation: 'The assessment rubric does not give performance criteria for the middle levels of mastery.',
        evidence: 'Wisniewski et al. (2020) [T1 meta-analysis, d=0.48]: Elaborated feedback and clear rubrics increase student self-regulation and achievement.',
        recommendation: 'idstack recommends that you replace the general labels of each grade band with clear performance descriptors and milestone criteria.'
      },
      {
        severity: 'critical',
        tier: 'T5',
        citation: '[Alignment-1] Direct Constructive Alignment',
        observation: 'Learning objectives are at the analysis and synthesis levels, but the assessments measure only lower-order recall.',
        evidence: 'Biggs (1996) [T5]: If the assessments do not align with the learning objectives, students use surface learning strategies.',
        recommendation: 'idstack recommends that you add authentic problem-solving prompts and case analysis, not only multiple-choice recall questions.'
      },
      {
        severity: 'info',
        tier: 'T1',
        citation: '[CogLoad-1] Cognitive Load & Chunking',
        observation: 'The task instructions give many complex conditions in one long paragraph that has no segments.',
        evidence: 'Costley et al. (2023) [T1]: Segmentation of complex tasks into a sequence of steps decreases extraneous cognitive load.',
        recommendation: 'idstack recommends that you put multi-step assignment instructions into a numbered checklist or into milestone steps.'
      }
    ],
    improvedDraft: {
      title: 'Recommended Rubric Draft',
      content: `### Recommended Task & Assessment Rubric for: ${title}

> **Note:** This is a sample draft from demo mode. If you save a Google AI Studio API key in Settings, idstack audits the text of each page.

#### Analysis Task Prompt
Analyze the case scenario. Then write a recommendation that includes these parts:
1. The primary causes that the evidence shows.
2. The trade-offs between the intervention strategies that you recommend.
3. A measurable evaluation plan for the outcomes.

#### Evaluation Rubric (Elaborated Criteria)
| Criterion | Exemplary (Proficient) | Developing | Novice |
| :--- | :--- | :--- | :--- |
| **Evidence Application [T1]** | Synthesizes three or more related research sources and gives a clear justification. | Uses one or two sources and gives some justification. | Makes claims without research citations. |
| **Analysis Quality [T2]** | Evaluates all trade-offs and alternative hypotheses carefully. | Identifies trade-offs but does not compare them carefully. | Gives facts but does not evaluate trade-offs. |
| **Action Plan [T1]** | Gives clear, measurable milestones and a metric for each milestone. | Gives general steps without measurable metrics. | Gives recommendations that are not clear or not possible to use. |`
    }
  };
}

export function getDemoCourseAuditResult(payload = {}) {
  const title = payload.title || 'Sample Canvas Course';
  return {
    summary: {
      bloomsLevel: 'Analyze & Evaluate (Levels 4-5)',
      alignmentScore: 'Moderate (74%)',
      keyTakeaway: `[Course-Level Demo] This is a full-course audit for "${title}". The audit found alignment problems between the recall quizzes in weeks 1-4 and the analysis capstone in week 12.`
    },
    findings: [
      {
        severity: 'critical',
        tier: 'T5',
        citation: '[Alignment-1] Direct Constructive Alignment',
        observation: 'Modules 1-6 assess only lower-order factual recall. The last course project assesses higher-order synthesis, and no scaffold prepares students for it.',
        evidence: 'Biggs (1996) [T5]: In constructive alignment, each assessment must measure the cognitive level that its learning outcome names.',
        recommendation: 'idstack recommends that you add mid-semester milestone case studies in Module 4 to connect the quizzes and the capstone.'
      },
      {
        severity: 'warning',
        tier: 'T1',
        citation: '[CogLoad-6] Cognitive Load & Spaced Practice',
        observation: 'The deadlines for the primary assignments are together in weeks 14-15. The course has no spaced formative checkpoints.',
        evidence: 'Chen et al. (2018) [T1]: Distributed practice gives better long-term retention than massed practice of the same content in one session.',
        recommendation: 'idstack recommends that you divide the submissions into 3 deliverables in weeks 6, 10 and 14. Each deliverable adds to the one before it.'
      },
      {
        severity: 'info',
        tier: 'T1',
        citation: '[Assessment-8] Formative Rubric Transparency',
        observation: 'The grading policy in the syllabus does not give clear performance criteria for collaborative group deliverables.',
        evidence: 'Wisniewski et al. (2020) [T1 meta-analysis]: If students get analytic rubrics with milestone criteria before the task, their self-regulation and achievement increase.',
        recommendation: 'idstack recommends that you publish the multi-level analytic grading rubric when the first module opens.'
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
| **Weeks 12-15**| Autonomous Investigation | Capstone Check with Scaffold | Last Research Capstone |`
    }
  };
}

