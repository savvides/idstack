# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is idstack

An open source set of skills for evidence-based instructional design. Runs in Claude Code. Each skill is a SKILL.md file that defines a conversational workflow backed by evidence from peer-reviewed research across 11 domains.

## Commands

```bash
./setup              # Install idstack — registers the plugin with Claude Code
./setup --local      # Install at project scope (./.claude/) instead of user scope
bin/idstack-gen-skills                     # Regenerate skills/<name>/SKILL.md from the .tmpl sources, and the extension's
                                           # ste-rules.js (from the preamble)
bin/idstack-gen-skills --dry-run           # Check if generated files are up to date
bin/idstack-doctor                         # Diagnose plugin install (python3, presence, manifest version)
bin/idstack-doctor --quick                 # One python3 code for /idstack:start: OK, PYTHON_MISSING, PYTHON_OLD or PYTHON_STUB
bin/idstack-status                         # Course health dashboard (run in a project dir)
bin/idstack-status --readiness             # Pre-export readiness check only
bin/idstack-status --context               # Context-recovery lines the preamble reads
bin/idstack-migrate                        # Migrate an existing .idstack/project.json to the latest schema
bin/idstack-migrate --init                 # Also create a canonical manifest when none exists (standalone skill runs)
bin/idstack-manifest-merge --create --section <s> --payload <f>   # Canonical manifest write path (atomic, section-scoped; repeat the pair for several sections)
bin/idstack-slugify "<project name>"       # Derive the <course-slug> used for .idstack/exports/
bin/idstack-slugify --from-manifest        # Same, from the manifest's project_name (what skills call)
bin/idstack-ste-check <file|dir|->          # Find some ASD-STE100 writing-rule problems in idstack output
bin/idstack-ste-check --format markdown <f> # Use for .tmpl/.md: skips frontmatter and code fences. Reports a paragraph's problems on its first line
bin/idstack-report-section init <report> --skill <s> --title <t>   # Start a report: header, status line, placeholders (--reserve, --mode)
bin/idstack-report-section check <draft>   # Check a draft section: table shape, citation tiers, ASD-STE100
bin/idstack-report-section append <report> <draft>   # Check, then add the section to the report as a draft (atomic)
bin/idstack-report-section approve <report> [--draft <f>]  # Remove each draft mark; print SECTION_APPROVED: <heading>; delete the draft
bin/idstack-report-section finish <report> # Fail on a placeholder or a draft that remains; remove the status line.
                                           # --stopped (skill stopped early) fills each empty reserved section
bin/package-extension.sh                   # Package Chrome extension into build/ for Web Store distribution
bin/idstack-timeline-log '<json>'          # Append one event to .idstack/timeline.jsonl (adds "ts"; never fails the skill)
bin/idstack-learnings log|search|delete|promote   # Project learnings in .idstack/learnings.jsonl; promote copies to ~/.idstack/global/
```

Tests (run in CI on every PR and every push to main — see `.github/workflows/test.yml`. CI starts `smoke-test.sh` and `integration-test.sh`; smoke-test runs the other bash, node and python suites, but not `mutation-test.sh`, which CI runs in its own job):

```bash
./test/smoke-test.sh              # 538 assertions: install, SKILL.md freshness, frontmatter, version agreement,
                                  # canonical section names, /idstack: namespacing, resolve-snippet single source, bash -n,
                                  # Claude-Code-only invariant (no dist/, no AGENTS.md, no retired-CLI references)
./test/integration-test.sh        # 52 behavioral tests across the bin/ scripts; also proves the suite
                                  # leaves the working tree untouched
./test/test-setup.sh              # 10 behavioral tests for ./setup (flags, scope, failure handling, regeneration)
./test/test-doctor.sh             # 18 behavioral tests for bin/idstack-doctor's PROBLEM/WARNING branches and --quick
./test/test-status.sh             # 27 tests for bin/idstack-status, incl. the --readiness export gate
./test/test-manifest-merge.sh     # bin/idstack-manifest-merge unit tests
./test/test-plugin-status.sh      # bin/lib/plugin-status.sh unit tests
./test/test-preamble-python.sh    # Runs the preamble's Context Recovery (idstack-status --context) on the local python3; CI covers 3.9 and 3.12
./test/test-skill-shell-zsh.sh    # 83 tests: runs real skill bash blocks in bash AND zsh (the Bash tool runs the
                                  # user's shell, zsh on macOS; a new shell per call). smoke-test runs it
./test/test-extension.sh          # Chrome extension unit tests; import the shipped extension/ modules via
                                  # test/extension-harness.mjs (Node >= 20.19 or 22.7; never add .cjs twins)
./test/test-responsive-landing.js # Responsive/mobile invariants for docs/index.html, as CSS text (node; via smoke-test)
./test/test-rendered-landing.js   # Renders docs/index.html in headless Chrome and asserts the outcome:
                                  # no sideways scroll, 44px touch targets, column counts (node + Chrome)
python3 test/test-ste-check.py          # bin/idstack-ste-check unit tests (smoke-test also runs them)
python3 test/test-report-section.py     # 37 tests for bin/idstack-report-section: init, check, append, approve, finish (smoke-test also runs them)
python3 test/check-evidence-cards.py . # Verifies landing page evidence cards match evidence/references.md
python3 test/check-citation-tiers.py . # Verifies each [Code-N] [Tn] in skills, templates, README and landing page has its references.md tier
python3 test/test-citation-tiers.py   # check-citation-tiers.py unit tests: comma lists, line-split citations (smoke-test also runs them)
python3 test/check-doc-accuracy.py .   # Verifies version strings, the schema version, that each bin/ path in README exists and is
                                       # executable, and that each test/ file named in CLAUDE.md and CONTRIBUTING.md exists
./test/mutation-test.sh           # Reintroduces each fixed defect and asserts its guarding test fails.
                                  # The full run takes ~2.5 h: run it in the background.
                                  # A case whose anchor text no longer matches prints ERROR, and no result counts until
                                  # it is fixed. When you rename or move text, grep this file for it and update the anchor
                                  # To run only cases from N on (header, baseline and no-op control included):
                                  # { sed '/^# 1\. /,$d' test/mutation-test.sh;
                                  #   awk '/^shell_mutation\(\) \{/,/^}/' test/mutation-test.sh;
                                  #   sed -n '/^# 61a\./,$p' test/mutation-test.sh; } > "$f" && bash "$f" "$(pwd -P)"
                                  # To check only that every anchor still matches (~30 s): run a copy in which
                                  # expect_fail records STALE instead of running the suites, with the baseline
                                  # smoke run and the case-0 no-op control turned off
```

The counts in the comments above are kept by hand. After you add or remove a check, update them from a real run.

`test/test-helper.sh` is not a suite — it is sourced by every **bash** suite that runs assertions itself and owns the shared `PASS`/`FAIL`/`TOTAL` counters and the `check()` assertion (`test-extension.sh` is the exception: it delegates to node). Do not add a local counter block to a bash suite; smoke-test fails on one, and a mutation proves that guard works. The node suites (`test-extension.sh`'s sixteen unit tests, `test/test-responsive-landing.js`, and `test/test-rendered-landing.js`) cannot source it. The two landing-page suites collect their problems and report a count, which is the same contract in another language. The extension unit tests use `node:assert` and stop at the first failure. Three of them (`test-disclosures.mjs`, `test-evidence-labels.mjs`, `test-ste-rules.mjs`) collect their problems first and list them all in one failed assertion.

CI matrix: ubuntu (Python 3.9 + 3.12) and macOS (3.12). 3.9 is the leg that catches modern-only Python syntax reaching the preamble's embedded scripts — it is what macOS ships. `mutation-test.sh` runs once, pinned to 3.9. The test, mutation and release jobs pin Node 22 for the extension and rendered-landing tests.

No build step for users. No dependencies beyond bash and python3 3.9 or later; `bin/idstack-doctor` reports a missing or older python3. Skills are plain Markdown files.

### Testing a branch in the desktop app

Desktop sessions load idstack from the GitHub marketplace. To try a worktree, then switch back:

```bash
claude plugin marketplace remove idstack && ./setup    # point the install at this checkout
claude plugin uninstall idstack@idstack && claude plugin install idstack@idstack   # same VERSION keeps the old cache; reinstall copies the new files
# ...open a NEW session in a course folder (a running one keeps the skill it already loaded)...
claude plugin marketplace remove idstack && claude plugin marketplace add https://github.com/savvides/idstack.git && claude plugin install idstack@idstack
```

### Releasing

`VERSION` is the source of truth. A bump must also update `.claude-plugin/plugin.json`, a `## vX.Y.Z.W` entry in `CHANGELOG.md`, `README.md`, and `docs/index.html` (`vX.Y.Z.W` plus the same 4-part `softwareVersion`). smoke-test and `check-doc-accuracy.py` fail on any mismatch. Pushing a `v*` tag runs `release.yml`, which checks the tag against these files and then creates the GitHub release.

Changes that are not released yet go under `## Unreleased` at the top of `CHANGELOG.md`; the version checks look only for `## vX.Y.Z.W`. At a bump, move its sections into the new `## vX.Y.Z.W` entry (and its summary). Do not leave both headings.

Two versions move on their own schedule. The Chrome extension has its own version in `extension/manifest.json`, and `bin/package-extension.sh` names the zip from it. The manifest schema version (`1.4`) is hard-coded in `templates/manifest-schema.md` and in `check-doc-accuracy.py`, so a schema bump also needs a `bin/idstack-migrate` step.

## Architecture

### Skills

Each skill is a directory with a template and generated file:

```
skills/{skill-name}/
├── SKILL.md.tmpl  # Source: YAML frontmatter + {{PREAMBLE}} + workflow
└── SKILL.md       # Generated by bin/idstack-gen-skills (do not edit directly)
```

In a merge or rebase conflict on a generated `SKILL.md`, take either side, resolve the `.tmpl`, then run `bin/idstack-gen-skills`.

12 skills total. The 8-skill linear pipeline is the canonical sequence; `/idstack:course-import` joins it when there's an existing course to start from, `/idstack:learn` is a cross-project memory utility that runs outside the pipeline, and `/idstack:start` is the first-run guide that checks the setup and starts the correct skill. All invoked via `/idstack:<skill>`:

```
/idstack:pipeline (orchestrates the 8-skill linear chain, auto-skips completed)

/idstack:needs-analysis → learning-objectives → assessment-design → course-builder → course-quality-review → accessibility-review → red-team → course-export
                                    ↑
/idstack:course-import ─────────────┘

/idstack:learn (manage cross-project learnings)

/idstack:start (first-run guide: setup check, folder check, then hands off)
```

Adding a skill: update every hard-coded skill list and count. smoke-test catches some of them; `git grep -nE '(^|[^0-9])N skills'` finds the rest (`\b` does not work in `git grep -E` on macOS).

Any skill also works standalone (asks questions directly if no manifest exists).

### Project manifest and reports — the dual-output contract

Every skill that produces findings writes **both**:

1. **JSON section** in `.idstack/project.json` — system state for downstream skills, the pipeline orchestrator, and `bin/idstack-status`.
2. **Markdown report** at `.idstack/exports/<course-slug>/<skill>.md` — the human view, plain Markdown with no styling. Skeleton: `templates/report.md.tmpl`. Content contract: `templates/report-format.md`. The skill writes the relative path back into its section's `report_path` field.

After each step, `bin/idstack-report-section` adds the output to the report at once as a draft section with a table (the "Step Review" in `templates/preamble.md`). The user reads the table in the report file, not in the chat. The chat keeps only a note of a maximum of three lines and the question. When the user approves the section, `approve` removes the draft mark. A stopped session keeps every section, and an unapproved one keeps its draft mark. The manifest is written after `finish` and holds only approved rows, and scores come from approved rows.

The Markdown report is what the instructional designer reads. The JSON is for the system. The two stay in sync: every finding in the report corresponds to a finding in the manifest's structured arrays.

`<course-slug>` is derived from the manifest's `project_name` via `bin/idstack-slugify` (NFKD-fold, lowercase, kebab-case, ASCII-safe; empty input → `untitled-course`). All per-course artifacts — every per-skill Markdown report, the pipeline `index.md` dashboard, and LMS packages (`course-export.imscc`, `scorm-export.zip`) — live under the same `.idstack/exports/<course-slug>/` folder, so the deliverable is self-describing when zipped, emailed, or handed off.

`/idstack:pipeline` produces `.idstack/exports/<course-slug>/index.md` — the cross-cutting course dashboard, from the skeleton in `templates/index.md.tmpl`. It surfaces readiness scores, top issues that recur across multiple skills, evidence themes, links to every per-skill report, and where to start. Regenerated on every pipeline run (including partial runs and explicit re-runs when all skills are already complete).

Rules for writing the manifest:

- Validate JSON on read. If malformed, report and stop. Never silently overwrite.
- Own your section only. Read full manifest, modify only your skill's section, preserve everything else.
- Update the `updated` timestamp on every write.
- Use `bin/idstack-manifest-merge` for the write path: it's section-scoped, atomic (tempfile + rename), preserves foreign sections, and rejects a section name that is not in the canonical schema in `templates/manifest-schema.md` (exit 3) and a payload that is not a JSON object (exit 1). It does not check the fields inside a section. Inline full-manifest `Edit` is the deprecated fallback only.
- Pass `--create` on every merge. A skill can run standalone, and without a manifest the merge exits 4 and the results are never saved. `--create` seeds a canonical manifest through `bin/idstack-migrate --init` first; it never replaces one that exists.
- A skill that writes several sections (`needs-analysis`, `course-import`, `assessment-design`) passes one `--section`/`--payload` pair per section in a single call, so the write is atomic: if any payload is malformed, nothing is written. `--set project_name=<v>` writes the one top-level field a skill owns. For a section that another skill also writes, read it, add your fields, and pass the whole merged section.

Rules for writing the report:

- Follow the skeleton in `templates/report.md.tmpl` and the **content contract** in `templates/report-format.md` — observation → evidence → why-it-matters → recommendation, with severity (`critical|warning|info`) and evidence tier (`T1`–`T5`) on every finding. Write Markdown, not HTML: `## <Heading>` sections, pipe tables and plain-text citations (`[Domain-N] [TN]`). There is no stylesheet to copy.
- Build the report with the preamble's Step Review, never in one write. Run `init` in the report-prep block, `check` and `append` for each draft, `approve` when the user approves it, then `finish`. Never show the table in the chat or put a row in the question. A skill names the section and its columns and does not repeat the procedure.
- Every step table has `ID` first and `Justification | Evidence` last: one sentence and a citation from `evidence/references.md` per row. `check` refuses a code that is not there or has the wrong tier. Fact sections (Project context, Course information, Imported structure, Readiness, Export contents, Generated artifacts) have no Justification or Evidence.
- Findings are a table (`ID | Severity | What we saw | Recommendation | Justification | Evidence`). The helper writes the `### Finding` blocks from it. The skill does not.
- Write all report text in ASD-STE100, as the "Writing Standard (ASD-STE100)" section of `templates/preamble.md` tells. Write a recommendation as "idstack recommends that you …" or "You can …". Do not use "consider", "may", "should" or "suggest". idstack is a collaborator.
- Cite every recommendation. Findings without a `[Domain-N] [Tier]` citation belong in *Limitations* or *Notes*, not *Findings*.
- The report-prep block prints `Report path:`, relative to the course folder. The skill writes it to the manifest `report_path` and gives it to the user as a Markdown link, with the same path as the link text and no angle brackets (the "Report Links" section of `templates/preamble.md`). The slug is ASCII kebab-case, so the relative path has no spaces and the link opens in the Claude desktop app. `/idstack:pipeline` and `/idstack:start` print `Dashboard path:` for the dashboard in the same way. In a skill's quoted closing message, name the link as a `<…>` placeholder, as `<course-slug>` is: the model says quoted text word for word. Never write "Open it in a web browser"; smoke-test fails on it.
- In the desktop app a path in chat is a link only when it is relative to the session folder: a Markdown link (any link text) or a path in backticks. An absolute path and a bare path are plain text (tested in the app). The Step Review note writes the exact line `Read the draft in [<path>](<path>).`, with the path that `append` prints. Given only "the report link", the model wrote the report name as plain text.
- AskUserQuestion refuses an option with no description. Give every option a short description; never write a rule that removes them.

### SKILL.md.tmpl structure

Every skill template follows this pattern:

1. **YAML frontmatter** with `name`, `description`, and `allowed-tools` fields.
2. **`{{PREAMBLE}}`** placeholder (replaced by `templates/preamble.md` during generation)
3. **Workflow** (Markdown defining the conversational flow, decision trees, outputs)
4. **`{{MANIFEST_SCHEMA}}`** placeholder (replaced by `templates/manifest-schema.md`). Optional: only `needs-analysis` and `course-import` use it
5. **`{{IDSTACK_RESOLVE}}`** placeholder (replaced by `templates/snippets/idstack-resolve.sh`). Unlike the other two, this one appears many times per template — once at the top of every bash block that calls `$_IDSTACK/bin/...`. Bash blocks run in separate shells, so `_IDSTACK` must be re-derived in each; the snippet is the single definition of that resolution order (`${CLAUDE_PLUGIN_ROOT}`, `IDSTACK_HOME`, then the Claude Code marketplace cache). Claude Code writes the plugin path into skill text only where it finds the exact token `${CLAUDE_PLUGIN_ROOT}`, and the Bash tool's shell never has the variable, so never give it a `:-` default. The generator expands the placeholder in `templates/preamble.md` too and leaves the snippet's comment lines out, so the snippet is the only copy. `templates/manifest-schema.md` is also read raw, so it has no placeholder and no resolve lines. smoke-test fails on a hand-written chain in either file and on any `${CLAUDE_PLUGIN_ROOT:-` in templates or skills.
6. **Timeline logging** (logs session data to `.idstack/timeline.jsonl` on completion). Not in `learn` or `start`: neither writes a timeline event
7. **Writing standard check** — after each file that the skill writes for a person, a bash block runs `"$_IDSTACK/bin/idstack-ste-check"` on that file. `test/smoke-test.sh` sets the number of check steps for each skill template, and fails on a different number. Update it when you add or remove a check step. A skill that starts a sub-agent puts a copy of the preamble's "Writing Standard (ASD-STE100)" section in the sub-agent prompt.

The shared preamble includes: interaction conventions (defines how skills use `AskUserQuestion`, `Agent`, and `Skill`), writing standard (the ASD-STE100 rules and word list), manifest check, preferences check, designer profile check, and context recovery (reads timeline + learnings for welcome-back messages and pipeline guidance).

Python that the preamble runs must parse on Python 3.9 — the version macOS ships. Context Recovery calls `bin/idstack-status --context`, which reads the timeline with the same code as the dashboard; `test/test-preamble-python.sh` runs the preamble block against it on the local python3, and the CI matrix runs it on 3.9 and 3.12. A syntax error there dies silently at runtime, which is how context recovery stayed broken for several releases. Skills get the course slug from `bin/idstack-slugify --from-manifest`, never from inline Python.

### Shared libraries

Logic used by more than one script — or that deserves a unit test — lives in `bin/lib/` and is loaded by its callers rather than inlined:

- `bin/lib/plugin-status.sh` — parses `claude plugin list` output into idstack's own entry
- `bin/lib/citations.py` — parses `[Code-N] [Tn]` citations and the tiers in `evidence/references.md`. Imported by `bin/idstack-report-section` and `test/check-citation-tiers.py`

Test the shipped file, never a copy. The version classifier drifted across three PRs while a mirrored copy in its test passed green.

### Chrome extension

`extension/` is a Manifest V3 side panel that audits Canvas, Google Docs and web pages. Plain ES modules: no package.json, no build step. `bin/idstack-gen-skills` writes `shared/ste-rules.js` from `templates/preamble.md`; do not edit it.

### Writing standard (ASD-STE100)

All text that idstack shows to a person follows the ASD-STE100 Simplified Technical English rules. This includes skill chat, reports, the dashboard, learner content, CLI messages and the Chrome extension.

- The text between `<!-- ste-core:begin -->` and `<!-- ste-core:end -->` in `templates/preamble.md` is the only source of the rules and the word list. `bin/idstack-gen-skills` writes `extension/shared/ste-rules.js` from that block, and smoke-test fails on a stale copy. Do not edit the JS file by hand.
- `bin/idstack-ste-check` finds the problems that a script can find. Each skill runs it on each file that the skill writes. The CLI suites and `test/smoke-test.sh` run it on fixed output.
- Do not add the ASD-STE100 dictionary, or a list that comes from it, to the repo. The idstack word list has a maximum of 50 words. ASD does not endorse idstack, so do not write "STE-compliant" or "certified".
- The terms of instructional design and software are technical nouns and technical verbs. Do not add them to the word list.

### Course memory

Skills log session data to `.idstack/timeline.jsonl` (what skills ran, scores, dimensions) and `.idstack/learnings.jsonl` (project-specific discoveries). The context recovery preamble reads these on session start to provide continuity across conversations.

### Evidence standards

Every recommendation in a skill must cite its evidence tier using domain codes from `evidence/references.md`:

| Tier | Meaning |
|------|---------|
| T1 | Meta-analyses, RCTs |
| T2 | Quasi-experimental with controls |
| T3 | Systematic reviews of mixed evidence |
| T4 | Observational, no comparison group |
| T5 | Expert opinion, theoretical frameworks |

`test/test-evidence-labels.mjs` parses this table and asserts the extension's `TIER_METADATA` labels match the Meaning column. Change the two together, and keep the `| Tn | text |` row format.

Format: `[DomainCode-Number] [Tier]` (e.g., `[Alignment-14] [T1]`). Stronger evidence takes precedence when tiers conflict.

Editing `evidence/references.md`:
- Add each new reference with the next free number in its domain. Never renumber or reuse a number.
- When a tier changes, update every `[Code-N] [Tn]` that cites it, then run `bin/idstack-gen-skills`. If a grouped citation (`[A] [B] [T1]`) now has mixed tiers, split it (`[A] [T1] [B] [T2]`).
- `check-citation-tiers.py` does not scan `extension/`. `test/test-evidence-labels.mjs` (run by `test-extension.sh`) checks the codes and tiers in `extension/shared/prompts.js`, `extension/background/parser-helper.js` (the demo findings) and `extension/shared/evidence-base.js`.
- The total study count is hand-typed: 6 places in `docs/index.html`, plus `DESIGN.md` and `docs/og-template.html`. The README evidence table has hand-typed study counts, T1 counts and tier ranges for 7 domains. `check-evidence-cards.py` checks only the per-domain cards.
- `test/mutation-test.sh` quotes literal citation lines and needs one card tier range that is unique on the page (case 18). After changing tiers, grep it for the old strings.
- The Consensus MCP server, if connected, can verify references and find newer ones. Run at most 3 searches at a time. idstack itself has no Consensus integration since v3.9.0.0.

### Interaction pattern

- Ask one structured question at a time, using the `AskUserQuestion` tool. The preamble's "Interaction Conventions" section defines this protocol.
- Never batch multiple questions
- Skills must work without a manifest (fallback to asking questions directly)
- Write next-step text in the namespaced form, `/idstack:foo`. A bare `/foo` does not resolve, and smoke-test fails on one

## Tracking work

GitHub Issues is the only tracker. Do not add TODO lists or backlog files to the repo.

- When you defer a finding (from a review, a test run or a PR), open an issue with `gh issue create` and say so in your summary.
- Put `Closes #N` in the body of the PR that fixes an issue. GitHub closes an issue only on a closing keyword in a merged PR or commit; `(#N)` in a commit subject or CHANGELOG line does not close it.
- Labels: `bug`, `enhancement`, `documentation`, `tests`, `extension`, `backlog` (long-lived feature work), `decision-needed` (the owner must choose before anyone fixes it).

## Skill routing

When working in this repo, route user requests to the appropriate idstack skill:

- First run, "where do I start", or a Claude desktop app user → `/idstack:start`
- New course / fresh design → `/idstack:needs-analysis` (or `/idstack:pipeline` to chain all 8)
- Existing course (Canvas, Blackboard, Moodle, D2L cartridge, SCORM, PDF) → `/idstack:course-import`
- Bloom's classification, learning objectives, ILO development → `/idstack:learning-objectives`
- Rubrics, assessment design, formative checkpoints, feedback strategy → `/idstack:assessment-design`
- Generate course content (syllabus, modules, assignments) → `/idstack:course-builder`
- Quality audit (Quality Matters + Community of Inquiry) → `/idstack:course-quality-review`
- WCAG 2.1 AA + UDL accessibility review → `/idstack:accessibility-review`
- Adversarial pre-launch audit (5 dimensions, confidence score) → `/idstack:red-team`
- Package for LMS (IMS Common Cartridge, Canvas API, SCORM) → `/idstack:course-export`
- Search, prune, promote, or export cross-project learnings → `/idstack:learn`

Skills are auto-discovered by Claude Code via the plugin manifest at
`.claude-plugin/plugin.json`.

## Design system

Always read `DESIGN.md` (repo root) before making any visual or UI decision in this project. All font choices, colors, spacing, border radii, motion timing, and aesthetic direction are defined there. Do not deviate without explicit user approval and a corresponding update to `DESIGN.md`.

Reports and the dashboard are plain Markdown and carry no styling, so `DESIGN.md` does not apply to them. Reflect any update to `DESIGN.md` in `docs/index.html` (landing-page tokens) in the same PR.
