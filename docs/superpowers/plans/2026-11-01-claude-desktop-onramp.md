# Claude Desktop On-Ramp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an instructional designer who never uses a terminal install and use idstack through the Claude desktop app's Code tab on a Mac.

**Architecture:** No new app. A new `/idstack:start` skill is the front door: it runs a new `bin/idstack-doctor --quick` setup check, refuses a non-course folder, reads the manifest state that the preamble already gives it, and hands off with the Skill tool. Every report-writing skill prints an absolute `Report link:` line so a desktop user clicks to open the report. README and the landing page gain a desktop install path.

**Tech Stack:** bash (3.2-compatible, also run under zsh), python3 ≥ 3.9, Markdown skill templates rendered by `bin/idstack-gen-skills`, static HTML landing page.

**Spec:** `docs/superpowers/specs/2026-11-01-claude-desktop-onramp-design.md` (amended after recon).

## Global Constraints

- All user-facing text (skill chat, CLI output, README, landing page) follows ASD-STE100 per `templates/preamble.md`. Never write "consider", "may", "should" or "suggest" in idstack's voice.
- Write every skill command in namespaced form, `/idstack:<name>`. A bare `/start` fails smoke-test once `start` is in `BARE_SLASH_RE`.
- Edit `skills/*/SKILL.md.tmpl` and `templates/preamble.md`, never a generated `SKILL.md`. After any template edit, run `bin/idstack-gen-skills`.
- Bash in skill templates and `bin/` must run in bash 3.2 and zsh (`-f`): no `for x in $VAR`, no bare `ls *.ext` globs, no GNU-only `head -n -N`.
- Python that skills or the preamble run must parse on Python 3.9.
- Test suites source `test/test-helper.sh` and use `check`. Never add a local `PASS=0` / `FAIL=0` / `TOTAL=0`.
- Before you change any existing line of text, run `grep -nF '<the old text>' test/mutation-test.sh`. If a mutation anchors on it, update that anchor in the same commit.
- Do not change the `.idstack/` layout, the manifest schema (`1.4`), or the relative `report_path` values written to the manifest.
- `/idstack:start` writes no file, no manifest section and no timeline event.
- Version: `3.10.0.0`. `softwareVersion` in `docs/index.html` is the full 4-part value.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `bin/idstack-doctor` | Modify | Argument parsing; `--quick` mode; skill list gains `start` |
| `test/test-doctor.sh` | Modify | `--quick` cases with fake `python3`/`uname`/`xcode-select`; skill list copy |
| `templates/preamble.md` | Modify | New "Report Links" section; Skill-tool line names `/idstack:start` |
| `skills/{needs-analysis,learning-objectives,assessment-design,course-builder,course-quality-review,course-import,course-export,accessibility-review,red-team}/SKILL.md.tmpl` | Modify | Print `Report link:` / `Dashboard link:` |
| `skills/pipeline/SKILL.md.tmpl` | Modify | Print `Dashboard link:` |
| `skills/start/SKILL.md.tmpl` | Create | The `/idstack:start` workflow |
| `skills/*/SKILL.md` | Regenerate | Output of `bin/idstack-gen-skills` |
| `test/smoke-test.sh` | Modify | Register `start`; link-line checks; handoff and no-timeline checks |
| `test/test-skill-shell-zsh.sh` | Modify | Run the new blocks in bash and zsh |
| `test/mutation-test.sh` | Modify | Cases 61a–61d |
| `setup`, `README.md`, `docs/index.html`, `DESIGN.md`, `CLAUDE.md`, `.claude-plugin/*.json` | Modify | Skill count 12, `start` listed, desktop guide, release |
| `VERSION`, `CHANGELOG.md`, `ROADMAP.md` | Modify | Release v3.10.0.0 |

---

### Task 0: Hand checks in the Claude desktop app (USER-ONLY)

> **A subagent must not do this task or make up its results.** The controller asks the user to do it and records the answers. If the user skips it, use the defaults below and repeat the checks in Task 7.

**Files:** none (the answers are recorded in the Task 2 and Task 5 choices).

- [ ] **Step 1: Make a probe page**

```bash
mkdir -p .onramp-probe/exports
cat > .onramp-probe/exports/probe.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>idstack probe</title></head>
<body style="font-family:Georgia,serif;padding:2rem"><h1 style="color:#8a3b12">Rendered ✓</h1></body></html>
EOF
echo "$(pwd -P)/.onramp-probe/exports/probe.html"
```

- [ ] **Step 2: Ask the user to click three forms of the printed path in the desktop chat**: (A) the bare path, (B) the path in backticks, (C) a Markdown link `[probe.html](<path>)`. Record which ones open the page rendered.

- [ ] **Step 3: Ask the user to open a new Code-tab session and type `/plugin marketplace add savvides/idstack`.** Record "accepted" (including "already added") or "unknown command".

- [ ] **Step 4: Remove the probe** — `rm -rf .onramp-probe`

- [ ] **Step 5: Record the decisions**
  - **Link form:** if A rendered, use form **P** (bare path) in Task 2. If only C rendered, use form **L** (Markdown link). If the user skipped, use **P** (the documented behavior: "clicking an HTML path in chat opens it").
  - **Install path:** if accepted, use install text **A** in Task 5. If unknown, use install text **B**. If skipped, use **A** and repeat the check in Task 7.

---

### Task 1: `bin/idstack-doctor --quick`

**Files:**
- Modify: `bin/idstack-doctor:1-28`
- Test: `test/test-doctor.sh` (insert before the `# --- writing standard (ASD-STE100) ---` block at line 157)
- Test: `test/mutation-test.sh` (insert before the footer `echo ""` / `echo "guarded: ..."` at the end)

**Interfaces:**
- Produces: `idstack-doctor --quick` prints exactly one line, one of `OK`, `PYTHON_MISSING`, `PYTHON_OLD`, `PYTHON_STUB`. Exit 0 for `OK`, 1 for the others. An unknown argument prints `ERROR: unknown argument: <arg>` to stderr and exits 2. Task 3 calls this.

- [ ] **Step 1: Write the failing tests** — insert in `test/test-doctor.sh` directly before the line `# --- writing standard (ASD-STE100) ---`:

```bash
# --- --quick: one machine-readable code for /idstack:start ---
# The order is the point. A working python3 wins over a failing xcode-select,
# because a python.org install leaves the Command Line Tools absent; a stub
# check that ran first would block that user for ever.
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
check "--quick prints OK when python3 is 3.9 or later" "'$DOCTOR_CMD' --quick" 0 "^OK$"

fake_cmd uname 'echo Darwin'
fake_cmd xcode-select 'exit 2'
check "--quick prints OK on a Mac with python.org python3 and no developer tools" "'$DOCTOR_CMD' --quick" 0 "^OK$"

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
Expected: the six new checks FAIL (doctor ignores `--quick` today, runs the full report and exits 0), and the old 12 PASS.

- [ ] **Step 3: Implement** — in `bin/idstack-doctor`, replace the usage comment (lines 7-10):

```bash
# Usage:
#   idstack-doctor           full diagnosis
#   idstack-doctor --quick   one code for /idstack:start: OK, PYTHON_MISSING,
#                            PYTHON_OLD or PYTHON_STUB
#
# Exit code: 0 if all green (--quick: OK), 1 if any problem is detected,
# 2 for an unknown argument.
```

Then insert this directly before the line `echo "idstack doctor"` (after `SKILLS=...`):

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
Expected: `18/18 passed` (12 old + 6 new). If the count differs, read the FAIL lines; do not edit the expectation to match.

- [ ] **Step 5: Add mutations** — insert in `test/mutation-test.sh` directly before the footer `echo ""` that precedes `echo "guarded: $pass ...`:

```bash
# 61a. doctor --quick checks for the macOS stub before the python3 version ->
# test-doctor must fail. A python.org python3 on a Mac with no Command Line
# Tools would then be told to install the developer tools for ever.
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

- [ ] **Step 6: Run the mutation suite**

Run: `./test/mutation-test.sh`
Expected: the last lines include `GUARDED: doctor --quick reports the stub before it tries python3` and `GUARDED: doctor --quick no longer reports the macOS stub`, then `NOT guarded: 0`. Any `ERROR:` line means an anchor did not match; fix the case.

- [ ] **Step 7: Run smoke-test** — `./test/smoke-test.sh` → `0 failed`.

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
- Modify: `skills/red-team/SKILL.md.tmpl` "Return value" list
- Test: `test/smoke-test.sh` (after the `for tmpl in ... prints the plugin path of its report template` loop, before the final `echo ""`)
- Test: `test/test-skill-shell-zsh.sh` (inside the `for sh in bash zsh` loop, directly before `# Every preamble block exits 0 ...`)
- Test: `test/mutation-test.sh`

**Interfaces:**
- Produces: every report-preparation block prints `Report link: <absolute path>`; when `<export dir>/index.html` exists it also prints `Dashboard link: <absolute path>`. The pipeline prints `Dashboard link: <absolute path>`. Task 3's dashboard option prints the same `Dashboard link:` format.

- [ ] **Step 1: Write the failing smoke checks** — in `test/smoke-test.sh`, insert after the `done` that closes the `for tmpl in "$IDSTACK_DIR"/skills/*/SKILL.md.tmpl` loop at the end of the file (directly before `echo ""` / `echo "Results: ...`):

```bash
# A desktop user opens a report by clicking its full path in chat, so each
# report block prints one, and the pipeline prints one for the dashboard.
for skill in $REPORT_PRODUCING_SKILLS; do
  check "$skill prints an absolute report link" \
    "grep -qF 'echo \"Report link: \$(pwd -P)/\$_REPORT_PATH\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
check "pipeline prints an absolute dashboard link" \
  "grep -qF 'echo \"Dashboard link: \$(pwd -P)/\$_EXPORT_DIR/index.html\"' '$IDSTACK_DIR/skills/pipeline/SKILL.md.tmpl'"
check "preamble tells skills to give the report link" \
  "grep -q '^## Preamble: Report Links' '$IDSTACK_DIR/templates/preamble.md'"
```

- [ ] **Step 2: Write the failing zsh/bash checks** — in `test/test-skill-shell-zsh.sh`, insert directly before the line `  # Every preamble block exits 0 and prints the same output in both shells.`:

```bash
  # Report links: a real report block prints the full path of the report, and
  # of the dashboard only when the dashboard exists.
  mkdir -p "$P/links"
  b=$(block learning-objectives '_REPORT_PATH="$_EXPORT_DIR/learning-objectives.html"')
  out=$(run "$P/links" "$b")
  want="Report link: $(cd "$P/links" && pwd -P)/.idstack/exports/untitled-course/learning-objectives.html"
  check "[$sh] a report block prints an absolute report link" \
    "printf '%s\n' \"\$out\" | grep -qxF \"\$want\""
  check "[$sh] a report block gives no dashboard link before the dashboard exists" \
    "! printf '%s' \"\$out\" | grep -q 'Dashboard link:'"
  touch "$P/links/.idstack/exports/untitled-course/index.html"
  out=$(run "$P/links" "$b")
  want="Dashboard link: $(cd "$P/links" && pwd -P)/.idstack/exports/untitled-course/index.html"
  check "[$sh] a report block gives the dashboard link when the dashboard exists" \
    "printf '%s\n' \"\$out\" | grep -qxF \"\$want\""
```

- [ ] **Step 3: Run to verify failure**

Run: `./test/smoke-test.sh`
Expected: FAIL lines for the 11 new smoke checks. Also run `./test/test-skill-shell-zsh.sh` on its own: the 6 new checks (3 per shell) FAIL.

- [ ] **Step 4: Add the link lines to the templates.** In each file, find the anchor line exactly and insert the two new lines directly after it.

| File | Anchor line (current line no.) |
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

Lines to insert (identical in all nine):

```bash
echo "Report link: $(pwd -P)/$_REPORT_PATH"
if [ -f "$_EXPORT_DIR/index.html" ]; then echo "Dashboard link: $(pwd -P)/$_EXPORT_DIR/index.html"; fi
```

In `skills/pipeline/SKILL.md.tmpl`, directly after `echo "Dashboard: $_EXPORT_DIR/index.html"` (147), insert:

```bash
echo "Dashboard link: $(pwd -P)/$_EXPORT_DIR/index.html"
```

In `skills/red-team/SKILL.md.tmpl`, in the `## Return value` list, directly after the line that starts `- Path: the value of \`$_REPORT_PATH\``, insert:

```markdown
- Link: the path from the "Report link:" line, and from the "Dashboard link:" line if there is one
```

- [ ] **Step 5: Add the preamble section.** In `templates/preamble.md`, insert directly before `## Preamble: Context Recovery`. Use form **P** unless Task 0 chose **L**.

Form **P** (bare path):

```markdown
## Preamble: Report Links

A skill that writes a report runs a block that prints a `Report link:` line. If
the course dashboard exists, the block also prints a `Dashboard link:` line.
Each line gives the full path of the file.

When you tell the user that you wrote a report, put the path from the
`Report link:` line on a separate line, with no backticks. Do the same for the
dashboard. For example:

Report: /Users/ana/Courses/BIO-101/.idstack/exports/bio-101/course-import.html

In the Claude desktop app, the user clicks the path to open the report. Do not
give a path for a report that you did not write.

```

Form **L** (Markdown link): the same section, with the second paragraph and example replaced by:

```markdown
When you tell the user that you wrote a report, put the path from the
`Report link:` line in a Markdown link, on a separate line. Do the same for the
dashboard. For example:

[Open the report](/Users/ana/Courses/BIO-101/.idstack/exports/bio-101/course-import.html)
```

- [ ] **Step 6: Check the new preamble text against the writing standard**

Run: `python3 bin/idstack-ste-check templates/preamble.md`
Expected: no problem reported in the lines of the new section. If a line of the new section is reported, rewrite that sentence and run again (maximum three times). Problems on other lines existed before this change; do not touch them.

- [ ] **Step 7: Regenerate and run the tests**

```bash
bin/idstack-gen-skills
./test/smoke-test.sh
```
Expected: `0 failed`.

- [ ] **Step 8: Add the mutation** — in `test/mutation-test.sh`, after case 61b:

```bash
# 61c. A report block stops printing its full report link -> smoke-test must
# fail. The desktop user then has no link to click.
shell_mutation "a report block stops printing its absolute report link" \
  skills/learning-objectives/SKILL.md.tmpl 'echo "Report link: $(pwd -P)/$_REPORT_PATH"
' ''
```

- [ ] **Step 9: Run the mutation suite** — `./test/mutation-test.sh` → `GUARDED: a report block stops printing its absolute report link`, `NOT guarded: 0`, no `ERROR:`.

- [ ] **Step 10: Commit**

```bash
git add templates/preamble.md skills test/smoke-test.sh test/test-skill-shell-zsh.sh test/mutation-test.sh
git commit -m "feat(skills): print a clickable full path for each report and the dashboard

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The `/idstack:start` skill

**Files:**
- Create: `skills/start/SKILL.md.tmpl`, then generate `skills/start/SKILL.md`
- Modify: `templates/preamble.md:19-20` (Skill-tool line)
- Modify: `bin/idstack-doctor:24-26` and `:87`, `test/test-doctor.sh:51-53` (skill list)
- Test: `test/smoke-test.sh` (lines 37, 286, 296, 400)
- Test: `test/test-skill-shell-zsh.sh` (same insertion point as Task 2, after the Task 2 block)
- Test: `test/mutation-test.sh`

**Interfaces:**
- Consumes: `idstack-doctor --quick` codes and exit codes (Task 1); the `Dashboard link:` line format (Task 2); the preamble's `MANIFEST_EXISTS` / `NO_MANIFEST` output.
- Produces: the user-invocable skill `/idstack:start` (Skill-tool name `idstack:start`). Its folder block prints `NOT_A_COURSE_FOLDER: <path>` or `COURSE_FOLDER: <path>`.

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
    check "start does not log to the timeline" "! grep -q 'idstack-timeline-log' '$IDSTACK_DIR/skills/start/SKILL.md.tmpl'"
    ```

- [ ] **Step 2: Write the failing zsh/bash checks** — in `test/test-skill-shell-zsh.sh`, directly after the Task 2 report-link block (still before `# Every preamble block ...`):

```bash
  # start: the setup check prints one machine-readable code.
  mkdir -p "$P/start"
  b=$(block start 'idstack-doctor" --quick')
  out=$(run "$P/start" "$b")
  check "[$sh] start setup check prints OK when python3 3.9 or later is present" \
    "printf '%s\n' \"\$out\" | grep -qx OK"

  # start: the folder check refuses the home folder and /, and accepts a course folder.
  b=$(block start 'NOT_A_COURSE_FOLDER')
  out=$(run "$HOME" "$b")
  check "[$sh] start refuses the home folder" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run / "$b")
  check "[$sh] start refuses /" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run "$P/start" "$b")
  check "[$sh] start accepts a course folder" \
    "printf '%s' \"\$out\" | grep -q '^COURSE_FOLDER: '"
```

- [ ] **Step 3: Run to verify failure**

Run: `./test/smoke-test.sh`
Expected: FAIL for `skills/start/SKILL.md reachable` and the other per-skill checks for `start`, and the two new start checks. Also run `./test/test-skill-shell-zsh.sh` on its own: the 8 new checks (4 per shell) FAIL.

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
  - Skill
  - AskUserQuestion
---

{{PREAMBLE}}

# Start — First Steps with idstack

You are the idstack guide. Your job is to make sure that idstack can run in this
folder, and then to start the correct skill for the user. Many users of this
skill do not use a terminal. Use short sentences. Do not tell the user to type a
command in a terminal.

This skill does not write the manifest, a report or the timeline. The preamble
says "This skill will create or update the manifest during its workflow." That
line is not true for this skill.

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
  Then type `/idstack:start` again." STOP.
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
if [ "$_HERE" = "/" ] || [ "$_HERE" = "$_HOME_DIR" ]; then echo "NOT_A_COURSE_FOLDER: $_HERE"; else echo "COURSE_FOLDER: $_HERE"; fi
```

- **COURSE_FOLDER:** Go to Step 3.
- **NOT_A_COURSE_FOLDER:** Tell the user: "idstack keeps the files for one
  course in one folder. This session is not in a course folder. Make a new
  folder for the course, for example in Documents. Start a new session, and use
  the folder button below the message box to select the new folder. Then type
  `/idstack:start` again." STOP.

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

**If MANIFEST_EXISTS** and the JSON is valid: give the welcome-back message from
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

A bare name such as `"course-import"` does not resolve in Claude Code. If the
`Skill` tool fails, tell the user: "Type `/idstack:<name>` to start the next
step." Then STOP.

## Step 5: Open the course dashboard

```bash
{{IDSTACK_RESOLVE}}
_SLUG=$("$_IDSTACK/bin/idstack-slugify" --from-manifest 2>/dev/null || echo "untitled-course")
_DASH=".idstack/exports/$_SLUG/index.html"
if [ -f "$_DASH" ]; then echo "Dashboard link: $(pwd -P)/$_DASH"; else echo "NO_DASHBOARD"; fi
```

- **Dashboard link:** give the path as the "Report Links" section of the
  preamble tells you. Say that the user can click it to open the dashboard.
- **NO_DASHBOARD:** Tell the user: "This course has no dashboard. The pipeline
  makes the dashboard." Then go to Step 4 with `idstack:pipeline`.

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
- Do not write `.idstack/project.json`. Do not write a file.
- Do not log this skill to the timeline.
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
  child skill in-process via the `Skill` tool, and by `/idstack:start`, which starts the
  first skill for the user.
```

- [ ] **Step 6: Add `start` to doctor's skill list and its test copy.**
  - `bin/idstack-doctor` lines 24-26 and `test/test-doctor.sh` lines 51-53: change the last line of the `SKILLS=` value from `pipeline learn"` to `pipeline learn start"`.
  - `bin/idstack-doctor` line 87: `echo "  found all 11 SKILL.md files"` → `echo "  found all 12 SKILL.md files"`.

- [ ] **Step 7: Generate and check the writing standard**

```bash
bin/idstack-gen-skills
python3 bin/idstack-ste-check skills/start/SKILL.md.tmpl
```
Expected: generation prints `skills/start/SKILL.md` with no `ERROR`. For any problem the checker reports in start's own text (not the `{{PREAMBLE}}` line), rewrite that sentence and run again (maximum three times). Never add the literal string `"$_IDSTACK/bin/idstack-ste-check"` to this template: the check-count map expects zero.

- [ ] **Step 8: Run the tests**

```bash
./test/smoke-test.sh
./test/test-doctor.sh
```
Expected: both report `0 failed` / all passed.

- [ ] **Step 9: Add the mutation** — in `test/mutation-test.sh`, after case 61c:

```bash
# 61d. /idstack:start stops refusing the home folder -> smoke-test must fail
# (through test-skill-shell-zsh). A desktop session starts in the home folder,
# and the next skill would write .idstack/ there.
shell_mutation "start no longer refuses the home folder" \
  skills/start/SKILL.md.tmpl 'if [ "$_HERE" = "/" ] || [ "$_HERE" = "$_HOME_DIR" ]; then' 'if [ "$_HERE" = "/" ]; then'
```

- [ ] **Step 10: Run the mutation suite** — `./test/mutation-test.sh` → `GUARDED: start no longer refuses the home folder`, `NOT guarded: 0`, no `ERROR:`.

- [ ] **Step 11: Commit**

```bash
git add skills/start templates/preamble.md skills bin/idstack-doctor test/smoke-test.sh test/test-doctor.sh test/test-skill-shell-zsh.sh test/mutation-test.sh
git commit -m "feat: add /idstack:start, the first-run guide

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Skill count and `start` on every listing surface

**Files:**
- Modify: `.claude-plugin/plugin.json:4`, `.claude-plugin/marketplace.json:3`, `DESIGN.md:7`, `setup:82-95`, `README.md` (93, 164-177, 241 table, 328, 487), `docs/index.html` (1154-1155, 1203-1212, 1295, 1303), `CLAUDE.md` (17, 89-99, 217)

**Interfaces:** none (text only). Grep each old string in `test/mutation-test.sh` before editing (Global Constraints).

- [ ] **Step 1: Manifests and DESIGN.md**
  - `.claude-plugin/plugin.json:4` and `.claude-plugin/marketplace.json:3`: `11 skills backed` → `12 skills backed` (the second `11`, "11 domains", stays).
  - `DESIGN.md:7`: `Runs in Claude Code. 11 skills,` → `Runs in Claude Code. 12 skills,`.

- [ ] **Step 2: `setup` closing message.** Replace lines 82-95 (from `echo "  To use a skill, run /idstack:<skill>"` to the last `All skills:` line) with:

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

Mirror it in the README "You should see:" block (README.md:164-177): insert the two lines `  If you do not know where to start:` / `    /idstack:start` and a blank line after `  To use a skill, run /idstack:<skill>` + blank line, and change `  All skills: needs-analysis,` to `  All skills: start, needs-analysis,`.

- [ ] **Step 3: README counts and table**
  - README.md:93: replace `(\`course-import\` branches in for existing courses; \`learn\` is a separate cross-project memory utility — those two sit outside the linear chain, which is why pipeline runs 8 of the 11 skills)` with `(\`course-import\` branches in for existing courses, \`learn\` is a separate cross-project memory utility, and \`start\` is the first-run guide. These three sit outside the linear chain, which is why pipeline runs 8 of the 12 skills)`.
  - README.md:328: `└─▶ 11 skills, invoked as /idstack:<skill>` → `└─▶ 12 skills, invoked as /idstack:<skill>`.
  - README.md:487: `all 11 SKILL.md files` → `all 12 SKILL.md files`.
  - In the "Your design team" table, insert a new first data row directly after the `|-------|...` separator line:
    ```markdown
    | `/idstack:start` | **Guide** | The first skill to run in a course folder. It makes sure that idstack can run, then starts the correct skill: course import, needs analysis or the pipeline. It writes no report. |
    ```

- [ ] **Step 4: Landing page**
  - `docs/index.html:1154`: `Eleven skills. Pipeline optional.` → `Twelve skills. Pipeline optional.`
  - `docs/index.html:1155`: `standalone utilities handle course import and institutional memory` → `standalone utilities handle first-run setup, course import and institutional memory`.
  - In `<div class="pipeline-aside-row" ...>` (1203), insert as the first child:
    ```html
          <div class="pipeline-aside">
            <span class="aside-tag">start</span>
            <span>Checks that idstack can run in a course folder, then starts the correct skill. The first skill to run.</span>
          </div>
    ```
  - `docs/index.html:1295`: `Full 11-Skill Pipeline` → `Full 12-Skill Pipeline`. `:1303`: `installs all 11 skills` → `installs all 12 skills`.
  - Do not change "11 domains", "11 research domains", or line 1348.

- [ ] **Step 5: CLAUDE.md**
  - Line 17, after the `bin/idstack-doctor` command line, add:
    ```
    bin/idstack-doctor --quick                 # One python3 code for /idstack:start: OK, PYTHON_MISSING, PYTHON_OLD or PYTHON_STUB
    ```
  - Line 89: `11 skills total.` → `12 skills total.`, and change `and \`/idstack:learn\` is a cross-project memory utility that runs outside the pipeline.` to `\`/idstack:learn\` is a cross-project memory utility that runs outside the pipeline, and \`/idstack:start\` is the first-run guide that checks the setup and starts the correct skill.`
  - In the diagram, after `/idstack:learn (manage cross-project learnings)`, add a blank line and `/idstack:start (first-run guide: setup check, folder check, then hands off)`.
  - In "## Skill routing", add as the first list item: ``- First run, "where do I start", or a Claude desktop app user → `/idstack:start` ``.

- [ ] **Step 6: Verify**

```bash
./test/smoke-test.sh
python3 test/check-doc-accuracy.py .
node test/test-responsive-landing.js
node test/test-rendered-landing.js
git grep -nE '\b11 skills|Eleven skills|11-Skill|all 11 SKILL' -- ':!CHANGELOG.md' ':!docs/superpowers'
```
Expected: suites pass; the last grep prints nothing except `docs/index.html:1348` (historical).

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin DESIGN.md setup README.md docs/index.html CLAUDE.md
git commit -m "docs: list /idstack:start and count 12 skills

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Desktop guide (README and landing page)

**Files:**
- Modify: `README.md` (Quick start 13-18; new section before `### Chrome Extension (No-Terminal Mode)` at 182; FAQ 435-439)
- Modify: `docs/index.html` (new install card in `.install-tracks`, 1272-1313; 1309)

**Interfaces:** Consumes the Task 0 install-path decision (text **A** or **B**).

- [ ] **Step 1: README Quick start.** Replace lines 15-16 with:

```markdown
1. Install idstack (30 seconds, see below). No terminal? Use the [Claude desktop app](#claude-desktop-app-no-terminal).
2. Run `/idstack:start` in a folder for your course. It checks your setup and starts the correct skill.
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
   > Install idstack: run `git clone https://github.com/savvides/idstack.git ~/idstack && cd ~/idstack && ./setup`, then tell me it's installed.
4. When Claude says that idstack is installed, close the Claude app and open it again.
````

- [ ] **Step 3: README FAQ.** Replace the answer under `**Do I need to know how to code?**` (line 436) with:

```markdown
No. You interact with idstack through conversation in Claude Code. It's a chat interface. In the [Claude desktop app](#claude-desktop-app-no-terminal) you do not need a terminal at all.
```

- [ ] **Step 4: Landing install card.** In `docs/index.html`, insert a new card as the second child of `<div class="install-tracks">` (between the Chrome card's closing `</div>` at 1290 and the Claude Code Plugin card at 1292). For install text **A**:

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

For install text **B**, the `<code>` content is `Install idstack: run git clone https://github.com/savvides/idstack.git ~/idstack &amp;&amp; cd ~/idstack &amp;&amp; ./setup` and the last paragraph is: `When Claude says that idstack is installed, close the app and open it again. Then type <code>/idstack:start</code>.`

Also change `docs/index.html:1309` `When Claude Code starts, run <code>/idstack:pipeline</code>.` → `When Claude Code starts, run <code>/idstack:start</code>.`

- [ ] **Step 5: Writing standard and landing tests**

```bash
python3 bin/idstack-ste-check README.md docs/index.html
node test/test-responsive-landing.js
node test/test-rendered-landing.js
./test/smoke-test.sh
python3 test/check-doc-accuracy.py .
```
Expected: no checker problem on the new lines (rewrite any that are reported; earlier lines are out of scope); all suites pass. `test-rendered-landing.js` must report no sideways scroll at 320px: the command sits in `.install-block code`, which scrolls itself.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/index.html
git commit -m "docs: add the Claude desktop app install path

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Release v3.10.0.0

**Files:** `VERSION`, `.claude-plugin/plugin.json:3`, `CHANGELOG.md` (top), `README.md:3`, `docs/index.html` (45, 1033, new release card at 1323), `ROADMAP.md:5`, `CLAUDE.md` (33-44 counts, 71).

- [ ] **Step 1: Version strings**
  - `VERSION`: `3.10.0.0`
  - `.claude-plugin/plugin.json:3`: `"version": "3.10.0.0",`
  - `README.md:3`: `(v3.9.0.0)` → `(v3.10.0.0)`
  - `docs/index.html:45`: `"softwareVersion": "3.10.0.0",`; `:1033`: `v3.10.0.0 · Claude Code &amp; Chrome Extension`

- [ ] **Step 2: CHANGELOG.** Insert after `# Changelog` and its blank line:

```markdown
## v3.10.0.0 (2026-11-01)

This release lets you use idstack in the Claude desktop app with no terminal. A new skill, `/idstack:start`, checks your setup and starts the correct skill, and each skill gives you a link that opens its report in the app.

To update: `cd` into your idstack clone, then `git pull && ./setup`. For a marketplace install, run `claude plugin update idstack@idstack`.

### Added — `/idstack:start`

- **`/idstack:start` is the first skill to run in a course folder.** It makes sure that python3 3.9 or a later version is available, stops if the session is in your home folder, and then asks if you want to import a course or design a new one. It writes no file.
- **`bin/idstack-doctor --quick` prints one python3 code.** The codes are `OK`, `PYTHON_MISSING`, `PYTHON_OLD` and `PYTHON_STUB`. `PYTHON_STUB` tells the macOS python3 stub apart from a python3 that is too old.

### Added — report links

- **Each skill prints the full path of its report.** In the Claude desktop app you click the path to open the report. The course dashboard gets a link when it exists.

### Added — Claude desktop app guide

- **README and idstack.org show how to install idstack in the Claude desktop app.**

### Tests

- `test/test-doctor.sh` tests each `--quick` code with fake `python3`, `uname` and `xcode-select` commands. `test/test-skill-shell-zsh.sh` runs the new `/idstack:start` blocks and a report-link block in bash and zsh. `test/mutation-test.sh` cases 61a–61d.
```

- [ ] **Step 3: ROADMAP.** Insert after `## Just shipped` and its blank line:

```markdown
### idstack in the Claude desktop app & `/idstack:start` (v3.10.0.0)
- **You can use idstack with no terminal.** Install it in the Code tab of the Claude desktop app, then type `/idstack:start`.
- **`/idstack:start` checks your setup and starts the correct skill.** It finds the macOS python3 stub and a session in your home folder before they cause a problem.
- **Each skill gives you a link to its report.** Click the link to open the report in the app.

```

- [ ] **Step 4: Landing release card.** In `docs/index.html`, insert directly before the first `<article class="release-card">` (1323):

```html
      <article class="release-card">
        <p class="release-meta">November 1, 2026 · v3.10.0.0</p>
        <h3>idstack in the Claude desktop app.</h3>
        <p>Install idstack in the Code tab of the Claude desktop app, then type <code>/idstack:start</code>. It checks your setup and starts the correct skill. Each skill gives you a link that opens its report in the app.</p>
      </article>
```

- [ ] **Step 5: CLAUDE.md release wording.** Line 71: `plus a 3-part \`softwareVersion\`` → `plus the same 4-part \`softwareVersion\``.

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
./test/mutation-test.sh
```
Expected: all pass; mutation suite `NOT guarded: 0` and no `ERROR:`. Update the hand-kept counts in `CLAUDE.md` lines 33-44 from these runs: the smoke-test assertion total (was 434), `test-doctor.sh` (was 12), `test-skill-shell-zsh.sh` (was 44). Change only numbers that changed.

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

- [ ] **Step 1: The user runs the journey** in the Claude desktop app with a new, empty course folder: install (Task 5 text) → `/idstack:start` → "Import a course that I have" → import a small `.imscc` → click the report link. If Task 0 was skipped, this run also settles both Task 0 questions; if a result differs from the default, go back and apply the other variant in Task 2 Step 5 and Task 5.

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
- No automated test proves that the desktop app renders a clicked path. Task 0 and Task 7 check it by hand.
- If Task 0 shows that `/plugin` is unknown, install text B needs `claude` on the PATH of the desktop app's shell, as `./setup` does today.
