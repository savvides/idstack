# idstack

Evidence-based design partner for instructional designers. Three Claude Code skills that encode findings from 283 research papers into your course design workflow.

Unlike generic AI prompts, idstack maintains a project manifest that remembers your course across sessions. Your needs analysis feeds your learning objectives. Your objectives feed your quality review. It works like a knowledgeable colleague who read all the research.

## What You Get

### /needs-analysis
Walks you through a structured three-level assessment before you build anything. Organizational analysis (is training the right intervention?), task analysis (what must learners do?), and learner analysis (what do they already know?). Creates a project manifest that the other skills read.

### /learning-objectives
Helps you write measurable learning objectives using the revised Bloom's taxonomy. Classifies each objective on two dimensions (knowledge type and cognitive process), checks alignment between objectives, activities, and assessments, and flags gaps. Reads from your needs analysis to give better recommendations.

### /course-quality-review
Audits your course against Quality Matters standards and the Community of Inquiry framework. Checks 8 structural standards, evaluates teaching/social/cognitive presence, and runs a constructive alignment audit. Every finding includes the evidence strength behind it.

## Install

### What you need
- [Claude Code](https://claude.ai/code) (desktop app, web app, or CLI)

### Steps

**Option A: Using git**
```bash
git clone https://github.com/savvides/idstack.git
cd idstack
./setup
```

**Option B: Download ZIP**
1. Download and unzip idstack from GitHub
2. Open Terminal (Mac) or PowerShell (Windows)
3. Navigate to the idstack folder: `cd path/to/idstack`
4. Run: `./setup`

You should see:
```
Installing idstack...
  linked: /needs-analysis
  linked: /learning-objectives
  linked: /course-quality-review

idstack installed successfully.
Open Claude Code and try: /needs-analysis
```

### Project-scoped install
If you only want idstack in one project:
```bash
./setup --local
```

## Quick Start

Open Claude Code in your course project folder. Then:

**1. Start with needs analysis**
Type `/needs-analysis` and answer the questions about your course. The skill will walk you through organizational context, task analysis, and learner profiling. It saves everything to a project manifest file.

**2. Develop learning objectives**
Type `/learning-objectives`. It reads your needs analysis and helps you write measurable objectives with proper Bloom's taxonomy classification. It checks that each objective has a matching activity and assessment.

**3. Review course quality**
Type `/course-quality-review`. It audits your course against Quality Matters standards, checks for teaching/social/cognitive presence, and verifies constructive alignment. Every finding tells you how strong the evidence is.

You can also run any skill independently. `/course-quality-review` works without a manifest by asking you questions directly.

## How It Works

### The project manifest
idstack saves your design decisions in `.idstack/project.json` so each skill remembers your course context. You never need to edit this file directly. The skills manage it.

### Evidence tiers
Every recommendation includes an evidence tier so you know how strong the backing is:

| Tier | Meaning |
|------|---------|
| T1 | Meta-analyses and randomized controlled trials |
| T2 | Quasi-experimental studies with controls |
| T3 | Systematic reviews of mixed evidence |
| T4 | Observational studies without comparison groups |
| T5 | Expert opinion and theoretical frameworks |

### Using skills independently
Any skill works on its own. The pipeline adds context but isn't required. If you run `/course-quality-review` without a manifest, it asks you about your course directly.

## The Evidence Base

idstack encodes findings from a literature synthesis of approximately 283 papers across 10 domains of instructional design research. The full citation list is in [evidence/references.md](evidence/references.md).

The strongest evidence domains in the synthesis:
- **Cognitive Load Theory** (Domain 4): Very strong experimental evidence
- **Multimedia Learning Principles** (Domain 6): Very strong experimental evidence
- **Formative Assessment & Feedback** (Domain 5): Strong meta-analytic evidence

## FAQ

**Do I need to know how to code?**
No. You interact with idstack through conversation in Claude Code.

**Can I edit the project manifest directly?**
You can, but let the skills manage it. If you do edit it, make sure the JSON stays valid.

**What if I only want to run the quality review?**
That works. It will ask you questions about your course instead of reading from the manifest.

**How do I update idstack?**
If you installed with git: `cd path/to/idstack && git pull`
If you downloaded ZIP: download the latest version and run `./setup` again.

**Does idstack work offline?**
idstack itself is just text files. But it runs inside Claude Code, which requires an internet connection.

## Contributing

Found a bug or have a suggestion? [Open an issue on GitHub](https://github.com/savvides/idstack/issues).

Want to add a new skill? The architecture is simple: create a directory with a SKILL.md file and run `./setup`. See the existing skills for the pattern.

## License

MIT
