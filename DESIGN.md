# Design System — idstack

This file is the source of truth for idstack's visual system. Any visual or UI decision (font, color, spacing, radius, motion) must be grounded here. Per-skill reports and the course dashboard are plain Markdown and carry no styling (see Decisions log, 2026-11-02), so this system has no report stylesheet to keep in sync. The token, type and report-layout sections below record the report identity that the retired HTML reports used. The idstack.org landing page (`docs/index.html`), its OG card template (`docs/og-template.html`, which renders `docs/og-image.png`) and the Chrome extension side panel (`extension/sidepanel/`) are now the only styled surfaces. All three use these tokens and fonts. The landing page has its own prussian hero, and the side panel has its own dark mode; see § Landing page and the Decisions log, 2026-11-01.

## Product context

- **What this is:** Open-source set of skills for evidence-based instructional design. Runs in Claude Code. 12 skills, 146 peer-reviewed studies across 11 research domains, every recommendation tagged with its evidence tier T1–T5.
- **Who it's for:** Instructional designers (university, K-12, corporate L&D), faculty doing their own course design, course-design teams. **Downstream stakeholders:** deans, faculty senates, accreditation reviewers — they read the Markdown reports the designer hands them.
- **Space:** Edtech / instructional design. Adjacent inspiration: open-access academic publishing (eLife), evidence-based-medicine reference (UpToDate, Cochrane), modern dev tools (Linear, Cursor).
- **Project type:** Hybrid — four surfaces share one system:
  1. Marketing landing (`idstack.org`) — drives discovery + install. Uses the Proof tokens with a prussian hero; see § Landing page.
  2. CLI tool — terminal interaction, text-only, design-irrelevant.
  3. Stakeholder deliverables — plain Markdown reports + `index.md` course dashboard under `.idstack/exports/<course-slug>/`. Audience: designer + their stakeholders. No visual system: the content contract in `templates/report-format.md` sets their structure.
  4. Chrome extension side panel (`extension/sidepanel/`) — audits Canvas, Google Docs and web pages. Uses the Proof tokens (ivory background, tier and severity palettes, Source Serif 4 / Public Sans / JetBrains Mono), copied into `extension/sidepanel/sidepanel.css`.

## Memorable thing

**Proof.** This is evidence applied to course design — every claim is cited and tier-rated, like a clinical reference. Every design decision serves this. The visual hierarchy is built around tier badges and citations; the artifact survives a dean's skepticism on first read.

## Aesthetic direction

- **Direction:** Academic publication × clinical reference. eLife meets UpToDate. The product feels like a peer-reviewed deliverable, not a SaaS dashboard.
- **Decoration level:** Minimal-with-purpose. The only decoration is functional — tier-color borders on findings, severity-coded chips, mono citation marks. No gradients, no illustrations, no stock photos, no decorative blobs anywhere.
- **Mood:** Quiet authority. The page rhythm is set by typography and tier markers. Reads as defensible without needing to be told it's defensible.
- **Reference sites consulted:** elifesciences.org (energy + restraint), uptodate.com (evidence-tier convention), linear.app (modern restraint). Anti-references (what NOT to do): qualitymatters.org (association look), stripe.com gradient hero (overused signature pattern).

## Typography

- **Display + body:** **Source Serif 4** (Adobe / open source). Body-serif is the deliberate commitment — every paragraph reinforces the publication mood. Source Serif 4 has multiple optical sizes (`opsz` axis) so the same family handles 13px captions through display headings without going off-design.
- **UI / labels / badges / table cells:** **Public Sans** (USWDS / open source). Designed for US-government documents; reads as "official record" rather than "SaaS chrome." Anti-Inter.
- **Landing display voice:** on `docs/index.html` only, headings use **Public Sans**: the page and section headings (h1, h2) are 700 with tight tracking (−0.02 to −0.025em); the smaller h3 labels use 600 or 700, most with lighter tracking (−0.005 to −0.01em), and the install-card h3s keep the base −0.02em. Body text stays Source Serif 4. Headlines then read as an official record rather than an editorial essay; the May 2026 landing with serif headlines read as generic. Reports are unchanged.
- **Citations / IDs / code / file paths:** **JetBrains Mono** (open source). Citations like `[Alignment-14] [T1]` are the academic-paper convention rendered in mono: functional reference notation, not decorative.
- **Loading:** Google Fonts via one `<link>` in each HTML surface. `docs/index.html` and `docs/og-template.html` load `https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&family=Public+Sans:wght@400;500;600;700&family=Source+Serif+4:opsz,wght@8..60,400;8..60,500;8..60,600;8..60,700&display=swap`; smoke-test checks that the landing loads this URL. The extension side panel (`extension/sidepanel/index.html`) loads its own subset: JetBrains Mono 400–500, Public Sans 400–600, and Source Serif 4 400/600 plus italic 400. System-font fallbacks are preserved in `--font-*` tokens so the page is legible even when the network is unavailable. Total weight ~120kb woff2 for the variable axes used.
- **Scale (modular, ratio 1.250 — major third), base 1rem = 17px:**

  | Token | rem | px | Role |
  |---|---|---|---|
  | `h1` | 3.82 | 65 | Page title (reference scale; the landing hero uses its own size, see below) |
  | `h2` | 2.44 | 41 | Section heading |
  | `h3` | 1.95 | 33 | Subsection heading |
  | `h4` | 1.56 | 27 | Finding card title |
  | `h5` | 1.25 | 21 | Inline emphasis heading |
  | `body` | 1.00 | 17 | Default paragraph |
  | `small` | 0.80 | 14 | Captions, mono citations, badges |

- **Landing page sizes:** `docs/index.html` sets no root font size, so there 1rem = 16px and the 17px base is only the body text size (`body { font-size: 1.0625rem }`). The hero `h1` is Public Sans 700 at `clamp(2rem, 5vw, 3.3rem)`, which is 32px to about 53px.

- **Line heights:** 1.65 body · 1.20 display · 1.40 UI.
- **When to use fluid `clamp()` type (landing page):** only where the size genuinely moves —
  a total min→max span of roughly 1.5px or more. Below that the clamp is a three-term
  declaration encoding a sub-pixel step, so use a fixed rem value instead. Seven declarations
  in `docs/index.html` clear the bar (`.brand`, `.nav-links a`, `.section-header h2`,
  `.hero h1`, `.hero .lede`, `.install-track-header h3`, `.install-block code`); the rest are
  fixed. The layout tokens `--pad-x` / `--pad-y` stay fluid regardless: 16→32px (fluid across a
  457–914px viewport) and 44→88px (800–1600px).

## Color

Restrained. Two-color annotation set (rust + prussian blue) for primary marks; tier and severity palettes do the work of differentiating findings.

**Background / ink / rules:**

| Token | Hex | Role |
|---|---|---|
| `--bg` | `#faf8f3` | Pristine ivory — pages, page backgrounds. NOT pure white (too sterile), NOT parchment-warm (too cozy). |
| `--raised` | `#ffffff` | Card / surface backgrounds — finding cards, swatches. |
| `--ink` | `#1a1815` | Body text and primary headings. Warm near-black. |
| `--ink-soft` | `#3a352e` | Secondary text, captions over `--raised`. |
| `--ink-muted` | `#6b6358` | Tertiary text — meta lines, finding-card labels. |
| `--rule` | `#e6e0d2` | Hairline rules, finding-card borders. |
| `--rule-strong` | `#d4cdb9` | Stronger dividers, table borders. |

**Two-color annotation set (the strategic accent pair):**

| Token | Hex | Role |
|---|---|---|
| `--accent` | `#7a1f1f` | Library-stamp / annotation red. Page kickers, primary CTA, critical chips. Evokes academic editor's red pen. |
| `--accent-blue` | `#1d4a5e` | Prussian blue. Hyperlinks, citation cross-references, "see also" markers. The second color in academic editing. |
| `--accent-soft` | `#f4eae8` | Tinted hover / fill for `--accent` surfaces. |

**Evidence-tier palette (the heart of Proof):**

| Token | Hex | Tier |
|---|---|---|
| `--tier-1` | `#2f7a4a` | T1 — Meta-analyses, RCTs (heaviest weight, deepest color) |
| `--tier-2` | `#2864a8` | T2 — Quasi-experimental with controls |
| `--tier-3` | `#a87726` | T3 — Systematic reviews of mixed evidence |
| `--tier-4` | `#b35a1f` | T4 — Observational without comparison |
| `--tier-5` | `#6b6b6b` | T5 — Expert opinion (lightest, grey to evoke weakness) |

**Severity palette (finding-card left border + chip fill):**

| Severity | fg | bg | Use |
|---|---|---|---|
| critical | `#8c2515` | `#f5dcd5` | Course will measurably fail learners. |
| warning | `#7a4f0c` | `#fbf0d9` | Likely problem worth addressing. |
| info | `#344566` | `#e7eaf1` | Worth knowing, not blocking. |

**Landing hero (`docs/index.html` only):**

| Token | Hex | Role |
|---|---|---|
| `--hero-bg` | `#163a4a` | Hero and topbar ground. A darker step of `--accent-blue`; reads like a journal cover. |
| `--hero-ink` | `#faf8f3` | Hero headline and primary text (the ivory `--bg`). |
| `--hero-soft` | `#dfe6e8` | Hero lede, nav links, meta line. |
| `--hero-panel` | `#0f2c39` | Session transcript and install command panels. |
| `--hero-rule` | `#2b5263` | Borders on the hero. |

**Dark mode strategy:** Auto via `prefers-color-scheme: dark` (the retired report stylesheet). Surfaces redesigned (not just inverted): inky-dark background `#16140f`, warm-cream text `#ebe7dd`, terracotta accent `#d97461` replaces oxblood (oxblood loses too much chroma when inverted). All tier and severity tokens redefined with 10–20% saturation drop and adjusted backgrounds. The light theme is canonical; dark mode is a courtesy. The landing page uses these dark tokens through `prefers-color-scheme` (no toggle); its hero darkens to `#10232c`.

## Landing page

`docs/index.html` is a Persuade surface built from the Proof tokens: the fonts, tier colors and `[Code-N] [Tn]` citation notation that the skills write.

- **Hero:** a full-width prussian band. On the left: the claim, the lede with filled T1 and T5 chips, the CTAs, the meta line. On the right: a static session transcript (`/idstack:course-import`) that ends in the short Step Review note, which names the draft report path (`.idstack/exports/bio-101/course-import.md`) in code, not as a link. Then come one ivory finding card, captioned as a row from that report, with a severity chip, a tier chip and a `[Domain-N] [Tn]` citation, and a line about 3 more flags in the report. The visitor sees a cited finding before they install. No animation.
- **Evidence index:** one row per research domain, ranked by study count. Each row has the study count and a stacked T1–T5 bar. The bar width scales to the count (the largest domain = full width), and each segment is that domain's count at one tier. `data-tiers` holds the five counts; `test/check-evidence-cards.py` checks them, the count and the tier range against `evidence/references.md`. The counts, the row widths and the segment widths are typed by hand in `docs/index.html`. Count them from `evidence/references.md`, never from memory. The check does not compare the row or segment widths, so recompute them when a count changes.
- **CTAs:** one solid color for each surface: ivory with prussian text on the hero, oxblood with ivory text on ivory sections. Name the outcome ("Add to Chrome", "Copy").
- **Tier chips:** outlined (the reports are plain Markdown and have no chips). On the hero the outlined chip is too dark to read, so the hero fills it (white text on the light-mode tier color).
- **OG card:** `docs/og-template.html` renders `docs/og-image.png` (1200×630) on the hero ground, with the whole corpus's tier mix as its bottom rail.

## Spacing

- **Base unit:** 4px.
- **Density:** Comfortable. Academic-publishing convention — generous whitespace earns attention.

| Token | px | Use |
|---|---|---|
| `2xs` | 2 | Tight inline gaps (badge padding) |
| `xs` | 4 | Finding card border-left, button padding-y |
| `sm` | 8 | Inline gaps between badges/chips |
| `md` | 16 | Paragraph spacing, table cell padding |
| `lg` | 24 | Section spacing within a card |
| `xl` | 32 | Card-to-card spacing |
| `2xl` | 48 | Section dividers |
| `3xl` | 64 | Major page section spacing |
| `4xl` | 96 | Hero spacing |

- **Minimum interactive target (landing page only):** 44px, as `--tap-min` in `docs/index.html`.
  44px is where Apple's HIG and WCAG 2.5.5 Target Size (Enhanced) both land; citing it is the source
  of the number, not a claim that the page conforms to that AAA criterion. Applies to buttons and
  form inputs at every viewport width, not only in stacked mobile layouts. Text links are not sized
  to it — measured at 375px they run 18px in prose, 29-32px for nav, footer, `.brand` and
  `.cta-secondary`, and 35px for `.skip-link`. They sit in running text where a 44px box would break
  the line rhythm, and all clear WCAG 2.5.8 (AA) at 24px or fall under its inline-target exception.

## Layout

- **Approach:** Hybrid. Grid-disciplined for marketing landing; single-column prose for reports.
- **Grid:** 12-col desktop, 4-col mobile, gutter 24px.
- **Max content width:** `1120px` outer container (marketing) · `64ch` prose column (reports).
- **Optional Tufte side-notes:** 200px right column for evidence callouts on long reports. Only used when there's lateral content worth surfacing — never as decoration.

**Border radius (sharp by default — the publication signal):**

| Token | px | Use |
|---|---|---|
| `none` | 0 | Finding cards, table cells, surfaces |
| `sm` | 2 | Buttons, install snippet, badges, chips |
| `md` | 4 | Form inputs (rare) |
| `full` | 9999 | Avatars only (none in current scope) |

## Motion

- **Approach:** Minimal-functional. Academic publications don't animate.

| Token | Curve | Use |
|---|---|---|
| `enter` | `cubic-bezier(0.2, 0, 0, 1)` | Hover, focus |
| `exit` | `cubic-bezier(0.4, 0, 1, 1)` | Dismissal |

| Token | ms | Use |
|---|---|---|
| `micro` | 50–100 | Hover, focus rings |
| `short` | 200 | Dropdown reveal (no surface uses it at present) |

No medium / long durations. No scroll-driven animations. No parallax. No entrance animations on page load. On the landing page, `prefers-reduced-motion: reduce` disables all transitions. One landing-page transition breaks these rules: the skip link slides in on focus with a 150 ms transition on the default `ease` curve. The extension side panel does not follow these motion rules yet: it uses 150 ms transitions, a 300 ms width transition and an 800 ms loading spinner, and it has no `prefers-reduced-motion` rule.

## Anti-patterns (NEVER ship)

- Gradients of any kind: mesh heroes, gradient text, gradient buttons. This binds the reports and the landing page.
- A kicker label above every heading. The heading carries its own weight.
- Equal-size cards for content of unequal weight (for example, research domains with 10 and 19 studies). Rank it and show the difference.
- Stock photo of person looking at laptop (Quality Matters does this; category cliché).
- 3-column or 5-column badge-icon feature grid (Quality Matters has FIVE; category cliché).
- Bright association blue + orange palette.
- "Built for X" / "Designed for Y" marketing copy.
- Inter, Roboto, Helvetica, Open Sans, Space Grotesk as primary fonts.
- Rounded card corners > 4px.
- Sans-serif body text (we go serif; that's the named risk).
- Centered-everything layouts.
- Decorative shadows or glows.

## Decisions log

| Date | Decision | Rationale |
|---|---|---|
| 2026-05-13 | Initial design system created | `/design-consultation` after v3.0.0.0 shipped HTML reports. North-star: Proof. |
| 2026-05-13 | Body-serif (Source Serif 4) instead of sans | Deliberate departure from modern editorial sites' sans-body convention. Locks the publication mood every paragraph. Cost: ~2–3% screen readability on low-DPI; accepted. |
| 2026-05-13 | 0 border-radius on finding cards | Sharp corners signal "publication," not "consumer SaaS." Visual differentiation from category. Cost: feels austere on first encounter; accepted. |
| 2026-05-13 | No hero illustration / gradient / image anywhere | Type-only marketing hero. Anti-SaaS, anti-AI-slop. Cost: scroll-stoppage power; accepted. Open question for future if first-time-visitor metrics call for revisiting. |
| 2026-05-13 | Background ivory `#faf8f3` (replaces parchment `#fbfaf6`) | Cleaner publication feel. Parchment-warm read as "old book"; ivory reads as "good paper." |
| 2026-05-13 | Add prussian blue `#1d4a5e` as secondary accent | Two-color annotation set (red + blue) mirrors how academic editors marked manuscripts. |
| 2026-06-12 | Landing reverted to original dark/indigo aesthetic, separate from the report system (owner request) | Reports retain scholarly ivory "Proof" identity. Landing uses indigo→purple gradient accents — a scoped exception to the no-gradient anti-pattern, which still binds reports. |
| 2026-08-29 | Fluid `clamp()` type reserved for sizes that span ≥1.5px | The responsive pass put `clamp()` on 19 landing-page font sizes; 12 of them varied by at most 1.12px across their whole range, i.e. a fixed value written in three terms. Those 12 reverted to fixed rem. Cost: type on phones is up to 1.1px larger than the clamp gave; accepted, it reads slightly better. |
| 2026-08-29 | Minimum interactive target fixed at 44px (`--tap-min`) | The landing page had grown three ad-hoc floors (36/40/42px), and the footer controls applied theirs only below 480px, leaving every width above 480px (desktop included) at 36.6px. One token, applied at every width. Cost: slightly taller controls on desktop; accepted in a product that ships a WCAG review skill. |
| 2026-11-02 | Reports and the course dashboard moved from branded HTML (an HTML skeleton plus the idstack.css stylesheet) to plain Markdown (`templates/report.md.tmpl`, `templates/index.md.tmpl`) (owner request) | Fewer moving parts means fewer errors: no stylesheet copy, no HTML to get wrong. A relative `.md` path has no spaces, so the report link opens in the Claude desktop app; the old absolute HTML path did not when the folder path had a space. Cost: reports lose the "Proof" visual identity (tier-color borders, severity chips, serif type); accepted. |
| 2026-11-01 | Landing rejoins the Proof tokens and fonts; supersedes 2026-06-12 | `/design-consultation`. The tier colors and citation notation match what the skills write. The dark/indigo page looked like most AI dev tools. Since 2026-11-02 the reports are plain Markdown, so the landing (with its OG card template, `docs/og-template.html`) and the Chrome extension side panel (`extension/sidepanel/sidepanel.css`) are the only surfaces that use these tokens. |
| 2026-11-01 | Prussian hero (`#163a4a`) + Public Sans headlines on the landing | The May 2026 ivory landing (PR #27) was reverted because it read as generic: ivory + serif display + oxblood is a common look. A prussian ground and sans headlines give the landing its own face from tokens the system already owns. Cost: the first screen differs from a report's first screen; accepted. |
| 2026-11-01 | Ranked evidence index with tier-mix bars replaces 11 equal cards | Shows where each domain rests on trials and where it rests on reviews or expert opinion (needs analysis is 9 of 11 T3; formative feedback is 10 of 14 T1). Equal cards hid this. Checked against `references.md` per tier. |
| 2026-11-01 | Static session transcript in the hero | Pre-install demo (issue #131): the visitor sees a cited finding before installing. Static, so the motion rules hold. |
