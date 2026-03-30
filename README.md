# idstack

283 papers say elaborated feedback improves learning. Cognitive load theory has been replicated for 30 years. Constructive alignment measurably raises grades. The evidence is not the problem.

The problem is that none of your course design tools implement any of it.

idstack is an open source set of Claude Code skills that encode findings from 283 research papers into your actual workflow. Not a chatbot that summarizes papers. A design partner that checks your alignment matrix, flags cognitive load issues, classifies your objectives with Bloom's taxonomy, and tells you the evidence strength behind every recommendation.

Four skills. One shared project manifest that remembers your course across sessions. Every recommendation tagged with its evidence tier, from T1 (meta-analyses) to T5 (expert opinion), so you always know how strong the backing is.

Free, MIT licensed, open source.

## Quick start

1. Install idstack (30 seconds, see below)
2. Run `/course-import` on your Canvas/Blackboard/Moodle course
3. Run `/course-quality-review` to see what the evidence says
4. Stop there. You'll know if this is for you.

## See it work

```
You:    /course-import

idstack: How do you want to import your course?
         A) IMS Common Cartridge file (.imscc)
         B) Paste course documents
         C) Canvas API

You:    C — here's my Canvas URL and access token.

idstack: Connected. Pulling course data...
         Found: 12 modules, 8 assignments, 4 discussions, 6 outcomes.

         ## Import Quality Triage

         Found 4 flags during import:
         ⚠ 12 modules, only 4 have stated learning objectives
         ⚠ All 8 assessments are auto-graded quizzes (no rubrics)
           [Assessment-8] [T1] — elaborated feedback produces larger
           learning gains than correctness-only
         ⚠ No collaborative activities beyond discussion forums
           [Online-15] [T2] — low social presence predicts weaker outcomes
         ⚠ No accessibility information for video content

         6 objectives pre-classified with Bloom's taxonomy.
         12 modules mapped to task analysis.

         Manifest saved to .idstack/project.json.
         Run /course-quality-review for a full evidence-based audit.

You:    /course-quality-review

idstack: Reading your manifest... I have 12 modules, 6 objectives,
         and 8 assessments from your Canvas import.

         ## Course Quality Review

         **Overall Score: 62/100**

         ### QM Structural Review
         | Standard              | Status | Finding                    |
         |-----------------------|--------|----------------------------|
         | Course Overview       | pass   | Clear syllabus, nav set    |
         | Learning Objectives   | flag   | 8 modules lack objectives  |
         | Assessment            | flag   | No rubrics, no alignment   |
         | Instructional Materials| pass   | Materials current           |
         | Learning Activities   | flag   | No active learning design  |
         | Course Technology     | pass   | Tools used purposefully    |
         | Learner Support       | flag   | No support section found   |
         | Accessibility         | flag   | No alt formats for video   |

         ### Community of Inquiry Presence
         - Teaching Presence:  7/10 — strong content, weak facilitation
         - Social Presence:    3/10 — no group work, minimal peer interaction
         - Cognitive Presence: 5/10 — surface-level activities, no inquiry cycle

         This course meets 3 of 8 QM standards but scores 3/10 on social
         presence. Courses with low social presence show weaker learning
         outcomes in online settings [Online-15] [T2].

         ### Top 3 Recommendations
         1. Add rubrics to all assessments with elaborated feedback
            [Assessment-8] [T1] — Run /learning-objectives to align
         2. Design collaborative activities for at least 4 modules
            [Online-15] [T2]
         3. Add learner support section with office hours, tutoring,
            and technical help resources
```

You had a course in Canvas. Now you have an evidence-based audit with specific recommendations, evidence tiers, and cross-references to the skills that fix each issue. Two commands.

## Install — 30 seconds

**Requirement:** [Claude Code](https://claude.ai/code) (desktop app, web app, or CLI)

### Paste this into Claude Code. Claude does the rest.

> Install idstack: run **`git clone https://github.com/savvides/idstack.git ~/.claude/skills/idstack && cd ~/.claude/skills/idstack && ./setup`** then tell me it's installed and show me the available skills.

That's it. Claude clones the repo, runs setup, and confirms the skills are registered. No terminal knowledge required.

### Alternative install methods

<details>
<summary>Manual install with git</summary>

```bash
git clone https://github.com/savvides/idstack.git
cd idstack
./setup
```
</details>

<details>
<summary>Download ZIP (no git required)</summary>

1. Click the green "Code" button on GitHub, then "Download ZIP"
2. Unzip the file
3. Open Terminal (Mac) or PowerShell (Windows)
4. Navigate to the folder: `cd path/to/idstack`
5. Run: `./setup`
</details>

<details>
<summary>Project-scoped install (one project only)</summary>

```bash
./setup --local
```
</details>

You should see:
```
Installing idstack...
  linked: /course-import
  linked: /course-quality-review
  linked: /learning-objectives
  linked: /needs-analysis

idstack installed successfully.
Open Claude Code and try: /needs-analysis
```

## Your design team

idstack turns Claude Code into an evidence-based instructional design team. Each skill is a specialist.

| Skill | Your specialist | What they do |
|-------|----------------|--------------|
| `/needs-analysis` | **Needs Analyst** | Three-level assessment before you build anything. Organizational analysis (is training even the right intervention?), task analysis (what must learners do?), learner profiling (prior knowledge, not learning styles). Creates the project manifest. |
| `/learning-objectives` | **Curriculum Designer** | Writes measurable objectives with revised Bloom's taxonomy. Classifies on two dimensions (knowledge type + cognitive process). Bidirectional alignment check: does each objective have a matching activity AND assessment? Flags gaps. |
| `/course-import` | **LMS Bridge** | Imports your course from any LMS. Three input methods: IMS Common Cartridge (Canvas, Blackboard, Moodle, D2L), pasted documents, or Canvas API. Quick-scan quality flags, auto-maps modules to task analysis, pre-classifies objectives with Bloom's. |
| `/course-quality-review` | **Quality Auditor** | Full QM-aligned audit plus Community of Inquiry presence layer. 8 structural standards, 3 presence dimensions (teaching, social, cognitive), constructive alignment audit. Every finding cites its evidence tier. |

## The workflow

Each skill feeds into the next. The project manifest is the thread.

```
EXISTING COURSE                           NEW COURSE

/course-import                            /needs-analysis
  Import from Canvas/Blackboard/Moodle      Three-level needs assessment
  Quick-scan quality flags                  Is training the right intervention?
  Pre-classify objectives                   Task analysis + learner profile
        │                                          │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
              /learning-objectives
                Write measurable ILOs
                Bloom's classification
                Alignment check (ILO ↔ activity ↔ assessment)
                       │
                       ▼
             /course-quality-review
                QM structural audit (8 standards)
                CoI presence analysis
                Evidence-tiered recommendations
```

Any skill works independently. The pipeline adds context but isn't required.

## How it works

### The project manifest
idstack saves your design decisions in `.idstack/project.json` so each skill remembers your course context. You never edit this file directly. The skills manage it.

When you run `/course-import`, it creates the manifest with your course structure. When you run `/learning-objectives`, it reads the manifest and extends it with your objectives and alignment data. When you run `/course-quality-review`, it reads everything and audits the full chain.

### Evidence tiers
Every recommendation includes an evidence tier so you know how strong the backing is:

| Tier | What it means | Example |
|------|--------------|---------|
| **T1** | Meta-analyses and randomized controlled trials | "Elaborated feedback improves learning" (Wisniewski et al., 2020) |
| **T2** | Quasi-experimental studies with controls | "QM + CoI combination improves outcomes" (Swan et al., 2012) |
| **T3** | Systematic reviews of mixed evidence | "Multi-level needs analysis is necessary" (Ferreira & Abbad, 2013) |
| **T4** | Observational studies without comparison groups | "QM peer review improves course quality" (Zimmerman et al., 2020) |
| **T5** | Expert opinion and theoretical frameworks | "Constructive alignment improves learning" (Biggs, 1996) |

When the skill says "add elaborated feedback to your quizzes," it tells you that's T1 evidence from multiple meta-analyses, not someone's blog post.

### Using skills independently
Any skill works on its own. `/course-quality-review` works without a manifest by asking you questions directly. `/learning-objectives` works without a needs analysis. The pipeline adds context and makes recommendations sharper, but every skill is self-contained.

## The evidence base

idstack encodes findings from a literature synthesis of approximately 283 papers across 10 domains of instructional design research. The full citation list is in [evidence/references.md](evidence/references.md).

| Domain | Evidence Strength | Key Finding |
|--------|------------------|-------------|
| Cognitive Load Theory | Very strong (T1) | Manage working memory load through sequencing, segmenting, and integration |
| Multimedia Learning | Very strong (T1) | Spatial contiguity, signaling, and coherence reliably improve learning |
| Formative Assessment | Strong (T1) | Elaborated, timely feedback drives learning; correctness-only does not |
| Constructive Alignment | Moderate-Strong (T2) | Objectives, activities, and assessments must form a coherent chain |
| Online Course Quality | Moderate (T2-T4) | QM standards + CoI presence predicts outcomes beyond compliance |
| Needs Analysis | Weak-Moderate (T3) | Multi-level analysis is necessary but rarely done |

**Cross-domain principles** (appear in 3+ domains):
1. Alignment is non-negotiable
2. Expertise level modulates everything (what helps novices hurts experts)
3. Feedback quality matters more than feedback quantity
4. Cognitive load is the central design constraint
5. Context determines model selection (no universal "best" approach)

## FAQ

**Do I need to know how to code?**
No. You interact with idstack through conversation in Claude Code. It's a chat interface.

**What is Claude Code?**
Claude Code is Anthropic's coding tool. It's available as a [desktop app, web app, and CLI](https://claude.ai/code). You type slash commands like `/needs-analysis` and have a conversation. No programming required.

**Can I use this with Canvas?**
Yes. `/course-import` connects to Canvas via API or reads Canvas course exports (.imscc files). It also works with Blackboard, Moodle, and D2L through the IMS Common Cartridge format.

**What if I only want to run the quality review?**
That works. `/course-quality-review` asks you about your course directly if there's no manifest.

**Is my data safe?**
idstack runs locally on your machine. Course data stays in your project folder (`.idstack/project.json`). Nothing is sent to external servers by idstack itself. Claude Code's own privacy policy applies to the AI conversation.

**Can I edit the project manifest directly?**
You can, but let the skills manage it. If you do edit it, keep the JSON valid.

**How do I update idstack?**
If you installed with git: `cd path/to/idstack && git pull`
If you downloaded ZIP: download the latest version and run `./setup` again.

**Does idstack work offline?**
idstack itself is just text files. But it runs inside Claude Code, which requires an internet connection.

## Troubleshooting

**Skill not showing up?** Run setup again:
```bash
cd ~/.claude/skills/idstack && ./setup
```

**Can't import a .imscc cartridge?** Make sure the file is a valid ZIP. Try re-exporting from your LMS with "Course" selected (not just content).

**Canvas API says "token rejected"?** Generate a fresh token: Canvas -> Account -> Settings -> New Access Token. Tokens expire.

**Claude says it can't find idstack skills?** Make sure you've run `./setup` after cloning. The setup script creates the symlinks Claude Code needs to discover the skills.

## Contributing

Found a bug or have a suggestion? [Open an issue on GitHub](https://github.com/savvides/idstack/issues).

Want to add a new skill? The architecture is simple: create a directory with a SKILL.md file and run `./setup`. See the existing skills for the pattern. The full evidence synthesis supports 7 more skills beyond the current 4.

## License

MIT. Free forever. Go design something evidence-based.
