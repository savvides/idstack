# Design System — idstack

This file is the source of truth for idstack's visual system. Any visual or UI decision (font, color, spacing, radius, motion) must be grounded here. The canonical implementation is `templates/assets/idstack.css` (per-skill HTML reports + course dashboard); when this file changes, that implementation updates in the same PR. The idstack.org landing page (`docs/index.html`) is an intentional separate dark/indigo surface that no longer tracks this report token system (see Decisions log, 2026-06-12).

## Product context

- **What this is:** Open-source set of skills for evidence-based instructional design. Runs in Claude Code and OpenAI Codex CLI. 11 skills, 108 peer-reviewed studies across 11 research domains, every recommendation tagged with its evidence tier T1–T5.
- **Who it's for:** Instructional designers (university, K-12, corporate L&D), faculty doing their own course design, course-design teams. **Downstream stakeholders:** deans, faculty senates, accreditation reviewers — they read the HTML reports the designer hands them.
- **Space:** Edtech / instructional design. Adjacent inspiration: open-access academic publishing (eLife), evidence-based-medicine reference (UpToDate, Cochrane), modern dev tools (Linear, Cursor).
- **Project type:** Hybrid — three surfaces share one system:
  1. Marketing landing (`idstack.org`) — drives discovery + install. Uses a distinct dark/indigo aesthetic, separate from the report system.
  2. CLI tool — terminal interaction, text-only, design-irrelevant.
  3. Stakeholder deliverables — branded HTML reports + `index.html` course dashboard under `.idstack/exports/<course-slug>/`. Audience: designer + their stakeholders.

## Memorable thing

**Proof.** This is evidence applied to course design — every claim is cited and tier-rated, like a clinical reference. Every design decision serves this. The visual hierarchy is built around tier badges and citations; the artifact survives a dean's skepticism on first read.

## Aesthetic direction

- **Direction:** Academic publication × clinical reference. eLife meets UpToDate. The product feels like a peer-reviewed deliverable, not a SaaS dashboard.
- **Decoration level:** Minimal-with-purpose. The only decoration is functional — tier-color borders on findings, severity-coded chips, mono citation marks. No gradients, no illustrations, no stock photos, no decorative blobs anywhere.
- **Mood:** Quiet authority. The page rhythm is set by typography and tier markers. Reads as defensible without needing to be told it's defensible.
- **Reference sites consulted:** elifesciences.org (energy + restraint), uptodate.com (evidence-tier convention), linear.app (modern restraint). Anti-references (what NOT to do): qualitymatters.org (association look), stripe.com gradient hero (overused signature pattern).

## Typography

- **Display + body:** **Source Serif 4** (Adobe / open source). Body-serif is the deliberate commitment — every paragraph reinforces the publication mood. Source Serif 4 has multiple optical sizes (`opsz` axis) so the same family handles 13px captions through 65px hero headlines without going off-design.
- **UI / labels / badges / table cells:** **Public Sans** (USWDS / open source). Designed for US-government documents; reads as "official record" rather than "SaaS chrome." Anti-Inter.
- **Citations / IDs / code / file paths:** **JetBrains Mono** (open source). Citations like `[Alignment-14] [T1]` are the academic-paper convention rendered in mono — load-bearing, not decorative.
- **Loading:** Google Fonts via one `<link>` in each HTML surface (`docs/index.html`, `templates/report.html.tmpl`, `templates/index.html.tmpl`). System-font fallbacks are preserved in `--font-*` tokens so the page is legible even when the network is unavailable. Total weight ~120kb woff2 for the variable axes used.
- **Scale (modular, ratio 1.250 — major third), base 1rem = 17px:**

  | Token | rem | px | Role |
  |---|---|---|---|
  | `h1` | 3.82 | 65 | Page title (report header, landing hero) |
  | `h2` | 2.44 | 41 | Section heading |
  | `h3` | 1.95 | 33 | Subsection heading |
  | `h4` | 1.56 | 27 | Finding card title |
  | `h5` | 1.25 | 21 | Inline emphasis heading |
  | `body` | 1.00 | 17 | Default paragraph |
  | `small` | 0.80 | 14 | Captions, mono citations, badges |

- **Line heights:** 1.65 body · 1.20 display · 1.40 UI.

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

**Dark mode strategy:** Auto via `prefers-color-scheme: dark` (the report stylesheet). Surfaces redesigned (not just inverted): inky-dark background `#16140f`, warm-cream text `#ebe7dd`, terracotta accent `#d97461` replaces oxblood (oxblood loses too much chroma when inverted). All tier and severity tokens redefined with 10–20% saturation drop and adjusted backgrounds. The light theme is canonical; dark mode is a courtesy. The landing page is now dark-only (not a toggle), with its own indigo palette (`#0a0a0f` background, `#6366f1`→`#a855f7` gradient accents), distinct from the report stylesheet dark mode described here.

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
| `enter` | `cubic-bezier(0.2, 0, 0, 1)` | Hover, focus, theme toggle |
| `exit` | `cubic-bezier(0.4, 0, 1, 1)` | Dismissal |

| Token | ms | Use |
|---|---|---|
| `micro` | 50–100 | Hover, focus rings |
| `short` | 200 | Theme toggle, dropdown reveal |

No medium / long durations. No scroll-driven animations. No parallax. No entrance animations on page load. `prefers-reduced-motion: reduce` disables all transitions.

## Anti-patterns (NEVER ship)

- Gradient mesh hero (Stripe owns it; copying = derivative AI-slop). _(Scope: this binds the report system. The marketing landing uses an indigo→purple gradient-ACCENT treatment by explicit decision — accent marks, not a full-bleed mesh hero background. See Decisions log, 2026-06-12.)_
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
