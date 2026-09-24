# Changelog

## v3.6.0.0 (2026-09-24)

Adds an optional Consensus evidence engine to the skills and the Chrome extension, and hardens the extension after a code review of v3.5.0.0. The extension no longer asks for access to every website, refuses Canvas pages that show student records, reads every page of a course's assignments, and its privacy notes now say what is sent to Google and to Consensus. The extension is now version 1.1.0 and needs Chrome 116 or later.

To update: `cd` into your idstack clone, then `git pull && ./setup`. The Chrome Web Store updates the extension on its own once 1.1.0 is published there.

### Added — Consensus evidence engine (bring your own key)

- **`bin/idstack-consensus`** looks up a claim in the Consensus research database and caches every answer under `~/.idstack/cache/consensus/`, so a claim is looked up once. Its subcommands are `status`, `configure`, `query`, `verify`, and `sync`. It reads your own Consensus API key from `CONSENSUS_API_KEY`, `~/.idstack/profile.yaml`, or the project manifest. Without a key it works from `evidence/references.md` alone.
- **An evidence check before findings are written.** `/idstack:course-quality-review`, `/idstack:assessment-design`, and `/idstack:red-team` now pass their findings through `idstack-consensus verify` before writing the report or the manifest. It corrects four known neuromyths (learning styles, left- and right-brain learning, "10% of the brain", and Dale's cone retention percentages), checks each tier against `evidence/references.md`, and attaches literature matches when a key is set.
- **Every skill's preamble reports whether a Consensus key is configured**, and `bin/idstack-doctor` checks the CLI and its cache.
- **The Chrome extension takes an optional Consensus API key in Settings.** With a key, each finding's claim is looked up on Consensus after the audit, and a matched finding shows a Consensus badge and a link to the top paper. The neuromyth corrections apply with or without a key. PRIVACY.md says what is sent and where results are kept.

### Fixed — the extension could read every website

- **v3.5.0.0 injected its page reader into every site you visited.** Chrome's install prompt therefore said it could read your data on all websites, and the same match let the extension's background worker make logged-in requests to any site and read the replies. The reader is now injected only into the tab you are looking at, after you click the idstack toolbar icon. Canvas at `instructure.com` needs no click. A Canvas site on its own domain is requested for that site only, when you first click **Audit Entire Course** there, and Chrome asks you before granting it. The toolbar icon now opens the panel and no longer closes it.
- **The background worker took course-audit requests from any part of the extension, including the page reader it injected into every site, and fetched whatever course address it was given.** Web pages themselves could not message it. It now ignores messages that don't come from the extension's own pages. The course audit accepts only a bare `https` site address and a numeric course id before it requests anything with your Canvas login.

### Fixed — student-record pages, Modules pages, and Google Docs

- **Canvas pages that show student records were read like any other page.** Gradebook and SpeedGrader, grades, People (in a course or the whole account), groups, discussions, submissions, and Inbox are now refused, and the panel says why instead of auditing them. Other Canvas pages no longer fall back to reading the whole page body, and rubric text is now included. On a Canvas site outside `instructure.com`, only numeric `/courses/<n>` pages are read as Canvas; its other pages, such as the dashboard, are read like any web page.
- **A Modules page audited only its first item.** Every module item title is now read, including a course home shown in Modules view.
- **Google Docs were read from the editor's rendered page.** The extension now downloads the document's plain-text export with your Google login, waits at most 10 seconds, accepts only plain text, and says so when a document can't be exported. Published (`/d/e/`) documents are not fetched.

### Fixed — the course audit read at most 50 assignments and hid failures

- **Courses with more than 50 assignments were silently cut short.** The crawler now follows Canvas's pagination to the end, up to 10 pages (500 assignments), and says so when a course has more. A failed request or an unexpected response now stops the audit with an error. It used to become an empty assignment list, so the audit ran as if the course had no assessments.
- **The course prompt could cut an assignment off partway through.** It keeps its 20,000-character budget but fills it with whole assignments, and its header now states how many of the course's items are shown in full.

### Fixed — empty pages, malformed answers, slow requests, and the API key in the URL

- **An empty or unreadable page was still audited.** Pages with fewer than 10 words are refused before anything is sent, with the reason when the extension knows it (for example, a tab it cannot read). A course with no syllabus text and no assignments is refused too. Both checks also apply in demo mode.
- **A malformed answer from the model was saved and could crash the results view.** An answer must contain a list of findings before it is saved or shown.
- **A slow model request had no limit of its own.** It now stops after 25 seconds with a message that says so.
- **Your API key travelled in the request URL.** It is now sent in a request header.

### Fixed — the side panel labelled, kept, or retried the wrong result

- **A result could carry the wrong page's name.** A page audit is now labelled with the page that was sent, not whichever tab is active when the answer arrives, and a course audit is labelled with the course. A slow tab read can no longer overwrite a newer one.
- **After an error, the previous result stayed actionable.** The error card now clears it and hides **Add to Dossier** and **Export .md** until the next successful audit. **Retry** re-runs the audit you started, page or course, instead of always running a page audit. If you have since moved to a different course, it goes back to the ready screen instead of auditing that course.
- **A thumbs-up or thumbs-down vote also removed Audit Another Page.** Now only the vote buttons go.
- **The copy buttons did not report a refused clipboard.** One said "Copied!" anyway and the other failed silently. Both now say "Copy failed".
- **The results view crashed on findings that were not a list, on empty entries, or on a tier that was not text.** It now handles all three.

### Fixed — evidence labels disagreed with `evidence/references.md`

- **The extension's tier scale put randomized trials in T2 and called T3 observational.** Its labels now match idstack's scale, T1 meta-analyses and RCTs through T5 expert opinion, and both prompts give the model that scale.
- **Demo findings and the course prompt cited studies idstack does not hold, or held them at the wrong tier.** Biggs (1996) is now `[Alignment-1] [T5]`, not `[Alignment-3]` at T2. The non-existent `[Cognitive-2]` is replaced by `[CogLoad-1]` and `[CogLoad-6]`, which exist. Carpenter (2022), Sweller (2011), and Wood (1976), none of which are in `evidence/references.md`, are replaced by studies that are. An unused list of evidence domains that cited unreferenced studies is removed.
- **The page prompt asked for a `suggestion` severity, which idstack does not use.** It now asks for `critical`, `warning`, or `info`.

### Fixed — the Chrome extension's privacy promises did not match what it does

- **The Settings panel promised that no student data is "ever collected, retained, or used for model training."** None of that held. On a Canvas page the extractor did not recognize, such as Gradebook, People, Inbox, or a discussion, it read the whole page. The panel also points you to a free Google AI Studio key, whose terms let Google use submitted content to improve its products and let human reviewers read it. The extractor now refuses those pages (see above), and the panel says what is sent, to whom, and what Google's free tier allows.
- **"Leave blank to use the built-in free demo tier" described a service that does not exist.** Without a key, every audit returns the same sample findings, whatever the page says. The panel, README, and PRIVACY.md now say so.
- **PRIVACY.md said the API key is stored with `chrome.storage.local`.** The code uses `chrome.storage.sync`, which Chrome copies to your Google account when sync is on. The policy now says that. It also discloses that the last 20 audit results are kept in `chrome.storage.local` and that the side panel loads its fonts from Google Fonts. It no longer claims that the extension never touches rosters or grades, or that its design is FERPA-compliant. The README's "Is my data safe?" answer now points to it for the extension.
- **Correction to the v3.5.0.0 notes.** They said the course crawler audits "syllabi, modules, assignments, discussions, quizzes". It requests the syllabus and assignments only. README repeated the claim, along with a course "dashboard" and a JSON export that do not exist, and is fixed. The v3.5.0.0 entry is left as released.

### For contributors

- **The mutation suite refuses a mutation that changes nothing.** Two cases whose anchors had gone stale kept reporting GUARDED because nothing checked that the mutation had edited anything. The suite now copies the repo once into a snapshot that its baseline smoke run vouches for, and stops on any mutation that leaves the copy unchanged. It grows from 36 cases to 109.
- **The retired-CLI sweep now covers `docs/superpowers/`.** `--exclude-dir=superpowers` matched that name at any depth and exempted every committed spec and plan.
- **The extension tests run the shipped code.** They used to load hand-copied `.cjs` twins, which are gone, and `test-extension.sh` fails if one comes back. `test/extension-harness.mjs` stubs the Chrome APIs and a small DOM, so the tests import the shipped modules and now also run the background worker, storage, and side panel. `test/test-evidence-labels.mjs` checks every citation and tier against `evidence/references.md`. `test/test-disclosures.mjs` checks the side panel, PRIVACY.md, and README against the shipped code.
- **The release workflow pins Node 22**, as the test and mutation jobs already did, and `test-extension.sh` stops with a clear message on a Node too old to import the modules (it needs 20.19+ or 22.7+). The extension suite also has its own CI step, so its full failure output shows.
- **`bin/package-extension.sh` names the zip from `extension/manifest.json`** and leaves the dev-only `icons/generate-icons.js` out of it. The side panel's version badge is tested against the manifest.

## v3.5.1.0 (2026-08-29)

Fixes three defects on idstack.org that only show up on a phone, and repairs the test harness that
was supposed to be catching them. No skill behavior changes.

To update: `cd` into your idstack clone, then `git pull && ./setup`.

### Fixed — every mutation in the suite was passing vacuously

- **`test/mutation-test.sh` reported a perfect score while proving nothing.** Its `fresh()` helper
  copies the repo into a throwaway directory per mutation, and `extension/` was not on the copy
  list. So `test/test-extension.sh` failed on every copy before any mutation was applied, and
  because `expect_fail` only checks that smoke-test exits non-zero, all 36 mutations reported
  GUARDED whether or not their guard worked. The suite that exists to prove the other tests work
  had been unable to fail since the extension landed.

  `extension` is now copied, and a null-mutation control runs first: it aborts the whole suite if
  an unmutated copy is already red, because that is the state in which every GUARDED below it is
  meaningless. Verified by removing the fix again and watching the control fire.

### Fixed — idstack.org on a phone

- **Every content section sat under the notch.** The responsive pass added `viewport-fit=cover`,
  which extends the page into the display cutout, then gave the safe-area inset to the nav, hero
  and footer but not to `.section` — which wraps the evidence, pipeline, output, install and
  what's-new regions. On a notched phone in landscape the install command ran under the cutout.
  The four containers now share one rule, so a fifth cannot be added without the gutter.
- **Touch targets were below the 44px floor, inconsistently.** The page carried three ad-hoc
  minimums (36px, 40px, 42px), and the footer controls applied theirs only below 480px, leaving
  every width above that — tablets and desktop included — at 36.6px. One `--tap-min` token now
  applies at every width.
- **A viewport clip was hiding overflow rather than preventing it.** `overflow-x: clip` on
  `html`/`body` suppressed horizontal scrolling, which also meant a real overflow became content
  the reader could not reach instead of a visible bug. The grid tracks that actually contain long
  install commands now size with `minmax(0, …)`, and the clip is gone: measured clean at 11
  viewport widths from 320px up.

### Added — the landing page is now tested by rendering it

- **`test/test-rendered-landing.js`** loads `docs/index.html` in headless Chrome and asserts what
  the page does at 11 widths: no sideways scroll, every control at least 44px, the pipeline and
  output grids collapsing at their breakpoints, the nav sticky and all its links reachable. It
  adds no npm dependency (Chrome over CDP with node's built-in `fetch` and `WebSocket`) and skips
  loudly when no browser is present. It does require node 22.4+, which is where the global
  `WebSocket` becomes available; CI pins node 22 for exactly this reason.

  The existing suite checks CSS as text, which can only forbid the spellings someone thought of.
  Six kinds of edit shipped a broken page past it — a selector list, an `:is()` wrapper, an
  `@container` wrapper, a print-only media query, a media query nested inside a desktop one, and a
  `<style>` block inside an HTML comment. All six fail the rendered suite. Both run: the text one
  is fast and names the exact rule, the rendered one cannot be talked around.

### Fixed — the responsive guard had holes in it

- Assertions accepted the regressions they existed to catch: `(clip|hidden)` allowed the
  `overflow-x: hidden` that breaks the sticky nav, `grid-template-columns: 1fr` matched the
  `1fr 1fr` it forbids, a `--tap-min` existence check passed while a later rule shipped 30px
  targets, and a `@media` regex spanned block boundaries so a rule could move to another
  breakpoint unnoticed. Each is now pinned and carries a mutation.
- Guards no longer fail correct changes: adding a fifth container to the shared gutter rule, or
  reformatting `minmax(0, 1fr)`, used to fail a page that renders identically.

### Changed

- **CI declares its node dependency.** Both jobs install node rather than relying on the runner
  image. Without it the landing-page suites skip, which in the mutation job means nine mutations
  silently report NOT-GUARDED.
- **Landing page type simplified.** 12 of 19 fluid `font-size: clamp()` declarations varied by at
  most 1.12px across their whole range — a fixed value written in three terms — and are now fixed
  values. The 7 that move meaningfully stay fluid. `DESIGN.md` records the rule and the 44px
  target figure.
- **Documentation corrected** where it disagreed with the code: the smoke-test assertion count,
  the suite tables in `CLAUDE.md` and `CONTRIBUTING.md`, and the claim that every suite sources
  `test/test-helper.sh` (the two node suites cannot).

## v3.5.0.0 (2026-08-16)

Adds the native Chrome Side Panel extension for Canvas LMS and web course audits, the Course Dossier compiled Markdown export, and resolves open issues in learnings log management and test coverage.

To update: `cd` into your idstack clone, then `git pull && ./setup`.

### Added — Chrome Extension (No-Terminal Mode) & Canvas Course Crawler

- **Native Chrome Side Panel extension.** Audits course pages directly inside Canvas LMS, Google Docs, or web syllabi. Evaluates cognitive demand across Bloom's levels, assesses constructive alignment against course outcomes, provides T1–T5 evidence citations, and generates 1-click improved rubrics.
- **Background Canvas Course Crawler.** When viewing a Canvas course home or modules list (`/courses/:id`), idstack can audit the entire course hierarchy (syllabi, modules, assignments, discussions, quizzes) using your active browser session without requiring developer API tokens or command-line tools.
- **Multi-Page Course Dossier & Compiled Markdown Export.** Incrementally collect audits across multiple course pages into an active Course Dossier drawer. Compiles into a single structured institutional deliverable (`.md`) or copies to the clipboard with executive summaries, cognitive demand matrices, and empirical citations.
- **Automated Web Store Packaging.** Added `bin/package-extension.sh` to package clean `.zip` archives into `build/` for Chrome Web Store distribution.

### Fixed — Learnings log atomicity & cross-project search precedence

- **Atomic delete in `bin/idstack-learnings-delete` (#60).** Truncating in-place risked corrupted or lost learning records on mid-write interrupts. Deletions now write via `tempfile.mkstemp`, preserve original file mode permissions (`shutil.copymode`), and perform atomic `os.replace` with cleanup on exception.
- **Local-over-global precedence in `bin/idstack-learnings-search` (#61).** Under `--cross-project`, global entries previously won when `--limit` truncated matches. Sources are now ordered global-first, local-last so local learnings take precedence across both Python and shell fallback search paths.
- **Test coverage gaps closed (#62).** Added test coverage in `test/smoke-test.sh` for `bin/idstack-slugify` implicit and explicit (`-`) stdin pipelines and emoji/non-ASCII character stripping, and `bin/idstack-migrate` raw fallback on malformed JSON manifests. Corrected `bin/idstack-learnings-delete` header comment.

## v3.4.0.1 (2026-08-07)

Accuracy pass over the public surfaces before sharing the project more widely. No skill behavior changes.

To update: `cd` into your idstack clone, then `git pull && ./setup`.

### Fixed — three evidence cards claimed better evidence than idstack holds

- **Two cards on idstack.org advertised T2 for domains whose strongest reference is T3**, and a third advertised T5 for a domain that bottoms out at T4. Needs Analysis showed `T2–T5` when all 7 of its references are T3; Evaluation Models showed `T2–T5` against an actual `T3–T5`; Online Course Quality Frameworks showed `T1–T5` against an actual `T1–T4`. The other eight cards were correct, and every study count already matched.

  Overstating a tier is the one inaccuracy this project cannot ship — labelling evidence honestly is the entire claim. The cards are no longer hand-maintained: `test/check-evidence-cards.py` derives every count and tier span from `evidence/references.md` and smoke-test fails on any disagreement, naming the domain and flagging when a card overstates. Two mutations pin it, one per direction (tier drift, count drift).

### Fixed — PRIVACY.md did not disclose two outbound calls

- **`/idstack:course-export` uploads to Canvas and the privacy policy never said so.** PRIVACY.md stated "No data is sent to external servers by idstack" and carved out only `/idstack:course-import` *fetching* from Canvas. But `course-export` POSTs modules, pages, assignments, and discussions to the Canvas instance you point it at. That is your institution's server rather than ours, and it only runs when you invoke the skill and confirm the target course, but an undisclosed upload in a privacy policy is a defect regardless of where the bytes land.
- **The hourly update check was also undisclosed.** `bin/idstack-update-check` runs `git fetch` against this repository. It carries nothing but the fetch and never touches course data, and it only runs for git installs, but it is a network call and now says so.
- Both are listed under Third-party services. Audited by enumerating every outbound host across `bin/`, `templates/`, and `skills/`: the Canvas API and that `git fetch` are the only two.

### Fixed — the Windows install path could not work

- **`README.md` told Windows users to open PowerShell and run `./setup`.** `setup` is an extensionless bash script; PowerShell cannot execute it, and no `.ps1` ships. The ZIP instructions now name the shell that works (WSL or Git Bash) and say why PowerShell does not. This lived in the collapsed "Download ZIP" block, the path written for people who cannot use `git clone`.

### For contributors

- `ROADMAP.md` claimed "18 mutations" against an actual 24. The count is gone rather than corrected, so it cannot drift a third time; run the suite to see the number.
- `TODOS.md`'s landing-page demo item described a "See it work" transcript section that a redesign had already removed, so the task read as an upgrade to something that no longer existed. Rewritten against the page as it stands.
- v3.4.0.0 was merged but never tagged, so `.github/workflows/release.yml` never fired and GitHub still listed v3.3.0.4 as the latest release. Tagged retroactively at its merge commit.

## v3.4.0.0 (2026-08-06)

idstack is a Claude Code plugin now, and only that. The OpenAI Codex CLI target that shipped in v2.5.0.0 is removed, and the Gemini CLI target that was planned is off the roadmap. Nothing about the 11 skills, the evidence base, the manifest schema, or the report contract changes.

To update: `cd` into your idstack clone, then `git pull && ./setup`. Restart Claude Code afterward — plugins load at session start.

### Removed — the second CLI target

- **Codex CLI is no longer supported.** `./setup` no longer detects `codex` on `PATH`, and the `--codex` / `--no-codex` flags are gone (passing either is now an unknown-argument error). `dist/codex/` is deleted, along with the repo-root `AGENTS.md` and `templates/agent-context.md`, the file it was generated from.
- **If you had the Codex install, `./setup` will not clean it up** — it no longer knows those paths, and with `dist/codex/` deleted the symlinks it created now dangle. Remove them yourself:

  ```bash
  rm -f "${CODEX_HOME:-$HOME/.codex}"/skills/idstack-* "$HOME/.agents/plugins/idstack"
  ```

  For a `--local` install the same two live under the project: `./.codex/skills/idstack-*` and `./.agents/plugins/idstack`.
- **Gemini CLI support is off the roadmap.** It was never implemented; the ROADMAP and TODOS entries planning it are removed.

### Changed

- **`bin/idstack-gen-skills` takes no `--target`.** One output layout, `skills/<name>/SKILL.md`. A caller passing `--target all` now exits 2 — `setup` and `test/mutation-test.sh` were updated.
- **`$_IDSTACK` resolution dropped two paths.** `~/.agents/plugins/idstack` and `~/.agents/skills/idstack` existed only for the Codex install layout. The chain is now `CLAUDE_PLUGIN_ROOT`, `IDSTACK_HOME`, then the Claude Code marketplace cache. All five copies move together: the canonical snippet, the preamble's three inline blocks, and the longhand copy spliced from `templates/manifest-schema.md`.
- **The preamble's Interaction Conventions no longer describe two hosts.** `AskUserQuestion`, `Agent`, and `Skill` are still named as concepts, and `Agent`'s inline fallback stays — it is genuinely absent from some skills' `allowed-tools`. What goes is the per-CLI translation rule that told the model to rewrite `/idstack:foo` as `$foo`. `/idstack:pipeline`'s degradation branch now prints `/idstack:<skill>` instructions and fires on a failed `Skill` call rather than on a host without the tool.

### For contributors

- **A regression gate replaces the Codex assertions.** smoke-test lost the 47 assertions covering the Codex bundle and gained 7: `dist/`, `AGENTS.md`, and `templates/agent-context.md` must not exist; the generator must accept no `--target`; the resolve snippet and preamble must not carry the `~/.agents` fallbacks; and a repo-wide grep must find no `codex`/`gemini` outside `CHANGELOG.md`. That last one is the assertion that matters — a green suite proves nothing once you delete the checks that were doing the looking. 393 → 353 assertions.
- **One deliberate exemption in that sweep.** `test/smoke-test.sh` and `test/test-version-classifier.sh` credit "Gemini Code Assist", the PR-review bot that flagged the version classifier on #15, #19, #20, and #21. That attribution is why those cases exist and has nothing to do with the CLI, so it stays. It is exempted by a per-line `IDSTACK_CLI_LEAK_ALLOW` tag, not by filtering the bot's name as a string — the first draft did the latter, which silently exempted that string everywhere and would have let an untagged capability claim carrying it through anywhere in the repo. Mutation 17 pins the difference.
- `test/mutation-test.sh`'s `regen()` called `--target all` under `|| true`. Left alone, the flag removal would have turned every regeneration into a silent no-op, and the mutations would have been caught by the staleness gate instead of by the assertions they exist to exercise. Fixed. Its fixture now also copies `CLAUDE.md`, `CONTRIBUTING.md`, `DESIGN.md`, and `ROADMAP.md` so the new sweep can see them.
- `test/test-setup.sh` no longer passes `--no-codex`, and `test/integration-test.sh` no longer builds `dist/` and `AGENTS.md` into its sandbox.
- Four new mutations prove the gate bites: a reference reintroduced into README, an empty `dist/` directory (which the content grep alone would miss), an untagged reference inside `docs/index.html` — the one file carrying legitimate tagged lines, so this catches a future "simplification" from exempting lines to exempting the whole landing page — and a capability claim that happens to carry the review bot's name. Mutation suite 18 → 22.
- `regen()` in the mutation suite no longer swallows a generator failure. A failed regeneration means the mutation trips smoke-test's staleness gate instead of the assertion it exists to exercise, and every GUARDED line after it is meaningless. It now aborts loudly.

## v3.3.0.4 (2026-08-06)

No user-facing change — this release is test coverage for the two scripts a user runs when something has gone wrong.

### For contributors

- **`bin/idstack-doctor` now has execution coverage.** It had none: smoke-test checked only that the file existed and parsed. Since doctor's entire job is telling a user why `/idstack:<skill>` is missing, every branch it prints is one somebody acts on. 13 cases covering both missing manifests, an unparseable `plugin.json` (doctor parses it as JSON, so a regex-shaped test would miss this), missing `SKILL.md`, absent `claude` as a WARNING rather than a failure, installed-but-disabled, not-installed, all three legacy-conflict shapes, and an unrecognized directory being warned about rather than claimed.
- **`bin/idstack-status --readiness` now has coverage** — roughly 100 lines deciding whether a course is fit to export. Each threshold is probed at its own boundary with the other two held passing (quality 70 vs 69, accessibility 80 vs 79, red-team 0 vs 1 critical), because a fixture failing everything at once still passes when a single constant is wrong. The WCAG Level-A override is asserted in both places it is implemented; removing either one alone leaves the other reporting.
- **One shared assertion helper.** Nine suites each carried their own `PASS`/`FAIL`/`TOTAL` and copy of `check()`, and they had drifted: two spelled it `assert`, and one ran assertions with `>/dev/null 2>&1` and printed a bare `FAIL` — a red CI run that said something broke but not what. `test/test-helper.sh` owns it now. Two suites keep a differently-shaped wrapper, named so they cannot shadow the shared one. smoke-test asserts no suite regrows private counters, and a mutation proves that guard works.
- Test suites 9 → 11 in CI. smoke-test 371 → 393 assertions, mutation suite 14 → 18.

## v3.3.0.3 (2026-08-06)

To get this fix: `cd` into your idstack clone, then `git pull && ./setup`. Restart Claude Code afterward — plugins load at session start.

### Fixed — searching learnings by type returned nothing without python3

- **Only affects machines without python3.** `bin/idstack-learnings-search` falls back to `grep` when python3 is absent, and that fallback filtered on `"type":"technical"` while `bin/idstack-learnings-log` writes `"type": "technical"` — `json.dumps` puts a space after the colon. So `--type` matched nothing idstack had ever written and returned zero results rather than filtering. The pattern now tolerates whitespace around the colon. Found by writing the first test that ever exercised the fallback (#43, redone as #63).
- A keyword beginning with `-` was passed to `grep` without an end-of-options `--`, so it was read as an option bundle rather than a search term (#38).

### For contributors

- The grep fallback existed in two byte-identical copies and had zero coverage, which is why a bug could sit in it unnoticed. Collapsed into one `search_fallback` function with four assertions driving it via a PATH with no python3.
- First behavioral coverage for `bin/idstack-learnings-delete` (#41), `bin/idstack-learnings-promote` (#37), `bin/idstack-learnings-search` flags (#42), and three untested branches of `bin/idstack-timeline-log` (#47). `test/integration-test.sh` 25 → 48 assertions.
- #47 also loosened an existing timeline-count assertion from `-eq 2` to `-gt 1`, which passes when four of five writes are lost; restored to an exact count.
- These were the last mergeable PRs from the May/June bot queue. CI had never run on any of them — all were updated against main and passed the full matrix before landing.

## v3.3.0.2 (2026-08-06)

To get these fixes: `cd` into your idstack clone, then `git pull && ./setup`. Restart Claude Code afterward — plugins load at session start.

### Fixed — learnings search returned wrong results for apostrophes

- **Searching your learnings for a term with an apostrophe returned the wrong answer, silently.** `bin/idstack-learnings-search` spliced `$SOURCES`, `$TYPE`, `$KEYWORD` and `$LIMIT` straight into Python source. A search for `Bloom's` or `learner's` made that source a SyntaxError, `2>/dev/null` swallowed it, and the script fell through to a `grep` fallback that has no `--type` filter — so it answered with a record of the wrong type rather than failing. In a tool for instructional designers, those are ordinary search terms. The values now travel as `sys.argv` arguments, and a non-numeric `--limit` falls back to 3 instead of reaching `tail -"abc"`. This is the same defect class v3.3.0.0 fixed in `bin/idstack-status`; that pass missed this file. Thanks to the Jules bot run that flagged it (#33).
- **A malformed payload could corrupt the manifest.** `bin/idstack-manifest-merge` validated that the *manifest* root was a JSON object but never checked the *payload* root, so a bare JSON array merged in cleanly and surfaced much later as `AttributeError: 'list' object has no attribute 'get'` inside `bin/idstack-status --readiness`. It now rejects a non-object payload with exit 1 (#48).

### For contributors

- `test/test-manifest-merge.sh` covers non-object payload roots (list and string): 21 → 23 assertions.
- Closed 15 stale bot PRs from May/June that the v3.3.0.0 audit had already superseded, that duplicated a better sibling, or that were incorrect (deleting live migration code, converting a clean exit into a traceback, a benchmark that does not reproduce, and one whose pty assertion deadlocks `smoke-test.sh` under CI).

## v3.3.0.1 (2026-08-05)

To get this fix: `cd` into your idstack clone, then `git pull && ./setup`. Restart Claude Code afterward — plugins load at session start.

### Fixed — skills no longer suggest commands that don't exist

- **Welcome-back and next-step messages named unrunnable commands.** v3.3.0.0 banned bare `/skill` references because they resolve in neither CLI, and fixed them in `bin/idstack-status`. The guard enforcing it matched only backticked refs, so three plain-prose examples in the preamble's context-recovery section survived — and the preamble is spliced into all 22 skill files. The model copied their shape and told users things like "Based on your progress, /assessment-design is the natural next step." Typing that does nothing. Landing inside the context-recovery message v3.3.0.0 had just repaired made it the first thing a user saw once welcome-back messages started working again. Now namespaced; on Codex the existing translation rule renders them as `$<skill>`.

### For contributors

- The smoke-test guard now matches a bare `/skill` in any command position, not only inside backticks, and scans skill bodies with frontmatter still exempt (`description:` is picker prose, not a command). Suite count unchanged at 371.
- `test/mutation-test.sh` gained a case that reintroduces an unbackticked bare reference into the preamble and asserts smoke-test fails: 14 mutations, 14 guarded.

## v3.3.0.0 (2026-08-04)

To get these fixes: `cd` into your idstack clone, then `git pull && ./setup`. Restart Claude Code afterward — plugins load at session start.

### Fixed — course memory, pipeline orchestration, re-run detection

A full audit of the toolchain surfaced a set of bugs that broke user-visible behavior, some since their features shipped:

- **Context recovery never ran on Python < 3.12.** The session-memory script embedded in every skill contained an f-string with nested same-type quotes — a SyntaxError on macOS system python3 (3.9) that died silently. Welcome-back messages, quality-score trends, and next-skill suggestions now work, and a new test suite runs the block on Python 3.9 and 3.12 in CI so the class of failure can't ship again.
- **`/idstack:pipeline` invoked child skills with an unnamespaced name** that never resolved in Claude Code. The orchestrator now uses `skill: "idstack:<name>"`, logs its own completion to the timeline, and its status table and prompts use `/idstack:` forms the Codex translation rule can strip.
- **Re-run detection was dead in five skills** (assessment-design, course-builder, course-export, course-import, course-quality-review): their "update or start fresh?" checks looked up manifest section names that don't exist. Corrected to the canonical names; smoke-test now bans the drifted tokens.
- **`$_IDSTACK` resolution missed the marketplace cache** in `learn` and `course-export` — the way most users are installed — so their `bin/` calls pointed at a nonexistent directory. All bash blocks now splice one canonical resolution snippet (new `{{IDSTACK_RESOLVE}}` generator placeholder), re-derived per block because blocks run in separate shells.
- **`bin/idstack-status` blanked the dashboard** when the course name contained an apostrophe (shell text interpolated into Python source). The name now travels via the environment; readiness failures print a message instead of vanishing. `course-import` counts as a pipeline entry for next-step suggestions.
- **`bin/idstack-doctor` could report a broken install as healthy.** Its enabled-check read a fixed 4-line window of `claude plugin list`, so when another plugin was listed right after idstack, the neighbour's `enabled` line was attributed to idstack — a disabled install diagnosed as "installed and enabled". The check is now scoped to idstack's own entry. Doctor also parses the plugin version as JSON rather than by regex, and `--local` no longer scans `$HOME`.
- **`setup`**: `--keep-legacy` is honored in all legacy-removal paths (was 1 of 3); `--local` no longer touches `$HOME/.claude/plugins`; `claude plugin` failures error loudly with manual-recovery steps instead of aborting silently.

### Changed

- course-quality-review, course-export, and learning-objectives now write their manifest sections through `bin/idstack-manifest-merge` (atomic, section-scoped, preserves every other section). needs-analysis and course-import keep the Read-modify-Write path — both write several co-owned sections in one pass, which whole-section merge cannot express — and each now documents why.
- `bin/idstack-migrate --init` creates a canonical manifest with every section at its default. Three skills told the user to run `idstack-migrate` to create one when running standalone; it was a no-op on a missing file, so the merge that followed died with exit 4 and standalone results were silently never persisted. The skeleton comes from running the existing migration chain over a minimal seed, so there is no second definition of "canonical".
- learning-objectives reports gained the required "Top recommendations" section; `[Alignment-1]` is now correctly cited as T5.

### For contributors

The audit found the test suite had never run automatically, and that some of it was not testing what it appeared to test. Both are fixed:

- Logic that was duplicated or inlined and therefore untestable now lives in `bin/lib/` and is sourced by its callers: `version-classify.sh` (shared by `setup` and `bin/idstack-doctor`) and `plugin-status.sh` (the `claude plugin list` parser). Their unit tests exercise the shipped code rather than a copy — the version classifier had drifted across three PRs while a mirrored test passed green.
- **CI.** New GitHub Actions `test.yml` runs all eight suites on push and PR — seven in a matrix job (ubuntu + macos, Python 3.9 + 3.12 — 3.9 is the leg that catches the context-recovery class of bug), plus the mutation suite in its own job. `release.yml` refuses to publish unless the tag, `VERSION`, `plugin.json`, and `CHANGELOG.md` agree and the smoke test passes.
- **`./setup` is now tested** — 17 behavioral tests covering flag parsing, scope selection, all three legacy-cleanup shapes, and failure handling, run against a repo copy with a fake `$HOME` and a stub `claude`. It previously had no coverage at all while the smoke test spent 14 assertions on landing-page CSS.
- **A mutation suite proves the guards work.** `test/mutation-test.sh` reintroduces each of the 13 defects fixed here into a throwaway copy and asserts the guarding test fails. This is what was missing: the version-classifier suite passed green while testing a local copy of the classifier rather than the shipped code, and `gen-skills` counted a placeholder-less template as neither generated nor failed.
- smoke-test grew from 272 to 371 assertions (version agreement, canonical section names, `/idstack:` namespacing, resolve-snippet lockstep, v1.1 migration, `bash -n` on every script) and prints failure diagnostics instead of a bare FAIL; integration-test proves it leaves the working tree untouched.

## v3.2.0.0 (2026-05-14)

### Fixed — Claude Code install uses the plugin marketplace flow

`./setup` registered the plugin by symlinking the repo into `~/.claude/plugins/idstack`. Current Claude Code (2.1.x) does not discover plugins from bare symlinks — it requires marketplace registration — so `claude plugin list` showed nothing and `/idstack:<skill>` never appeared in the slash-command picker. New Claude Code users could not install idstack.

- **`.claude-plugin/marketplace.json`** — new one-plugin marketplace manifest (`source: "./"`), the manifest the install flow requires.
- **`setup`** — the Claude branch now runs `claude plugin marketplace add` + `claude plugin install --scope <user|project>` (both idempotent; `--local` maps to project scope). Detects a missing `claude` on `PATH` and prints manual steps. Removes the now-vestigial bare symlink from older installs (only ever a symlink, never a real directory). Codex install path unchanged.
- **`bin/idstack-doctor`** — self-locates the repo and checks the real signal: `claude plugin list` for `idstack@idstack` installed and enabled, plus the plugin and marketplace manifests. Legacy-conflict detection retained.
- **`templates/preamble.md`** — `$_IDSTACK` detection no longer falls back to the removed bare symlink; the last-ditch branch resolves the marketplace cache directory. All 22 skill files regenerated.
- **`test/smoke-test.sh`** — `$IDSTACK_DIR` self-locates the repo instead of assuming `~/.claude/plugins/idstack`.

The install command in the README and on idstack.org changes from `git clone … ~/.claude/plugins/idstack && …` to `git clone … && cd idstack && ./setup`.

### Changed — idstack.org SEO and landing-page copy

- **Discoverability.** Added `docs/robots.txt` and `docs/sitemap.xml`; the `SoftwareApplication` JSON-LD gained `softwareVersion`, `datePublished`, and `dateModified`; the `<head>` announces the GitHub releases Atom feed.
- **Evidence section redesign.** The per-domain bar graph that counted studies is replaced with eleven short descriptions of what each body of evidence claims, plus a compact tier legend.
- **Branded OG share card.** `docs/og-image.png` regenerated against the current design system; `docs/og-template.html` added as the regenerable source.
- **Language pass.** Evidence-card copy, four other landing-page lines, and AI-language tells across the repo's other Markdown were rewritten to drop negative parallelism, metaphor stacking, and marketing clichés.

### Notes

- No manifest schema, path, or API changes. Minor version bump: the installer mechanism changed and the landing page got substantive work, but nothing breaks existing course folders or downstream skills.
- Claude Code copies marketplace plugins into a versioned cache; a re-run of `./setup` refreshes it on a version bump. For live plugin development, use `claude --plugin-dir <repo>`.

## v3.1.0.0 (2026-05-13)

### Added — `DESIGN.md` and design-system reconciliation

The visual system that ships in the report stylesheet and the landing page is now documented at the repo root in `DESIGN.md`. Skills, contributors, and reviewers read it before touching anything visual. `CLAUDE.md` and `AGENTS.md` route to it.

- **`DESIGN.md` at the repo root.** Source of truth for fonts, colors, spacing, border radii, motion timing, and aesthetic direction. North-star is **Proof** — the artifact should read like a peer-reviewed clinical reference. Includes anti-patterns to never ship and a dated decisions log.
- **Web fonts swapped to publication-grade.** Source Serif 4 (display + body), Public Sans (UI/labels/badges), JetBrains Mono (citations/IDs/code), loaded via Google Fonts `<link>` in `docs/index.html`, `templates/report.html.tmpl`, and `templates/index.html.tmpl`. System-font fallbacks preserved so pages stay legible offline.
- **Palette shift: ivory replaces parchment.** Background goes from `#fbfaf6` (parchment-warm) to `#faf8f3` (pristine ivory). Reads as "good paper," not "old book."
- **Second annotation color added.** Prussian blue `#1d4a5e` joins library-stamp red `#7a1f1f`. Links and citation cross-references now use blue; the kicker / primary marks stay red. Mirrors the two-pen academic-editor convention.
- **Sharper corners across the surface.** Finding cards and other card surfaces are now `border-radius: 0`. Buttons, badges, chips, install snippets normalize to `2px`. The publication signal at the expense of consumer-SaaS softness.
- **Tier-badge weights amplified.** T1 / T2 render bold (the strongest evidence reads heaviest); T5 stays light grey (expert opinion reads weakest). Hex values unchanged.

### Changed

- `templates/assets/idstack.css` — reconciled to `DESIGN.md` tokens (ivory bg, prussian-blue links, sharp finding cards, new font tokens). Shipped to every course folder as before.
- `docs/index.html` — same token swap; UI chrome (eyebrows, badges, copy button, footer form, brand-beta, severity chips, pipeline labels) now uses Public Sans via `--font-ui`.
- `templates/report.html.tmpl` / `templates/index.html.tmpl` — `<head>` now includes Google Fonts preconnect + stylesheet link for Source Serif 4 / Public Sans / JetBrains Mono.
- `CLAUDE.md` / `AGENTS.md` (via `templates/agent-context.md`) — new **Design system** section instructing skills to read `DESIGN.md` before any UI decision.

### Notes

- No path, manifest, or API changes; minor version bump because the design system is now load-bearing for new skills and reviewers.
- Reports written by older versions still render correctly with the new stylesheet — the existing class hooks (`finding sev-{severity}`, `tier-badge tier-T{N}`, `sev-badge`, `citation`) are unchanged.

## v3.0.0.0 (2026-05-13)

### Changed — branded HTML reports + per-course export folder

The human-facing report format is now HTML. The container is now a per-course folder. Every artifact that belongs to a course — every per-skill report, the pipeline dashboard, the bundled stylesheet, and any LMS packages — lives under one self-describing folder: `.idstack/exports/<course-slug>/`. Zip the folder to hand the whole deliverable to a stakeholder.

- **HTML replaces Markdown for the human view.** Every skill that produces findings now writes a branded, self-contained HTML report at `.idstack/exports/<course-slug>/<skill>.html`. Visual contract: `templates/report.html.tmpl` (the HTML skeleton) plus `templates/assets/idstack.css` (the brand stylesheet). Content contract is unchanged: observation → evidence → why-it-matters → suggestion, severity (`critical|warning|info`) and evidence tier (`T1`–`T5`) on every finding.
- **Brand stylesheet matches `idstack.org`.** Scholarly serif body, ink-on-parchment palette, severity-colored finding cards (rust/amber/slate), tier badges weighted by strength (T1 heaviest, T5 lightest), citation marks in mono. Print-friendly. Auto light/dark via `prefers-color-scheme`. No JavaScript, no external fonts, no network — open and read.
- **Course folder, by name.** `<course-slug>` is derived from `project_name` via `bin/idstack-slugify` (NFKD-fold, lowercase, kebab-case, ASCII-safe; empty input → `untitled-course`). Renaming a course's `project_name` moves future exports to a new folder; older folders are left in place.
- **`/idstack:pipeline` produces a course dashboard.** `.idstack/exports/<course-slug>/index.html` carries readiness scores (Quality / Accessibility / Red-team confidence), a pipeline status table with links to every per-skill report, top cross-cutting issues, evidence themes, the LMS artifact list, and a where-to-start pointer. Same structure as `templates/index.html.tmpl`. Replaces the old `pipeline.md` aggregate.
- **LMS packages move into the course folder.** `course-export.imscc` and `scorm-export.zip` now write to `.idstack/exports/<course-slug>/`, not the root `.idstack/`. The `export_metadata.destination` field reflects the new path.
- **`course-export` now writes a report.** Previously the only pipeline skill without a human-facing report. Now produces `.idstack/exports/<course-slug>/course-export.html` alongside the LMS package.
- **`bin/idstack-status` reads the new layout.** Surfaces the dashboard first, then per-skill HTML reports, then LMS packages — all from the course folder. Auto-resolves the slug from `project_name`; falls back to the only `.idstack/exports/*` subfolder when present.
- **`bin/idstack-slugify` is a new CLI helper.** Standalone bash + python3 script implementing the slug rule. Documented in `templates/manifest-schema.md`; called by every skill that writes a report.

### Added

- `templates/report.html.tmpl` — per-skill HTML skeleton (visual contract).
- `templates/index.html.tmpl` — course dashboard skeleton.
- `templates/assets/idstack.css` — branded stylesheet matching `idstack.org` tone.
- `bin/idstack-slugify` — `project_name` → course slug.
- `bin/idstack-gen-skills` now sanity-checks that the three new template files exist; fails loud if any is missing.

### Breaking

- `report_path` semantics moved from `.idstack/reports/<skill>.md` to `.idstack/exports/<course-slug>/<skill>.html`. Existing `.idstack/reports/*.md` files from previous runs are left in place but treated as legacy — re-run the pipeline (or any skill) to migrate. Manifest schema version is unchanged (still 1.4) since field shape is identical; only the path the field points to has changed.
- LMS package paths moved: `.idstack/course-export.imscc` → `.idstack/exports/<course-slug>/course-export.imscc`; `.idstack/scorm-export.zip` → `.idstack/exports/<course-slug>/scorm-export.zip`. Tooling and docs that hard-coded the old paths need updating.

### Notes

- `bin/idstack-status` reads from the new location; legacy `.idstack/reports/*.md` are not surfaced in the dashboard listing.
- Plugin manifest version bumped to `3.0.0.0` (major: breaking `report_path` semantics).

## v2.5.0.0 (2026-05-09)

### Added — OpenAI Codex CLI support

idstack now runs natively in OpenAI Codex CLI in addition to Claude Code. Same 11
skills, same evidence base, same `.idstack/` dual-output contract, same manifest
schema. The skill bodies are CLI-agnostic; small per-CLI shims handle interaction
primitives.

- **Multi-target generator.** `bin/idstack-gen-skills --target {claude|codex|all}`.
  Codex output goes to `dist/codex/` (committed, so `codex marketplace add` works
  directly from a clone). Claude output unchanged at `skills/<name>/SKILL.md`.
- **Frontmatter portability.** The `allowed-tools:` block is stripped from Codex
  output (Codex has no per-skill allowlist; tool restrictions are session-global
  via approval policy + per-MCP `enabled_tools`/`disabled_tools`).
- **Concept-name preamble.** New "Interaction Conventions" section in
  `templates/preamble.md` defines `AskUserQuestion`, `Agent`, and `Skill (cross-skill
  invocation)` as portable concept names. Skill bodies use the same wording in both
  CLIs; the preamble interprets the concept per-host. Same body, two hosts, no
  per-target text substitution.
- **Pipeline graceful degradation.** `pipeline` skill picks up a "If the Skill tool
  is NOT available" branch — Codex prompts the user to type the next skill name and
  resumes when they re-invoke `$pipeline`. The partial-run report is regenerated
  before stopping.
- **Codex bundle artifacts.** Top-level `AGENTS.md` (memory file generated from
  `templates/agent-context.md`) and 11 `dist/codex/skills/idstack-<name>/SKILL.md`
  files. All committed; all freshness-checked by smoke test. Skill discovery in
  Codex happens at `$CODEX_HOME/skills/<name>/SKILL.md` (Codex auto-discovers
  skills there) — no marketplace.json or `.codex-plugin/plugin.json` needed for
  v1 distribution. Marketplace publishing is on the v2.6 roadmap.
- **Multi-CLI install path detection.** Preamble path resolution and the in-skill
  `_IDSTACK` chain in `course-export` and `learn` now check, in order:
  `$CLAUDE_PLUGIN_ROOT`, `$IDSTACK_HOME`, `~/.claude/plugins/idstack`,
  `~/.agents/plugins/idstack`, `~/.agents/skills/idstack`. One install layout per
  CLI; same code finds either.
- **`setup` extended.** Auto-detects `codex` on PATH and creates a two-part Codex
  install: per-skill symlinks at `$CODEX_HOME/skills/idstack-<name>/` (Codex auto-
  discovers each skill) plus a whole-repo symlink at `~/.agents/plugins/idstack/`
  (so the in-skill `$_IDSTACK/bin/idstack-*` resolves via the preamble's path
  fallback chain). Force on with `--codex`, opt out with `--no-codex`. Existing
  Claude Code install is unchanged for users who don't have Codex CLI. Setup also
  detects pre-existing real directories at install targets and removes them before
  symlinking (avoids the `ln -snf` symlink-inside-dir footgun). Caught in PR
  review by Gemini bot.
- **Smoke test extended.** New checks for `dist/codex/` artifacts: bundle directory,
  marketplace.json validity, AGENTS.md presence, all 11 Codex SKILL.md files with
  correct frontmatter and stripped `allowed-tools`. Total: 217 checks (was 161).

### Changed

- **README** marks idstack as supporting Claude Code **and** Codex CLI. (Gemini
  CLI is on the v2.6 roadmap.)
- **Plugin manifest version** bumped to `2.5.0.0` (minor: adds CLI target without
  breaking Claude Code).

## v2.4.0.2 (2026-05-05)

### Fixed — version-pattern fragility (Gemini code review, third pass)

Third Gemini-flagged iteration on the same legacy-version classifier (PR #15 → PR #19 → PR #20 → PR #21). The v2.4.0.1 pattern `1[0-9]*` correctly handled multi-digit majors starting with `1` (10–19, 100–199, …) but silently missed any other multi-digit major: `20.x`, `25.x`, `200.x`, etc. fell through both arms of the `case` and ended up classified as `unknown` — meaning a future v20 install at the legacy path would neither be skipped nor flagged for cleanup.

- **Pattern generalized.** Replaced `1[0-9]*` with `[1-9][0-9]*` in `setup`, `bin/idstack-doctor`, and `test/test-version-classifier.sh`. Strictly more general, no false positives against the legacy arm (`0.*|1.*|2.0.0.*|2.0.0`) since `[1-9][0-9]*` requires a second digit and the legacy arm requires a literal `.` or matches the bare `2.0.0`.
- **Test fixture extended.** Seven new fixtures pin the previously-silent cases: `20.0.0.0`, `21.5.0`, `25.99.0`, `29.0.0`, `30.0.0`, `200.0.0`, `999.0.0`. Total fixture count: 27. Comment header updated to record the third Gemini iteration so the next maintainer can see the history.

### Changed

- **Plugin manifest version aligned with `VERSION`.** `.claude-plugin/plugin.json` bumped to `2.4.0.2`.

## v2.4.0.1 (2026-05-05)

### Fixed — install-hygiene follow-ups (Gemini code review)

Two rounds of post-ship Gemini review caught fragility in the install-hygiene code that v2.4.0.0 introduced. All fixes target `setup` and `bin/idstack-doctor`; no skill behavior changes.

- **Multi-digit version classification.** The `case` statement that decides "modern install — leave alone" vs "pre-v2.0.1.0 — flag for cleanup" used literal-dot + single-digit `[1-9]` patterns that broke on multi-digit components like `2.0.10.0`, `2.10.0.0`, and `100.0.0` — a future v2.0.10.0 install at the legacy path would fall through both arms and produce a false "not recognized" warning. Replaced with multi-digit-safe globs (`2.0.[1-9]*|2.[1-9]*|[3-9]*|1[0-9]*`) mirrored across both files. (Gemini code review of PR #19.)
- **`test/test-version-classifier.sh`.** New unit test pins the version-glob behavior against 20 representative inputs (legacy + modern + multi-digit). Wired into `test/smoke-test.sh`. Second time Gemini caught a version-pattern bug in this code path; the test stops the third.
- **Argument parsing.** `setup --keep-legacy` and `bin/idstack-doctor --local` now match in any argument position (were: only `$1`/`$2`). Matches typical CLI flag-handling expectations. (Gemini code review of PR #15, #16.)
- **Doctor robustness.** `bin/idstack-doctor` now: explicitly `-d` checks the plugin dir (catches the rare "exists but isn't a directory or symlink" case), flags silently-failing version parses as a problem instead of swallowing them, and uses bash-native `[[ == ]]` for symlink-target matching (avoids subshell + grep, dodges the leading-dash echo footgun). (Gemini code review of PR #15.)
- **Voice-consistency in user-facing copy.** README status callout uses 3-digit `v2.4.0` to match the landing-page timeline convention; canonical 4-digit form stays in `CHANGELOG` / `VERSION` / `plugin.json`. `docs/index.html` hero-beta line now says "between minor versions" to match the README phrasing. (Gemini code review of PR #18.)

### Changed

- **Plugin manifest version aligned with `VERSION`.** `.claude-plugin/plugin.json` bumped to `2.4.0.1` to track this patch. Same alignment rule established in v2.4.0.0.

## v2.4.0.0 (2026-05-05)

### Fixed — install-hygiene

`/idstack:<skill>` was failing with `Unknown skill` on machines that still had a pre-v2.0.1.0 clone at `~/.claude/skills/idstack/`. The legacy clone shipped a top-level dispatcher `SKILL.md` (`name: idstack`); Claude Code matched it on `/idstack <args>`, the dispatcher then asked for bare-name child skills, and the plugin-only layout (post-v2.0.1.0) no longer exposes those names — so resolution failed in both fallbacks.

- **`setup` actively cleans up legacy installs.** The `~/.claude/skills/idstack/` warning branch now deletes the directory when the dispatcher SKILL.md or `VERSION < 2.0.1.0` is present. Pass `--keep-legacy` to opt out. Other contents of `~/.claude/skills/` are left alone.
- **`test/smoke-test.sh` regression checks.** Fails when `~/.claude/skills/idstack/SKILL.md` declares `name: idstack`, or when any `~/.claude/skills/<skill-name>` is a pre-v2 symlink pointing into the idstack tree. Skipped under `--local` and CI-fixture runs that pass a custom plugins dir.
- **New `bin/idstack-doctor`.** One-shot diagnostic: plugin presence + manifest version, all 11 SKILL.md files reachable, legacy-install conflicts. Prints exact remediation commands and exits non-zero on any problem.

### Added — the dual-output report contract

Every skill that produces findings now writes **both** a JSON manifest section (system state) and a human-readable Markdown report at `.idstack/reports/<skill>.md` (the designer's view). idstack is positioned as a collaborator on the designer's work, not a course builder — reports speak in observation → evidence → why-it-matters → suggestion, with severity and evidence tier on every finding, and recommendations phrased as "consider…", not "you must…".

- **Canonical format.** New `templates/report-format.md` documents the per-finding structure and the voice rules: suggest don't direct, cite every recommendation, uncited claims belong in *Limitations* not *Findings*. Skills reference this file as the contract for tone and per-finding fields.
- **Schema additions** (additive, no version bump): optional `report_path` field on every section in `templates/manifest-schema.md` that produces findings — `needs_analysis`, `learning_objectives`, `assessments`, `course_content`, `import_metadata`, `export_metadata`, `quality_review`, `accessibility_review`. (`red_team_audit` already had the field from v1.4.) Skills write the relative path of their Markdown report into this field so other skills, the pipeline orchestrator, and `bin/idstack-status` can find it.
- **Per-skill rollout.** All 8 finding-producing skills now write a Markdown report:
  - `needs-analysis`, `learning-objectives`, `assessment-design`, `course-builder`, `course-import`, `accessibility-review` — each got a new "Generate Report" step before the manifest write, with stable finding ids per skill (`needs-1`, `align-1`, `assess-1`, `cogload-1`, `import-1`, `wcag-1`, `udl-1`, etc.) so other skills and the aggregator can cross-reference findings deterministically.
  - `red-team` and `course-quality-review` migrated from flat `.idstack/red-team-report.md` / `.idstack/quality-report.md` onto the new `.idstack/reports/` directory layout. `course-quality-review` now also writes `report_path` into the manifest.

### Added — pipeline cross-cutting aggregate

`/idstack:pipeline` now produces `.idstack/reports/pipeline.md` — a single document the designer can read for the full audit across all 8 stages. Three sections:

- **Across your course** — top cross-cutting issues (findings that recur in multiple per-skill reports), evidence themes (which research domains keep showing up), and where to start. The designer's 30-second read of the whole audit.
- **Pipeline status** — table of all 8 skills with status, headline score/signal, and report path.
- **Per-skill summaries** — Summary paragraph from each per-skill report plus the top 2 finding ids, with a link out to the per-skill report for detail.

Re-invoking `/idstack:pipeline` when all skills are already complete now offers **"Regenerate the pipeline report"** as the primary option via `AskUserQuestion`, alongside re-run-a-skill and exit. Useful after the designer edits per-skill outputs by hand and wants the aggregate refreshed without re-running skills. Also regenerated automatically after every skill the orchestrator completes, so a partial pipeline still leaves a useful aggregate behind if the designer pauses.

### Changed

- **`bin/idstack-status` lists report paths.** New "Reports (read these for the human view)" block under the existing readiness verdict surfaces every Markdown report present under `.idstack/reports/`, with `pipeline.md` listed first as the entry point.
- **Plugin manifest version aligned with `VERSION`.** `.claude-plugin/plugin.json` was stale at `2.0.1.0` (frozen since v2.0.1, never bumped through v2.1, v2.2, v2.3); now matches `VERSION` at `2.4.0.0`.
- **Outward-facing tone pass across all 8 skills.** Confirmation messages now point the designer at *two artifacts* uniformly: "Read this: `.idstack/reports/<skill>.md`. System state: `.idstack/project.json`." Recommendations across reports framed as suggestions ("consider…", "you may want to…"), citations are mandatory on every recommendation, and uncited claims are moved to *Limitations*.

### Manifest schema

No version bump (still 1.4). The `report_path` additions are optional fields; existing manifests without them continue to read correctly.

### Out of scope (future)

- Pipeline-level fix-application loop. Red-team has a parent-side triage-and-fix flow today; the pipeline aggregator could surface cross-cutting fixes for batch application.
- `bin/idstack-status` ranks reports lexicographically. Ranking by recency-of-write or severity-of-topmost-finding would be more useful for a designer scanning a long-running course.
- A smoke-test guard that asserts every skill template both calls the report-write step and writes `report_path` to the manifest. Worth adding once the contract has been live in main for a few releases and is unlikely to change.

## v2.3.0.0 (2026-05-02)

### Added
- **Imported-course mode for `needs-analysis`, `assessment-design`, and `course-builder`.** The TMC-430 test report flagged that these skills assume net-new course design and break down for imported courses. Each now branches early on `import_metadata.source`:
  - `needs-analysis` skips the "is training the right intervention?" decision gate for credit-bearing imports (the registrar can't be told to remove the course); records the rationale and confidence automatically and runs a "design-fit" check instead.
  - `assessment-design` adds **Mode 3: Audit Existing Assessments** alongside the existing Mode 1/Mode 2 split. Reads the existing rubrics from the cartridge, classifies criteria on Bloom's, compares to ILOs, and surfaces alignment gaps — does NOT propose new assessments unless the user explicitly asks. Mode 3 takes precedence over Mode 1.
  - `course-builder` adds **gap-fill mode** triggered when `import_metadata.source` is set and `course_content.modules` is non-empty. Generates ONLY the artifacts upstream skills flagged as missing (e.g., a missing rubric, a formative practice quiz set), instead of regenerating the syllabus, modules, and rubrics that already exist in the cartridge.
  - All three skills announce the chosen mode at the start of the conversation so the user can override if the auto-detection is wrong.
  - Resolves test-report issues #7, #13, #14.
- **Canonical schema additions** (additive, no version bump): optional `needs_analysis.mode`, `assessments.mode`, `course_content.mode` (record which mode the skill ran in); `assessments.audit_notes[]` (Mode 3 outputs); `course_content.recommended_generation_targets[]` (gap-fill mode outputs). Per-section item shapes documented in `templates/manifest-schema.md`.
- **`assessment-design` switches to `bin/idstack-manifest-merge`.** Replaces the inline-write pattern (with its misleading "Include the COMPLETE schema structure" instruction) with two scoped merge calls — one for `assessments`, one for `learning_objectives`. Same atomic-write benefits introduced in v2.1.0.0.

### Changed
- Smoke test now runs 153 assertions (was 150). New: each of the 3 mode-aware skill templates must reference `import_metadata.source` (drift guard against accidental removal of the mode-detection branch).

## v2.2.0.1 (2026-05-02)

### Fixed
- **`bin/idstack-manifest-merge` validates manifest root is a JSON object.** A manifest containing a JSON list, string, or other non-object at the root previously crashed with `TypeError` on `manifest[args.section] = payload`. Now exits 2 with a clear "manifest root must be a JSON object" message. Two new unit tests (list root, string root) cover this. (Gemini code review of PR #8.)
- **`setup` legacy-cleanup paths now respect the `--local` scope.** Cleanup of legacy v2.0 dispatcher symlinks and pre-v2 per-skill symlinks previously hardcoded `$HOME/.claude/skills`, which meant `--local` installs never had their own `./.claude/skills/` cleaned up. Introduced a `LEGACY_SKILLS_DIR` variable that defaults to `$HOME/.claude/skills` and switches to `$(pwd)/.claude/skills` for `--local` — each scope only touches its own legacy path. (Gemini code review of PR #6.)
- **`fixes_applied` and `fixes_deferred` shapes documented** in `red-team` skill. The skill mentioned recording "a one-line reason" for deferred fixes but didn't show the JSON shape. Now documents `{id, description}` for applied and `{id, reason}` for deferred fixes — same convention used by other findings arrays. (Gemini code review of PR #7.)

### Changed
- **`bin/idstack-gen-skills` removed dead `frontmatter` variable.** Variable was extracted but never used (the awk pass below it handles frontmatter detection independently). (Gemini code review of PR #8.)
- **`test/test-manifest-merge.sh` simplified Test 1 assertion.** Removed a redundant `||` clause whose first half (`d["red_team_audit"] == ""`) could never be true given the dict payload — only the second half ever ran. Replaced with the single dict-equality check. (Gemini code review of PR #8.)

## v2.2.0.0 (2026-05-02)

### Changed
- **Red team now runs in a clean-context sub-agent.** Previously the audit's per-dimension scans ran as parallel sub-agents but the synthesis layer (which decides "is this course actually good?") ran in the parent's context — inheriting whatever build-bias the parent had accumulated. The skill now spawns a single `general-purpose` orchestrator with a self-contained brief; the orchestrator sees the manifest and course files fresh, runs the 5 dimensions (still parallel where Agent tool is available), writes `.idstack/red-team-report.md`, and returns a short executive summary. The parent never sees the audit reasoning, only the report — same view a real student gets.

### Added
- **Pre-spawn focus question.** The skill asks one question before invoking the orchestrator: full sweep (default) vs. a specific angle (assessment gaming, cognitive overload, persona accessibility, evidence accuracy). Lets reviewers steer depth without forcing it.
- **Triage-and-fix loop in the parent.** After the orchestrator returns, the parent surfaces the summary and asks one AskUserQuestion: which severity bucket to address (Critical only / Critical+High / All / Skip). Selected fixes are applied in-context (parent already knows the course structure), with each finding tracked as `fixes_applied` or `fixes_deferred` in the manifest. No automatic re-verification — re-running `/idstack:red-team` is opt-in.
- **Stable finding ids.** Each finding now has a `<dimension>-<n>` id (e.g., `alignment-1`) so the parent can reference findings deterministically when applying fixes and when re-running for verification.
- **`.idstack/red-team-report.md`.** Durable, user-readable artifact with the full finding list, per-dimension summaries, top 3 actions, and limitations. Manifest's `red_team_audit` section now also stores `report_path` pointing at it.
- **Red-team uses `bin/idstack-manifest-merge`.** Step 6 (update manifest) now calls the merge tool introduced in v2.1.0.0 instead of inlining the full manifest in an `Edit` operation. Atomic, foreign-section-preserving, schema-validated write. Falls back to inline write if the tool is unavailable.

### Manifest schema
- No further version bump. v2.1.0.0 already raised the schema to 1.4 and added the optional `red_team_audit.focus`, `report_path`, `fixes_applied`, `fixes_deferred` fields that this PR consumes.

## v2.1.0.0 (2026-05-02)

### Changed
- **Manifest schema centralized into one canonical source.** Each skill's SKILL.md.tmpl previously inlined its own copy of the manifest schema; the copies had drifted apart, and bin scripts had hardcoded paths that didn't always match. Now `templates/manifest-schema.md` is the single source of truth, substituted into skill templates via the existing `{{MANIFEST_SCHEMA}}` mechanism (mirroring `{{PREAMBLE}}`). Adds explicit per-section item shapes (`assessments.items`, `learning_objectives.alignment_matrix.ilo_to_activity`, `red_team_audit.dimensions.*.findings`, `accessibility_review.wcag_violations`, etc.) so downstream skills can rely on them. Resolves issues #5, #6, #9, #11, #12, #15, #19, #23 from the TMC-430 test report.
- **`bin/idstack-status` verdict logic now stricter.** Previously a course with quality 60+ and zero critical red-team findings reported `READY TO EXPORT` even when accessibility was 0 or had unaddressed Level-A WCAG violations. New gate: `READY` requires `quality_score >= 70` AND `accessibility_score >= 80` AND zero critical red-team findings AND zero WCAG Level-A violations. Per-skill rows now use a 3-tier `NOT RUN / NEEDS-WORK / READY` rating (was binary `PASS/WARN/NOT RUN`). Thresholds are named constants near the top of the script. Courses that previously reported READY may now report NEEDS-WORK or NOT-READY — re-run the relevant skills to address gaps. Resolves issues #17, #20, #24.
- **Manifest schema bumped 1.3 → 1.4.** Additive plus drift-cleanup. New optional fields under `red_team_audit` (`focus`, `report_path`, `fixes_applied`, `fixes_deferred`) and `import_metadata` (`quality_flag_details`). The 1.3 → 1.4 migration in `bin/idstack-migrate` renames `red_team_audit.summary.{critical_count,warning_count,info_count}` to `red_team_audit.findings_summary.{critical,warning,info}` (the names `bin/idstack-status` reads), and moves any legacy root `_import_quality_flags` field into `import_metadata.quality_flag_details`.

### Added
- **`bin/idstack-manifest-merge`** — Python tool that atomically replaces one top-level section of the manifest, preserving every other section and the top-level `version`/`project_name`/`created` fields. Section-level replacement (not recursive deep-merge), whitelisted section names, atomic via tempfile+rename, structured exit codes (1/2/3/4/5 for malformed payload / malformed manifest / unknown section / missing manifest / missing payload). Skills should use this in preference to inlining the full manifest in `Edit` operations. Partially resolves issue #21 (Edit-driven JSON manipulation fragility at scale).
- **`templates/manifest-schema.md`** — canonical schema reference. Documents top-level fields, ownership per skill, and per-section item shapes.
- **`test/test-manifest-merge.sh`** — 13-case unit suite for the merge tool (replace, preserve foreign sections, reject malformed input, reject unknown sections, atomic timestamp bump, etc.). Invoked from `test/smoke-test.sh`.
- **Schema-drift regression guards in smoke-test.** New assertions: every skill template that previously had an inline schema now uses `{{MANIFEST_SCHEMA}}`; no SKILL.md.tmpl mentions historically-drifted field names like `red_team_audit.summary.critical_count` or `_import_quality_flags`; every generated SKILL.md inlines the canonical v1.4 schema. Smoke test now runs 150 assertions (was 115).

### Fixed
- **`bin/idstack-timeline-log` no longer overwrites caller-supplied `ts` field.** Now uses `setdefault` semantics: if the caller passes `"ts": "..."`, it's preserved; only when absent does the script mint one. Documented in the script header. Resolves issue #2.
- **`course-import` documents the macOS `mktemp -d` portability gotcha.** The `-t` flag on macOS treats its argument as a literal prefix instead of substituting `XXXXXX` — producing a broken path. Template now states the bare `mktemp -d` form is portable and must be used. Resolves issue #3.

### Out of scope (deferred — see TMC-430 test report)
- "Imported-course mode" branching for needs-analysis, assessment-design, course-builder (issues #7, #13, #14). Substantive scope work, deserves its own PR.
- Per-skill scope improvements (#10, #16, #18, #22, #25): coverage cross-walk, scoring methodology, parallel-dispatch payload size, accessibility tooling, evidence currency check.
- Minor docs/UX polish (#4, #8). Issue #1 (sub-skill routing) was already resolved in v2.0.1.0.

## v2.0.1.0 (2026-05-02)

### Fixed
- **Plugin install actually exposes namespaced sub-skills.** v2.0.0 promised `/idstack:<skill>` but `./setup` symlinked the repo into `~/.claude/skills/idstack`, where Claude Code only discovers the top-level dispatcher SKILL.md (one level deep). The 11 sub-skills under nested directories were never registered. Setup now installs to `~/.claude/plugins/idstack` (the plugin discovery path), and the 11 skills live under `skills/` per the plugin layout — so `/idstack:needs-analysis`, `/idstack:pipeline`, etc. show up in the slash command picker.
- **Circular self-symlink when cloning into the install target.** The README's recommended one-liner clones into the install path, then runs `./setup`. The script unconditionally ran `ln -snf $REPO $TARGET` even when `$REPO == $TARGET`, producing a broken self-symlink (`~/.claude/skills/idstack/idstack -> ~/.claude/skills/idstack`) inside the repo. Setup now detects the same-path case and skips the symlink step (the install is already in place).
- **Removed root dispatcher SKILL.md.** The dispatcher only existed as a workaround for the broken symlink discovery — once the plugin install works, the namespaced skills replace it. The welcome-message logic moves into the slash command picker, where users see all 11 sub-skills directly.
- **Setup migrates legacy v2.0 installs.** If `~/.claude/skills/idstack` is a symlink, setup removes it. If it's a real directory (i.e., the v2.0 README had users clone there), setup leaves it in place but warns and tells the user how to remove it manually.

### Changed
- Repo layout: skill directories moved from repo root into `skills/` subdirectory (required by the plugin format).
- `bin/idstack-gen-skills` now reads templates from `skills/*/SKILL.md.tmpl`.
- Default install path in preamble fallback, README, and CLAUDE.md updated to `~/.claude/plugins/idstack`.

## v2.0.0.0 (2026-04-20)

### Added
- **Pipeline orchestrator.** `/idstack:pipeline` chains all 8 design skills automatically, auto-skipping completed ones. Pause anytime, resume later. Your progress is saved in timeline.jsonl.
- **Cross-course intelligence.** Learnings from one course now appear in another via `~/.idstack/global/learnings.jsonl`. Keyword search with `--keyword` and `--cross-project` flags.
- **`/idstack:learn` skill.** Search, list, delete, promote, and export project learnings. Promote local discoveries to the global store for cross-project reuse.
- **Course readiness dashboard.** `bin/idstack-status --readiness` shows a pre-export gate: quality score, red-team critical findings, accessibility score, with pass/fail verdict. Integrated into `/idstack:course-export`.
- **Designer profile.** Create `~/.idstack/profile.yaml` with `experience_level: novice|intermediate|expert`. Skills adapt explanation depth to your expertise.
- **Manifest preferences.** Schema v1.3 adds `preferences` section: verbosity, export_format, preferred_lms, auto_advance_pipeline.
- **Sub-agent architecture.** On Claude Code, review skills dispatch parallel sub-agents for speed: `/idstack:red-team` (5 agents), `/idstack:accessibility-review` (2 agents), `/idstack:course-quality-review` (3 agents). Graceful sequential fallback on other platforms.
- **Spec review loop.** `/idstack:course-builder` validates alignment via adversarial sub-agent after generating content. Reports "Review: N issues found, M fixed."
- **Claude Code plugin.** `.claude-plugin/plugin.json` manifest for marketplace distribution. Install via `claude plugin install idstack` or traditional `git clone && ./setup`.
- **`IDSTACK_HOME` env var.** All internal paths now use `${IDSTACK_HOME:-~/.claude/skills/idstack}`. Set this to install anywhere.
- **New bin scripts.** `bin/idstack-learnings-delete`, `bin/idstack-learnings-promote` for managing learnings programmatically.

### Changed
- **Namespace refactor.** All skills now invoked via `/idstack:<skill>` (e.g., `/idstack:needs-analysis`) instead of `/<skill>`. Avoids name collisions with other skill packages.
- **Setup creates single symlink.** `./setup` now creates only `~/.claude/skills/idstack` (cleans up legacy individual symlinks automatically).
- **Manifest schema v1.3.** Adds preferences section. Chained migration from v1.0/v1.1/v1.2 in one pass.
- **Preamble reads designer profile and preferences** on every skill start.

## v1.5.1.0 (2026-04-10)

### Added
- **Bidirectional pipeline.** All 9 skills now write back to the manifest. Previously 5 skills were read-only (course-quality-review, course-builder, red-team, accessibility-review, course-export). Now every skill contributes to the shared project state, so downstream skills get richer input.
- **Score trending.** Run `/course-quality-review` multiple times and see your score improve: "Score: 78/100 (+16 since last review)." Current score in the manifest, history in the timeline. One source of truth per data point.
- **Export readiness info.** `/course-export` now shows quality, red-team, and accessibility scores before export. Informational only, never blocks.
- **WCAG 2.1 AA depth.** `/accessibility-review` expanded from 8 to 20+ evidence citations with full WCAG success criteria. Course-specific guidance for videos, quizzes, forums, PDFs, and simulations.
- **Red-team evidence grounding.** `/red-team` expanded from 12 to ~45 evidence citations. All 5 adversarial dimensions now cite their research.
- **Chained schema migrations.** `bin/idstack-migrate` refactored to support migration chains (1.0→1.1→1.2). Users on any version get upgraded in one pass.
- **Migration test fixtures.** New `test/fixtures/` with v1.0 and v1.1 manifest fixtures. 11 new migration assertions in smoke-test.sh.

### Changed
- Manifest schema bumped to v1.2 (additive only, no breaking changes).

## v1.5.0.2 (2026-04-06)

### Fixed
- **Security:** Removed silent auto-update that pulled and executed code from GitHub without user review. Skills now notify when updates are available. Users update manually with `git pull && ./setup`.

## v1.5.0.1 (2026-04-04)

- Landing page now shows development updates and roadmap at [idstack.org](https://idstack.org). Timeline with recent releases (dates as primary identifiers, not version numbers) plus "Coming soon" items and a "Where we're headed" narrative. Non-technical visitors can see what's new without navigating GitHub.
- Updated architecture description on landing page to reflect course memory (timeline, learnings).
- Removed stale architecture ASCII diagram from landing page (replaced with prose description).

## v1.5.0 (2026-04-04)

- **Course memory.** idstack now remembers your design sessions. Each skill logs what it did to `.idstack/timeline.jsonl`, and the next session starts with a welcome-back message: quality score trend, last skill run, suggested next step. Your course context compounds across sessions instead of starting from scratch.
- **Learnings.** When a skill discovers something specific to your project (Canvas uses custom rubric formatting, SCORM packages from Rise need special handling), it stores the discovery in `.idstack/learnings.jsonl`. Future sessions surface relevant learnings automatically.
- **Pipeline guidance.** Skills now suggest the next step based on what you've already completed, replacing inconsistent static "Next step:" text with data-driven recommendations.
- **`bin/idstack-status`** prints a course health dashboard: skills completed, quality score trend, dimension breakdown, and suggested next skill.
- **Template system.** Shared preamble code (update check, manifest check, context recovery) is now maintained in one place (`templates/preamble.md`). Skills use `.tmpl` files with a `{{PREAMBLE}}` placeholder. Run `bin/idstack-gen-skills` to regenerate.
- **python3 recommended.** Course memory features work best with python3 (score trends, search filtering, JSON validation). Without it, basic timeline logging still works via bash fallback.

## v1.4.1.1 (2026-04-03)

- Setup now tells you to restart Claude Code if it's already running, so skills appear immediately
- Post-install message routes you to the right starting skill: `/course-import` if you have an existing course, `/needs-analysis` if starting fresh

## v1.4.1 (2026-04-02)

- Landing page live at [idstack.org](https://idstack.org) with getting started guide, terminal demo, skill pipeline diagram, and evidence grid across 11 research domains
- Skills check for updates and notify when a new version is available.
- SEO: Open Graph and Twitter card tags, JSON-LD structured data, OG image, and favicon for link previews when shared on social media

## v1.4.0 (2026-04-01)

- You can now import SCORM 1.2 and 2004 packages directly into `/course-import`. Works with Articulate Rise, Storyline, Adobe Captivate, Lectora, iSpring, and any SCORM-compliant authoring tool. Extracts course structure, objectives, and assessments from the imsmanifest.xml.
- You can now export to SCORM 1.2 packages from `/course-export`. Produces a standard SCORM ZIP that works with every LMS and corporate training platform.
- PDF and document file import added to `/course-import` for Articulate Rise exports and course syllabi

## v1.3.0 (2026-04-01)

- You can now run `/accessibility-review` to audit your course for WCAG 2.1 AA compliance and Universal Design for Learning (UDL 3.0). Two-tier output: "Must Fix" for legal accessibility violations, "Should Improve" for inclusive design recommendations. Scores accessibility 0-100.
- You can now run `/red-team` to stress-test your course design. Five adversarial dimensions: alignment gaps, evidence verification, cognitive load analysis, learner persona simulation, and prerequisite chain integrity. Produces a confidence score so you know how solid your design is before you export.
- New evidence domain added: Domain 11 (Accessibility & Universal Design for Learning) with 9 citations covering WCAG, UDL Guidelines 3.0, and differentiated instruction research
- Pipeline extended: `/accessibility-review` and `/red-team` sit between `/course-quality-review` and `/course-export` as the final quality gates
- Smoke tests expanded from 46 to 58 checks covering all 9 skills

## v1.2.1 (2026-04-01)

- You can now submit feedback and feature requests without a GitHub account via a [Google Form](https://forms.gle/6LDgDD1M6WWyYvME8)
- Feedback link added to every skill, so you can share thoughts right after using one
- README intro softened for a warmer, more inviting tone
- Multi-platform install (Gemini CLI + Codex CLI) added to roadmap as a P2 item

## v1.2.0 (2026-03-31)

- Cross-domain quality checks in `/course-quality-review`: cognitive load, multimedia principles, feedback quality, and expertise reversal flags
- Manifest versioning with automatic schema migration (`bin/idstack-migrate`)
- Fix-link integration so quality review recommendations point you to the skill that fixes each issue
- Quick-win prioritization ranks recommendations by effort vs impact
- Score trending tracks your course quality across review sessions
- Shareable quality report and per-category scoring breakdown
- Pipeline reordered so `/course-quality-review` runs before `/course-export`
- Auto-create GitHub Release on tag push

## v1.1.1 (2026-03-31)

- VERSION file added for tracking
- Branch protection and CONTRIBUTING.md for contributors

## v1.1.0 (2026-03-30)

- 4 new skills: `/assessment-design`, `/course-builder`, `/course-export`, `/course-import`
- Full pipeline from import to export now works end to end
- Automatic update check in all skills (tells you when a new version is available)
- README rewritten with install-by-pasting flow and live demo walkthrough

## v1.0.0 (2026-03-30)

- Initial release with 3 skills: `/needs-analysis`, `/learning-objectives`, `/course-quality-review`
- Evidence base from peer-reviewed research across 11 domains
- Shared project manifest (`.idstack/project.json`)
- Evidence tier citations (T1-T5) on every recommendation
