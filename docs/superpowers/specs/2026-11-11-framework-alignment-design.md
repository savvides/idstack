# Framework alignment and landing page: design

Date: 2026-11-11. Owner request: show how the skills align with ADDIE and backward design, give non-technical designers a visual guide, and make idstack.org communicate the value to individual designers and to teams.

## Goal

An instructional designer who knows ADDIE, backward design or SAM can find the idstack skill for the phase they are in, in the README, on the website, or by naming the phase to Claude.

## The mapping (single source: `docs/frameworks.md`)

| Skill | ADDIE | Backward design | SAM |
|-------|-------|-----------------|-----|
| needs-analysis, course-import | Analyze | Stage 1 | Preparation |
| learning-objectives | Design | Stage 1 | Iterative design |
| assessment-design | Design | Stage 2 | Iterative design |
| question-bank | Develop | Stage 2 | Iterative development |
| storyboard | Develop | Stage 3 | Prototype |
| course-builder | Develop | Stage 3 | Iterative development |
| course-quality-review, accessibility-review, red-team | Evaluate (formative) | Alignment check | Review |
| course-export | Implement | After the stages | Release |
| evaluation-plan | Evaluate (summative) | Stage 2 | Preparation, then after release |

Decisions:

- **The three reviews are ADDIE's formative evaluation**, not a sixth phase. ADDIE evaluates before launch and after it; the pipeline order (reviews, then export) is correct ADDIE, and the map says so.
- **The pipeline order is backward design.** Objectives, then assessments, then content. No skill changes sequence.
- **SAM is the third framework** because it is the common alternative to ADDIE and idstack's re-runnable skills and red-team fix loop fit its cycles.
- **Honest gaps are stated**: idstack does not deliver the course, collect evaluation data, or select the framework.
- **No new reference.** Wiggins and McTighe is a book; the evidence base holds peer-reviewed studies. The guide names the book in prose and cites constructive alignment `[Alignment-1] [T5]`.

## Surfaces

1. `docs/frameworks.md`: one-page map, a Mermaid diagram and a phase table (question, skill, exit check) per framework, a selection table, frameworks inside the skills, limits.
2. `docs/idstack-guide.svg`: README infographic. Start in three steps; the eight pipeline skills between an ADDIE band (prussian) and a backward design band (oxblood); companion skills; three shortcuts. Hand-edited SVG, Proof tokens, system-font fallbacks, `<title>`/`<desc>` plus a text equivalent in the README table.
3. README: infographic above Quick start; "Works with your framework" table.
4. Skills: a `Framework phase:` line in 13 skill descriptions (routing by phase name); a phase table in `/idstack:start`.
5. `docs/index.html`: see below.
6. Guard: smoke-test fails when a skill has no row in `docs/frameworks.md`.

## Landing page

Audience: individual instructional designers and design teams. Job: show what idstack changes in their work, then let them install.

Kept: the Proof tokens, prussian hero, session transcript, evidence index, output pair, install tracks (DESIGN.md; all are tested and recent).

Changed:

- **New section `#why`, directly after the hero**: two columns, "For one designer" and "For a design team", four outcomes each. Rows with hairline rules, not cards. Every claim is something a skill does today.
- **`#pipeline` becomes the framework section and moves above the evidence.** A three-way switch (ADDIE, backward design, SAM) relabels the same eight skills with the phase names of the selected framework. This is the one interactive moment of the page: the skills do not move, the vocabulary does. CSS `:has()` on radio inputs, no JavaScript; without `:has()` the page shows ADDIE.
- Companion skills show their ADDIE phase. A link goes to the full guide.
- Nav: Why, Frameworks, Evidence, Install, GitHub.
- Hero lede and meta descriptions name the three frameworks.

Order: hero, why, frameworks and skills, evidence, output, install.

## Out of scope

- A framework-selector skill (ROADMAP "Model selector").
- Phase names in the pipeline dashboard (`templates/index.md.tmpl`).
- A new OG image.

## Verification

smoke-test, test-responsive-landing, test-rendered-landing, check-evidence-cards, check-citation-tiers, check-doc-accuracy, integration-test; screenshots of the page at 1280px and 375px in light mode, each framework selected.
