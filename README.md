# idstack

Decades of research say elaborated feedback improves learning. Cognitive load theory has been replicated for 30 years. Constructive alignment measurably raises grades. The evidence is strong, but most course design tools don't make it easy to apply.

idstack is an open source set of Claude Code skills that bring peer-reviewed instructional design research into your actual workflow. Not a chatbot that summarizes papers. A design partner that checks your alignment matrix, flags cognitive load issues, classifies your objectives with Bloom's taxonomy, and tells you the evidence strength behind every recommendation.

Skills covering the full lifecycle: analyze, design, build, export. One shared project manifest that remembers your course across sessions. Every recommendation tagged with its evidence tier, from T1 (meta-analyses) to T5 (expert opinion), so you always know how strong the backing is.

Free, MIT licensed, open source. [Have feedback or a feature request?](https://forms.gle/6LDgDD1M6WWyYvME8)

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
         D) PDF or document file
         E) SCORM package (.zip)

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
  linked: /accessibility-review
  linked: /assessment-design
  linked: /course-builder
  linked: /course-export
  linked: /course-import
  linked: /course-quality-review
  linked: /learning-objectives
  linked: /needs-analysis
  linked: /red-team

idstack installed successfully.

  Have an existing course?
    /course-import → /course-quality-review

  Starting fresh?
    /needs-analysis

  All 9 skills: https://idstack.org
```

## Your design team

idstack turns Claude Code into an evidence-based instructional design team. Each skill is a specialist.

| Skill | Your specialist | What they do |
|-------|----------------|--------------|
| `/needs-analysis` | **Needs Analyst** | Three-level assessment before you build anything. Organizational analysis (is training even the right intervention?), task analysis (what must learners do?), learner profiling (prior knowledge, not learning styles). Creates the project manifest. |
| `/learning-objectives` | **Curriculum Designer** | Writes measurable objectives with revised Bloom's taxonomy. Classifies on two dimensions (knowledge type + cognitive process). Bidirectional alignment check: does each objective have a matching activity AND assessment? Flags gaps. |
| `/assessment-design` | **Assessment Architect** | Designs assessments aligned to Bloom's levels with evidence-based rubrics and feedback strategies. Applies Nicol's 7 principles of good feedback. Builds formative checkpoints before summative assessments. |
| `/course-import` | **LMS Bridge** | Imports your course from any LMS or authoring tool. Five input methods: IMS Common Cartridge, pasted documents, Canvas API, PDF upload (Articulate Rise, Storyline), or SCORM package. Quick-scan quality flags, auto-maps modules to task analysis, pre-classifies objectives with Bloom's. |
| `/course-builder` | **Content Generator** | Generates complete course content from the manifest: syllabus, module pages, assignment descriptions, and rubric documents. Content follows cognitive load principles and adapts to learner expertise level. |
| `/course-export` | **LMS Publisher** | Exports to any LMS. Generates IMS Common Cartridge (.imscc), SCORM 1.2 packages, or pushes directly to Canvas via API. The output IS the course. |
| `/course-quality-review` | **Quality Auditor** | Full QM-aligned audit plus Community of Inquiry presence layer. 8 structural standards, 3 presence dimensions (teaching, social, cognitive), constructive alignment audit. Every finding cites its evidence tier. |
| `/accessibility-review` | **Accessibility Reviewer** | WCAG 2.1 AA compliance audit plus Universal Design for Learning (UDL 3.0) enhancement review. Two-tier output: "Must Fix" for accessibility violations, "Should Improve" for UDL recommendations. Scores accessibility 0-100. |
| `/red-team` | **Adversarial Auditor** | Assumes your course is broken and tries to prove it. Five dimensions: alignment stress test, evidence verification, cognitive load analysis, learner persona simulation, prerequisite chain integrity. Produces a confidence score. |

## The workflow

Each skill feeds into the next. The project manifest is the thread.

```
EXISTING COURSE                           NEW COURSE

/course-import                            /needs-analysis
  IMS Cartridge, SCORM, PDF, Canvas API     Three-level needs assessment
  Quick-scan quality flags                  Is training the right intervention?
  Pre-classify objectives                   Task analysis + learner profile
        │                                          │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
              /learning-objectives
                Write measurable ILOs
                Bloom's classification
                Alignment check
                       │
                       ▼
              /assessment-design
                Design assessments per Bloom's level
                Evidence-based rubrics + feedback
                Formative checkpoints
                       │
                       ▼
              /course-builder
                Generate syllabus, modules, assignments
                Content adapts to learner expertise
                       │
                       ▼
             /course-quality-review
                QM structural audit (8 standards)
                CoI presence analysis
                Evidence-tiered recommendations
                       │
                       ▼
             /accessibility-review
                WCAG 2.1 AA compliance
                UDL 3.0 enhancement
                Accessibility score (0-100)
                       │
                       ▼
                  /red-team
                Adversarial stress test
                Persona simulation
                Confidence score (0-100)
                       │
                       ▼
              /course-export
                IMS Common Cartridge (.imscc)
                SCORM 1.2 package
                or Canvas API push
```

Any skill works independently. The pipeline adds context but isn't required.

## Architecture

```
+-------------------------------------------------------+
|                     Claude Code                        |
|                                                        |
|  +-----------------------------------------------+    |
|  |                  9 Skills                      |    |
|  |   Each: SKILL.md (YAML frontmatter +           |    |
|  |   evidence-based conversational workflow)       |    |
|  +------------+-----------------------+-----------+    |
|               |                       |                |
|        reads/writes                cites               |
|               |                       |                |
|  +------------v------+  +------------v------------+   |
|  | .idstack/         |  | evidence/               |   |
|  | project.json      |  | references.md           |   |
|  | (manifest)        |  | (11 domains, T1-T5)     |   |
|  +-------------------+  +-------------------------+   |
|                                                        |
|  ./setup  bin/idstack-migrate                          |
|  bin/idstack-update-check  test/smoke-test.sh          |
+-------------------------------------------------------+
```

Skills are plain Markdown files. No build step, no dependencies. `./setup` creates symlinks so Claude Code discovers the skills. Each skill reads the shared manifest, runs its evidence-based workflow, and writes back its section. The pipeline adds context but every skill also works standalone.

## How it works

### The project manifest
idstack saves your design decisions in `.idstack/project.json` so each skill remembers your course context. You never edit this file directly. The skills manage it.

When you run `/course-import`, it creates the manifest with your course structure. When you run `/learning-objectives`, it reads the manifest and extends it with objectives and alignment data. `/assessment-design` adds rubrics and feedback strategies. `/course-builder` generates the actual content. `/course-quality-review` audits the full chain. `/course-export` packages it for your LMS. Each skill reads what came before and adds its layer.

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

idstack encodes findings from a literature synthesis spanning multiple domains of instructional design research. The full citation list is in [evidence/references.md](evidence/references.md).

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

**Can I use this with Articulate Rise?**
Yes. Export your Rise course as a PDF (hover over the course card > `...` > Download as PDF), then run `/course-import` and choose "PDF or document file." Give it the file path and it reads the PDF directly, extracts the course structure, and maps it to the project manifest. From there, every skill works: quality review, accessibility audit, red team, everything. Note: interactive elements like Storyline blocks and flashcards don't render in PDFs, but course structure, objectives, and assessment descriptions come through fine.

**What if I only want to run the quality review?**
That works. `/course-quality-review` asks you about your course directly if there's no manifest.

**Is my data safe?**
idstack runs locally on your machine. Course data stays in your project folder (`.idstack/project.json`). Nothing is sent to external servers by idstack itself. Claude Code's own privacy policy applies to the AI conversation.

**Can I edit the project manifest directly?**
You can, but let the skills manage it. If you do edit it, keep the JSON valid.

**How do I update idstack?**
idstack updates automatically. When you run any skill, it checks for updates and pulls the latest version in the background. You'll see "idstack updated to the latest version" and the skill continues without interruption. If auto-update fails, it'll tell you how to update manually: `cd ~/.claude/skills/idstack && git pull && ./setup`
If you downloaded ZIP: download the latest version and run `./setup` again.

**How do I request a feature or report a bug?**
[Fill out this form](https://forms.gle/6LDgDD1M6WWyYvME8). No GitHub account needed. If you have a GitHub account, you can also [open an issue](https://github.com/savvides/idstack/issues).

**Does idstack work offline?**
idstack itself is just text files. But it runs inside Claude Code, which requires an internet connection.

## Troubleshooting

**Skill not showing up?** Claude Code loads skills at session start. If you installed while Claude Code was running, restart it (close and reopen). If that doesn't help, run setup again:
```bash
cd ~/.claude/skills/idstack && ./setup
```

**Can't import a .imscc cartridge?** Make sure the file is a valid ZIP. Try re-exporting from your LMS with "Course" selected (not just content).

**Canvas API says "token rejected"?** Generate a fresh token: Canvas -> Account -> Settings -> New Access Token. Tokens expire.

**Claude says it can't find idstack skills?** Make sure you've run `./setup` after cloning. The setup script creates the symlinks Claude Code needs to discover the skills.

## Contributing

Have feedback or a feature request? [Fill out this form](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed.

Found a bug? You can also [open an issue on GitHub](https://github.com/savvides/idstack/issues).

Want to add a new skill? See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide. The architecture is simple: create a directory with a SKILL.md file and run `./setup`.

## More

- [idstack.org](https://idstack.org) — landing page
- [CHANGELOG.md](CHANGELOG.md) — full version history
- [ROADMAP.md](ROADMAP.md) — what's coming next
- [Why AI-native?](docs/why-ai-native.md) — why idstack is built this way

## License

MIT. Free forever. Go design something evidence-based.
