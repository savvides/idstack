# idstack

> **Status: beta (v3.10.0.0).** Skills work end-to-end and ship behind a versioned plugin, but expect rough edges and breaking changes between minor versions while we shake out the rest of the workflow with real instructional designers. See [CHANGELOG.md](CHANGELOG.md) for what's new in the current release. [Tell us what's broken or missing.](https://forms.gle/6LDgDD1M6WWyYvME8)

Decades of research say elaborated feedback improves learning. Cognitive load theory has been replicated for 30 years. Constructive alignment measurably raises grades. The evidence is strong, but most course design tools don't make it easy to apply.

idstack is an open source set of skills for evidence-based instructional design that brings peer-reviewed research into your workflow. Runs in Claude Code. Rather than summarizing papers, idstack audits alignment matrices, flags cognitive load issues, classifies objectives against Bloom's taxonomy, and references the empirical evidence behind every recommendation.

Skills covering the full lifecycle: analyze, design, build, export. One shared project manifest that remembers your course across sessions. Every recommendation tagged with its evidence tier, from T1 (meta-analyses) to T5 (expert opinion), so you always know how strong the backing is.

Free, MIT licensed, open source. Available as a [Claude Code plugin](#install-30-seconds) and a [Chrome Extension](https://chromewebstore.google.com/detail/eclnhfehloplcnidkkopphamllnlhinm). [Have feedback or a feature request?](https://forms.gle/6LDgDD1M6WWyYvME8)

## Quick start

1. Install idstack (30 seconds, see below). No terminal? Use the [Claude desktop app](#claude-desktop-app-no-terminal).
2. Run `/idstack:start` in a folder for your course. It checks your setup and starts the correct skill.
3. If you imported a course, run `/idstack:course-quality-review` to see what the evidence says.
4. Stop there. You'll know if this is for you.

## See it work

```
You:    /idstack:course-import

idstack: How do you want to import your course?
         - LMS or SCORM package file
         - PDF or Word file
         - Paste course documents
         - Canvas API

You:    Canvas API. The course is https://canvas.university.edu/courses/12345.

idstack: Open .idstack/canvas.env in a text editor. Paste your Canvas access
         token between the two quotes after CANVAS_TOKEN=. Save the file,
         then tell me when it is done.

You:    Done.

idstack: Connected. Found 12 modules, 8 assignments, 4 discussions, 6 outcomes.

         ... a note and a question for the Imported structure section ...

         Import quality triage: 4 rows (4 warning).
         All 8 assessments are auto-graded quizzes with no rubrics.
         Read the draft in .idstack/exports/bio-101/course-import.md.

         Do you approve the Import quality triage section?
         - Approve  - Change a row  - Remove a row

You:    Approve

         ... one draft section and one question for each step ...

You:    /idstack:course-quality-review

idstack: QM structural review: 8 rows (3 pass, 5 flag).
         Standard 3 (Assessment): no rubrics, no alignment to objectives.
         Read the draft in .idstack/exports/bio-101/course-quality-review.md.

         Do you approve the QM structural review section?
```

The chat shows a short note and one question for each section. The tables, scores and citations go into the Markdown report. For example, the report for this course has the finding "All 8 assessments are auto-graded quizzes with no rubrics", the citation `[Assessment-8] [T1]` and the recommendation to run `/idstack:assessment-design`.

You had a course in Canvas. Now you have an evidence-based audit with specific recommendations, evidence tiers, and cross-references to the skills that fix each issue. Two commands. Or just run `/idstack:pipeline` and it chains the 8-skill linear pipeline automatically (`course-import` branches in for existing courses, `learn` is a separate cross-project memory utility, and `start` is the first-run guide. These three sit outside the linear chain, which is why pipeline runs 8 of the 12 skills).

## Install (30 seconds)

**Requirements:** [Claude Code](https://claude.ai/code) — desktop app, web app, or CLI — and python3 3.9 or later.

**Not using Claude Code?** The idstack skills run in Claude Code only. Without Claude Code, use the [Chrome extension](#chrome-extension-no-terminal-mode). The skills are plain Markdown, so you can fork this repo and adapt it for a different agent, for example Codex or Antigravity. idstack does not support or test those forks. <!-- IDSTACK_CLI_LEAK_ALLOW: unsupported-fork pointer, not a support claim -->

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
3. Open a bash shell: Terminal on macOS or Linux; WSL or Git Bash on Windows.
   `./setup` is a bash script, so PowerShell and `cmd` cannot run it.
4. Navigate to the folder: `cd path/to/idstack`
5. Run: `./setup`
</details>

<details>
<summary>Project-scoped install (one project only)</summary>

```bash
./setup --local
```
</details>

<details>
<summary>All setup flags</summary>

```bash
./setup                # Register the plugin with Claude Code at user scope
./setup --local        # Install at project scope (./.claude/) instead of user scope
./setup --help         # Show the usage and exit (also -h)
```

Setup is idempotent — re-run it any time.
</details>

You should see output like this:
```
  regenerated skill files
Setup installs idstack (scope: user)...
  source: /path/to/idstack

<messages from claude plugin marketplace add and claude plugin install>

Setup installed idstack in Claude Code (scope: user).

  If Claude Code is open, close it and open it again.
  Claude Code reads plugins only when a session starts.

  To use a skill, run /idstack:<skill>

  If you do not know where to start:
    /idstack:start

  If you have a course, import it and examine it:
    /idstack:course-import -> /idstack:course-quality-review

  To start a new course:
    /idstack:needs-analysis

  Run the full pipeline:
    /idstack:pipeline

  All skills: start, needs-analysis, learning-objectives, assessment-design,
    course-builder, course-quality-review, accessibility-review,
    red-team, course-export, course-import, pipeline, learn

  More information: https://idstack.org
```

### Claude desktop app (no terminal)

You can use idstack in the Code tab of the [Claude desktop app](https://claude.ai/download) on a Mac. You do not need a terminal.

1. Open the Claude desktop app and select the **Code** tab.
2. Make a folder for your course, for example `Documents/BIO-101`. Start a new session and select that folder with the folder button below the message box.
3. Paste this line in the message box and press Return:
   ```
   /plugin marketplace add savvides/idstack
   ```
4. Click **+** next to the message box, then **Add plugins**. Select **idstack** and install it.
5. Start a new session. Select the course folder again with the folder button. Claude Code loads a plugin only when a session starts.
6. Type `/idstack:start` and press Return. idstack checks your setup, then asks how you want to start.

Each skill that writes a report gives you a link to it. Click the link to open the report in the app.

**macOS asks you to install developer tools?** idstack needs python3. Click **Install** in the macOS window. When the installation is complete, type `/idstack:start` again.

### Chrome Extension (No-Terminal Mode)

[![Available in the Chrome Web Store](https://img.shields.io/badge/Chrome_Web_Store-idstack-4285F4?logo=googlechrome&logoColor=white)](https://chromewebstore.google.com/detail/eclnhfehloplcnidkkopphamllnlhinm)

If you or your instructional designers don't use the terminal, idstack is available as a native Chrome Side Panel extension in the [Chrome Web Store](https://chromewebstore.google.com/detail/eclnhfehloplcnidkkopphamllnlhinm):

1. Install [idstack from the Chrome Web Store](https://chromewebstore.google.com/detail/eclnhfehloplcnidkkopphamllnlhinm).
2. Pin the extension to your Chrome toolbar.
3. Navigate to any Canvas assignment, syllabus, or Google Doc and click the idstack icon to open the Side Panel.
4. Click **"Audit Page with Evidence"** for instant Bloom's classification, constructive alignment reviews, and 1-click improved rubrics.

If you switch tabs while the panel is open, click the idstack icon again so it can read the new tab. This isn't needed on Canvas pages at `instructure.com` or on a Canvas site you've already allowed.

#### Loading Unpacked (Local Development)

If developing or modifying the extension locally:
1. Open Chrome and navigate to `chrome://extensions/`.
2. Enable **Developer mode** in the top-right corner.
3. Click **Load unpacked** and select the `extension/` directory from this repo.

#### Full Course Audit (Canvas LMS)

When viewing any Canvas course homepage or modules list (`/courses/:id`), idstack automatically detects the course environment and presents an **"Audit Full Course"** button:
- **Zero Developer Tokens Required:** Reads the course syllabus and assignment descriptions through Canvas's API using your active browser session. No Canvas API keys, LMS admin setup, or command line required.
- **Course-level findings:** Reviews the syllabus and assignments together for alignment gaps, cognitive demand across Bloom's levels, and prioritized fixes, shown in the same results view as a page audit.
- **Export Ready:** Add the course audit to your Course Dossier or export it as Markdown to share with instructional design teams and faculty stakeholders.

On Canvas hosted outside `instructure.com` (for example, a university's own domain), Chrome asks once, for that site only, when you first click **"Audit Full Course"**.

#### Multi-Page Course Dossier & Markdown Export

Audit multiple pages across a course or syllabus and accumulate findings into a structured institutional deliverable:
- **Incremental Dossier Accumulation:** Click **"Add to Dossier"** on any page audit (assignments, pages, syllabi, rubrics, Google Docs). The header dossier badge tracks your collected course components across browsing sessions.
- **1-Click Compiled Markdown Export (`.md`):** Open the Dossier drawer to download a synthesized multi-page Markdown report (`idstack-course-dossier-<title>.md`) containing executive summaries, cognitive demand tables, itemized empirical citations (T1–T5), and improved rubric drafts.
- **Clipboard Ready:** Copy the compiled Markdown report directly to your clipboard for pasting into LMS course notes, Google Docs, Notion, or faculty review tickets.

#### Free Google AI Studio API Key Setup

Without a key, the extension runs in demo mode: every audit returns the same sample findings, whatever the page says. To get real audits:
1. Obtain a free API key from [Google AI Studio](https://aistudio.google.com/app/apikey).
2. In the idstack Side Panel, click the **Settings** (gear) icon in the top header.
3. Paste your API key into the input field and click **Save Settings**.
4. Each audit sends the page's title and text (or, for a full-course audit, the syllabus and assignments) straight from your browser to Google's API; no idstack server is involved. On Google's free tier, Google may use that content to improve its products, so read [PRIVACY.md](PRIVACY.md) before auditing anything that names students.

#### Packaging for Chrome Web Store

To create a distribution bundle:
```bash
./bin/package-extension.sh
```
Produces `build/idstack-chrome-extension-v<version>.zip` (version from `extension/manifest.json`), ready for submission to the Chrome Web Store Developer Console.


## Your design team

idstack turns Claude Code into an evidence-based instructional design team. Each skill is a specialist. All invoked via `/idstack:<skill>`.

| Skill | Your specialist | What they do |
|-------|----------------|--------------|
| `/idstack:start` | **Guide** | The first skill to run in a course folder. It makes sure that idstack can run and that the session is in a course folder (not your home folder or a temporary folder of the app), then starts the correct skill: course import or needs analysis for a new folder. For a course that already has a manifest, it continues the pipeline or starts one skill that you select from a list. It can also open the course dashboard. It writes no report. |
| `/idstack:needs-analysis` | **Needs Analyst** | Three-level assessment before you build anything. Organizational analysis (is training even the right intervention?), task analysis (what must learners do?), learner profiling (prior knowledge, not learning styles). Creates the project manifest. For a course imported from an LMS package, a SCORM package or the Canvas API, it runs a design-fit check instead of the training-decision gate. Writes `.idstack/exports/<course-slug>/needs-analysis.md`. |
| `/idstack:learning-objectives` | **Curriculum Designer** | Writes measurable objectives with revised Bloom's taxonomy. Classifies on two dimensions (knowledge type + cognitive process). Bidirectional alignment check: does each objective have a matching activity AND assessment? Flags gaps. Writes `.idstack/exports/<course-slug>/learning-objectives.md`. |
| `/idstack:assessment-design` | **Assessment Architect** | Designs assessments aligned to Bloom's levels with evidence-based rubrics and feedback strategies. Applies Nicol's 7 principles of good feedback. Builds formative checkpoints before summative assessments. It switches to audit mode only for a course imported from an LMS package, a SCORM package or the Canvas API whose manifest already lists assessments (`assessments.items` or `course_content.assessments`). `/idstack:course-import` does not write those lists, so the first run after an import designs from the ILOs. In audit mode it classifies existing rubric criteria on Bloom's, compares them to the ILOs, and shows alignment gaps without proposing new assessments. Writes `.idstack/exports/<course-slug>/assessment-design.md`. |
| `/idstack:course-import` | **LMS Bridge** | Imports your course from any LMS or authoring tool. Four options: an LMS or SCORM package file (IMS Common Cartridge `.imscc`, or a SCORM 1.2 / 2004 `.zip` from Rise, Storyline or Captivate), a PDF or Word file, pasted course documents, or the Canvas API. Quick-scan quality flags, auto-maps modules to task analysis, pre-classifies objectives with Bloom's. Writes `.idstack/exports/<course-slug>/course-import.md`. |
| `/idstack:course-builder` | **Content Generator** | Generates complete course content from the manifest: syllabus, module pages, assignment descriptions, and rubric documents. Content follows cognitive load principles. Includes adversarial spec review (auto-validates alignment). It switches to gap-fill mode only for a course imported from an LMS package, a SCORM package or the Canvas API whose manifest already lists modules in `course_content`. `/idstack:course-import` does not write `course_content`, so the first run after an import builds new content. In gap-fill mode it generates only the artifacts that upstream skills flagged as missing. Writes `.idstack/exports/<course-slug>/course-builder.md`. |
| `/idstack:course-export` | **LMS Publisher** | Generates an IMS Common Cartridge (.imscc) for Canvas, Blackboard, Moodle or D2L, a SCORM 1.2 package, or pushes directly to Canvas via API. Shows an advisory readiness check before export. The output IS the course. Writes `.idstack/exports/<course-slug>/course-export.md`. |
| `/idstack:course-quality-review` | **Quality Auditor** | Full QM-aligned audit plus Community of Inquiry presence layer. 8 structural standards, 3 presence dimensions (teaching, social, cognitive), constructive alignment audit. Parallel sub-agents for speed. Writes `.idstack/exports/<course-slug>/course-quality-review.md`. |
| `/idstack:accessibility-review` | **Accessibility Reviewer** | WCAG 2.1 AA compliance audit plus Universal Design for Learning (UDL 3.0) enhancement review. Two-tier output: "Necessary changes" for accessibility violations, "Recommended changes" for UDL recommendations. Parallel sub-agents for WCAG and UDL. Writes `.idstack/exports/<course-slug>/accessibility-review.md`. |
| `/idstack:red-team` | **Adversarial Auditor** | Assumes your course is broken and tries to prove it. Runs in a clean-context sub-agent so the audit can't inherit build-bias from the parent. Five dimensions in parallel: alignment stress test, evidence verification, cognitive load analysis, learner persona simulation, prerequisite chain integrity. The sub-agent writes its findings to `.idstack/.red-team-findings.json` and returns a summary. The parent then adds each findings table to `.idstack/exports/<course-slug>/red-team.md` for your approval, then runs a triage-and-fix loop (Critical only / Critical + Warning / All findings / Skip). Produces a confidence score. |
| `/idstack:pipeline` | **Orchestrator** | Chains the 8-skill linear pipeline automatically. Auto-skips completed skills. Shows pipeline status. Pause anytime, resume later. Produces `.idstack/exports/<course-slug>/index.md`, a Markdown course dashboard linking to every per-skill report, with readiness scores, top recurring issues, evidence themes, and where to start. |
| `/idstack:learn` | **Memory Manager** | Search, list, delete, promote, and export project learnings. Supports cross-project intelligence. |

## The workflow

Each skill feeds into the next. The project manifest is the thread.

Skill names in the diagram below are shown unprefixed to keep the columns readable. To run a skill, use the namespaced form: `/idstack:<skill>`.

```
EXISTING COURSE                           NEW COURSE

/course-import                            /needs-analysis
  IMSCC, SCORM, PDF, Word, paste, Canvas    Three-level needs assessment
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
BUILD (./setup runs it on each install; marketplace installs use the committed SKILL.md files)

  skills/<name>/SKILL.md.tmpl ──────────┐
  templates/preamble.md ────────────────┤
  templates/manifest-schema.md ─────────┼──▶ bin/idstack-gen-skills
  templates/snippets/idstack-resolve.sh ┘              │
                                                       ▼
                                             skills/<name>/SKILL.md
                                             extension/shared/ste-rules.js
                                               (writing rules, from the preamble)

INSTALL

  ./setup ──▶ registers .claude-plugin/plugin.json with Claude Code
                └─▶ 12 skills, invoked as /idstack:<skill>
  bin/idstack-doctor   diagnoses the install
                       (bin/lib/plugin-status.sh)

RUN (Claude Code, inside your course project folder)

  /idstack:<skill>
     │
     ├─ preamble: manifest check (bin/idstack-migrate) · preferences ·
     │            designer profile (~/.idstack/profile.yaml) · context
     │            recovery (reads the timeline and learnings below)
     ▼
  workflow: one AskUserQuestion at a time
     │  cites evidence/references.md as [Domain-N] [T1–T5]
     │
     ├──▶ .idstack/project.json        manifest: the system view (JSON)
     │      written via bin/idstack-manifest-merge (atomic, section-scoped);
     │      needs-analysis, course-import and assessment-design write
     │      several sections in one merge call
     │      └─▶ read by later skills, /idstack:pipeline, bin/idstack-status
     │
     ├──▶ .idstack/exports/<course-slug>/      (bin/idstack-slugify)
     │      <skill>.md            per-skill report: the human view, built one
     │                            draft section at a time (bin/idstack-report-section)
     │      index.md              course dashboard (/idstack:pipeline)
     │      course-export.imscc, scorm-export.zip   (/idstack:course-export)
     │      skeletons: templates/report.md.tmpl, index.md.tmpl
     │      content contract: templates/report-format.md
     │
     └──▶ .idstack/timeline.jsonl   runs, scores (bin/idstack-timeline-log)
          .idstack/learnings.jsonl  discoveries (bin/idstack-learnings log)
            └─ /idstack:learn promote ─▶ ~/.idstack/global/learnings.jsonl

CHROME EXTENSION (separate runtime: no Claude Code, no .idstack/ folder)

  sidepanel ── injects content/extractor.js into the tab, reads page text
     │
     ├─ RUN_AUDIT (one page) ──────────────┐
     └─ CRAWL_AND_AUDIT_COURSE (course) ───┴─▶ background/service-worker
                        ├─ canvas-crawler (course audits: syllabus, assignments)
                        └─ shared/prompts ──▶ Google AI API (your key;
                                              demo findings without one)
     ◀── findings in the side panel; "Add to Dossier" saves them in
         chrome.storage; dossier export as Markdown
```

Skills are plain Markdown files generated from templates. No build step for users, and no dependencies beyond bash and python3. `./setup` registers the repo as a Claude Code plugin marketplace and installs it, which is what gives the namespaced `/idstack:<skill>` commands. Users invoke skills via `/idstack:<skill>`. Each skill that produces results (all skills except `/idstack:start`, `/idstack:pipeline` and `/idstack:learn`) reads the shared manifest and session history, runs its evidence-based workflow, writes back its section, and logs the session to the timeline. The pipeline adds context but every skill also works standalone.

## How it works

### The project manifest
idstack saves your design decisions in `.idstack/project.json` so each skill remembers your course context. The skills manage it, so you do not need to edit it.

When you run `/idstack:course-import`, it creates the manifest with your course structure. When you run `/idstack:learning-objectives`, it reads the manifest and extends it with objectives and alignment data. `/idstack:assessment-design` adds rubrics and feedback strategies. `/idstack:course-builder` generates the actual content. `/idstack:course-quality-review` audits the full chain. `/idstack:course-export` packages it for your LMS. Each skill reads what came before and adds its layer. Or run `/idstack:pipeline` and it chains them all automatically.

### How idstack reports back to you
idstack functions as a design partner rather than an automated content generator. When a skill finishes, it produces two artifacts:

- **Markdown report** at `.idstack/exports/<course-slug>/<skill>.md` — the human view. The skill gives you a link to it. Every finding follows the same structure: *what we saw* in your course, *what the evidence says* (with a citation tag like `[Assessment-8] [T1]`), *why it matters* for learners, and a *recommendation* for what to change. Recommendations, not orders: the designer owns the course, while idstack provides the analytical review.
- **Manifest section** at `.idstack/project.json` — the system view. Same findings in JSON so other skills can read and act on them.

After each step, the skill adds its output to the report at once, as a draft section with a table. Each row has a justification and a citation, except in the fact sections (for example Course information and Readiness), which have no Justification or Evidence columns. You read the table in the report file. The chat shows only a short note, a link to the draft and the question "Do you approve the <section> section?". You can approve the section, change a row or remove a row. When you approve, the draft mark goes away. If a session stops, the report keeps each section, and a section that you did not approve keeps its draft mark. The manifest gets only the rows that you approved. `bin/idstack-report-section` does these steps and checks each citation against `evidence/references.md`.

The report skeleton lives in [`templates/report.md.tmpl`](templates/report.md.tmpl). The content contract is in [`templates/report-format.md`](templates/report-format.md). Re-running a skill overwrites its report; the timeline at `.idstack/timeline.jsonl` carries the run history.

Every per-course artifact — every per-skill report, the pipeline dashboard, and any LMS packages — lands in the same self-describing folder: `.idstack/exports/<course-slug>/`. The `<course-slug>` is derived from your course's `project_name` (lowercased, kebab-cased). Zip the folder to hand the whole deliverable to a stakeholder.

When you run `/idstack:pipeline`, it also produces a course dashboard at `.idstack/exports/<course-slug>/index.md` — readiness scores, links to every per-skill report, top issues that recur across multiple stages, evidence themes, and where to start. Open this first if you've run multiple skills and want one entry point that synthesizes the whole audit.

### Course memory
idstack remembers your design sessions. Each skill logs what it did to `.idstack/timeline.jsonl`, and project-specific discoveries (LMS quirks, format issues, course patterns) are stored in `.idstack/learnings.jsonl`. When you start a new session, idstack tells you where you left off: quality score trends, which skills have been completed, and what the next step is. To see your course health dashboard at any time, run `<your idstack clone>/bin/idstack-status` in your course folder. It reads `.idstack/` in the current folder.

### Evidence tiers
Every recommendation includes an evidence tier so you know how strong the backing is:

| Tier | What it means | Example |
|------|--------------|---------|
| **T1** | Meta-analyses and randomized controlled trials | "Elaborated feedback improves learning" (Wisniewski et al., 2020) |
| **T2** | Quasi-experimental studies with controls | "Spaced practice beats massed practice" (Chen et al., 2018) |
| **T3** | Systematic reviews of mixed evidence | "Multi-level needs analysis is necessary" (Ferreira & Abbad, 2013) |
| **T4** | Observational studies without comparison groups | "QM peer review improves course quality" (Zimmerman et al., 2020) |
| **T5** | Expert opinion and theoretical frameworks | "Constructive alignment improves learning" (Biggs, 1996) |

When the skill says "add elaborated feedback to your quizzes," it references T1 evidence from multiple meta-analyses rather than unverified opinion.

### Using skills independently
Any skill works on its own. `/idstack:course-quality-review` works without a manifest by asking you questions directly. `/idstack:learning-objectives` works without a needs analysis. The pipeline adds context and makes recommendations sharper, but every skill is self-contained.

## The evidence base

idstack encodes findings from a literature synthesis spanning 11 domains of instructional design research. The full citation list (all 11 domains, 5 evidence tiers) is in [evidence/references.md](evidence/references.md). A selection:

| Domain | Studies (T1 studies) | Tier range | Key Finding |
|--------|---------------------|------------|-------------|
| Cognitive Load Theory | 19 (6) | T1–T5 | Manage working memory load through sequencing, segmenting, and integration |
| Multimedia Learning | 14 (7) | T1–T5 | Spatial contiguity, signaling, and coherence reliably improve learning |
| Formative Assessment | 14 (10) | T1–T5 | Feedback that explains what to do next outperforms correctness-only feedback |
| Constructive Alignment | 13 (2) | T1–T5 | Objectives, activities, and assessments must form a coherent chain |
| Online Course Quality | 14 (3) | T1–T5 | QM standards + CoI presence predicts outcomes beyond compliance |
| Needs Analysis | 11 (2) | T1–T3 | Multi-level analysis is necessary but rarely done |
| Accessibility & UDL | 13 (2) | T1–T5 | WCAG 2.1 AA is the legal baseline; UDL 3.0 extends to design for learner variation |

The counts come from `evidence/references.md`. Most of the Constructive Alignment references are T4 and T5, and most of the Needs Analysis references are T3.

**Cross-domain principles** (each is in 2 or more domains):
1. Alignment is non-negotiable
2. Expertise level changes which instructional moves help and which backfire
3. Feedback quality matters more than feedback quantity
4. Cognitive load is the central design constraint
5. Context determines model selection (no universal "best" approach)

## FAQ

**Do I need to know how to code?**
No. You interact with idstack through conversation in Claude Code. It is a chat interface. In the [Claude desktop app](#claude-desktop-app-no-terminal) you do not need a terminal to install or use idstack. To update it, you run two commands in a terminal (see "How do I update idstack?").

**What is Claude Code?**
Claude Code is Anthropic's coding tool. It's available as a [desktop app, web app, and CLI](https://claude.ai/code). You type `/idstack:needs-analysis` and have a conversation. No programming required.

**Can I use this with Canvas?**
Yes. `/idstack:course-import` connects to Canvas via API or reads Canvas course exports (.imscc files). It also works with Blackboard, Moodle, and D2L through the IMS Common Cartridge format.

**Can I use this with Articulate Rise?**
Yes. Export your Rise course as a PDF (hover over the course card > `...` > Download as PDF), then run `/idstack:course-import` and choose "PDF or Word file." Give it the file path and it reads the PDF directly, extracts the course structure, and maps it to the project manifest. From there, every skill works: quality review, accessibility audit, red team, everything. Note: interactive elements like Storyline blocks and flashcards don't render in PDFs, but course structure, objectives, and assessment descriptions come through fine.

**What if I only want to run the quality review?**
That works. `/idstack:course-quality-review` asks you about your course directly if there's no manifest.

**How do I check my course health without re-running a skill?**
Run `<your idstack clone>/bin/idstack-status` in your course folder for the dashboard (quality score trends, dimensions, what skills have run, paths to every report under `.idstack/exports/<course-slug>/`). Add `--readiness` to get only the pre-export readiness check (quality ≥ 70, accessibility ≥ 80, zero critical red-team findings, zero WCAG Level-A violations). The check is advisory: `/idstack:course-export` shows it, but you can always export. After `/idstack:pipeline` writes the course dashboard (`index.md`), you can also run `/idstack:start` and select **Open the course dashboard**.

**Do I need python3?**
Yes, python3 3.9 or later. Each skill that produces results (all skills except `/idstack:start`, `/idstack:pipeline` and `/idstack:learn`) uses it to save those results to the project manifest. The status dashboard, learnings and timeline use it too. macOS and most Linux systems already have it. Run `bin/idstack-doctor` to check; it reports a missing or older python3 as a problem.

**Is my data safe?**
idstack runs locally on your machine. Course data stays in your project folder (`.idstack/project.json`). Session history (`.idstack/timeline.jsonl`) and learnings (`.idstack/learnings.jsonl`) are also local. In the Claude Code plugin, course data reaches external servers only when you explicitly invoke integration skills (such as Canvas API calls via `/idstack:course-import` or `/idstack:course-export`). `/idstack:red-team` also searches the web for newer research on the studies that your course cites. The search terms are about the studies, not your course text. Your Canvas token stays in `.idstack/canvas.env` in your course folder, which only you can read and git ignores. Delete the file when you are done. The Chrome extension sends page text to Google's API when you run an audit with your own API key saved; see [PRIVACY.md](PRIVACY.md). Claude Code's own privacy policy applies to the AI conversation.

**Can I edit the project manifest directly?**
You can, but let the skills manage it. If you do edit it, keep the JSON valid.

**How do I update idstack?**
Update manually. idstack does not tell you when a new version is available.
- If you installed from a clone: `cd <your idstack clone> && git pull && ./setup`
- If you installed in the Claude desktop app (or with `/plugin marketplace add`): run these commands in a terminal: `claude plugin marketplace update idstack`, then `claude plugin update idstack@idstack`.
- If you downloaded ZIP: download the latest version and run `./setup` again.

Then start a new session. Claude Code loads a plugin only when a session starts.

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

**Canvas API says "token rejected"?** Generate a fresh token: Canvas -> Account -> Settings -> Approved Integrations -> New Access Token. Paste it into `.idstack/canvas.env` in your course folder, not into the chat. Tokens expire.

**Claude says it can't find idstack skills?** Make sure you've run `./setup` after cloning. Setup registers the repo as a plugin marketplace and installs it so Claude Code discovers the namespaced `/idstack:<skill>` commands. Restart Claude Code after install — plugins load at session start.

**Upgrading from v2.0?** v2.0 installed under `~/.claude/skills/idstack`, which only exposed `/idstack` (the dispatcher) — never the 11 namespaced sub-skills. Remove the old install, then clone fresh and run setup: `rm -rf ~/.claude/skills/idstack && git clone https://github.com/savvides/idstack.git && cd idstack && ./setup`. Setup no longer removes old installs for you; the CHANGELOG lists every path an older install can leave behind.

**`/idstack:<skill>` won't autocomplete or returns "Unknown skill"?** Run `bin/idstack-doctor` from your idstack clone. It checks the plugin + marketplace manifests, the Claude Code install state, all 12 SKILL.md files, and python3. It reports each problem it finds, and for a Claude Code install problem it prints the command that fixes it.

## Contributing

Have feedback or a feature request? [Fill out this form](https://forms.gle/6LDgDD1M6WWyYvME8) — no GitHub account needed.

Found a bug? You can also [open an issue on GitHub](https://github.com/savvides/idstack/issues).

Want to add a new skill? See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide. The architecture is simple: create a directory with a `SKILL.md.tmpl` template, run `bin/idstack-gen-skills` to generate its `SKILL.md`, then `./setup`.

## More

- [idstack.org](https://idstack.org) — landing page
- [CHANGELOG.md](CHANGELOG.md) — full version history
- [ROADMAP.md](ROADMAP.md) — what's coming next
- [PRIVACY.md](PRIVACY.md) — privacy policy (idstack collects nothing)
- [Why AI-native?](docs/why-ai-native.md) — why idstack is built this way

## License

MIT License. Free and open source.
