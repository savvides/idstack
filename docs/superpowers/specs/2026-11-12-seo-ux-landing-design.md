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

- `<title>`, `og:title`, `twitter:title`: `AI instructional design tool, backed by 168 studies | idstack`.
- Meta description (160 characters maximum), `og:description`, `twitter:description` and the JSON-LD `description`: start with "AI instructional design tool" or "idstack is an open-source AI instructional design tool". Keep the facts that are there now (frameworks, 168 studies, evidence tier, open source, where it runs).
- `og:image:alt` and `twitter:image:alt`: the new H1 text.
- Delete `<meta name="keywords">`.
- Headings:

| Now | New |
|---|---|
| H1: A copilot for instructional designers. | The AI instructional design tool that cites its research. |
| Help with the jobs that you do each day. | AI help for each instructional design job |
| Sixteen skills, in the framework you already use. | AI course design skills for ADDIE, backward design and SAM |
| Every recommendation cites its source. | Evidence-based instructional design: 168 studies |
| Three ways to install. | Three ways to install idstack |

- "Each pipeline skill writes a report and a manifest." does not change.
- `docs/og-template.html`: the same headline. (C7 renders `docs/og-image.png` again.)
- `DESIGN.md`: a decision-log row for the new headline, and each place that quotes the old one.

### C2. Hero paragraph and the no-terminal path

Model: **sonnet**. Reason: a small edit in one block, with the text given here; the risk is only the markup and the touch-target tests.

- Replace the 85-word paragraph with about 35 words:
  "idstack helps you do each job of an instructional designer, in ADDIE, backward design or SAM. Each recommendation cites its study and its evidence tier, from T1 to T5. 168 peer-reviewed studies. It runs in Claude Code, Cowork or Chrome."
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
