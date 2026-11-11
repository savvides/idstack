import { TIER_METADATA } from './evidence-base.js';
import { STE_RULES } from './ste-rules.js';

const TIER_SCALE = Object.entries(TIER_METADATA).map(([tier, m]) => `   ${tier}: ${m.description}`).join('\n');
// The side panel shows the model's text to people, so the model gets the
// writing rules that the skills obey.
const WRITING_STANDARD = `Obey the rules that follow when you write keyTakeaway, observation, evidence, recommendation and improvedDraft. Do not change JSON keys, severity and tier values, citations or quotations from the course.
${STE_RULES}`;

// The same checks and studies as /idstack:quick-check. Without a list, the
// model made up citation codes. test-evidence-labels.mjs checks each code,
// author, year and tier against evidence/references.md.
const ITEM_CHECKS = `   Learning objective: one measurable behavior; the cognitive level agrees with the task, not only with the verb. [Alignment-1] Biggs (1996) [T5], [Alignment-12] Larsen et al. (2022) [T4], [Alignment-14] Agarwal (2019) [T1]
   Quiz or test question: one clear problem in the stem; three options that learners can believe; no "all of the above"; feedback that explains the answer. [Assessment-23] Rodriguez (2005) [T1], [Assessment-24] Gierl et al. (2017) [T5], [Assessment-25] Yang et al. (2021) [T1]
   Rubric or assignment: criteria that describe quality; learners get the rubric before the task; feedback tells what to do next. [Assessment-19] Panadero et al. (2023) [T1], [Assessment-8] Wisniewski et al. (2020) [T1]
   Slide, video or media page: no text that repeats the narration; no decoration that does not teach; cues that show what is important. [Multimedia-9] Noetel et al. (2021) [T1], [Multimedia-21] Alpizar et al. (2020) [T1], [Multimedia-22] Sundararajan (2020) [T1]
   Activity or practice: worked examples for novices, problems for experienced learners; practice spread across time. [CogLoad-23] Barbieri et al. (2023) [T1], [CogLoad-21] Tetzlaff et al. (2025) [T1], [CogLoad-24] Mawson et al. (2025) [T1]
   Do not recommend learning styles. Prior knowledge is the difference that changes the design. [Learner-21] Simonsmeier et al. (2021) [T1]`;

export function buildAuditPrompt({ title, pageType, content = '' }) {
  return `You are idstack, an evidence-based instructional design co-pilot.
Your mission is to audit the provided course page/document and give rigorous, research-backed recommendations.

Target Document Title: "${title || 'Untitled Course Page'}"
Detected Document Type: ${pageType || 'Course Content'}

Document Content:
"""
${(content || '').slice(0, 10000)}
"""

Please audit this material against peer-reviewed instructional design evidence:
1. Classify learning objectives or implied cognitive depth using Bloom's Revised Taxonomy (Remember, Understand, Apply, Analyze, Evaluate, Create).
2. Check Constructive Alignment: Do activities and assessments match the stated or necessary cognitive depth?
3. Flag Cognitive Load, Elaborated Feedback gaps, and Accessibility considerations.
4. Use the checks for the type of item on the page. Cite only the studies in this list, with the code and the tier that the list gives. If no study in the list supports a finding, do not write the finding.
${ITEM_CHECKS}
5. Rate each recommendation with an evidence tier:
${TIER_SCALE}
6. Provide a ready-to-use, improved version (rewritten rubric, upgraded learning outcome verbs, or enhanced prompt).

You MUST respond strictly with valid JSON conforming to this schema:
{
  "summary": {
    "bloomsLevel": "Remember | Understand | Apply | Analyze | Evaluate | Create",
    "alignmentScore": "Strong | Moderate | Weak",
    "keyTakeaway": "Summary of the findings in one or two sentences"
  },
  "findings": [
    {
      "severity": "critical | warning | info",
      "tier": "T1 | T2 | T3 | T4 | T5",
      "citation": "[Code-N] Author (Year), copied from the list in step 4",
      "observation": "What is in the current material",
      "evidence": "What peer-reviewed research shows",
      "recommendation": "One clear change that idstack recommends"
    }
  ],
  "improvedDraft": {
    "title": "Recommended Rubric / Learning Objective / Assignment Prompt",
    "content": "Full markdown text that the instructor can paste into Canvas"
  }
}

${WRITING_STANDARD}`;
}

export function buildCourseAuditPrompt(courseData = {}) {
  const blocks = (courseData.assignments || [])
    .map((a, i) => `Assignment ${i+1}: ${a.title} (${a.points || 0} pts)\nDescription: ${(a.description || '').slice(0, 500)}`);
  // Whole assignment blocks (each description already cut to 500 characters)
  // up to a 20,000-char budget, and the header says how many
  // made it: a plain character cut ended mid-assignment under a header that
  // still counted every item. The budget keeps a 500-assignment course's
  // prompt, and so the model's response time, bounded.
  const total = blocks.length;
  let shown = 0;
  let assignmentsSummary = '';
  for (const block of blocks) {
    const next = shown ? `${assignmentsSummary}\n\n${block}` : block;
    if (next.length > 20000) break;
    assignmentsSummary = next;
    shown++;
  }

  return `You are an expert instructional designer and cognitive scientist using the idstack evidence base.
Perform a full-course Constructive Alignment audit (courseAudit) for the following course:

COURSE TITLE: ${courseData.title || 'Canvas Course'}
SYLLABUS & LEARNING OBJECTIVES:
${(courseData.syllabus || 'No syllabus provided').slice(0, 8000)}

COURSE ASSIGNMENTS & ASSESSMENTS (${total} items; ${shown} shown below, each description cut to 500 characters):
${assignmentsSummary}

Evaluate whether the assessment system constructively aligns with stated learning outcomes ([Alignment-1] Biggs (1996) [T5]).
Identify cognitive load bottlenecks ([CogLoad-4] Sweller (1994) [T5]), scaffolding gaps ([CogLoad-1] Costley et al. (2023) [T1]), and formative feedback quality ([Assessment-8] Wisniewski et al. (2020) [T1]).
Rate each finding's evidence tier on this scale:
${TIER_SCALE}

Respond with ONLY a valid JSON object matching this schema:
{
  "summary": {
    "bloomsLevel": "Bloom's level of the course (for example Apply / Analyze)",
    "alignmentScore": "High (90%) | Moderate (70%) | Low (40%)",
    "keyTakeaway": "Summary of the alignment of the full course in one or two sentences."
  },
  "findings": [
    {
      "severity": "critical" | "warning" | "info",
      "tier": "T1" | "T2" | "T3" | "T4" | "T5",
      "citation": "[Domain-ID] Citation Name",
      "observation": "What idstack found in the course syllabus and assignments.",
      "evidence": "Author (Year) [Tier description]: Empirical finding.",
      "recommendation": "One clear change to the curriculum that idstack recommends."
    }
  ],
  "improvedDraft": {
    "title": "Course Alignment & Scaffolding Matrix",
    "content": "Markdown formatted course roadmap and revised assessment scaffolding."
  }
}

${WRITING_STANDARD}`;
}

