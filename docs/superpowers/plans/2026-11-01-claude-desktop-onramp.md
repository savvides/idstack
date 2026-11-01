# Claude Desktop On-Ramp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an instructional designer who never uses a terminal install and use idstack through the Claude desktop app's Code tab on a Mac.

**Architecture:** No new app. A new `/idstack:start` skill is the front door. It runs a new `bin/idstack-doctor --quick` setup check, refuses a non-course folder, reads the manifest state that the preamble already gives it, and hands off with the Skill tool. Every report-writing skill prints an absolute `Report link:` line and points its closing message at it, so a desktop user clicks to open the report. README and the landing page gain a desktop install path.

**Tech Stack:** bash (3.2-compatible, also run under `zsh -f`), python3 ≥ 3.9, Markdown skill templates rendered by `bin/idstack-gen-skills`, static HTML landing page.

**Spec:** `docs/superpowers/specs/2026-11-01-claude-desktop-onramp-design.md`

**Verified:** Tasks 1–5 of an earlier draft were dry-run in throwaway worktrees; every anchor matched and all suites passed at the end. The fixes from that run are folded in below. Counts marked "Expected" were measured, or derived from measured counts where the fix changed the number of checks.

## Global Constraints

- All user-facing text (skill chat, CLI output, README, landing page, CHANGELOG) follows ASD-STE100 per `templates/preamble.md`: sentences of 25 words or fewer, no contractions, never "consider", "may", "should", "suggest" or "such as" in idstack's voice.
- To check text in a `.tmpl` or `.md` file, run `python3 bin/idstack-ste-check --format markdown <file>`. Without `--format markdown` the checker also reads YAML frontmatter and bash code as prose. A reported semicolon inside a bash line is code: leave it. The checker reports a paragraph's problems on the paragraph's first line.
- Write every skill command in namespaced form, `/idstack:<name>`. A bare `/start` fails smoke-test once `start` is in `BARE_SLASH_RE`.
- Edit `skills/*/SKILL.md.tmpl` and `templates/preamble.md`, never a generated `SKILL.md`. After any template edit, run `bin/idstack-gen-skills`.
- Bash in skill templates and `bin/` must run in bash 3.2 and `zsh -f`: no `for x in $VAR`, no bare `ls *.ext` globs, no GNU-only `head -n -N`.
- Python that skills or the preamble run must parse on Python 3.9.
- Test suites source `test/test-helper.sh` and use `check`. Never add a local `PASS=0` / `FAIL=0` / `TOTAL=0`.
- Before you change any existing line, run `grep -nF '<the old text>' test/mutation-test.sh`. If a mutation anchors on it, update that anchor in the same commit.
- Do not change the `.idstack/` layout, the manifest schema (`1.4`), or the relative `report_path` values written to the manifest.
- `/idstack:start`'s own steps write no file, no manifest section and no timeline event. The one exception: repairing a malformed manifest's JSON syntax, with the user's yes.
- Line numbers in this plan are for the file as it is when that task starts (earlier tasks applied). Always match by the quoted text.
- Version: `3.10.0.0`. `softwareVersion` in `docs/index.html` is the full 4-part value.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `bin/idstack-doctor` | Modify | Argument parsing; `--quick` mode; skill list gains `start` |
| `test/test-doctor.sh` | Modify | `--quick` cases with fake `python3`/`uname`/`xcode-select`; skill list copy |
| `templates/preamble.md` | Modify | New "Report Links" section; Skill-tool line names `/idstack:start` |
| 9 report templates (`needs-analysis`, `learning-objectives`, `assessment-design`, `course-builder`, `course-quality-review`, `course-import`, `course-export`, `accessibility-review`, `red-team`) | Modify | Print `Report link:`; closing message points at it |
| `skills/pipeline/SKILL.md.tmpl` | Modify | Print `Dashboard link:`; closing message points at it |
| `skills/start/SKILL.md.tmpl` | Create | The `/idstack:start` workflow |
| `skills/*/SKILL.md` | Regenerate | Output of `bin/idstack-gen-skills` |
| `test/smoke-test.sh` | Modify | Register `start`; link checks; handoff and no-timeline checks |
| `test/test-skill-shell-zsh.sh` | Modify | Run the new blocks in bash and zsh |
| `test/mutation-test.sh` | Modify | Cases 61a–61f |
| `setup`, `README.md`, `docs/index.html`, `DESIGN.md`, `CLAUDE.md`, `.claude-plugin/*.json` | Modify | Skill count 12, `start` listed, desktop guide, release |
| `VERSION`, `CHANGELOG.md`, `ROADMAP.md` | Modify | Release v3.10.0.0 |

---

### Task 0: Hand checks in the Claude desktop app (USER-ONLY)

> **A subagent must not do this task or make up its results.** The controller asks the user to do it and records the answers. If the user skips it, use the defaults in Step 5 and repeat the checks in Task 7.

**Files:** none.

- [ ] **Step 1: Make a probe page in a folder whose name has a space** (course folders often do)

```bash
mkdir -p ".onramp-probe/Intro Bio/.idstack/exports"
cat > ".onramp-probe/Intro Bio/.idstack/exports/probe.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>idstack probe</title></head>
<body style="font-family:Georgia,serif;padding:2rem"><h1 style="color:#8a3b12">Rendered ✓</h1></body></html>
EOF
echo "$(pwd -P)/.onramp-probe/Intro Bio/.idstack/exports/probe.html"
```

- [ ] **Step 2: Ask the user to click two forms of the printed path in the desktop chat**: (P) the bare path on its own line, and (L) a Markdown link with angle brackets, `[Open the report](<path>)`. Record which ones open the page rendered (a rust heading "Rendered ✓").

- [ ] **Step 3: Ask the user to open a new Code-tab session and type `/plugin marketplace add savvides/idstack`.** Record "accepted" (including "already added") or "unknown command".

- [ ] **Step 4: Remove the probe** — `rm -rf .onramp-probe`

- [ ] **Step 5: Record the decisions**
  - **Link form:** use form **L** in Task 2 unless only P rendered; then use **P**. If skipped, use **L** (it survives spaces in folder names).
  - **Install path:** if accepted, use install text **A** in Task 5. If unknown, use install text **B**. If skipped, use **A** and repeat the check in Task 7.

---

### Task 1: `bin/idstack-doctor --quick`

**Files:**
- Modify: `bin/idstack-doctor:1-28`
- Test: `test/test-doctor.sh` (insert before `# --- writing standard (ASD-STE100) ---`, line 157)
- Test: `test/mutation-test.sh` (insert before the footer `echo ""` that precedes `echo "guarded: $pass ...`)

**Interfaces:**
- Produces: `idstack-doctor --quick` prints exactly one line, one of `OK`, `PYTHON_MISSING`, `PYTHON_OLD`, `PYTHON_STUB`. Exit 0 for `OK`, 1 for the others. An unknown argument prints `ERROR: unknown argument: <arg>` and `Command: idstack-doctor [--quick]` to stderr and exits 2. Task 3 calls this.

- [ ] **Step 1: Write the failing tests** — insert in `test/test-doctor.sh` directly before the line `# --- writing standard (ASD-STE100) ---`:

```bash
# --- --quick: one machine-readable code for /idstack:start ---
# The order is the point. A working python3 wins over a failing xcode-select,
# because a python.org install leaves the Command Line Tools absent. A stub
# check that ran first would block that user every time.
# The OK checks compare the whole output: the full report also ends with an
# OK line, so a regex would pass even if --quick were ignored.
# Fakes REPLACE the file in MOCK_BIN. Remove it first: MOCK_BIN/python3 is a
# symlink to the real interpreter, and a redirect would write through it.
fake_cmd() { # fake_cmd <name> <shell body>
  rm -f "$MOCK_BIN/$1"
  printf '#!/bin/sh\n%s\n' "$2" > "$MOCK_BIN/$1"
  chmod +x "$MOCK_BIN/$1"
}
restore_quick_cmds() {
  rm -f "$MOCK_BIN/uname" "$MOCK_BIN/xcode-select" "$MOCK_BIN/python3"
  ln -sf "$PYTHON" "$MOCK_BIN/python3"
}

setup_happy_path
check "--quick prints only OK when python3 is 3.9 or later" "[ \"\$('$DOCTOR_CMD' --quick 2>&1)\" = OK ]"

fake_cmd uname 'echo Darwin'
fake_cmd xcode-select 'exit 2'
check "--quick prints only OK on a Mac with python.org python3 and no developer tools" "[ \"\$('$DOCTOR_CMD' --quick 2>&1)\" = OK ]"

fake_cmd python3 'exit 1'
check "--quick prints PYTHON_STUB for the macOS python3 stub" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_STUB$"

fake_cmd uname 'echo Linux'
check "--quick prints PYTHON_OLD for an old python3 that is not the macOS stub" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_OLD$"
restore_quick_cmds

rm "$MOCK_BIN/python3"
check "--quick prints PYTHON_MISSING without python3" "'$DOCTOR_CMD' --quick" 1 "^PYTHON_MISSING$"
restore_quick_cmds

check "an unknown argument exits 2" "'$DOCTOR_CMD' --bogus" 2 "ERROR: unknown argument: --bogus"
"$DOCTOR_CMD" --bogus > "$TEST_ROOT/bad-arg.txt" 2>&1 || true
```

Then, in the writing-standard block, add this line directly after `cp "$TEST_ROOT/no-python.txt" "$STE_OUT/no-python.txt"`:

```bash
cp "$TEST_ROOT/bad-arg.txt" "$STE_OUT/bad-arg.txt"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./test/test-doctor.sh`
Expected: `12/18 passed`. All six new checks FAIL (doctor ignores `--quick` today and runs the full report, so the output is not just `OK` and the codes are missing; `--bogus` exits 0). The old 12 PASS.

- [ ] **Step 3: Implement** — in `bin/idstack-doctor`, replace the usage comment (lines 7-10, from `# Usage:` to `# Exit code: 0 if all green, 1 if any problem is detected.`) with:

```bash
# Usage:
#   idstack-doctor           full diagnosis
#   idstack-doctor --quick   one code for /idstack:start: OK, PYTHON_MISSING,
#                            PYTHON_OLD or PYTHON_STUB
#
# Exit code: 0 if all green (--quick: OK), 1 if any problem is detected,
# 2 for an unknown argument.
```

Then insert this directly before the line `echo "idstack doctor"` (after the `SKILLS=...` lines):

```bash
QUICK=0
for arg in "$@"; do
  case "$arg" in
    --quick) QUICK=1 ;;
    *) echo "ERROR: unknown argument: $arg" >&2; echo "Command: idstack-doctor [--quick]" >&2; exit 2 ;;
  esac
done

# --quick: the one python3 code that /idstack:start reads. A working python3
# comes first: a python.org install on a Mac has no Command Line Tools, and
# that is not a problem. Running the macOS stub here is also what opens the
# "install developer tools" window that /idstack:start tells the user about.
if [ "$QUICK" = "1" ]; then
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
    echo "OK"
    exit 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "PYTHON_MISSING"
  elif [ "$(uname -s 2>/dev/null)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
    echo "PYTHON_STUB"
  else
    echo "PYTHON_OLD"
  fi
  exit 1
fi
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./test/test-doctor.sh`
Expected: `18/18 passed`.

- [ ] **Step 5: Add mutations** — insert in `test/mutation-test.sh` directly before the footer `echo ""` that precedes `echo "guarded: $pass ...`:

```bash
# 61a. doctor --quick checks for the macOS stub before the python3 version ->
# test-doctor must fail. A python.org python3 on a Mac with no Command Line
# Tools would then be told to install the developer tools every time.
fresh
python3 - "$WORK/r/bin/idstack-doctor" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '  if command -v python3 >/dev/null 2>&1 && python3 -c'
assert s.count(old) == 1, 'anchor count %d' % s.count(old)
s = s.replace(old, '  if [ "$(uname -s 2>/dev/null)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then echo "PYTHON_STUB"; exit 1; fi\n' + old, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "doctor --quick reports the stub before it tries python3" "$WORK/r/test/test-doctor.sh"

# 61b. doctor --quick stops telling the stub apart from an old python3 ->
# test-doctor must fail.
fresh
python3 - "$WORK/r/bin/idstack-doctor" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = '    echo "PYTHON_STUB"\n'
assert s.count(old) == 1, 'anchor count %d' % s.count(old)
s = s.replace(old, '    echo "PYTHON_OLD"\n', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "doctor --quick no longer reports the macOS stub" "$WORK/r/test/test-doctor.sh"
```

- [ ] **Step 6: Run the mutation suite** (slow: about 2.5 hours; run it in the background)

Run: `./test/mutation-test.sh`
Expected: `GUARDED: doctor --quick reports the stub before it tries python3`, `GUARDED: doctor --quick no longer reports the macOS stub`, and a footer with `NOT guarded: 0`. Any `ERROR:` line means an anchor did not match; fix the case.

- [ ] **Step 7: Run smoke-test** — `./test/smoke-test.sh` → `434/434 passed, 0 failed` (smoke-test counts test-doctor as one check).

- [ ] **Step 8: Commit**

```bash
git add bin/idstack-doctor test/test-doctor.sh test/mutation-test.sh
git commit -m "feat(doctor): add --quick, one python3 code for /idstack:start

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Report links

**Files:**
- Modify: `templates/preamble.md` (new section before `## Preamble: Context Recovery`)
- Modify: the 9 report templates and `skills/pipeline/SKILL.md.tmpl` (exact lines below)
- Test: `test/smoke-test.sh` (after the `for tmpl in ... prints the plugin path of its report template` loop at the end, before the final `echo ""`)
- Test: `test/test-skill-shell-zsh.sh` (inside the `for sh in bash zsh` loop, directly before `  # Every preamble block exits 0 and prints the same output in both shells.`)
- Test: `test/mutation-test.sh`

**Interfaces:**
- Produces: every report-preparation block prints `Report link: <absolute path>`. The pipeline prints `Dashboard link: <absolute path>`. The preamble section `## Preamble: Report Links` defines how a skill shows either line. Task 3 prints both line formats.

- [ ] **Step 1: Write the failing smoke checks** — in `test/smoke-test.sh`, insert after the `done` that closes the `for tmpl in "$IDSTACK_DIR"/skills/*/SKILL.md.tmpl` loop at the end of the file (directly before `echo ""` / `echo "Results: ...`):

```bash
# A desktop user opens a report by clicking its full path in chat. Each report
# block prints one, and the closing message points at it rather than at a
# relative path; the pipeline does the same for the dashboard.
for skill in $REPORT_PRODUCING_SKILLS; do
  check "$skill prints an absolute report link" \
    "grep -qF 'echo \"Report link: \$(pwd -P)/\$_REPORT_PATH\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
  check "$skill closing message names the Report link line" \
    "[ \$(grep -c 'Report link:' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl') -ge 2 ]"
done
check "pipeline prints an absolute dashboard link" \
  "grep -qF 'echo \"Dashboard link: \$(pwd -P)/\$_EXPORT_DIR/index.html\"' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"
check "preamble tells skills to give the report link" \
  "grep -q '^## Preamble: Report Links' '$IDSTACK_DIR/templates/preamble.md'"
check "no skill tells the user to open a report in a web browser" \
  "! grep -l 'Open it in a web browser' $IDSTACK_DIR/skills/*/SKILL.md.tmpl"
```

- [ ] **Step 2: Write the failing bash/zsh check** — in `test/test-skill-shell-zsh.sh`, insert directly before `  # Every preamble block exits 0 and prints the same output in both shells.`:

```bash
  # Report links: a real report block prints the full path of the report.
  mkdir -p "$P/links"
  b=$(block learning-objectives '_REPORT_PATH="$_EXPORT_DIR/learning-objectives.html"')
  out=$(run "$P/links" "$b")
  want="Report link: $(cd "$P/links" && pwd -P)/.idstack/exports/untitled-course/learning-objectives.html"
  check "[$sh] a report block prints an absolute report link" \
    "printf '%s\n' \"\$out\" | grep -qxF \"\$want\""
```

- [ ] **Step 3: Run to verify failure**

Run: `./test/smoke-test.sh`
Expected: `433/455 passed, 22 failed` — the 21 new checks, plus `skill bash blocks work in bash and zsh` (smoke-test runs the zsh suite).
Run: `./test/test-skill-shell-zsh.sh`
Expected: `44/46 passed, 2 failed` (the new check, in each shell).

- [ ] **Step 4: Add the link line to the report blocks.** In each file, find the anchor line exactly and insert this line directly after it:

```bash
echo "Report link: $(pwd -P)/$_REPORT_PATH"
```

| File | Anchor line (line no.) |
|---|---|
| `skills/needs-analysis/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (340) |
| `skills/learning-objectives/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (331) |
| `skills/assessment-design/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (450) |
| `skills/course-builder/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (571) |
| `skills/course-quality-review/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (770) |
| `skills/course-import/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (822) |
| `skills/accessibility-review/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (307) |
| `skills/red-team/SKILL.md.tmpl` | `echo "Report path: $_REPORT_PATH"` (309) |
| `skills/course-export/SKILL.md.tmpl` | `echo "Course export folder: $_EXPORT_DIR"` (126) — this skill has no `Report path:` echo |

In `skills/pipeline/SKILL.md.tmpl`, directly after `echo "Dashboard: $_EXPORT_DIR/index.html"` (147), insert:

```bash
echo "Dashboard link: $(pwd -P)/$_EXPORT_DIR/index.html"
```

Do not add a dashboard line to the report blocks: only the pipeline rewrites the dashboard, so a link from another skill could point at an old one.

- [ ] **Step 5: Point each closing message at the link.** Make these exact replacements (each old text occurs once in its file):

| File:line | Old text | New text |
|---|---|---|
| `needs-analysis.tmpl:401` | ``- **Read this:** `.idstack/exports/<course-slug>/needs-analysis.html` — the branded HTML`` | ``- **Read this:** the path from the "Report link:" line — the branded HTML`` |
| `needs-analysis.tmpl:403` | `Open it in a web browser.` | `Click the path to open it.` |
| `learning-objectives.tmpl:412` | ``- **Read this:** `.idstack/exports/<course-slug>/learning-objectives.html` — the alignment`` | ``- **Read this:** the path from the "Report link:" line — the alignment`` |
| `learning-objectives.tmpl:414` | `Open it in a web browser.` | `Click the path to open it.` |
| `assessment-design.tmpl:588` | ``- **Read this:** `.idstack/exports/<course-slug>/assessment-design.html` — the assessment`` | ``- **Read this:** the path from the "Report link:" line — the assessment`` |
| `assessment-design.tmpl:590` | `Open it in a web browser.` | `Click the path to open it.` |
| `course-builder.tmpl:647` | ``- **Read this:** `.idstack/exports/<course-slug>/course-builder.html` — the build report`` | ``- **Read this:** the path from the "Report link:" line — the build report`` |
| `course-builder.tmpl:649` | `Open it in a web browser.` | `Click the path to open it.` |
| `course-import.tmpl:936` | ``- **Read this:** `.idstack/exports/<course-slug>/course-import.html` — the import report`` | ``- **Read this:** the path from the "Report link:" line — the import report`` |
| `course-import.tmpl:938` | `Open it in a web browser.` | `Click the path to open it.` |
| `accessibility-review.tmpl:388` | ``- **Read this:** `.idstack/exports/<course-slug>/accessibility-review.html` — the report`` | ``- **Read this:** the path from the "Report link:" line — the report`` |
| `accessibility-review.tmpl:390` | `Open it in a web browser.` | `Click the path to open it.` |
| `course-quality-review.tmpl:802` | ``report to `.idstack/exports/<course-slug>/course-quality-review.html`. The`` | ``report. Its path is on the "Report link:" line. The`` |
| `course-quality-review.tmpl:804` | `Open it in a web browser.` | `Click the path to open it.` |
| `pipeline.tmpl:193` | ``The course dashboard is at `.idstack/exports/<course-slug>/index.html`. Open it in a web browser to see the cross-cutting view.`` | ``The course dashboard is at the path from the "Dashboard link:" line. Click the path to see the cross-cutting view.`` |
| `course-export.tmpl` (`Run the merge, then confirm:`, near 1067) | `Run the merge, then confirm:` | `Run the merge, then confirm. Give the path from the "Report link:" line first:` |

In `skills/red-team/SKILL.md.tmpl` (the parent talks to the user; a sub-agent writes the report):

| Line | Old text | New text |
|---|---|---|
| 341 | ``- Path: the value of `$_REPORT_PATH` (e.g., `.idstack/exports/<course-slug>/red-team.html`)`` | ``- Path (for the manifest): the value of `$_REPORT_PATH`, a relative path (e.g., `.idstack/exports/<course-slug>/red-team.html`)`` and, on a new line after it, `- Link (for the user): the path from the "Report link:" line` |
| 351 | `top critical finding, and the report path.` | `top critical finding, and the Link that the orchestrator returned.` |
| 352 | `3. Mention: "The full HTML report is at the path above. Open it in a web browser to see all of the findings."` | `3. Mention: "Click the path to see all of the findings."` |
| 405 | `<set to the orchestrator-returned path — e.g.` | `<set to the Path that the orchestrator returned, not the Link — e.g.` |
| 440 | ``The report is at `.idstack/exports/<course-slug>/red-team.html`."`` | `The report is at <the Link that the orchestrator returned>."` |

- [ ] **Step 6: Add the preamble section.** In `templates/preamble.md`, insert directly before `## Preamble: Context Recovery`. Use form **L** unless Task 0 chose **P**.

Form **L** (Markdown link; default):

```markdown
## Preamble: Report Links

A skill that writes a report runs a block that prints a `Report link:` line.
The line gives the full path of the report. `/idstack:pipeline` and
`/idstack:start` print a `Dashboard link:` line for the course dashboard.

When you tell the user about a report or the dashboard, put the path from that
line in a Markdown link, on a separate line. Put angle brackets around the
path, because a folder name can have a space. For example:

[Open the report](</Users/ana/Courses/BIO 101/.idstack/exports/bio-101/course-import.html>)

In the Claude desktop app, the user clicks the link to open the file. Give only
a path from a `Report link:` or `Dashboard link:` line, or a link that a
sub-agent returns. Do not make up a path. If the skill stopped before it wrote
the report, do not give the path.

```

Form **P** (bare path): the same section, with the second paragraph and the example replaced by:

```markdown
When you tell the user about a report or the dashboard, put the path from that
line on a separate line, with no backticks. For example:

Report: /Users/ana/Courses/BIO-101/.idstack/exports/bio-101/course-import.html
```

- [ ] **Step 7: Check the new text against the writing standard**

```bash
python3 bin/idstack-ste-check --format markdown templates/preamble.md
```
Expected: no problem on the lines of the new section. If one is reported, rewrite that sentence and run again (maximum three times). Problems on other lines existed before; leave them.

- [ ] **Step 8: Regenerate and run the tests**

```bash
bin/idstack-gen-skills
./test/smoke-test.sh
./test/test-skill-shell-zsh.sh
```
Expected: smoke `455/455 passed, 0 failed`; zsh `46/46 passed`.

- [ ] **Step 9: Add the mutations** — in `test/mutation-test.sh`, after case 61b:

```bash
# 61c. A report block stops printing its full report link -> smoke-test must
# fail. The desktop user then has no link to click.
shell_mutation "a report block stops printing its absolute report link" \
  skills/learning-objectives/SKILL.md.tmpl 'echo "Report link: $(pwd -P)/$_REPORT_PATH"
' ''

# 61d. A closing message sends the user to a web browser again -> smoke-test
# must fail. That text names a relative path, and the model follows it over
# the preamble's Report Links rule.
shell_mutation "a closing message tells the user to open the report in a web browser" \
  skills/learning-objectives/SKILL.md.tmpl 'Click the path to open it.' 'Open it in a web browser.'
```

- [ ] **Step 10: Run the mutation suite** (background) — `./test/mutation-test.sh` → both new cases `GUARDED`, `NOT guarded: 0`, no `ERROR:`.

- [ ] **Step 11: Commit**

```bash
git add templates/preamble.md skills test/smoke-test.sh test/test-skill-shell-zsh.sh test/mutation-test.sh
git commit -m "feat(skills): give a clickable full path for each report and the dashboard

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The `/idstack:start` skill

**Files:**
- Create: `skills/start/SKILL.md.tmpl`, then generate `skills/start/SKILL.md`
- Modify: `templates/preamble.md:19-20` (Skill-tool line)
- Modify: `bin/idstack-doctor:27-29` and `:117` (after Task 1), `test/test-doctor.sh:51-53` (skill list)
- Test: `test/smoke-test.sh` (lines 37, 286, 296, 400)
- Test: `test/test-skill-shell-zsh.sh` (directly after the Task 2 block)
- Test: `test/mutation-test.sh`

**Interfaces:**
- Consumes: `idstack-doctor --quick` codes (Task 1); the `Report link:` / `Dashboard link:` formats and the "Report Links" preamble section (Task 2); the preamble's `MANIFEST_EXISTS` / `NO_MANIFEST` output.
- Produces: the user-invocable skill `/idstack:start` (Skill-tool name `idstack:start`). Its folder block prints `NOT_A_COURSE_FOLDER: <path>` or `COURSE_FOLDER: <path>`. Its dashboard block prints `Dashboard link: <path>`, or `NO_DASHBOARD` followed by one `Report link: <path>` per report.

- [ ] **Step 1: Write the failing smoke changes** in `test/smoke-test.sh`:
  - Line 37: append ` start` to the end of the `SKILLS=` value (before the closing `"`).
  - Line 286: in `BARE_SLASH_RE`, change `|pipeline|learn)` to `|pipeline|learn|start)`.
  - Line 400: change the case line to
    ```bash
      case "$skill" in course-builder|course-export|red-team) want=2 ;; start) want=0 ;; *) want=1 ;; esac
    ```
  - After line 296 (`check "pipeline invokes children with the idstack: namespace" ...`), insert:
    ```bash
    check "start hands off with the idstack: namespace" "grep -qF 'skill: \"idstack:course-import\"' '$IDSTACK_DIR/skills/start/SKILL.md.tmpl'"
    # start runs before any course work. A timeline event from it would become
    # LAST_SKILL and spoil every welcome-back and next-step line.
    check "start does not log to the timeline" "[ -f '$IDSTACK_DIR/skills/start/SKILL.md.tmpl' ] && ! grep -q 'idstack-timeline-log' '$IDSTACK_DIR/skills/start/SKILL.md.tmpl'"
    ```

- [ ] **Step 2: Write the failing bash/zsh checks** — in `test/test-skill-shell-zsh.sh`, directly after the Task 2 report-link block (still before `# Every preamble block ...`):

```bash
  # start: the setup check prints one machine-readable code.
  mkdir -p "$P/start"
  b=$(block start 'idstack-doctor" --quick')
  out=$(run "$P/start" "$b")
  check "[$sh] start setup check prints OK when python3 3.9 or later is present" \
    "printf '%s\n' \"\$out\" | grep -qx OK"

  # start: the folder check refuses the home folder, /, and the shared folders
  # a folder picker offers first; it accepts a course folder.
  mkdir -p "$HOME/Documents"
  b=$(block start 'NOT_A_COURSE_FOLDER')
  out=$(run "$HOME" "$b")
  check "[$sh] start refuses the home folder" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run / "$b")
  check "[$sh] start refuses /" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run "$HOME/Documents" "$b")
  check "[$sh] start refuses Documents" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run "$P/start" "$b")
  check "[$sh] start accepts a course folder" \
    "printf '%s' \"\$out\" | grep -q '^COURSE_FOLDER: '"

  # start: with no dashboard, the dashboard step lists each report instead.
  mkdir -p "$P/startdash/.idstack/exports/untitled-course"
  touch "$P/startdash/.idstack/exports/untitled-course/course-import.html"
  b=$(block start 'NO_DASHBOARD')
  out=$(run "$P/startdash" "$b")
  want="Report link: $(cd "$P/startdash" && pwd -P)/.idstack/exports/untitled-course/course-import.html"
  check "[$sh] start lists the report links when there is no dashboard" \
    "printf '%s\n' \"\$out\" | grep -qx NO_DASHBOARD && printf '%s\n' \"\$out\" | grep -qxF \"\$want\""
```

- [ ] **Step 3: Run to verify failure**

Run: `./test/smoke-test.sh`
Expected: 13 failed — `skills/start/SKILL.md reachable` and the other per-skill checks for `start`, the two new start checks, and `skill bash blocks work in bash and zsh`.
Run: `./test/test-skill-shell-zsh.sh`
Expected: the 12 new checks (6 per shell) FAIL.

- [ ] **Step 4: Create `skills/start/SKILL.md.tmpl`** with exactly this content:

````markdown
---
name: start
description: |
  The first idstack skill to run in a course folder. It makes sure that idstack
  can run, makes sure that the session is in a course folder, and then starts
  the correct skill. Use when the user is new to idstack, uses the Claude
  desktop app, or asks "where do I start", "help me start" or "set up idstack". (idstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Skill
  - AskUserQuestion
---

{{PREAMBLE}}

# Start — First Steps with idstack

You are the idstack guide. Your job is to make sure that idstack can run in this
folder, and then to start the correct skill for the user. Many users of this
skill do not use a terminal. Use short sentences. Do not tell the user to type a
command in a terminal.

Do Step 1 and Step 2 before you act on the result of the Project Manifest check
in the preamble.

The steps of this skill do not write the manifest, a report or the timeline.
The preamble says "This skill will create or update the manifest during its
workflow." That line is not true for this skill. The preamble can update an old
manifest to the current schema. That is correct.

In this skill, do not give the NO_PROFILE note. If the Update Check shows
UPDATE_AVAILABLE, tell the user that a new version of idstack is available. Do
not give the update command.

When Step 4 starts a different skill with the Skill tool, the limits of this
skill stop. Do all of the steps of that skill, including the files that it
writes and its timeline entry.

## Step 1: Setup check

```bash
{{IDSTACK_RESOLVE}}
if [ -z "$_IDSTACK" ]; then echo "IDSTACK_NOT_FOUND"; else "$_IDSTACK/bin/idstack-doctor" --quick; fi
```

- **OK:** Go to Step 2. Do not tell the user about this check.
- **PYTHON_STUB:** The Mac does not have the free Apple developer tools, and
  idstack needs them for python3. Run this command:

  ```bash
  xcode-select --install >/dev/null 2>&1 || true
  ```

  Then tell the user: "idstack needs a free tool from Apple. A macOS window
  opens now. Click **Install**, and wait until the installation is complete.
  Then type `/idstack:start` again. If you cannot install the Apple tool, get
  the macOS installer from https://www.python.org/downloads/ and open it. Then
  close the Claude app, open it again and type `/idstack:start` again." STOP.
- **PYTHON_MISSING** or **PYTHON_OLD:** Tell the user: "idstack needs Python 3.9
  or a later version. Get the macOS installer from
  https://www.python.org/downloads/ and open it. When the installation is
  complete, close the Claude app and open it again. Then type `/idstack:start`
  again." STOP.
- **IDSTACK_NOT_FOUND:** Tell the user: "idstack cannot find its files. Install
  idstack again. Then type `/idstack:start` again." STOP.

## Step 2: Folder check

idstack keeps the files for one course in one folder.

```bash
_HERE=$(pwd -P)
_HOME_DIR=$(cd "$HOME" 2>/dev/null && pwd -P)
case "$_HERE" in
  /|"$_HOME_DIR"|"$_HOME_DIR/Documents"|"$_HOME_DIR/Desktop"|"$_HOME_DIR/Downloads") echo "NOT_A_COURSE_FOLDER: $_HERE" ;;
  *) echo "COURSE_FOLDER: $_HERE" ;;
esac
```

- **COURSE_FOLDER:** Go to Step 3.
- **NOT_A_COURSE_FOLDER:** Tell the user: "idstack keeps the files for one
  course in one folder. This session is in your home folder or in a shared
  folder, for example Documents. Make a new folder for the course, for example
  in Documents. Start a new session, and use the folder button below the
  message box to select the new folder. Then type `/idstack:start` again." STOP.

## Step 3: Find the course

Use the result of the Project Manifest check in the preamble.

**If NO_MANIFEST:** Tell the user, in two sentences: "This folder is now your
course folder. idstack keeps its notes in a hidden `.idstack` folder here, and
gives you a link to each report that it writes." Then ask with AskUserQuestion:
"How do you want to start?"

- **Import a course that I have** — "From Canvas, a course export file, a SCORM
  package or a document." Go to Step 4 with `idstack:course-import`.
- **Design a new course** — "Start with a needs analysis." Go to Step 4 with
  `idstack:needs-analysis`.

**If MANIFEST_EXISTS and the JSON is not valid:** Tell the user that the file
`.idstack/project.json` in this folder is damaged, and give the parse error in
one sentence. Ask with AskUserQuestion: "Do you want idstack to repair the
file?"

- **Repair the file** — "Correct only the JSON syntax. Keep all of the data."
  Correct only the JSON syntax and keep all of the data. This is the only file
  that this skill can change. Then continue with the next paragraph.
- **Stop** — "Do not change the file." STOP.

**If MANIFEST_EXISTS and the JSON is valid:** give the welcome-back message from
the Context Recovery section of the preamble. Then ask with AskUserQuestion:
"What do you want to do?"

- **Continue the pipeline** — "Run the next stages of the course design." Go to
  Step 4 with `idstack:pipeline`.
- **Open the course dashboard** — "See all of the reports for this course." Go
  to Step 5.
- **Run one skill** — "Select one idstack skill." Go to Step 6.

## Step 4: Start the skill

Say: "/idstack:<name> starts." Then invoke the skill with the `Skill` tool and
the plugin-namespaced name. Use one of these:

- `skill: "idstack:course-import"`
- `skill: "idstack:needs-analysis"`
- `skill: "idstack:pipeline"`
- for Step 6, `skill: "idstack:<name>"` with the name that the user selected

A bare name, for example `"course-import"`, does not resolve in Claude Code. If
the `Skill` tool fails, tell the user: "Type `/idstack:<name>` to start the next
step." Then STOP.

## Step 5: Open the course dashboard

```bash
{{IDSTACK_RESOLVE}}
_SLUG=$("$_IDSTACK/bin/idstack-slugify" --from-manifest 2>/dev/null || echo "untitled-course")
_EXPORT_DIR=".idstack/exports/$_SLUG"
if [ -f "$_EXPORT_DIR/index.html" ]; then
  echo "Dashboard link: $(pwd -P)/$_EXPORT_DIR/index.html"
else
  echo "NO_DASHBOARD"
  find "$_EXPORT_DIR" -maxdepth 1 -name '*.html' 2>/dev/null | sort | while IFS= read -r f; do echo "Report link: $(pwd -P)/$f"; done
fi
```

- **Dashboard link:** give the path as the "Report Links" section of the
  preamble tells you. Then STOP.
- **NO_DASHBOARD:** Tell the user: "This course has no dashboard. Type
  `/idstack:pipeline` to make the dashboard." Then give each `Report link:` path
  as the "Report Links" section of the preamble tells you. Then STOP.

## Step 6: Run one skill

Write this numbered list in chat, and ask the user to type a number:

1. `/idstack:course-import` — import a course that you have
2. `/idstack:needs-analysis` — find what the learners and the organization need
3. `/idstack:learning-objectives` — write and align learning objectives
4. `/idstack:assessment-design` — design assessments, rubrics and feedback
5. `/idstack:course-builder` — make the course content
6. `/idstack:course-quality-review` — examine the course quality
7. `/idstack:accessibility-review` — examine accessibility (WCAG and UDL)
8. `/idstack:red-team` — find problems before the course starts
9. `/idstack:course-export` — make a package for the LMS
10. `/idstack:pipeline` — run the 8 design stages in sequence
11. `/idstack:learn` — see what idstack learned about your courses

Then go to Step 4 with the skill that the user selected.

## Important Rules

- Ask one question at a time.
- In Steps 1 to 6, do not write a file, a manifest section or a timeline event.
  The one exception is the repair in Step 3, with the user's yes. This rule
  does not apply to the skill that Step 4 starts.
- Stop at each problem in Step 1 or Step 2. The user fixes the problem and
  types `/idstack:start` again.
````

- [ ] **Step 5: Update the preamble's Skill-tool line.** In `templates/preamble.md`, replace:

```markdown
- **Skill (cross-skill invocation)** — used only by `/idstack:pipeline`, which invokes each
  child skill in-process via the `Skill` tool.
```

with:

```markdown
- **Skill (cross-skill invocation)** — used by `/idstack:pipeline`, which invokes each
  child skill in-process through the `Skill` tool. `/idstack:start` also uses it to start
  the first skill for the user.
```

- [ ] **Step 6: Add `start` to doctor's skill list and its test copy.**
  - `bin/idstack-doctor` (the `SKILLS=` lines, 27-29 after Task 1) and `test/test-doctor.sh` lines 51-53: change the last line of the `SKILLS=` value from `pipeline learn"` to `pipeline learn start"`.
  - `bin/idstack-doctor` (117 after Task 1): `echo "  found all 11 SKILL.md files"` → `echo "  found all 12 SKILL.md files"`.

- [ ] **Step 7: Generate and check the writing standard**

```bash
bin/idstack-gen-skills
python3 bin/idstack-ste-check --format markdown skills/start/SKILL.md.tmpl
python3 bin/idstack-ste-check --format markdown templates/preamble.md
```
Expected: generation prints `skills/start/SKILL.md` with no `ERROR`. The first check prints `idstack-ste-check: no problems in 1 file(s)`. The second shows no problem on the Skill-tool lines (19-21). Never add the literal string `"$_IDSTACK/bin/idstack-ste-check"` to the start template: the check-count map expects zero.

- [ ] **Step 8: Run the tests**

```bash
./test/smoke-test.sh
./test/test-doctor.sh
./test/test-skill-shell-zsh.sh
```
Expected: all pass (`0 failed`; doctor `18/18`; zsh `58/58`).

- [ ] **Step 9: Add the mutations** — in `test/mutation-test.sh`, after case 61d:

```bash
# 61e. /idstack:start stops refusing the home folder -> smoke-test must fail
# (through test-skill-shell-zsh). A desktop session starts in the home folder,
# and the next skill would write .idstack/ there.
shell_mutation "start no longer refuses the home folder" \
  skills/start/SKILL.md.tmpl '/|"$_HOME_DIR"|"$_HOME_DIR/Documents"' '/|"$_HOME_DIR/Documents"'

# 61f. /idstack:start's no-write rule outlives the handoff again -> smoke-test
# must fail. The child skill would then not save its manifest or report.
shell_mutation "start does not release its limits at the handoff" \
  skills/start/SKILL.md.tmpl 'When Step 4 starts a different skill with the Skill tool, the limits of this
skill stop.' ''
```

and in `test/smoke-test.sh`, directly after the `start does not log to the timeline` check from Step 1, add the check that 61f guards:

```bash
check "start releases its limits when it hands off" "grep -qF 'the limits of this' '$IDSTACK_DIR/skills/start/SKILL.md.tmpl'"
```

Run `./test/smoke-test.sh` again → `0 failed`.

- [ ] **Step 10: Run the mutation suite** (background) — `./test/mutation-test.sh` → `GUARDED` for 61e and 61f, `NOT guarded: 0`, no `ERROR:`.

- [ ] **Step 11: Commit**

```bash
git add skills templates/preamble.md bin/idstack-doctor test/smoke-test.sh test/test-doctor.sh test/test-skill-shell-zsh.sh test/mutation-test.sh
git commit -m "feat: add /idstack:start, the first-run guide

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Skill count and `start` on every listing surface

**Files:**
- Modify: `.claude-plugin/plugin.json:4`, `.claude-plugin/marketplace.json:3`, `DESIGN.md:7`, `setup:82-95`, `README.md` (93, 164-177, the table after 240, 328, 487), `docs/index.html` (1154-1155, 1203, 1295, 1303), `CLAUDE.md` (17, 89-99, the routing list)

**Interfaces:** none (text only).

- [ ] **Step 1: Manifests and DESIGN.md**
  - `.claude-plugin/plugin.json:4` and `.claude-plugin/marketplace.json:3`: `11 skills backed` → `12 skills backed` (the second `11`, "11 domains", stays).
  - `DESIGN.md:7`: `Runs in Claude Code. 11 skills,` → `Runs in Claude Code. 12 skills,`.

- [ ] **Step 2: `setup` closing message.** Replace the lines from `echo "  To use a skill, run /idstack:<skill>"` to the last `All skills:` line (82-95) with:

```bash
echo "  To use a skill, run /idstack:<skill>"
echo ""
echo "  If you do not know where to start:"
echo "    /idstack:start"
echo ""
echo "  If you have a course, import it and examine it:"
echo "    /idstack:course-import -> /idstack:course-quality-review"
echo ""
echo "  To start a new course:"
echo "    /idstack:needs-analysis"
echo ""
echo "  Run the full pipeline:"
echo "    /idstack:pipeline"
echo ""
echo "  All skills: start, needs-analysis, learning-objectives, assessment-design,"
echo "    course-builder, course-quality-review, accessibility-review,"
echo "    red-team, course-export, course-import, pipeline, learn"
```

Mirror it in the README "You should see:" block (README.md:164-177): after `  To use a skill, run /idstack:<skill>` and its blank line, insert `  If you do not know where to start:`, `    /idstack:start` and a blank line; change `  All skills: needs-analysis,` to `  All skills: start, needs-analysis,`.

- [ ] **Step 3: README counts and table**
  - README.md:93: replace ``(`course-import` branches in for existing courses; `learn` is a separate cross-project memory utility — those two sit outside the linear chain, which is why pipeline runs 8 of the 11 skills)`` with ``(`course-import` branches in for existing courses, `learn` is a separate cross-project memory utility, and `start` is the first-run guide. These three sit outside the linear chain, which is why pipeline runs 8 of the 12 skills)``.
  - README.md:328: `└─▶ 11 skills, invoked as /idstack:<skill>` → `└─▶ 12 skills, invoked as /idstack:<skill>`.
  - README.md:487: `all 11 SKILL.md files` → `all 12 SKILL.md files`.
  - In the "Your design team" table, insert a new first data row directly after the `|-------|...` separator line:
    ```markdown
    | `/idstack:start` | **Guide** | The first skill to run in a course folder. It makes sure that idstack can run, then starts the correct skill: course import, needs analysis or the pipeline. It writes no report. |
    ```

- [ ] **Step 4: Landing page**
  - `docs/index.html:1154`: `Eleven skills. Pipeline optional.` → `Twelve skills. Pipeline optional.`
  - `:1155`: `standalone utilities handle course import and institutional memory` → `standalone utilities handle first-run setup, course import and institutional memory`.
  - In `<div class="pipeline-aside-row" ...>` (1203), insert as the first child:
    ```html
          <div class="pipeline-aside">
            <span class="aside-tag">start</span>
            <span>Checks that idstack can run in a course folder, then starts the correct skill. The first skill to run.</span>
          </div>
    ```
  - `Full 11-Skill Pipeline` → `Full 12-Skill Pipeline` (1295 before the aside insert); `installs all 11 skills` → `installs all 12 skills` (1303 before the insert).
  - Do not change "11 domains", "11 research domains", or the dated v3.4.0.0 note "across all 11 skills".

- [ ] **Step 5: CLAUDE.md**
  - After line 17 (`bin/idstack-doctor   # Diagnose plugin install ...`), add:
    ```
    bin/idstack-doctor --quick                 # One python3 code for /idstack:start: OK, PYTHON_MISSING, PYTHON_OLD or PYTHON_STUB
    ```
  - `11 skills total.` → `12 skills total.`, and change ``and `/idstack:learn` is a cross-project memory utility that runs outside the pipeline.`` to ```/idstack:learn` is a cross-project memory utility that runs outside the pipeline, and `/idstack:start` is the first-run guide that checks the setup and starts the correct skill.``
  - In the diagram, after `/idstack:learn (manage cross-project learnings)`, add a blank line and `/idstack:start (first-run guide: setup check, folder check, then hands off)`.
  - In "## Skill routing", add as the first list item: ``- First run, "where do I start", or a Claude desktop app user → `/idstack:start` ``.

- [ ] **Step 6: Verify**

```bash
./test/smoke-test.sh
python3 test/check-doc-accuracy.py .
node test/test-responsive-landing.js
node test/test-rendered-landing.js
git grep -nE '(^|[^0-9])11 skills|Eleven skills|11-Skill|all 11 SKILL' -- ':!CHANGELOG.md' ':!docs/superpowers'
```
Expected: suites pass. The grep prints exactly one line, `docs/index.html:1352:` (the dated v3.4.0.0 note). (`\b` does not work in `git grep -E` on macOS; the `(^|[^0-9])` form does.)

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin DESIGN.md setup README.md docs/index.html CLAUDE.md
git commit -m "docs: list /idstack:start and count 12 skills

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Desktop guide (README and landing page)

**Files:**
- Modify: `README.md` (Quick start 15-17; new section before `### Chrome Extension (No-Terminal Mode)` at 185; FAQ answer at 440)
- Modify: `docs/index.html` (new install card between the Chrome card's closing `</div>` at 1294 and the Claude Code Plugin card at 1296; line 1313)

**Interfaces:** Consumes the Task 0 install-path decision (text **A** or **B**).

- [ ] **Step 1: README Quick start.** Replace lines 15-17 with:

```markdown
1. Install idstack (30 seconds, see below). No terminal? Use the [Claude desktop app](#claude-desktop-app-no-terminal).
2. Run `/idstack:start` in a folder for your course. It checks your setup and starts the correct skill.
3. If you imported a course, run `/idstack:course-quality-review` to see what the evidence says.
```

- [ ] **Step 2: README desktop section.** Insert directly before `### Chrome Extension (No-Terminal Mode)`:

Install text **A** (Task 0: `/plugin` accepted, or skipped):

````markdown
### Claude desktop app (no terminal)

You can use idstack in the Code tab of the [Claude desktop app](https://claude.ai/download) on a Mac. You do not need a terminal.

1. Open the Claude desktop app and select the **Code** tab.
2. Make a folder for your course, for example `Documents/BIO-101`. Start a new session and select that folder with the folder button below the message box.
3. Paste this line in the message box and press Return:
   ```
   /plugin marketplace add savvides/idstack
   ```
4. Click **+** next to the message box, then **Add plugins**. Select **idstack** and install it.
5. Type `/idstack:start` and press Return. idstack checks your setup, then asks how you want to start.

Each skill gives you a link to its report. Click the link to open the report in the app.

**macOS asks you to install developer tools?** idstack needs python3. Click **Install** in the macOS window. When the installation is complete, type `/idstack:start` again.
````

Install text **B** (Task 0: `/plugin` unknown): the same section, with steps 3-4 replaced by:

````markdown
3. Paste this request in the message box and press Return:
   > Install idstack: run `git clone https://github.com/savvides/idstack.git ~/idstack && cd ~/idstack && ./setup`, then tell me that it is installed.
4. When Claude says that idstack is installed, close the Claude app and open it again.
````

- [ ] **Step 3: README FAQ.** Replace the answer under `**Do I need to know how to code?**` (line 440) with:

```markdown
No. You interact with idstack through conversation in Claude Code. It is a chat interface. In the [Claude desktop app](#claude-desktop-app-no-terminal) you do not need a terminal at all.
```

- [ ] **Step 4: Landing install card.** In `docs/index.html`, insert a new card between the Chrome card's closing `</div>` (1294) and `<div class="install-track-card">` of the Claude Code Plugin card (1296). For install text **A**:

```html
        <div class="install-track-card">
          <div class="install-track-header">
            <h3>Claude Desktop App</h3>
            <span class="track-badge">No Terminal</span>
          </div>
          <p class="install-prose">In the Code tab of the Claude desktop app, select a folder for your course. Then paste this line in the message box:</p>
          <div class="install-block" role="group" aria-label="Desktop install command">
            <span class="prompt" aria-hidden="true">›</span>
            <code id="install-cmd-3">/plugin marketplace add savvides/idstack</code>
            <button class="copy-btn" type="button" data-copy-target="install-cmd-3" aria-label="Copy desktop install command">Copy</button>
          </div>
          <p class="install-prose">Click <strong>+</strong>, then <strong>Add plugins</strong>, and install idstack. Then type <code>/idstack:start</code>. Each skill gives you a link to open its report in the app.</p>
        </div>

```

For install text **B**, the `<code>` content is `Install idstack: run git clone https://github.com/savvides/idstack.git ~/idstack &amp;&amp; cd ~/idstack &amp;&amp; ./setup` and the last paragraph is `When Claude says that idstack is installed, close the app and open it again. Then type <code>/idstack:start</code>.`

Also change `When Claude Code starts, run <code>/idstack:pipeline</code>.` (1313) → `When Claude Code starts, run <code>/idstack:start</code>.`

- [ ] **Step 5: Writing standard and landing tests**

```bash
python3 bin/idstack-ste-check --format markdown README.md
python3 bin/idstack-ste-check docs/index.html
node test/test-responsive-landing.js
node test/test-rendered-landing.js
./test/smoke-test.sh
python3 test/check-doc-accuracy.py .
```
Expected: no checker problem in the new text (a problem reported on the line just above a changed line can come from the new paragraph); all suites pass; `test-rendered-landing.js` reports no sideways scroll at 320px (the command sits in `.install-block code`, which scrolls itself).

- [ ] **Step 6: Commit**

```bash
git add README.md docs/index.html
git commit -m "docs: add the Claude desktop app install path

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Release v3.10.0.0

**Files:** `VERSION`, `.claude-plugin/plugin.json:3`, `CHANGELOG.md` (top), `README.md:3`, `docs/index.html` (45, 1033, new release card before the first `<article class="release-card">`, about 1341), `ROADMAP.md:5`, `CLAUDE.md` (counts 34-45, release wording 72).

- [ ] **Step 1: Version strings**
  - `VERSION`: `3.10.0.0`
  - `.claude-plugin/plugin.json:3`: `"version": "3.10.0.0",`
  - `README.md:3`: `(v3.9.0.0)` → `(v3.10.0.0)`
  - `docs/index.html:45`: `"softwareVersion": "3.10.0.0",`; `:1033`: `v3.10.0.0 · Claude Code &amp; Chrome Extension`

- [ ] **Step 2: CHANGELOG.** Insert after `# Changelog` and its blank line:

```markdown
## v3.10.0.0 (2026-11-01)

This release lets you use idstack in the Claude desktop app with no terminal. A new skill, `/idstack:start`, checks your setup and starts the correct skill. Each skill gives you a link that opens its report in the app.

To update: `cd` into your idstack clone, then `git pull && ./setup`. For a marketplace install, run `claude plugin update idstack@idstack`.

### Added — `/idstack:start`

- **`/idstack:start` is the first skill to run in a course folder.** It makes sure that python3 3.9 or a later version is available. It stops if the session is in your home folder or a shared folder. Then it asks if you want to import a course or design a new one.
- **`bin/idstack-doctor --quick` prints one python3 code.** The codes are `OK`, `PYTHON_MISSING`, `PYTHON_OLD` and `PYTHON_STUB`. `PYTHON_STUB` tells the macOS python3 stub apart from a python3 that is too old.

### Added — report links

- **Each skill gives the full path of its report.** In the Claude desktop app, you click the link to open the report. The pipeline gives a link to the course dashboard.

### Added — Claude desktop app guide

- **README and idstack.org show how to install idstack in the Claude desktop app.**

### Tests

- `test/test-doctor.sh` tests each `--quick` code with fake `python3`, `uname` and `xcode-select` commands. `test/test-skill-shell-zsh.sh` runs the new `/idstack:start` blocks and a report-link block in bash and zsh. `test/mutation-test.sh` has cases 61a–61f.
```

- [ ] **Step 3: ROADMAP.** Insert after `## Just shipped` and its blank line:

```markdown
### idstack in the Claude desktop app & `/idstack:start` (v3.10.0.0)
- **You can use idstack with no terminal.** Install it in the Code tab of the Claude desktop app, then type `/idstack:start`.
- **`/idstack:start` checks your setup and starts the correct skill.** It finds the macOS python3 stub and a session in your home folder before they cause a problem.
- **Each skill gives you a link to its report.** Click the link to open the report in the app.

```

- [ ] **Step 4: Landing release card.** In `docs/index.html`, insert directly before the first `<article class="release-card">`:

```html
      <article class="release-card">
        <p class="release-meta">November 1, 2026 · v3.10.0.0</p>
        <h3>idstack in the Claude desktop app.</h3>
        <p>Install idstack in the Code tab of the Claude desktop app, then type <code>/idstack:start</code>. It checks your setup and starts the correct skill. Each skill gives you a link that opens its report in the app.</p>
      </article>
```

- [ ] **Step 5: CLAUDE.md release wording.** `plus a 3-part \`softwareVersion\`` → `plus the same 4-part \`softwareVersion\`` (line 72 after Task 4).

- [ ] **Step 6: Run every suite and record the real counts**

```bash
./test/smoke-test.sh
./test/integration-test.sh
./test/test-setup.sh
./test/test-doctor.sh
./test/test-status.sh
./test/test-skill-shell-zsh.sh
python3 test/check-doc-accuracy.py .
python3 test/check-citation-tiers.py .
python3 test/check-evidence-cards.py .
python3 bin/idstack-ste-check --format markdown CHANGELOG.md ROADMAP.md
./test/mutation-test.sh
```
Expected: all pass; mutation suite `NOT guarded: 0`, no `ERROR:`; no checker problem in the new CHANGELOG and ROADMAP text. Update the hand-kept counts in `CLAUDE.md` (34-45) from these runs. Expected values: smoke-test `473` (was 434), `test-doctor.sh` `18` (was 12), `test-skill-shell-zsh.sh` `58` (was 44). Write the numbers the runs print, not these.

- [ ] **Step 7: Commit**

```bash
git add VERSION .claude-plugin/plugin.json CHANGELOG.md README.md docs/index.html ROADMAP.md CLAUDE.md
git commit -m "chore: release v3.10.0.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Open the deferred issues**

```bash
gh issue create --title "List idstack in the official Anthropic plugin directory" --label enhancement,backlog --body "So it shows in the Claude desktop app's Browse plugins with no marketplace-add step. Follow-up to the v3.10.0.0 desktop on-ramp."
gh issue create --title "Claude desktop on-ramp for Windows" --label enhancement,backlog --body "/idstack:start's python3 stub detection is Mac-only, and the desktop guide covers macOS. Follow-up to v3.10.0.0."
```

---

### Task 7: Manual journey and screenshots (USER-ONLY)

> **A subagent must not do this task or make up its results.** The controller asks the user and records what they see.

**Files:**
- Create: `docs/images/desktop-plugins.png`, `docs/images/desktop-start.png`, `docs/images/desktop-report-link.png`
- Modify: `README.md` (the desktop section from Task 5)

- [ ] **Step 1: The user runs the journey** in the Claude desktop app with a new, empty course folder whose name has a space, for example `Documents/Intro Bio`: install (Task 5 text) → `/idstack:start` → "Import a course that I have" → import a small `.imscc` → click the report link the skill gives. If Task 0 was skipped, this run also settles both Task 0 questions. If the link does not open, or the `/plugin` line is unknown, go back and apply the other variant in Task 2 Step 6 or Task 5, and run that task's tests again.

- [ ] **Step 2: The user takes three screenshots** (⌘⇧4, then Space, then click the window) and saves them as: the **Add plugins** dialog → `docs/images/desktop-plugins.png`; the `/idstack:start` question → `docs/images/desktop-start.png`; a report open from its link → `docs/images/desktop-report-link.png`. Keep each under 400 KB.

- [ ] **Step 3: Add the screenshots to the README desktop section** — after step 4 of the list, add `![The Add plugins dialog in the Claude desktop app](docs/images/desktop-plugins.png)`; after step 5, add `![/idstack:start asks how you want to start](docs/images/desktop-start.png)`; after "Each skill gives you a link…", add `![A report open in the Claude desktop app](docs/images/desktop-report-link.png)`.

- [ ] **Step 4: Verify and commit**

```bash
./test/smoke-test.sh
python3 test/check-doc-accuracy.py .
git add docs/images README.md
git commit -m "docs: add Claude desktop app screenshots

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Remove the spec and plan** (they go stale once shipped, as in commit 04899de; GitHub Issues is the tracker)

```bash
git rm docs/superpowers/specs/2026-11-01-claude-desktop-onramp-design.md docs/superpowers/plans/2026-11-01-claude-desktop-onramp.md
git commit -m "chore: remove the shipped desktop on-ramp spec and plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Known limitations

- The `PYTHON_STUB` path cannot be run on a Mac that already has the Command Line Tools; it is covered by fakes in `test/test-doctor.sh` only.
- No automated test proves that the desktop app opens a clicked link, or that the model follows the Report Links rule. Task 0 and Task 7 check it by hand.
- The handoff from `/idstack:start` to a child skill is checked by text (smoke-test and mutation 61f), not by running a model.
- If Task 0 shows that `/plugin` is unknown, install text B needs `claude` on the PATH of the desktop app's shell, as `./setup` does today.
- The full mutation suite takes about 2.5 hours.
