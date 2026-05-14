# idstack

> **Status: beta.** Skills work end-to-end and ship behind a versioned plugin (`v2.5.0`), but expect rough edges and breaking changes between minor versions while we shake out the rest of the workflow with real instructional designers. [Tell us what's broken or missing.](https://forms.gle/6LDgDD1M6WWyYvME8)

> **New in v2.5.0:** native support for **OpenAI Codex CLI** alongside Claude Code. Same 11 skills, same evidence base, same `.idstack/` manifest. Run `./setup` and idstack auto-detects which CLIs you have installed. (Gemini CLI on the v2.6 roadmap.)

Decades of research say elaborated feedback improves learning. Cognitive load theory has been replicated for 30 years. Constructive alignment measurably raises grades. The evidence is strong, but most course design tools don't make it easy to apply.

idstack is an open source set of skills for evidence-based instructional design that bring peer-reviewed research into your actual workflow. Runs in Claude Code and Codex CLI. Not a chatbot that summarizes papers — a design partner that checks your alignment matrix, flags cognitive load issues, classifies your objectives with Bloom's taxonomy, and tells you the evidence strength behind every recommendation.

Skills covering the full lifecycle: analyze, design, build, export. One shared project manifest that remembers your course across sessions. Every recommendation tagged with its evidence tier, from T1 (meta-analyses) to T5 (expert opinion), so you always know how strong the backing is.

Free, MIT licensed, open source. [Have feedback or a feature request?](https://forms.gle/6LDgDD1M6WWyYvME8)

## Quick start

1. Install idstack (30 seconds, see below)
2. Run `/idstack:course-import` on your Canvas/Blackboard/Moodle course
3. Run `/idstack:course-quality-review` to see what the evidence says
4. Stop there. You'll know if this is for you.

## See it work

```
You:    /idstack:course-import

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
         Run /idstack:course-quality-review for a full evidence-based audit.

You:    /idstack:course-quality-review

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

You had a course in Canvas. Now you have an evidence-based audit with specific recommendations, evidence tiers, and cross-references to the skills that fix each issue. Two commands. Or just run `/idstack:pipeline` and it chains the 8-skill linear pipeline automatically (`course-import` branches in for existing courses; `learn` is a separate cross-project memory utility — those two sit outside the linear chain, which is why pipeline runs 8 of the 11 skills).

## Install — 30 seconds

**Requirement:** [Claude Code](https://claude.ai/code) (desktop app, web app, or CLI).

Paste this into your terminal:

```bash
git clone https://github.com/savvides/idstack.git
cd idstack
./setup
```

`./setup` registers the repo as a Claude Code plugin marketplace and installs it. Restart Claude Code if it was already running — plugins load at session start. You should see `/idstack:<skill>` commands in the slash picker.

### Alternative install methods

<details>
<summary>Let Claude Code do it for you</summary>

If you'd rather not touch the terminal, paste this into Claude Code:

> Install idstack: run `git clone https://github.com/savvides/idstack.git && cd idstack && ./setup`, then tell me it's installed and show me the available skills.

Claude clones the repo, runs setup, and confirms the skills are registered.
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
  linked: /idstack → /path/to/idstack

idstack installed successfully.

  Usage: /idstack:<skill>

  Have an existing course?
    /idstack:course-import → /idstack:course-quality-review

  Starting fresh?
    /idstack:needs-analysis

  Run the full pipeline:
    /idstack:pipeline
```

## Your design team

idstack turns Claude Code into an evidence-based instructional design team. Each skill is a specialist. All invoked via `/idstack:<skill>`.

| Skill | Your specialist | What they do |
|-------|----------------|--------------|
| `/idstack:needs-analysis` | **Needs Analyst** | Three-level assessment before you build anything. Organizational analysis (is training even the right intervention?), task analysis (what must learners do?), learner profiling (prior knowledge, not learning styles). Creates the project manifest. Auto-detects imported courses and runs a design-fit check instead of the training-decision gate. Writes `.idstack/exports/<course-slug>/needs-analysis.html`. |
| `/idstack:learning-objectives` | **Curriculum Designer** | Writes measurable objectives with revised Bloom's taxonomy. Classifies on two dimensions (knowledge type + cognitive process). Bidirectional alignment check: does each objective have a matching activity AND assessment? Flags gaps. Writes `.idstack/exports/<course-slug>/learning-objectives.html`. |
| `/idstack:assessment-design` | **Assessment Architect** | Designs assessments aligned to Bloom's levels with evidence-based rubrics and feedback strategies. Applies Nicol's 7 principles of good feedback. Builds formative checkpoints before summative assessments. For imported courses, switches to audit mode: classifies existing rubric criteria on Bloom's, compares to ILOs, and surfaces alignment gaps without proposing new assessments. Writes `.idstack/exports/<course-slug>/assessment-design.html`. |
| `/idstack:course-import` | **LMS Bridge** | Imports your course from any LMS or authoring tool. Five input methods: IMS Common Cartridge, pasted documents, Canvas API, PDF upload (Articulate Rise, Storyline), or SCORM package. Quick-scan quality flags, auto-maps modules to task analysis, pre-classifies objectives with Bloom's. Writes `.idstack/exports/<course-slug>/course-import.html`. |
| `/idstack:course-builder` | **Content Generator** | Generates complete course content from the manifest: syllabus, module pages, assignment descriptions, and rubric documents. Content follows cognitive load principles. Includes adversarial spec review (auto-validates alignment). For imported courses, switches to gap-fill mode: generates only the artifacts upstream skills flagged as missing, instead of regenerating what already exists in the cartridge. Writes `.idstack/exports/<course-slug>/course-builder.html`. |
| `/idstack:course-export` | **LMS Publisher** | Exports to any LMS. Generates IMS Common Cartridge (.imscc), SCORM 1.2 packages, or pushes directly to Canvas via API. Shows readiness dashboard before export. The output IS the course. |
| `/idstack:course-quality-review` | **Quality Auditor** | Full QM-aligned audit plus Community of Inquiry presence layer. 8 structural standards, 3 presence dimensions (teaching, social, cognitive), constructive alignment audit. Parallel sub-agents on Claude Code for speed. Writes `.idstack/exports/<course-slug>/course-quality-review.html`. |
| `/idstack:accessibility-review` | **Accessibility Reviewer** | WCAG 2.1 AA compliance audit plus Universal Design for Learning (UDL 3.0) enhancement review. Two-tier output: "Must Fix" for accessibility violations, "Should Improve" for UDL recommendations. Parallel sub-agents for WCAG and UDL. Writes `.idstack/exports/<course-slug>/accessibility-review.html`. |
| `/idstack:red-team` | **Adversarial Auditor** | Assumes your course is broken and tries to prove it. Runs in a clean-context sub-agent so the audit can't inherit build-bias from the parent. Five dimensions in parallel: alignment stress test, evidence verification, cognitive load analysis, learner persona simulation, prerequisite chain integrity. Writes `.idstack/exports/<course-slug>/red-team.html` and returns to the parent for a triage-and-fix loop (Critical / Critical+High / All / Skip). Produces a confidence score. |
| `/idstack:pipeline` | **Orchestrator** | Chains the 8-skill linear pipeline automatically. Auto-skips completed skills. Shows pipeline status. Pause anytime, resume later. Produces `.idstack/exports/<course-slug>/index.html` — a branded course dashboard linking to every per-skill report, with readiness scores, top recurring issues, evidence themes, and where to start. Open in any browser. |
| `/idstack:learn` | **Memory Manager** | Search, list, delete, promote, and export project learnings. Supports cross-project intelligence. |

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

Any skill works independently. Run `/idstack:pipeline` to chain them all, or invoke any skill directly. The pipeline adds context but isn't required.

## Architecture

```
+-------------------------------------------------------+
|                     Claude Code                        |
|                                                        |
|  +-----------------------------------------------+    |
|  |                 11 Skills (plugin)              |    |
|  |   Each: SKILL.md.tmpl -> SKILL.md              |    |
|  |   (YAML frontmatter + shared preamble +        |    |
|  |    evidence-based conversational workflow)      |    |
|  +------+----------------+----------------+------+    |
|         |                |                |           |
|   reads/writes      reads on start     cites          |
|         |                |                |           |
|  +------v------+  +-----v---------+  +---v--------+  |
|  | .idstack/   |  | .idstack/     |  | evidence/  |  |
|  | project.json|  | timeline.jsonl|  | references |  |
|  | (manifest)  |  | learnings.jsonl  | (T1-T5)    |  |
|  +-------------+  +---------------+  +------------+  |
|                                                        |
|  +-------------------------------------------+        |
|  | .idstack/exports/<course-slug>/           |        |
|  |   index.html              (dashboard)     |        |
|  |   <skill>.html            (per-skill)     |        |
|  |   assets/idstack.css      (brand)         |        |
|  |   course-export.imscc     (LMS package)   |        |
|  |   scorm-export.zip        (LMS package)   |        |
|  | Visual contract: templates/report.html.tmpl       |
|  | Content contract: templates/report-format.md      |
|  +-------------------------------------------+        |
|                                                        |
|  templates/preamble.md  templates/report-format.md    |
|  templates/report.html.tmpl  templates/index.html.tmpl|
|  templates/assets/idstack.css                          |
|  bin/idstack-gen-skills  bin/idstack-manifest-merge   |
|  bin/idstack-migrate  bin/idstack-timeline-log        |
|  bin/idstack-learnings-log  bin/idstack-status        |
|  bin/idstack-slugify  bin/idstack-update-check        |
+-------------------------------------------------------+
```

Skills are plain Markdown files generated from templates. No build step for users, no dependencies. `./setup` registers the repo as a Claude Code plugin marketplace and installs it, which is what gives the namespaced `/idstack:<skill>` commands. Users invoke skills via `/idstack:<skill>`. Each skill reads the shared manifest and session history, runs its evidence-based workflow, writes back its section, and logs the session to the timeline. The pipeline adds context but every skill also works standalone.

## How it works

### The project manifest
idstack saves your design decisions in `.idstack/project.json` so each skill remembers your course context. You never edit this file directly. The skills manage it.

When you run `/idstack:course-import`, it creates the manifest with your course structure. When you run `/idstack:learning-objectives`, it reads the manifest and extends it with objectives and alignment data. `/idstack:assessment-design` adds rubrics and feedback strategies. `/idstack:course-builder` generates the actual content. `/idstack:course-quality-review` audits the full chain. `/idstack:course-export` packages it for your LMS. Each skill reads what came before and adds its layer. Or run `/idstack:pipeline` and it chains them all automatically.

### How idstack reports back to you
idstack is a collaborator, not a course builder. When a skill finishes, it produces two artifacts:

- **Branded HTML report** at `.idstack/exports/<course-slug>/<skill>.html` — the human view. Open it in any browser. Every finding follows the same structure: *what we saw* in your course, *what the evidence says* (with a citation tag like `[Assessment-8] [T1]`), *why it matters* for learners, and *what to consider* changing. Suggestions, not directives — the designer owns the course; idstack offers the read.
- **Manifest section** at `.idstack/project.json` — the system view. Same findings in JSON so other skills can read and act on them.

The visual contract lives in [`templates/report.html.tmpl`](templates/report.html.tmpl) (the HTML skeleton) and [`templates/assets/idstack.css`](templates/assets/idstack.css) (the branded stylesheet). The content contract is in [`templates/report-format.md`](templates/report-format.md). Re-running a skill overwrites its report; the timeline at `.idstack/timeline.jsonl` carries the run history.

Every per-course artifact — every per-skill report, the pipeline dashboard, and any LMS packages — lands in the same self-describing folder: `.idstack/exports/<course-slug>/`. The `<course-slug>` is derived from your course's `project_name` (lowercased, kebab-cased). Zip the folder to hand the whole deliverable to a stakeholder.

When you run `/idstack:pipeline`, it also produces a course dashboard at `.idstack/exports/<course-slug>/index.html` — readiness scores, links to every per-skill report, top issues that recur across multiple stages, evidence themes, and where to start. Open this first if you've run multiple skills and want one entry point that synthesizes the whole audit.

### Course memory
idstack remembers your design sessions. Each skill logs what it did to `.idstack/timeline.jsonl`, and project-specific discoveries (LMS quirks, format issues, course patterns) are stored in `.idstack/learnings.jsonl`. When you start a new session, idstack tells you where you left off: quality score trends, which skills have been completed, and what the next step is. Run `bin/idstack-status` anytime to see your course health dashboard.

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

idstack encodes findings from a literature synthesis spanning 11 domains of instructional design research. The full citation list (all 11 domains, 5 evidence tiers) is in [evidence/references.md](evidence/references.md). A selection:

| Domain | Evidence Strength | Key Finding |
|--------|------------------|-------------|
| Cognitive Load Theory | Very strong (T1) | Manage working memory load through sequencing, segmenting, and integration |
| Multimedia Learning | Very strong (T1) | Spatial contiguity, signaling, and coherence reliably improve learning |
| Formative Assessment | Strong (T1) | Feedback that explains what to do next outperforms correctness-only feedback |
| Constructive Alignment | Moderate-Strong (T2) | Objectives, activities, and assessments must form a coherent chain |
| Online Course Quality | Moderate (T2-T4) | QM standards + CoI presence predicts outcomes beyond compliance |
| Needs Analysis | Weak-Moderate (T3) | Multi-level analysis is necessary but rarely done |
| Accessibility & UDL | Moderate (T2-T3) | WCAG 2.1 AA is the legal baseline; UDL 3.0 extends to design for learner variation |

**Cross-domain principles** (appear in 3+ domains):
1. Alignment is non-negotiable
2. Expertise level changes which instructional moves help and which backfire
3. Feedback quality matters more than feedback quantity
4. Cognitive load is the central design constraint
5. Context determines model selection (no universal "best" approach)

## FAQ

**Do I need to know how to code?**
No. You interact with idstack through conversation in Claude Code. It's a chat interface.

**What is Claude Code?**
Claude Code is Anthropic's coding tool. It's available as a [desktop app, web app, and CLI](https://claude.ai/code). You type `/idstack:needs-analysis` and have a conversation. No programming required.

**Can I use this with Canvas?**
Yes. `/idstack:course-import` connects to Canvas via API or reads Canvas course exports (.imscc files). It also works with Blackboard, Moodle, and D2L through the IMS Common Cartridge format.

**Can I use this with Articulate Rise?**
Yes. Export your Rise course as a PDF (hover over the course card > `...` > Download as PDF), then run `/idstack:course-import` and choose "PDF or document file." Give it the file path and it reads the PDF directly, extracts the course structure, and maps it to the project manifest. From there, every skill works: quality review, accessibility audit, red team, everything. Note: interactive elements like Storyline blocks and flashcards don't render in PDFs, but course structure, objectives, and assessment descriptions come through fine.

**What if I only want to run the quality review?**
That works. `/idstack:course-quality-review` asks you about your course directly if there's no manifest.

**How do I check my course health without re-running a skill?**
Run `bin/idstack-status` from your project directory for the dashboard (quality score trends, dimensions, what skills have run, paths to every report under `.idstack/exports/<course-slug>/`). Add `--readiness` to get the pre-export readiness gate only (quality ≥ 70, accessibility ≥ 80, zero critical red-team findings, zero WCAG Level-A violations).

**Do I need python3?**
python3 is recommended but not required. With python3, you get quality score trends, dimension analysis, search filtering, and safe JSON serialization. Without it, basic timeline logging and learnings still work via bash fallback, but score trends and search filtering are unavailable. Most systems have python3 pre-installed.

**Is my data safe?**
idstack runs locally on your machine. Course data stays in your project folder (`.idstack/project.json`). Session history (`.idstack/timeline.jsonl`) and learnings (`.idstack/learnings.jsonl`) are also local. Nothing is sent to external servers by idstack itself. Claude Code's own privacy policy applies to the AI conversation.

**Can I edit the project manifest directly?**
You can, but let the skills manage it. If you do edit it, keep the JSON valid.

**How do I update idstack?**
idstack checks for updates when you run any skill. If a newer version is available, you'll see a notification. Update manually: `cd <your idstack clone> && git pull && ./setup`
If you downloaded ZIP: download the latest version and run `./setup` again.

**How do I request a feature or report a bug?**
[Fill out this form](https://forms.gle/6LDgDD1M6WWyYvME8). No GitHub account needed. If you have a GitHub account, you can also [open an issue](https://github.com/savvides/idstack/issues).

**Does idstack work offline?**
idstack itself is just text files. But it runs inside Claude Code, which requires an internet connection.

## Troubleshooting

**Skill not showing up?** Claude Code loads skills at session start. If you installed while Claude Code was running, restart it (close and reopen). If that doesn't help, run setup again:
```bash
cd <your idstack clone> && ./setup
```

**Can't import a .imscc cartridge?** Make sure the file is a valid ZIP. Try re-exporting from your LMS with "Course" selected (not just content).

**Canvas API says "token rejected"?** Generate a fresh token: Canvas -> Account -> Settings -> New Access Token. Tokens expire.

**Claude says it can't find idstack skills?** Make sure you've run `./setup` after cloning. Setup registers the repo as a plugin marketplace and installs it so Claude Code discovers the namespaced `/idstack:<skill>` commands. Restart Claude Code after install — plugins load at session start.

**Upgrading from v2.0?** v2.0 installed under `~/.claude/skills/idstack`, which only exposed `/idstack` (the dispatcher) — never the 11 namespaced sub-skills. Clone fresh and run setup: `git clone https://github.com/savvides/idstack.git && cd idstack && ./setup`. Setup now detects and removes any pre-v2.0.1.0 install at `~/.claude/skills/idstack` (symlink *or* real directory). If you ran an older setup that only warned, run `./setup` once more — or remove it manually with `rm -rf ~/.claude/skills/idstack`.

**`/idstack:<skill>` won't autocomplete or returns "Unknown skill"?** Run `bin/idstack-doctor` from your idstack clone. It checks the plugin + marketplace manifests, the Claude Code install state, all 11 SKILL.md files, and detects legacy-install conflicts — printing the exact remediation command for whatever it finds.

## Contributing

Have feedback or a feature request? [Fill out this form](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed.

Found a bug? You can also [open an issue on GitHub](https://github.com/savvides/idstack/issues).

Want to add a new skill? See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide. The architecture is simple: create a directory with a SKILL.md file and run `./setup`.

## More

- [idstack.org](https://idstack.org) — landing page
- [CHANGELOG.md](CHANGELOG.md) — full version history
- [ROADMAP.md](ROADMAP.md) — what's coming next
- [PRIVACY.md](PRIVACY.md) — privacy policy (idstack collects nothing)
- [Why AI-native?](docs/why-ai-native.md) — why idstack is built this way

## License

MIT. Free forever. Go design something evidence-based.
