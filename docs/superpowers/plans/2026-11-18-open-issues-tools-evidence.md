# Open Issues (#170, #181, #185, #186, #140) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close five open issues: keep a finished report on a second run, make `--help` and unknown options behave the same in the `scripts/` tools, give python3 help for each OS, correct the install advice, and replace two weak references.

**Architecture:** Each fix is a small change in one shipped script plus its test, in the suite that already owns that script. PR 1 holds tasks 1 to 5 in series on `claude/tool-fixes-170-181-185-186`. PR 2 holds task 6 on a new branch from `main`.

**Tech Stack:** bash 3.2, python3 3.9, the repo's own suites (`test/test-helper.sh` `check`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-11-18-open-issues-tools-evidence-design.md`

## Global Constraints

- Python must parse on 3.9. Bash must run on 3.2 and zsh where a skill runs it.
- All text that a person reads (messages, help, README, CHANGELOG, preamble) follows ASD-STE100. Run `scripts/idstack-ste-check --format text -` on each new message and `--format markdown` on each changed `.md`/`.tmpl`. Do not use "consider", "may", "should", "suggest".
- Never edit `skills/*/SKILL.md` or `extension/shared/ste-rules.js`. Edit the `.tmpl` or `templates/preamble.md`, then run `scripts/idstack-gen-skills`.
- Test the shipped file, never a copy. No local counter block in a bash suite; use `check` from `test/test-helper.sh`: `check "<desc>" "<cmd>" <exit> "<regex>"`.
- Fail first: run each new test and see it fail before the fix.
- Each fix gets a mutation case after `68l` in `test/mutation-test.sh` (IDs `69a`…; first `grep '^# 69'` to confirm they are free). Form: `shell_mutation "<desc>" <file> '<anchor text>' '<mutated text>' [suite]`. The anchor must be text found only at the mutated site. Do not run the full mutation suite; run the anchor-only check from `CLAUDE.md`.
- After each task: `./test/smoke-test.sh` and `./test/integration-test.sh` exit 0 (locally, smoke-test can show one known failure: the rendered-landing test, because Chrome does not start in a background job). Update the hand-kept counts in `CLAUDE.md` and the `CLAUDE.md`/`docs/cli-reference.md` text from the real run.
- One line for each issue below `## Unreleased` in `CHANGELOG.md`. No version bump. No number of studies in any doc.
- Keep scratch files in the session scratchpad, never in the repo.
- Workers: tasks 1 to 4 go to `coding-worker`. Tasks 5 and 6 stay with the coordinator (they depend on a live check and on a source of record).

## Review Focus

1. A report path that is a symlink, or a report with no parent `<course-slug>` folder (a bare `report.md`): `init` must still back up or fail cleanly, never write outside `.idstack/`. Test in Task 1.
2. `idstack-status --context` and `--readiness` must give byte-identical output before and after the argument loop. Test in Task 2.
3. `idstack-learnings search --limit=5` (the `=` forms) and `--cross-project` must still pass after unknown options become fatal. Test in Task 3.
4. A working python3 that lives in a `WindowsApps` folder (a real Store install) must give `OK`, not `PYTHON_WINSTUB`. Test in Task 4.
5. `--help` given after a valid flag (`idstack-status --context --help`, `idstack-doctor --quick --help`) prints the help and exits 0. Tests in Tasks 2 and 3.

---

### Task 1: `report-section init` keeps a finished report (#181)

**Files:**
- Modify: `scripts/idstack-report-section` (`cmd_init`, header docstring)
- Modify: `templates/preamble.md` (Step Review, where the report-prep block is described), then regenerate skills
- Modify: `docs/cli-reference.md` (`## idstack-report-section`), `CHANGELOG.md`, `CLAUDE.md` (the `init` line and the test count)
- Test: `test/test-report-section.py`, `test/mutation-test.sh`

**Interfaces:**
- Produces: stdout line `REPORT_KEPT: <relative backup path>` printed before `REPORT_STARTED:`. Backup path: `.idstack/prev-reports/<course-slug>/<basename>`, where `<course-slug>` is `os.path.basename(os.path.dirname(os.path.abspath(report)))` and `.idstack` is the folder two levels above the report's folder (`…/.idstack/exports/<slug>/x.md`). If the report is not under an `exports/<slug>/` folder, the backup goes to `prev-reports/` beside the report.

- [ ] **Step 1: Write the failing tests** in `ReportSectionTest`, next to `test_init_replaces_an_earlier_report`. `PREV = '.idstack/prev-reports/bio-101/needs-analysis.md'`. Use the existing helpers (`self.init()`, `self.append()`, `self.read()`, `self.path()`, `self.run_helper()`); write a small `finish_report()` helper only if none exists.

```python
def test_init_keeps_a_finished_report(self):
    # init, append TASKS, approve, append CLOSING, approve, finish -> finished report
    before = self.read(REPORT)
    result = self.init()
    self.assertEqual(result.returncode, 0, result.stdout)
    self.assertEqual(self.read(PREV), before)
    self.assertIn('REPORT_KEPT: ' + PREV, result.stdout)
    self.assertLess(result.stdout.index('REPORT_KEPT'), result.stdout.index('REPORT_STARTED'))

def test_init_does_not_keep_a_report_in_progress(self):
    # init, append TASKS, init again
    self.assertFalse(os.path.exists(self.path(PREV)))
    self.assertNotIn('REPORT_KEPT', result.stdout)

def test_init_in_progress_run_leaves_the_earlier_backup(self):
    # finished A -> init (backup = A) -> init again while in progress
    self.assertEqual(self.read(PREV), finished_a)

def test_init_second_finished_report_replaces_the_backup(self):
    # finished A -> init -> finish B -> init: backup == B

def test_init_backup_failure_leaves_the_report(self):
    # finished report; make .idstack/prev-reports a regular FILE so makedirs fails
    self.assertEqual(result.returncode, 4)
    self.assertIn('REPORT_WRITE_FAILED', result.stdout)
    self.assertEqual(self.read(REPORT), before)

def test_init_keeps_a_finished_report_that_is_a_symlink(self):
    # report path is a symlink to a finished file elsewhere in the course folder
    # backup holds the text; the report path is still a symlink after init
```

- [ ] **Step 2: Run** `python3 test/test-report-section.py -k init` — the six new tests FAIL; the existing init tests pass.
- [ ] **Step 3: Implement** in `cmd_init`, before `write_atomic(args.report, …)`: if `os.path.isfile(args.report)` and no line of it equals `STATUS_LINE`, compute the backup path (Interfaces), `os.makedirs(..., exist_ok=True)`, `write_atomic(backup, text)`, and print `REPORT_KEPT: <os.path.relpath(backup)>`. An `OSError` goes to the existing `REPORT_WRITE_FAILED` handler in `main` (exit 4). Add one sentence on this to the header docstring.
- [ ] **Step 4: Run** `python3 test/test-report-section.py` — all pass.
- [ ] **Step 5: Preamble.** In `templates/preamble.md`, where the skill reads the `Report path:` line, add: if the output has a line that starts with `REPORT_KEPT:`, tell the user in one line that idstack kept the earlier report, with that path in backticks. Run `scripts/idstack-ste-check --format markdown templates/preamble.md`, then `scripts/idstack-gen-skills`.
- [ ] **Step 6: Mutation case 69a** — anchor: the new `if` condition line in `cmd_init`; mutated: `if False:`; suite `test-report-section.py` (follow how case 68 neighbours name a python suite).
- [ ] **Step 7: Docs, counts, changelog** (`Closes #181` goes in the PR body, not here). Run smoke and integration suites.
- [ ] **Step 8: Commit** `fix: report-section init keeps the earlier finished report (#181)`.

### Task 2: `idstack-status` and `idstack-doctor` arguments (#170, part 1)

**Files:**
- Modify: `scripts/idstack-status:1-27`, `scripts/idstack-doctor` (argument loop, header lines 9-13)
- Modify: `docs/cli-reference.md` (both sections' synopsis and Exit tables), `CLAUDE.md`
- Test: `test/test-status.sh`, `test/test-doctor.sh`, `test/mutation-test.sh`

**Interfaces:**
- Produces, for both tools: `-h`/`--help` anywhere in the arguments prints the header comment to stdout, exit 0, and does nothing else. An unknown argument prints `ERROR: unknown argument: <arg>` and a `Command:` line on stderr, exit 2. This is the wording `idstack-doctor` and `idstack-gen-skills` use now.

- [ ] **Step 1: Capture the baseline** for Review Focus 2: in a scratch course folder with a manifest and a timeline (copy the fixture set-up that `test/test-status.sh` uses), save the output of `idstack-status`, `--context` and `--readiness` to the scratchpad.
- [ ] **Step 2: Write failing checks.** `test/test-status.sh`:

```bash
check "--help prints the usage and exits 0" "$STATUS --help" 0 "^Usage: idstack-status"
check "-h prints the usage and no dashboard" "$STATUS -h | grep -c 'Project:'" 1 "^0$"
check "--help does not print the shell constants" "$STATUS --help | grep -c READY_QUALITY_MIN=" 1 "^0$"
check "--context --help prints the usage" "$STATUS --context --help" 0 "^Usage: idstack-status"
check "an unknown argument exits 2" "$STATUS --bogus" 2 "ERROR: unknown argument: --bogus"
check "an unknown argument prints no dashboard" "$STATUS --bogus 2>/dev/null | wc -c | tr -d ' '" 0 "^0$"
check "the help text obeys the writing standard" "( set -o pipefail; $STATUS --help | python3 '$IDSTACK_DIR/scripts/idstack-ste-check' --format text - )"
```

  `test/test-doctor.sh` (next to line 193; the suite runs with a mock `PATH`, so follow its `DOCTOR_CMD` pattern):

```bash
check "--help prints the usage and exits 0" "'$DOCTOR_CMD' --help" 0 "idstack-doctor --quick"
check "-h exits 0" "'$DOCTOR_CMD' -h" 0
check "--quick --help prints the usage, not a code" "'$DOCTOR_CMD' --quick --help | grep -cxE 'OK|PYTHON_[A-Z]+'" 1 "^0$"
```

  Match the variable names the suites already define (`$STATUS`, `$IDSTACK_DIR`/`$SRC`).
- [ ] **Step 3: Run both suites** — the new checks FAIL.
- [ ] **Step 4: Implement.** `idstack-status`: put a blank line after the header comment (move the "Readiness thresholds" comment below it so it stays with the constants), make the `Usage:` line start the synopsis, and replace the two `[ "$1" = … ]` lines with a `for arg in "$@"` `case` loop. `idstack-doctor`: add `-h|--help)` to the loop with the same `sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'`; scan for help before `--quick` acts. Update the header's exit-code lines.
- [ ] **Step 5: Run both suites** — pass. Diff the three baseline outputs from Step 1 against new runs: no difference.
- [ ] **Step 6: Mutation cases 69b, 69c** — one per tool; anchor: the new unknown-argument line of `idstack-status`, and the `-h|--help)` line of `idstack-doctor`.
- [ ] **Step 7: Docs and counts; smoke and integration suites; commit** `fix: idstack-status and idstack-doctor accept --help and refuse an unknown argument (#170)`.

### Task 3: `idstack-learnings`, `idstack-gen-skills`, `idstack-migrate` (#170, part 2)

**Files:**
- Modify: `scripts/idstack-learnings` (`usage`, top-level dispatch, `search` loop line ~182, header), `scripts/idstack-gen-skills:4-5`, `scripts/idstack-migrate` (header)
- Modify: `docs/cli-reference.md` (three sections), `CLAUDE.md`, `CHANGELOG.md` (one line for all of #170)
- Test: `test/integration-test.sh`, `test/smoke-test.sh` or the suite that already tests `gen-skills`/`migrate` flags (find with `grep -ln 'idstack-migrate' test/*.sh`), `test/mutation-test.sh`

**Interfaces:**
- `idstack-learnings -h|--help` (first argument): header to stdout, exit 0. No subcommand or an unknown subcommand: `Usage:` on stderr, exit 2 (was 1). `search <unknown option>`: `idstack-learnings: unknown option: <opt>` on stderr, exit 2, no results on stdout. `log` unchanged: exit 0 always. `delete`/`promote` errors keep exit 1.

- [ ] **Step 1: Write failing checks** in `test/integration-test.sh` (replace the check at line 332, which accepts any non-zero code):

```bash
check "--help prints the usage and exits 0" "$IDSTACK_DIR/scripts/idstack-learnings --help" 0 "^Usage: idstack-learnings"
check "-h makes no .idstack folder" "mkdir -p '$TEST_DIR/h2' && (cd '$TEST_DIR/h2' && $IDSTACK_DIR/scripts/idstack-learnings -h >/dev/null) && [ ! -e '$TEST_DIR/h2/.idstack' ]"
check "an unknown subcommand exits 2 with usage" "$IDSTACK_DIR/scripts/idstack-learnings frobnicate" 2 "^Usage: idstack-learnings"
check "no subcommand exits 2 with usage" "$IDSTACK_DIR/scripts/idstack-learnings" 2 "^Usage: idstack-learnings"
check "search refuses an unknown option" "$IDSTACK_DIR/scripts/idstack-learnings search --bogus" 2 "unknown option: --bogus"
check "search with an unknown option prints no results" "$IDSTACK_DIR/scripts/idstack-learnings search --bogus 2>/dev/null | wc -c | tr -d ' '" 0 "^0$"
check "search still accepts --limit=1 and --cross-project" "$IDSTACK_DIR/scripts/idstack-learnings search --limit=1 --cross-project --keyword=test"
check "log still exits 0 on an unknown option" "$IDSTACK_DIR/scripts/idstack-learnings log --bogus"
check "gen-skills --help shows the help option" "$IDSTACK_DIR/scripts/idstack-gen-skills --help" 0 "\[-h\|--help\]"
check "migrate --help gives the exit code for an unknown flag" "$IDSTACK_DIR/scripts/idstack-migrate --help" 0 "exits 2"
check "migrate --help gives the INITIALIZED line" "$IDSTACK_DIR/scripts/idstack-migrate --help" 0 "INITIALIZED <path>"
```

  Before writing the `log --bogus` check, read what `log --bogus` does now (it logs `{"raw": …}`); run that check in a scratch subfolder as the neighbours do so the suite still leaves the tree clean.
- [ ] **Step 2: Run** `./test/integration-test.sh` — new checks FAIL.
- [ ] **Step 3: Implement.** `usage()` exits 2. Top-level `case`: `-h|--help)` prints the header. `search`: `*) echo "idstack-learnings: unknown option: $1" >&2; exit 2 ;;`. `gen-skills`: synopsis `idstack-gen-skills [--dry-run] [-h|--help]`. `migrate`: two header sentences (unknown flag exits 2; with `--init`, `INITIALIZED <path>` on stderr — confirm the exact line at `scripts/idstack-migrate:~68` and quote it). Update the learnings header ("python3 missing … exits 2" now shares the code; say so).
- [ ] **Step 4: Run** integration and smoke suites — pass. `grep -rn 'idstack-learnings' skills/*/SKILL.md.tmpl templates/` and confirm no caller passes an option outside `--limit --type --keyword --cross-project`.
- [ ] **Step 5: Mutation case 69d** — anchor: the new `search` unknown-option line; mutated: `*) shift ;;`; suite `integration-test.sh`. Check that the edit did not break the anchors of the existing learnings cases (lines ~2197, ~2244, ~2617).
- [ ] **Step 6: Docs, counts, changelog; commit** `fix: idstack-learnings refuses an unknown option; --help agrees across tools (#170)`.

### Task 4: python3 help for each OS (#185)

**Files:**
- Modify: `scripts/idstack-doctor` (`--quick` block lines 39-57; the python3 section of the full run; header lines 9-10)
- Modify: `skills/start/SKILL.md.tmpl` (Step 1 bash block and the code list, lines ~40-70), then regenerate
- Modify: `docs/cli-reference.md`, `CLAUDE.md` (the `--quick` line lists the codes), `README.md` FAQ line ~524 only if it names the codes, `CHANGELOG.md`
- Test: `test/test-doctor.sh`, `test/test-skill-shell-zsh.sh` (if it runs the start block; keep its count right), `test/smoke-test.sh` (if it pins the code list), `test/mutation-test.sh`

**Interfaces:**
- `--quick` codes: `OK`, `PYTHON_MISSING`, `PYTHON_OLD`, `PYTHON_STUB` (macOS), `PYTHON_WINSTUB` (new). `PYTHON_WINSTUB` when: python3 does not pass the 3.9 test, and `command -v python3` contains `/WindowsApps/` (case as Git Bash prints it; also accept `\WindowsApps\`). It is tested before the Darwin branch.
- Start skill block: after the doctor line it prints `OS: <uname -s>`. The skill maps `Darwin` → macOS text, `MINGW*`/`MSYS*`/`CYGWIN*` → Windows text, all others → Linux text.

- [ ] **Step 1: Confirm the stub's behaviour.** Use the `/browse` skill to read Microsoft's documentation on the "App execution aliases" python stub: its folder, and what it does when run with arguments. Record the source URL in the PR body. If the documentation contradicts the detection rule above, stop and report.
- [ ] **Step 2: Write failing checks** in `test/test-doctor.sh` with `fake_cmd` (lines 165-186). The fake python3 must live in a folder named `WindowsApps` on the mock PATH:

```bash
check "--quick prints PYTHON_WINSTUB for the Microsoft Store stub" "<PATH with $MOCK/WindowsApps> '$DOCTOR_CMD' --quick" 1 "^PYTHON_WINSTUB$"
check "--quick prints OK for a python3 that works in a WindowsApps folder" "<same PATH, python3 fake = real python3>" 0 "^OK$"
check "--quick prints PYTHON_OLD for a python3 that fails outside WindowsApps on Windows" "<uname fake = MINGW64_NT-10.0>" 1 "^PYTHON_OLD$"
check "the full run reports the Microsoft Store stub" "<stub PATH> '$DOCTOR_CMD'" 1 "PROBLEM: .*Microsoft Store"
```

  Existing checks at lines 178-186 (`PYTHON_STUB`, `PYTHON_OLD`) must still pass unchanged.
- [ ] **Step 3: Run** `./test/test-doctor.sh` — new checks FAIL.
- [ ] **Step 4: Implement** the `--quick` branch and the full-run PROBLEM line with a `Fix:` that names the python.org Windows installer and a new session.
- [ ] **Step 5: Start skill.** Add `echo "OS: $(uname -s 2>/dev/null)"` to the Step 1 block. Rewrite the code list: `PYTHON_STUB` stays macOS-only; add `PYTHON_WINSTUB`; `PYTHON_MISSING`/`PYTHON_OLD` choose the text by the `OS:` line. Windows text: get the Windows installer from https://www.python.org/downloads/, open it, set "Add python.exe to PATH", then start a new session. Linux text: install python3 with the package manager of the distribution, then start a new session. Run `idstack-ste-check --format markdown` on the template, then `scripts/idstack-gen-skills`. Run `./test/test-skill-shell-zsh.sh`.
- [ ] **Step 6: Mutation case 69e** — anchor: the `WindowsApps` test line; mutated to a condition that is never true; suite `test-doctor.sh`.
- [ ] **Step 7: Docs, counts, changelog (say plainly: checked with fake commands, not on Windows; #136 stays open). Smoke and integration suites. Commit** `fix: python3 help depends on the OS; the doctor finds the Microsoft Store stub (#185)`.

### Task 5: `./setup --local` scope and desktop advice (#186) — coordinator

**Files:**
- Modify: `README.md` (lines ~132-146 and ~588), `scripts/idstack-doctor` ("not installed" Fix, lines ~141-145), `setup` help text only if the check shows it is wrong, `docs/cli-reference.md` (`## setup`), `CHANGELOG.md`
- Test: `test/test-doctor.sh`, `test/mutation-test.sh`

- [ ] **Step 1: Check the scope without touching the real install.** In the scratchpad: `export CLAUDE_CONFIG_DIR="$S/cfg"`; make `$S/course`; from it run `claude plugin marketplace add /Users/whiplash/idstack` and `claude plugin install idstack@idstack --scope project`. Record which file changed (`$S/course/.claude/settings.json` or one under the clone). Run `claude plugin list` with and without the variable to prove the real install did not change. If the CLI ignores `CLAUDE_CONFIG_DIR` or asks to log in, stop and ask the owner before any test on the real install.
- [ ] **Step 2: Write the failing check** in `test/test-doctor.sh`: copy the doctor's tree into a path that contains `/.claude/plugins/cache/` (follow how the suite builds its sandbox), with a mock `claude` whose `plugin list` is empty:

```bash
check "in the plugin cache, the fix gives the GitHub marketplace" "'$CACHE_DOCTOR'" 1 "claude plugin marketplace add https://github.com/savvides/idstack.git"
check "in the plugin cache, the fix does not give the cache path" "'$CACHE_DOCTOR' | grep -c 'marketplace add \"/'" 1 "^0$"
```

- [ ] **Step 3: Run — FAIL. Implement** the branch in the doctor on `case "$IDSTACK_DIR" in */.claude/plugins/cache/*)`. **Run — PASS.**
- [ ] **Step 4: README.** Project-scoped install: state what Step 1 found. If the scope follows the current folder, give `cd <course folder>` then `/path/to/idstack/setup --local`. Troubleshooting (line ~588): keep the doctor line for a user with a clone; add the two commands for a desktop user with no clone (`claude plugin marketplace add https://github.com/savvides/idstack.git`, `claude plugin install idstack@idstack`). Run `python3 test/check-doc-accuracy.py .`.
- [ ] **Step 5: Mutation case 69f; docs, counts, changelog; suites; commit** `fix: install advice for a project scope and for a desktop user with no clone (#186)`.
- [ ] **Step 6: Finish PR 1.** Anchor-only mutation check (recipe in `CLAUDE.md`). `git status` clean of scratch files. Independent review (`reasoning-worker`: give it the diff and the spec; ask for architectural drift, helpers nobody asked for, spec violations). Push; `gh pr create` with `Closes #170`, `Closes #181`, `Closes #185`, `Closes #186`; watch CI.

### Task 6: Assessment-12 and Online-2 (#140) — coordinator, PR 2 from `main`

**Files:**
- Modify: `evidence/references.md:100,185`
- If a tier changes: `skills/assessment-design/SKILL.md.tmpl:98`, `skills/course-builder/SKILL.md.tmpl:249`, `skills/course-export/SKILL.md.tmpl:202`, `skills/course-quality-review/SKILL.md.tmpl:57`, `docs/index.html` (the domain card), `README.md` (tier range), `extension/shared/evidence-base.js`, `extension/shared/prompts.js`, `extension/background/parser-helper.js`, `test/mutation-test.sh` (cases 18, 18b, 18c and any quoted citation line)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Find the papers** with the `/browse` skill (at most 3 searches at a time). For each: the article's page, DOI, authors, year, journal, design, sample. Assessment-12: the peer-reviewed article by Faber, Luyten and Visscher from the same research. Online-2: the full paper of the Trivedi et al. Quality Matters study.
- [ ] **Step 2: Decide** per reference. Replace only if the DOI opens and the study is the same one. Tier from the design: randomized experiment or meta-analysis → T1; quasi-experimental with controls → T2; no comparison group → T4. Write down the evidence for each decision in the PR body.
- [ ] **Step 3: Baseline.** `python3 test/check-citation-tiers.py . && python3 test/check-evidence-cards.py . && ./test/test-extension.sh` — exit 0 before the edit.
- [ ] **Step 4: Edit `evidence/references.md`** in the format of the neighbouring lines. Same numbers.
- [ ] **Step 5: Run the three checks again.** If a tier changed they FAIL; update each file in the list above (`git grep -n -F '[Assessment-12]'`, `git grep -n -F '[Online-2]'`), recompute the card's `data-tiers`, `aria-label` shares and widths with a short script rather than by hand, run `scripts/idstack-gen-skills`, and grep `test/mutation-test.sh` for the old strings.
- [ ] **Step 6: Verify.** The three checks, `python3 test/check-doc-accuracy.py .`, smoke and integration suites, anchor-only mutation check: exit 0.
- [ ] **Step 7: Commit, push, PR** with `Closes #140`. If a reference could not be confirmed, do not use `Closes`; leave a comment on #140 with what was found and keep the issue open.
