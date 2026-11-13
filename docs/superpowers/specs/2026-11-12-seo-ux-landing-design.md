# SEO and UX changes to the landing page: design

Date: 2026-11-12. Status: approved.

## Goal

idstack.org (`docs/index.html`, served by GitHub Pages) must be found for "AI instructional design" searches, and a visitor who is an instructional designer must get to an install path quickly.

## What was measured

- The live page is byte-identical to `docs/index.html` on main. Tests pin the version, the skill count and the evidence cards. No repo-to-site drift was found.
- The page has a title, description, canonical URL, Open Graph and Twitter tags, JSON-LD, `robots.txt` and `sitemap.xml`. No heading contains "AI" or "instructional design".
- The page is 10 screens long on desktop and about 16 on a phone (375 px). Install is the last section.
- The hero gives two install paths: the Chrome extension and a `git clone` command. The no-terminal desktop app path is only in the Install section.
- The first hero paragraph has 85 words.
- 148 text elements are smaller than 13 px. The smallest is about 10 px.
- Load time is about 0.5 s. There is no sideways scroll on a phone.

## Decisions

- Scope: one page. No new content pages.
- Target search: "AI instructional design tool", "AI for instructional designers", "AI course design".
- Approach: keyword-led rewrite of the title, H1 and H2s. The word "copilot" stays in body text, so the README and the Chrome extension keep their term.

## Changes

Each change is implemented by one general-purpose subagent with the model given. All seven edit shared files, so they run one at a time, in this order. The main session reviews each diff before the next change starts.

### C1. Head tags and headings

Model: **opus**. Reason: this is the public headline copy; it has character limits and ASD-STE100 rules, and several files must agree.

- `<title>`, `og:title`, `twitter:title`: `AI instructional design tool, backed by <N> studies | idstack`.
- Meta description (160 characters maximum), `og:description`, `twitter:description` and the JSON-LD `description`: start with "AI instructional design tool" or "idstack is an open-source AI instructional design tool". Keep the facts that are there now (frameworks, <N> studies, evidence tier, open source, where it runs).
- `og:image:alt` and `twitter:image:alt`: the new H1 text.
- Delete `<meta name="keywords">`.
- Headings:

| Now | New |
|---|---|
| H1: A copilot for instructional designers. | The AI instructional design tool that cites its research. |
| Help with the jobs that you do each day. | AI help for each instructional design job |
| Sixteen skills, in the framework you already use. | AI course design skills for ADDIE, backward design and SAM |
| Every recommendation cites its source. | Evidence-based instructional design: <N> studies |
| Three ways to install. | Three ways to install idstack |

- "Each pipeline skill writes a report and a manifest." does not change.
- `docs/og-template.html`: the same headline. (C7 renders `docs/og-image.png` again.)
- `DESIGN.md`: a decision-log row for the new headline, and each place that quotes the old one.

### C2. Hero paragraph and the no-terminal path

Model: **sonnet**. Reason: a small edit in one block, with the text given here; the risk is only the markup and the touch-target tests.

- Replace the 85-word paragraph with about 35 words:
  "idstack helps you do each job of an instructional designer, in ADDIE, backward design or SAM. Each recommendation cites its study and its evidence tier, from T1 to T5. <N> peer-reviewed studies. It runs in Claude Code or Chrome."
  Keep the tier chip markup for T1 and T5 if the paragraph has it now.
- Add a link directly below the install command: "No terminal? Use the Claude desktop app". It goes to the Claude Desktop App card in the Install section. Give that card an `id` if it has none. The link must be a 44 px touch target on a phone.

### C3. Install moves up

Model: **sonnet**. Reason: a block move with no new text; the risk is test anchors and CSS that depends on section order.

- New section order: Hero, Jobs (`#why`), Install (`#install`), Skills (`#pipeline`), Evidence (`#evidence`), Output (`#output`), then the FAQ from C4.
- The nav links keep their targets. Put the nav items in the same order as the sections.
- Alternate section backgrounds must still alternate if the page uses them.

### C4. FAQ section

Model: **opus**. Reason: new public text; each answer must be true to the repo and follow ASD-STE100, and the section needs styling from `DESIGN.md`.

- A new `<section id="faq">` after Output, before the footer. H2: "AI instructional design FAQ".
- Six questions as `h3` with one `p` answer each. No JavaScript, no `<details>`.
  1. What is an AI instructional design tool?
  2. Does idstack replace an instructional designer?
  3. Which instructional design frameworks does idstack support?
  4. Where do the recommendations come from?
  5. Does idstack work with Canvas, Blackboard and Moodle?
  6. Is idstack free, and what do I need to run it?
- Each answer has three sentences maximum and states facts that the README or the repo supports. An answer does not give a recommendation, so it needs no citation. If an answer cites a study, the citation must pass `test/check-citation-tiers.py`.
- Reuse the page's CSS tokens and an existing section pattern. Add a "FAQ" nav item only if the nav still fits at 375 px with no sideways scroll.

### C5. 12 px minimum text size

Model: **sonnet**. Reason: a mechanical CSS change, but it can wrap labels and break the rendered-layout tests, and `DESIGN.md` must change with it.

- Each `font-size` in `docs/index.html` below 0.75rem (12 px at the 16 px root) becomes 0.75rem.
- `DESIGN.md`: state the 12 px floor for the landing page and add a decision-log row.
- `test/test-responsive-landing.js` and `test/test-rendered-landing.js` must pass.

### C6. 404 page and llms.txt

Model: **haiku**. Reason: two small new files that nothing else depends on.

- `docs/404.html`: a complete HTML document (GitHub Pages serves it for a URL that does not exist). Landing colors and fonts from `DESIGN.md`, `<meta name="robots" content="noindex">`, one H1, a short line, and links to `/` and `/#install`. Absolute paths for the links and the favicon, because the page is served at any path.
- `docs/llms.txt`: about 15 lines of Markdown. One H1, one summary paragraph, then links to the README, `docs/frameworks.md`, `evidence/references.md` and the Chrome extension. No counts and no version, so that it cannot go stale.

### C7. Guard test, social image and repo documents

Model: **sonnet**. Reason: one small Python check with clear assertions, plus bookkeeping that the test suites verify.

- One new function in `test/check-doc-accuracy.py`:
  - exactly one `<h1>`, and it contains "instructional design";
  - `<title>` has 65 characters maximum, the meta description 160 maximum;
  - `<title>`, `og:title` and `twitter:title` are equal;
  - there is no `keywords` meta tag;
  - the study count in the title equals the count in the hero;
  - no `font-size` in `docs/index.html` is below 0.75rem or 12px;
  - `id="install"` comes before `id="pipeline"`;
  - `docs/404.html` and `docs/llms.txt` exist.
- Render `docs/og-image.png` again with the command in the header comment of `docs/og-template.html`.
- `CHANGELOG.md`: entries under `## Unreleased`.
- `CLAUDE.md`: the places that list where the study count is hand-typed, and each hand-kept test count that changed, from a real run.
- `test/mutation-test.sh`: update each anchor that quotes text this work moved or renamed. Verify with the anchor-only check that `CLAUDE.md` describes, not the full run.

## Rules for every change

- All text for a person follows ASD-STE100. Run `scripts/idstack-ste-check --format markdown` or the plain mode on the new text.
- Read `DESIGN.md` before a visual decision.
- Do not commit. Do not edit sections that the change does not name.
- Before a change renames or moves text, grep `test/` for the old text.

## Verification

After C7: `./test/smoke-test.sh`, `python3 test/check-doc-accuracy.py .`, `python3 test/check-evidence-cards.py .`, `python3 test/check-citation-tiers.py .`, `node test/test-responsive-landing.js`, `node test/test-rendered-landing.js`. Then the main session looks at the page at desktop and phone widths.

## Not in this work

- `lastmod` in the sitemap and `dateModified` in the JSON-LD. `check-doc-accuracy.py` fails if they come back, because no check can keep them accurate.
- `FAQPage` structured data. Google shows FAQ rich results only for government and health sites, and the data would be a second copy of the FAQ.
- More pages on idstack.org.
- Search Console: the owner verifies the site and submits the sitemap.

## Round 2 (after the owner saw the page)

The owner asked for a new hero title and for less detail in the text. The same rules apply: one general-purpose subagent for each change, with the model given, one at a time, and the main session reviews each diff.

Done by the main session before this round: the hero paragraph has 28 words. It lost the T1 and T5 chips, the study count and the platform list. The guard test compares the title count with the "See the N studies" link in the hero.

### C8. Hero title

Model: **sonnet**. Reason: the text is given and the edits are mechanical, but the share card must be rendered again and judged by eye, and four files must agree.

- H1 in `docs/index.html`: "An AI copilot for instructional design."
- `og:image:alt` and `twitter:image:alt`: the same text.
- `<title>`, `og:title`, `twitter:title` and the descriptions do not change.
- `docs/og-template.html`: the same headline. Render `docs/og-image.png` again and look at it. Change the headline size only if the text touches the brand, the lede or the rail.
- `DESIGN.md`: correct the 2026-11-12 decision-log row for the headline. Do not add a second row for the same day and subject.
- `CHANGELOG.md`: correct the headline in the Unreleased entry.

### C9. Less detail in summary text

Model: **sonnet**. Reason: each replacement is given word for word, so the work is exact edits. The risk is the hand-kept counts and the tests, which need care but not design judgment.

Rule: a count, a version number of a standard or a file path goes out of headings, ledes, card text and FAQ answers when the sentence is true without it. Reference content keeps its detail.

| Where | Now | New |
|---|---|---|
| Why, "A second opinion in one minute" | You get a maximum of five findings, each with its study, and a corrected version. | You get findings, each with its study, and a corrected version. |
| Why, "One standard of review" | Quality Matters, WCAG 2.1 AA and constructive alignment. | Quality Matters, WCAG and constructive alignment. |
| Install, Claude Code card | installs all 16 skills | installs the skills |
| Skills lede | Eight skills run in sequence through `/idstack:pipeline`. Three more handle first-run setup, course import and course memory. Four companion skills work at any time: | The pipeline skills run in sequence through `/idstack:pipeline`. Other skills handle first-run setup, course import and course memory. Companion skills work at any time: |
| assessment-design card | Rubrics, checkpoints, Nicol's 7 feedback principles. | Rubrics, checkpoints and feedback principles. |
| course-quality-review card | QM 8 standards + Community of Inquiry. | Quality Matters + Community of Inquiry. |
| accessibility-review card | WCAG 2.1 AA + UDL 3.0 audit. | WCAG + UDL audit. |
| red-team card | Adversarial audit across 5 dimensions. | Adversarial audit before launch. |
| course-export card | Common Cartridge, SCORM 1.2, or Canvas API. | Common Cartridge, SCORM, or Canvas API. |
| Output lede | (the two sentences "Reports go in …" and "The manifest is …") | removed |
| Output foot | The timeline at `.idstack/timeline.jsonl` records each run. | removed |
| Output foot | writes an `index.md` dashboard | writes a dashboard |
| FAQ 1 | idstack has 16 skills that run in | idstack has skills that run in |
| FAQ 4 | cites a study from a list of <N> studies in 11 domains of instructional design research | cites a peer-reviewed study from the idstack reference list |
| FAQ 5 | a SCORM 1.2 package | a SCORM package |

Kept on purpose:

- The Evidence section (heading, lede, cards, tier ranges). It is the reference, and `check-evidence-cards.py` checks it.
- The install requirements (shells, Python 3.9). A person needs them to install.
- The sample session and the two sample output panels. They are examples of real output.
- The version in the hero meta line. `check-doc-accuracy.py` needs it.
- The tier meanings and the Python requirement in the FAQ. They are the answer to the question.
- The head tags.

After the edits: update the count of hand-typed study-count places in `CLAUDE.md`, and the Unreleased entries in `CHANGELOG.md` that the edits make untrue.

## Round 3: AI-writing audit of the page

Audited with the `avoid-ai-writing` skill: its detector on the visible text of `docs/index.html` (2,216 words), then a read against its pattern catalog.

Detector result: score 2 of 100, "Minimal AI signals". No em dashes. Two hits, and neither is a finding:

- "learnings": the name of an idstack feature (`/idstack:learn`, `learnings.jsonl`). It stays.
- "research shows": in "Cognitive load research shows when a visual cue helps". It names the field, and the Evidence card lists its references. It stays.

Findings from the read:

| # | Pattern | Text | Decision |
|---|---|---|---|
| 1 | Title-case subheadings | The three install card headings and their badges use title case. The page's other headings use sentence case. | Fix (C10) |
| 2 | Tailing negation fragment | "No command line." (Chrome card) and "No setup." (quick-check card) | Fix (C11) |
| 3 | Restated text | FAQ answer 2 repeats the Why lede: "You are the designer, and idstack is the copilot." | Fix (C11) |
| 4 | Repeated heading skeleton | The title, the H1 and four H2s all name "AI" and "instructional design". | Keep. The owner chose the keyword-led headings. |
| 5 | Title-case subheadings | The 11 Evidence card titles. | Keep. They are the domain names in `evidence/references.md`, and a test compares them. |
| 6 | Uniform cards | The Why list and the Evidence cards have items of equal length. | Keep. The content is a list. |

### C10. Sentence case for the install cards

Model: **haiku**. Reason: six label edits with the text given. No judgment is needed, and the tests show a mistake at once.

| Now | New |
|---|---|
| `<h3>Chrome Extension</h3>` | `<h3>Chrome extension</h3>` |
| `<h3>Claude Desktop App</h3>` | `<h3>Claude desktop app</h3>` |
| `<h3>Claude Code Plugin</h3>` | `<h3>Claude Code plugin</h3>` |
| badge `In-Browser (Canvas / Docs)` | `In-browser (Canvas / Docs)` |
| badge `No Terminal` | `No terminal` |
| badge `All Skills` | `All skills` |

Text on the page that names a card ("the Claude Desktop App card") follows the new case.

### C11. Three wording fixes

Model: **haiku**. Reason: three replacements given word for word, plus one CHANGELOG line. The risk is low and the main session reads the diff.

| Where | Now | New |
|---|---|---|
| Install, Chrome card | … in the Chrome side panel. No command line. | … in the Chrome side panel. You do not need a command line. |
| Skills, quick-check card | Cited findings and a corrected version. No setup. | You get cited findings and a corrected version. It needs no setup. |
| FAQ 2 | No. You are the designer, and idstack is the copilot. It writes a first draft and finds the research, but you make each decision: you approve, change or remove each row. | No. idstack writes a first draft and finds the research. You make each decision: you approve, change or remove each row. |

`CHANGELOG.md`, Unreleased: one bullet for C10 and C11 together.

## Round 4: no specific number of studies

The owner asked to remove each reference to a specific number of studies: on the page, on the share card (the tier counts too), on the Evidence cards, and in `README.md` and `DESIGN.md`. A number of domains, tiers, skills or frameworks is not a number of studies and stays. `evidence/references.md` is the list itself and does not change. The Chrome extension and the skill templates are out of scope.

### C12. Total count off the page and the share card

Model: **sonnet**. Reason: the new text is given, but nine places, the share card render and three repo documents must agree, and one guard assertion goes away.

| Where | New text |
|---|---|
| `<title>`, `og:title`, `twitter:title` | `AI instructional design tool, backed by research \| idstack` |
| Meta description, `og:description`, `twitter:description` | the same sentences with "<N> studies" → "peer-reviewed studies" and "<N> peer-reviewed studies" → "peer-reviewed studies". Description 160 characters maximum. |
| Hero link | See the studies |
| Evidence H2 | Evidence-based instructional design: the research behind idstack |
| Evidence lede | "All <N> references are in" → "All the references are in" |
| `docs/og-template.html` lede | "<N> peer-reviewed studies across 11 research domains" → "peer-reviewed studies across 11 research domains" |
| `docs/og-template.html` rail legend | the labels T1 to T5 with no numbers. The colored bar stays. The CSS comment loses its counts. |

- Render `docs/og-image.png` again and look at it.
- `test/check-doc-accuracy.py`: remove the assertion that the title count equals the hero count. C13 adds the new assertion.
- `DESIGN.md` decision-log row for the headline, `CHANGELOG.md` Unreleased entries and the `CLAUDE.md` sentence about hand-typed study counts: make each true again.

### C13. Evidence cards without study counts

Model: **opus**. Reason: this changes a test that guards the one claim idstack cannot get wrong (tier strength), its mutation cases, an accessible label and the card layout.

- Remove the `evidence-row-count` span ("<N> studies") from each of the 11 cards, and the CSS that only it uses. The card order does not change.
- The tier-mix bar keeps `data-tiers` (nothing renders it, and the test reads it). Its `aria-label` gives shares, not counts: "Tier mix: 71% at T1, 5% at T2, …", with the percentages that the bar segments already have, rounded to whole numbers.
- Evidence lede: "ranked by study count" stays true and stays.
- `test/check-evidence-cards.py`: stop reading a visible count. Keep the checks of the domain names, the number of cards, `data-tiers` against `evidence/references.md`, and the tier range. Add a check that each `aria-label` share agrees with `data-tiers`.
- `test/mutation-test.sh`: each case that mutates a card count has no anchor now. Replace it with a case on `data-tiers` or the `aria-label`, or remove it when another case guards the same check. The anchor-only run must report 0 STALE.
- `test/check-doc-accuracy.py`: add an assertion that the visible text of `docs/index.html` has no "N studies" or "N references", with N a number.
- `CLAUDE.md`: the notes about `check-evidence-cards.py` and the hand-typed counts. `CHANGELOG.md`: one Unreleased bullet.

### C14. README and DESIGN.md

Model: **sonnet**. Reason: prose and one table in two documents, with no test on the numbers. The risk is a sentence that reads wrong after the number goes.

- `README.md`: remove each total study count and each per-domain study count and T1 count. The evidence table keeps the domain names and tier ranges. Each sentence must read correctly without its number.
- `DESIGN.md`: the same for each study count outside the decision log. Decision-log rows are history and stay, except the row that C12 corrects.
- Report each remaining study count in the repo outside `evidence/`, `extension/`, `skills/`, `templates/`, `CHANGELOG.md` (released entries) and `docs/superpowers/`.
