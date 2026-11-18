# Five open issues: tools, on-ramp and two references: design

Date: 2026-11-18. Covers savvides/idstack#170, #181, #185, #186 and #140. The owner asked to resolve the open issues that code or research can close today, and left the design choices to the builder ("I rely on your judgement").

## Intent

Twelve issues are open. Five can be closed with a change in this repo. Each is a small reliability or accuracy defect from the pre-share review, the documentation audit or the Consensus audit. The other seven stay open: #160 (Cowork), #136 (Windows), #135 (plugin directory) need an environment or an action that this session does not have, and #128, #129, #130, #132 are backlog features.

## Goals

- A second run of a skill does not destroy the finished report of the first run (#181).
- Each `scripts/` tool in #170 prints its usage and exits 0 on `-h`/`--help`, and exits 2 with a message on an option that it does not know.
- The python3 help that a user gets depends on the OS, and the doctor finds the Microsoft Store stub (#185).
- The README says correctly where `./setup --local` installs, and a desktop user with no clone gets advice that works (#186).
- Assessment-12 and Online-2 cite a peer-reviewed paper of the same study, if one exists (#140).

## Non-goals

- No CI leg for Windows, and no claim that idstack was run on Windows. #136 stays open.
- No change to `idstack-slugify` (it reads any text as a name, so `--help` gives `help`) or `idstack-timeline-log` (exit 0 always, by design).
- No change to the manifest schema, and no version bump. Entries go below `## Unreleased`.

## Anti-goals

- A citation written from memory. Each replaced reference is confirmed against the paper's own page.
- A backup file that shows in the course deliverable folder.
- A fatal exit in a path that a skill calls today. `idstack-learnings log` keeps exit 0.

## State today (measured on 2026-11-18)

| Tool | `--help` | Unknown option |
|------|----------|----------------|
| `idstack-status` | prints the dashboard, exit 0 | prints the dashboard, exit 0 |
| `idstack-doctor` | exit 2 | exit 2 |
| `idstack-learnings` | usage on stderr, exit 1 | exit 1; `search --bogus` ignores it, exit 0 |
| `idstack-gen-skills` | exit 0 | exit 2 |
| `idstack-migrate` | exit 0 | exit 2 |
| `idstack-manifest-merge`, `idstack-ste-check`, `idstack-report-section` | exit 0 (argparse) | exit 2 (argparse) |

Other facts:

- `cmd_init` in `scripts/idstack-report-section` writes the new skeleton over any file at the report path.
- `idstack-status` lists each `*.md` in `.idstack/exports/<course-slug>/` as a report, and that folder is the deliverable.
- Exit 2 already means "python3 is missing" in `idstack-status` and `idstack-learnings`.
- The header comment of `idstack-status` has no blank line before the `READY_*` constants, so the usual `sed -n '2,/^$/p'` help would print them.
- `idstack-doctor --quick` gives `PYTHON_STUB` only on Darwin. `/idstack:start` Step 1 names the macOS installer for every code.
- Skills call these tools only as: `status --context`, `status --readiness`, `doctor --quick`, `learnings log|search|delete|promote` with `--limit`, `--keyword`, `--cross-project`.
- `claude plugin install` accepts `--scope user|project|local`. Where `project` writes is not confirmed yet.

## Approaches

### #181: where the earlier report goes

| Option | Trade-off | |
|--------|-----------|---|
| A. `.idstack/prev-reports/<course-slug>/<skill>.md` | Outside the deliverable. No other tool changes. Less visible, so `init` prints the path. | **Picked** |
| B. `<skill>.prev.md` beside the report | Easy to find. `idstack-status` must skip it, and it ships in the zip. | |
| C. `init` refuses and the skill asks first | Safest. Adds a question to each second run of each report skill. | |

### #170: exit code for an unknown option

| Option | Trade-off | |
|--------|-----------|---|
| A. Exit 2 in each tool | Agrees with the five tools that do this now. In `status` and `learnings`, 2 has two causes; the message tells which. | **Picked** |
| B. Move "python3 is missing" to a new code | Clean codes. Changes a documented contract. | |

### #185: how `/idstack:start` gets the OS

| Option | Trade-off | |
|--------|-----------|---|
| A. New code `PYTHON_WINSTUB`; the start skill reads the OS in its own bash block | `--quick` keeps its one-code contract. | **Picked** |
| B. `--quick` prints a second line with the OS | Breaks the contract and its tests. | |

## Design

### #181 `report-section init`

- If the report exists and is finished (it does not have the status line), `init` copies it to `.idstack/prev-reports/<course-slug>/<basename>` before it writes the skeleton. `<course-slug>` is the name of the report's folder. The copy is atomic, as in "Shared libraries" in `CLAUDE.md`.
- `init` then prints `REPORT_KEPT: <backup path>` before `REPORT_STARTED:`.
- One backup for each report. A report that is in progress is replaced with no backup, as today, so a stopped run cannot replace a good backup with an empty one.
- If the copy fails, `init` exits non-zero and does not change the report.
- The preamble tells the skill to give the `REPORT_KEPT` path to the user in one line.
- Tests in `test/test-report-section.py`: finished report is kept, in-progress report is not, second finished report replaces the backup, failed copy leaves the report.

### #170 arguments

- `idstack-status`: a real argument loop. `-h`/`--help` prints the header, exit 0. An unknown argument: message on stderr, exit 2. The header gets a blank line that ends the help text.
- `idstack-doctor`: `-h`/`--help` prints the header, exit 0.
- `idstack-learnings`: `-h`/`--help` as the first argument prints the header, exit 0. An unknown subcommand or no subcommand: usage on stderr, exit 2 (was 1). `search` with an unknown option: message, exit 2. `log` is not changed.
- `idstack-gen-skills`: the synopsis shows `[-h|--help]`.
- `idstack-migrate`: the header gives exit 2 for an unknown flag and the `INITIALIZED <path>` line.
- `docs/cli-reference.md` and the `CLAUDE.md` command list follow. One test for each tool and each case, in the suite that owns the tool.

### #185 python3 help

- `--quick` gives `PYTHON_WINSTUB` when `python3` is on PATH, does not run, and its path is in a `WindowsApps` folder. The full doctor reports the same condition as a PROBLEM with the Windows fix. The builder confirms the stub's behaviour in Git Bash from Microsoft's documentation before writing the test.
- `/idstack:start` Step 1 prints the OS (`uname -s`) in its bash block and has help text for macOS, Windows and Linux. Windows: the python.org installer, then a new session. Linux: the package manager of the distribution.
- Tests use fake `python3` and `uname` commands, as `test/test-doctor.sh` does now. The PR says that no run on Windows was done.

### #186 setup scope and desktop advice

- Confirm where `--scope project` writes, with `CLAUDE_CONFIG_DIR` set to a scratch folder so the owner's install is not touched. If the CLI refuses that, stop and ask the owner before a test on the real install.
- README: the project-scoped install gives the command to run from the course folder, if the check confirms that the scope follows the current folder.
- README troubleshooting: a desktop user gets the two `claude plugin` commands for the GitHub marketplace. The doctor line stays for a user with a clone.
- `idstack-doctor`: when its own folder is in the Claude Code plugin cache, the "not installed" fix gives the GitHub marketplace, not the cache path.

### #140 references (second PR, branch from `main`)

- Find the peer-reviewed article for each reference. Confirm the DOI opens, and that authors, sample and intervention agree with the cited work. The study design sets the tier (T1 needs a randomized experiment or a meta-analysis).
- The numbers `Assessment-12` and `Online-2` stay. The coordinator edits `evidence/references.md`.
- If a tier changes: each `[Code-N] [Tn]` that cites it, `scripts/idstack-gen-skills`, the landing card (`data-tiers`, `aria-label`, widths), the README tier range, the extension evidence files, and mutation cases 18, 18b, 18c.
- If no full paper can be confirmed for a reference, it does not change, and the issue gets a comment with what was found.

## For each fix

A failing test first. A mutation case with a new ID after 68l, and the anchor-only check (the full run goes to CI). The hand-kept counts in `CLAUDE.md` from a real run. A line below `## Unreleased` in `CHANGELOG.md`. `Closes #N` in the PR body.

## Shipping

Two PRs. PR 1 (`claude/tool-fixes-170-181-185-186`): #170, #181, #185, #186, done in series, because three of them change `scripts/idstack-doctor` and `docs/cli-reference.md`. PR 2: #140.

## Left to the builder

The words of each message (ASD-STE100), the names of the tests, and the order of the four fixes inside PR 1.
