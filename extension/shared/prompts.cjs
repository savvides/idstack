const { EVIDENCE_DOMAINS, TIER_METADATA } = require('./evidence-base.cjs');

function buildAuditPrompt({ title, pageType, content = '' }) {
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
4. Rate each recommendation with an evidence tier [T1] to [T5].
5. Provide a ready-to-use, improved version (rewritten rubric, upgraded learning outcome verbs, or enhanced prompt).

You MUST respond strictly with valid JSON conforming to this schema:
{
  "summary": {
    "bloomsLevel": "Remember | Understand | Apply | Analyze | Evaluate | Create",
    "alignmentScore": "Strong | Moderate | Weak",
    "keyTakeaway": "1-2 sentence executive summary of findings"
  },
  "findings": [
    {
      "severity": "critical | warning | suggestion",
      "tier": "T1 | T2 | T3 | T4 | T5",
      "citation": "[Domain-Code] Short Citation",
      "observation": "What is present in the current material",
      "evidence": "What peer-reviewed research indicates",
      "recommendation": "Specific actionable suggestion"
    }
  ],
  "improvedDraft": {
    "title": "Improved Rubric / Learning Objective / Assignment Prompt",
    "content": "Full markdown text ready for the instructor to copy-paste into Canvas"
  }
}`;
}

function buildCourseAuditPrompt(courseData = {}) {
  const assignmentsSummary = (courseData.assignments || [])
    .map((a, i) => `Assignment ${i+1}: ${a.title} (${a.points || 0} pts)\nDescription: ${(a.description || '').slice(0, 500)}`)
    .join('\n\n');

  return `You are an expert instructional designer and cognitive scientist using the idstack evidence base.
Perform a full-course Constructive Alignment audit (courseAudit) for the following course:

COURSE TITLE: ${courseData.title || 'Canvas Course'}
SYLLABUS & LEARNING OBJECTIVES:
${(courseData.syllabus || 'No syllabus provided').slice(0, 8000)}

COURSE ASSIGNMENTS & ASSESSMENTS (${(courseData.assignments || []).length} items):
${assignmentsSummary.slice(0, 20000)}

Evaluate whether the assessment system constructively aligns with stated learning outcomes (Biggs 1996 [T2], Liou et al. 2023 [T2]).
Identify cognitive load bottlenecks (Sweller 2011 [T1]), scaffolding gaps (Wood et al. 1976 [T2]), and formative feedback quality (Wisniewski et al. 2020 [T1]).

Respond with ONLY a valid JSON object matching this schema:
{
  "summary": {
    "bloomsLevel": "Overall Cognitive Demand (e.g. Apply / Analyze)",
    "alignmentScore": "High (90%) | Moderate (70%) | Low (40%)",
    "keyTakeaway": "1-2 sentence executive summary of course-wide curriculum alignment."
  },
  "findings": [
    {
      "severity": "critical" | "warning" | "info",
      "tier": "T1" | "T2" | "T3" | "T4" | "T5",
      "citation": "[Domain-ID] Citation Name",
      "observation": "What was identified across the course syllabus and assignments.",
      "evidence": "Author (Year) [Tier description]: Empirical finding.",
      "recommendation": "Concrete actionable curriculum fix."
    }
  ],
  "improvedDraft": {
    "title": "Course Alignment & Scaffolding Matrix",
    "content": "Markdown formatted course roadmap and revised assessment scaffolding."
  }
}`;
}

module.exports = {
  EVIDENCE_DOMAINS,
  TIER_METADATA,
  buildAuditPrompt,
  buildCourseAuditPrompt
};
