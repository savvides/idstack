# Landing page accuracy audit — design

- **Date:** 2026-08-14
- **Status:** approved, ready for planning
- **Audited surfaces:** `docs/` (the published idstack.org site) and `README.md`
- **Files changed:** `docs/index.html`, `docs/sitemap.xml`, `.github/workflows/static.yml`,
  `test/check-doc-accuracy.py`, `test/mutation-test.sh`, plus two `git mv`s.
  `README.md` was audited and needs no edit — see the change inventory.
- **Baseline commit:** `13db318`

## Problem

idstack.org is generated from `docs/` and deployed on every push to `main`. Two automated checks
guard it — `test/check-doc-accuracy.py` (version strings) and `test/check-evidence-cards.py`
(study counts and tier spans). Both pass. Everything they do not cover is unverified, and an audit
of the page against the repo found eleven defects across three kinds:

1. **The page states something untrue.**
2. **The page omits something material about the repo.**
3. **The site publishes files that were never meant to be public.**

## Findings and scoring

Findings are weighted by user impact: **4** = wastes a user's time or is a real obligation gap ·
**3** = a visitor would notice and be misled · **2** = countable inconsistency, low cost ·
**1** = machine-readable only, invisible to humans.

| # | Finding | Location | Kind | Wt |
|---|---|---|---|---|
| 5 | JSON-LD claims Windows support with no WSL/Git Bash caveat; `./setup` is a bash script that PowerShell and `cmd` cannot run | `docs/index.html:44` | wrong | 4 |
| 6 | Email signup form with no link to the `PRIVACY.md` that exists in the repo | `docs/index.html:1177` | omission | 4 |
| 10 | Internal design docs served at idstack.org | `docs/superpowers/{specs,plans}/` | hygiene | 4 |
| 1 | "Install in about five minutes" contradicts README's "Install — 30 seconds" | `docs/index.html:1127`, `README.md:15,95` | wrong | 3 |
| 4 | v3.4.0.1 release note covers only the evidence-card fix; ROADMAP lists two more shipped items | `docs/index.html:1153` | wrong | 3 |
| 7 | `bin/idstack-doctor` and `bin/idstack-status` never mentioned on the page | `docs/index.html` install section | omission | 3 |
| 8 | Prerequisites unstated — bash shell required, python3 recommended | `docs/index.html` install section | omission | 3 |
| 9 | "Eleven skills" headline names only ten | `docs/index.html:1012` | omission | 2 |
| 2 | JSON-LD `dateModified: 2026-08-06`; docs changed through 2026-08-12 | `docs/index.html:47` | wrong | 1 |
| 3 | Sitemap `lastmod: 2026-05-13` — three months stale | `docs/sitemap.xml:5` | wrong | 1 |
| 11 | `og-template.html` (the OG-card generator source) served publicly | `docs/og-template.html` | hygiene | 1 |

**Total gap: 29 points.** This design closes all 29.

Items 2 and 3 close *permanently* — by deleting the fields rather than correcting them, so they
cannot decay. Every other item is a one-time correction that cannot silently regress.

### Verified accurate — no action

Confirmed correct against the repo, recorded so a future audit does not re-derive them: all version
strings; "108 peer-reviewed studies across 11 research domains" (108 unique references counted in
`evidence/references.md`, 11 domains); all 11 evidence cards; every per-skill claim in the pipeline
section (`UDL 3.0`, `WCAG 2.1 AA`, `SCORM 1.2`, red-team's 5 dimensions, Nicol's 7 feedback
principles, three-level needs assessment — each matches its `SKILL.md`); `og-image.png` (no baked-in
version, no reference to the retired Codex build); all 11 outbound links (HTTP 200); and the GitHub
repo's description, topics, and homepage URL.

## Design decisions

### D1 — Stop publishing internal docs by excluding at build, not by moving files

`.github/workflows/static.yml` uploads `docs/` verbatim via `actions/upload-pages-artifact@v3`,
which accepts a single `path`. Add a staging step that copies `docs/`, removes the non-public
paths, and uploads the staged directory:

```yaml
# ordering: after Checkout and Setup Pages, before Upload
- name: Stage publishable files
  run: |
    rm -rf _site
    cp -R docs _site
    rm -rf _site/superpowers
    rm -f _site/og-template.html

- name: Upload artifact
  uses: actions/upload-pages-artifact@v3
  with:
    path: '_site'
```

Step order matters: staging must run after `actions/checkout@v4` and before
`upload-pages-artifact@v3`. Run verification item 6 (the three shell lines, locally) *before*
editing the workflow, so a staging bug is caught without a deploy round-trip.

**Why the exclusion is load-bearing and a `git mv` is not.** The brainstorming skill writes specs to
`docs/superpowers/specs/` by default. Relocating today's two files without a build exclusion gets
silently undone the next time anyone runs that skill. The `rm -rf _site/superpowers` line is the
durable fix; it remains a no-op backstop after the relocation below.

**Why `og-template.html` can only be excluded, never moved.** `test/smoke-test.sh:136-141` asserts
the file exists at `docs/og-template.html` and lints its gradient-text fallbacks. It must stay where
it is; build-time exclusion is the only mechanism that removes it from the published site without
breaking the suite.

Additionally, relocate the two existing design docs from `docs/superpowers/` to `superpowers/` at
the repo root. This is cosmetic once the exclusion exists, but it keeps `docs/` meaning "the
website." Verified safe: nothing in the repo references `docs/superpowers/`.

### D2 — Delete the two staleness-prone fields rather than correct them

Remove `"dateModified"` from the JSON-LD block and `<lastmod>` from `sitemap.xml`. Keep
`"datePublished": "2026-04-20"` (a historical fact that cannot go stale) and the sitemap's
`changefreq`/`priority`.

**Rejected: assert the date is current in CI.** The natural guard — `dateModified` must be no older
than the last commit touching `docs/` — fails on commits that did not introduce the defect. A pull
request that sits open for a week, or a merge dated after the docs edit, red-lights `main` for a
reason unrelated to the change being made. CI here runs every suite on every push and pull request;
a check that cries wolf is a check people learn to bypass.

**Why deletion is not a downgrade.** Both fields are optional, and under the scoring model both
items are weight 1 — "machine-readable only, invisible to humans." Whatever value a freshness
signal carries, a value three months stale is not delivering it: the field currently asserts
something false, and the choice is between an absent field and a wrong one. Absent wins. Search-
engine treatment of `lastmod` is deliberately left out of this rationale; the argument does not
need it and this document should not carry a third-party claim it cannot verify.

> **Assumption, stated explicitly.** The approved scope was "fix `dateModified` and sitemap
> `lastmod`." Deleting them is a *different action* that reaches the same score. Proceeding on the
> owner's approval of D2 as presented. Reverting to "keep the fields, bump them by hand" is a
> one-line change to this section and drops the guard in D3.

### D3 — Guard by asserting absence

Extend `test/check-doc-accuracy.py` with a `check_no_stale_dates(root, problems)` function, called
from `main()` alongside the existing checks:

- `docs/index.html` must not contain `dateModified`
- `docs/sitemap.xml` must not contain `lastmod`

An absence assertion cannot false-positive: it fails only when someone reintroduces the exact field
this design removed. Add a corresponding entry to `test/mutation-test.sh` (mutation 22, following
the established `fresh` → mutate → `expect_fail` pattern used by mutations 20 and 21) that
reintroduces `"dateModified": "2026-08-06",` into `docs/index.html` and asserts `smoke-test.sh`
fails.

### D4 — All page changes reuse existing landing-page styles

`DESIGN.md`'s decisions log (2026-06-12) records that the landing page is an intentional separate
dark/indigo surface that no longer tracks the report token system. Every change below therefore
reuses the page's existing inline classes — `.install-prose`, `.footer-links a`, `.lede`. **No new
CSS, no new visual patterns, no new components.** Nothing here constitutes a design decision, so
`DESIGN.md` needs no update and `templates/assets/idstack.css` is untouched.

## Change inventory

Line numbers are as of `13db318`; anchor text is authoritative.

### `docs/index.html`

| Anchor | Change | Closes |
|---|---|---|
| `"operatingSystem": "macOS, Linux, Windows"` (L44) | → `"macOS, Linux, Windows (WSL or Git Bash)"`. **Secondary.** Schema.org expects OS names here; a parenthetical caveat is a precision improvement, not a machine-readable constraint. Do not treat this as the fix for 5 | 5 (partial) |
| `"dateModified": "2026-08-06",` (L47) | delete the line | 2 |
| `<h2 id="pipeline-title">` lede (L1013) | the lede accounts for 8 pipeline skills + 2 asides = 10; revise so `/idstack:pipeline` is counted as the eleventh rather than only appearing in the track label, so a reader who counts reaches eleven | 9 |
| `<h2 id="install-title">Install in about five minutes.</h2>` (L1127) | → `Install in 30 seconds.` | 1 |
| after `.install-prose` (L1136) | new `.install-prose` paragraph: bash shell required (WSL or Git Bash on Windows), python3 recommended; `bin/idstack-doctor` diagnoses a broken install, `bin/idstack-status` shows course health. **This is the primary fix for 5** — a Windows visitor is stopped by prose they can read, not by a JSON-LD string they never see | **5**, 7, 8 |
| v3.4.0.1 patch paragraph (L1153) | add the two other shipped items per ROADMAP — `PRIVACY.md` disclosures for Canvas API uploads and `bin/idstack-update-check` git fetches, and the Windows/WSL install instructions | 4 |
| `.footer-links` block (L1177) | add `<a>` to `PRIVACY.md` on `main`, beside MIT License / Contribute / Roadmap | 6 |

### `docs/sitemap.xml`

Delete `<lastmod>2026-05-13</lastmod>` (L5). Closes 3.

### `README.md`

No change. It is already internally consistent at "30 seconds" (L15, L95); `docs/index.html`
reconciles to README, not the reverse, because README's number describes the exact command the page
displays. The page's separate "New to Claude Code? Download it first" line already carries the
Claude Code install time.

### `.github/workflows/static.yml`

Add the staging step from D1; repoint `upload-pages-artifact` at `_site`. Closes 10 and 11.

### `superpowers/specs/`, `superpowers/plans/`

`git mv docs/superpowers/specs/2026-08-12-documentation-accuracy-design.md` and
`git mv docs/superpowers/plans/2026-08-12-documentation-accuracy.md` to the repo-root
`superpowers/` tree. `superpowers/specs/` already exists (this document); `superpowers/plans/` must
be created first — `git mv` will not create it. Remove the now-empty `docs/superpowers/`. Closes 10.

### `test/check-doc-accuracy.py`, `test/mutation-test.sh`

Add the D3 guard and its mutation.

## Verification

Success criteria, each independently checkable:

1. `python3 test/check-doc-accuracy.py .` → exit 0 with the new check present.
2. `./test/smoke-test.sh` → green (it runs the validator and the `og-template.html` assertions).
3. `python3 test/check-evidence-cards.py .` → green, unchanged.
4. `./test/mutation-test.sh` → mutation 22 reports `GUARDED`; every prior mutation still `GUARDED`.
5. Reintroducing `dateModified` by hand makes check 1 fail — confirms the guard bites outside the
   mutation harness.
6. Staging step simulated locally (`rm -rf _site && cp -R docs _site && rm -rf _site/superpowers &&
   rm -f _site/og-template.html`) → `_site` contains `index.html`, `sitemap.xml`, `robots.txt`,
   `CNAME`, both favicons, `og-image.png`, and `why-ai-native.md` (raw Markdown, intended public
   content — see Non-goals); contains neither `superpowers/` nor `og-template.html`.
7. Post-merge: `curl -o /dev/null -w "%{http_code}"` on
   `https://idstack.org/superpowers/specs/2026-08-12-documentation-accuracy-design.md` and on
   `https://idstack.org/og-template.html` → both 404. `https://idstack.org/` → 200.
8. Re-run the outbound link sweep over `docs/index.html` — all links 200, including the new
   `PRIVACY.md` link.

## Non-goals

- **Repo About blurb, topics, homepage URL.** Checked via `gh repo view`; current and accurate.
- **Any visual redesign.** D4 constrains this to existing classes.
- **`docs/why-ai-native.md`.** Served as raw Markdown at idstack.org, but it is intended public
  content, linked from README, and reachable only by direct URL. Out of scope.
- **Rewriting the What's-new section beyond finding 4.** Only the incomplete v3.4.0.1 note changes.
- **A general link-checker in CI.** All 11 links currently resolve; adding network-dependent checks
  to the suite is a separate decision with its own flakiness tradeoff.

## Note on this document's location

Written to `superpowers/specs/` at the repo root, deviating from the brainstorming skill's
`docs/superpowers/specs/` default. That default is finding 10 — following it would publish this
design document at idstack.org, which is the defect being fixed.
