# Sample Course: Introduction to Data Ethics

This is a reference course scenario for testing the idstack pipeline. It includes
intentional quality gaps that /course-quality-review should catch.

## Manual Test Protocol

1. Start a fresh Claude Code session in an empty directory
2. Copy this file to the working directory
3. Run `/needs-analysis` — provide answers from the scenario below
4. Run `/learning-objectives` — verify it reads the manifest and references task analysis
5. Run `/course-quality-review` — verify it catches the intentional gaps listed below
6. Check `.idstack/project.json` — verify valid JSON with all sections populated

---

## Course Details

**Title:** Introduction to Data Ethics
**Subject:** Applied ethics for data science and analytics
**Requested by:** Department of Computer Science, undergraduate program committee
**Reason for request:** New state regulation requires data ethics training for all
graduates of data science programs starting Fall 2027.

## Organizational Context

The CS department has no existing ethics course. Currently, ethics is covered in a
single 50-minute guest lecture in the intro to data science course. Students have
reported feeling unprepared for ethical decisions in internships. Two employers
contacted the department after interns made questionable data handling decisions.

The department chair wants a full semester course. The dean wants a 4-week module
that can be embedded in existing courses. Budget: one adjunct instructor hire.

## Task Analysis

After completing this course, students should be able to:
- Identify potential ethical issues in a data science project (daily task for working data scientists)
- Evaluate a dataset for bias using a structured framework (weekly in practice, high criticality)
- Write a data ethics impact assessment for a proposed project (monthly, high criticality)
- Explain privacy regulations (GDPR, CCPA) to non-technical stakeholders (rare but high stakes)
- Design a data governance policy for a small team (rare, medium criticality)
- Recognize when to escalate an ethical concern to management (situational, high criticality)

Prerequisite knowledge: basic statistics, basic programming, familiarity with data
science workflows. No prior ethics coursework required.

Tools: Python/Jupyter for data analysis, institutional LMS (Canvas), video conferencing.

## Learner Profile

**Class size:** 60 students (medium)
**Prior knowledge:** Mixed. CS students have strong technical skills but no formal
ethics training. Some philosophy double-majors have ethics background but weak
technical skills.
**Motivation:** Primarily extrinsic (required for graduation). Some students
genuinely interested in AI ethics topics.
**Demographics:** Undergraduate juniors and seniors, 20-24 years old.
**Access constraints:** All students have laptops. One student uses a screen reader.
Campus Wi-Fi is reliable.

## Current Course Design (with intentional gaps)

**Modality:** Online asynchronous with 3 synchronous sessions per semester
**Timeline:** 15-week semester
**LMS:** Canvas

### Modules
1. Introduction to Ethics Frameworks (weeks 1-2)
2. Data Privacy and Regulation (weeks 3-5)
3. Algorithmic Bias (weeks 6-8)
4. Responsible AI (weeks 9-11)
5. Ethics in Practice (weeks 12-14)
6. Final Project (week 15)

### Assessments
- Weekly reading quizzes (multiple choice, auto-graded)
- Midterm exam (multiple choice + short answer)
- Final project: Write a data ethics impact assessment
- Discussion forum posts (participation credit, no rubric)

### Intentional Quality Gaps (for /course-quality-review to catch)

1. **Alignment gap:** ILO "evaluate a dataset for bias" (analyze/evaluate level) is only
   assessed via multiple-choice quiz (remember/understand level). The assessment doesn't
   match the objective.

2. **Low social presence:** Almost entirely asynchronous with only 3 sync sessions. Discussion
   forums have no structure or rubric. No group work. No peer interaction beyond forums.

3. **Missing accessibility:** No mention of alternative formats for video content. One
   student uses a screen reader but no accessibility audit has been done.

4. **Weak feedback design:** Quizzes are auto-graded with correctness feedback only
   (right/wrong). No elaborated feedback explaining why the answer is correct or incorrect.

5. **No learner support section:** Course doesn't mention tutoring, office hours,
   technical support, or where to go for help.

6. **Expertise reversal risk:** Course treats all students as novices (heavy scaffolding,
   step-by-step instructions) but some philosophy double-majors have advanced ethics
   knowledge. No differentiation pathway.
