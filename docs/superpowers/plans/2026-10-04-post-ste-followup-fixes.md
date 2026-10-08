# Post-STE Follow-up Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four defects found while running PR #113's manual test plan:
1. A flaky Chrome startup in the rendered landing test.
2. A resolve chain that never finds the loaded plugin, so skills run stale cached binaries and skip the writing check silently.
3. A report folder named `untitled-course` on a first run.
4. Evidence citations that claim T1 for T5 sources.

**Architecture:** Each defect is one task with its own tests and its own commit, in one PR. Tests come first. Each task adds a regression check to `test/smoke-test.sh` or a new checker that smoke runs. Each task also adds a mutation case to `test/mutation-test.sh` that puts the defect back and must fail. Skill text changes happen in `skills/*/SKILL.md.tmpl` and shared templates. `bin/idstack-gen-skills` then regenerates the `SKILL.md` files.

**Tech Stack:** Bash (3.2-compatible), Python 3.9+ standard library, Node 22 (CDP over the global `WebSocket`), headless Chrome.

## Global Constraints

- Python in any new or changed file must run on Python 3.9 (`/usr/bin/python3` on macOS). No modern-only syntax.
- Bash in skill templates must run in macOS `/bin/bash` 3.2.
- All text that idstack shows a person must follow ASD-STE100. This includes skill text, preamble rules, CLI messages and new test failure messages. Run `bin/idstack-ste-check` (with `--format markdown` for prose) on new wording. Do not use semicolons, "consider", "may", "should" or "suggest".
- Edit by anchor, never by line number. Three tasks edit `skills/needs-analysis/SKILL.md.tmpl` and two edit `skills/course-import/SKILL.md.tmpl`, so line numbers drift. Every scripted edit asserts that its anchor occurs exactly as often as expected.
- Never edit a generated `skills/*/SKILL.md` by hand. After any `.tmpl`, `templates/preamble.md`, `templates/manifest-schema.md` or `templates/snippets/` change, run `bin/idstack-gen-skills`.
- Mutation case numbers are 50 (Task 1), 51a–51c (Task 2), 52a–52b (Task 3) and 53a–53c (Task 4). Insert every new case directly before the footer of `test/mutation-test.sh`. The footer is the unique pair of lines `echo ""` and `echo "guarded: $pass   NOT guarded: $fail   skipped: $skip"`.
- Do not change `VERSION`, `.claude-plugin/plugin.json`, `CHANGELOG.md` or the extension version. No release is needed (see Task 6).
- Do not record smoke-test totals in any task. Task 5 measures the real total once and writes it to `CLAUDE.md`. Local runs inside a scratch copy of the repo skip 12 legacy-install checks. So always run smoke from this worktree with no argument.
- This session's sandbox refuses a Bash command that combines the repo path (it contains "github") with compound shell syntax, saying it "names git in a form too complex". If that happens, save the commands in a `.sh` file under the scratchpad and run `bash <file>`. Run git commands as plain, separate commands.
- This plan was dry-run end to end. Every step was applied in order to a scratch copy of the repo. Smoke passed with 0 failed, and every scripted edit's anchor counts held. If an anchor assert fails, stop and report it. Do not loosen the assert.
- Work on branch `fix/post-ste-followups` in worktree `/Users/philippossavvides/github/idstack/.claude/worktrees/feat-ste-output`. Commit message bodies end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Map

| File | Task | Responsibility |
|---|---|---|
| `test/test-rendered-landing.js` | 1 | Launch Chrome on port 0. Read the DevTools address from stderr, and fail fast when Chrome exits. |
| `templates/snippets/idstack-resolve.sh`, `templates/preamble.md`, `templates/manifest-schema.md` | 2 | Resolve chain uses the exact `${CLAUDE_PLUGIN_ROOT}` token. Add preamble rules for the two check tokens. |
| 14 check-step lines in 11 `skills/*/SKILL.md.tmpl` files, plus prose in `learn` and `course-export` | 2 | A distinct `STE_CHECK_MISSING: <path>` token. |
| `skills/needs-analysis/SKILL.md.tmpl`, `skills/course-import/SKILL.md.tmpl` | 3 | Report slug comes from the session's course title. |
| `test/check-citation-tiers.py` (new) | 4 | Compares every `[Code-N] [Tn]` citation with `evidence/references.md`. |
| 4 skill templates (needs-analysis, course-builder, course-quality-review, learning-objectives) | 4 | Correct 16 citations. |
| `test/smoke-test.sh`, `test/mutation-test.sh` | 1–4 | Regression checks and mutation guards. |
| `CLAUDE.md`, `CONTRIBUTING.md` | 2, 4, 5 | Resolve-order note, new checker, smoke total. |

---

### Task 1: Rendered landing test survives a slow Chrome start and explains a failed one

**Why:** On a cold ubuntu runner the test failed twice with `Chrome did not expose a debugging port within 12s`. Each time it passed on a rerun of the same commit. These problems caused it:
- A fixed port (`9400 + pid % 500`).
- A 12-second probe loop with no timeout on each `fetch`.
- Chrome's stderr discarded and its exit never watched.

The failures left no clue.

The fix:
- `--remote-debugging-port=0`, with the `DevTools listening on ws://…` stderr line as the address.
- A 30-second deadline.
- Immediate failure, with the exit code and the last stderr lines, when Chrome exits early.

No retry: port 0 removes clashes, and the longer deadline covers a slow start.

**Files:**
- Modify: `test/test-rendered-landing.js` (the `port` constant and the spawn and probe block in `main()`)
- Modify: `test/smoke-test.sh` (after the `rendered landing page tests pass` check and in the node-absent SKIP block)
- Modify: `test/mutation-test.sh` (new case 50)

**Interfaces:**
- Consumes: `check <desc> <cmd> [want_exit] [want_output_regex]` from `test/test-helper.sh`.
- Produces: the error texts `Chrome stopped (exit code N) before it opened a debugging port. Last output: …` and `Chrome did not open a debugging port within 30s. Last output: …`. Mutation 50 anchors on the line `    chrome.on('exit', (code, signal) => {`.

- [ ] **Step 1: Write the failing regression check**

In `test/smoke-test.sh`, replace this anchor (it occurs once):

````bash
  check "rendered landing page tests pass" "node '$IDSTACK_DIR/test/test-rendered-landing.js'"
````

with:

````bash
  check "rendered landing page tests pass" "node '$IDSTACK_DIR/test/test-rendered-landing.js'"
  # A Chrome that stops at startup must fail the test at once and give its exit code and last
  # output. Before, the test waited 12s and said only that no debugging port opened, so two CI
  # failures left no clue. Needs no real browser: CHROME_PATH points at a stub that stops.
  FAKE_CHROME_DIR=$(mktemp -d)
  printf '#!/bin/sh\necho "fake-chrome-startup-failure" >&2\nexit 3\n' > "$FAKE_CHROME_DIR/chrome"
  chmod +x "$FAKE_CHROME_DIR/chrome"
  check "rendered landing test reports why Chrome stopped at startup" \
    "CHROME_PATH='$FAKE_CHROME_DIR/chrome' node '$IDSTACK_DIR/test/test-rendered-landing.js'" \
    1 "exit code 3.*fake-chrome-startup-failure"
  rm -rf "$FAKE_CHROME_DIR"
````

Also replace the anchor `echo "  SKIP: rendered landing page tests (node not installed)"` with:

````bash
  echo "  SKIP: rendered landing page tests (node not installed)"
  echo "  SKIP: rendered landing startup report (node not installed)"
````

- [ ] **Step 2: Run it and see it fail**

Run: `./test/smoke-test.sh 2>&1 | grep -E "FAIL|Results"`
Expected: exactly one FAIL, `rendered landing test reports why Chrome stopped at startup (exit 1 correct, output missing /exit code 3.*fake-chrome-startup-failure/)`. It comes after a wait of about 13 s.

- [ ] **Step 3: Replace the fixed port with a startup deadline**

In `test/test-rendered-landing.js`, replace:

````js
const userDataDir = path.join(os.tmpdir(), `idstack-rendered-${process.pid}`);
const port = 9400 + (process.pid % 500);
let chrome = null;
````

with:

````js
const userDataDir = path.join(os.tmpdir(), `idstack-rendered-${process.pid}`);
// A cold Chrome on a fresh ubuntu runner has missed a 12s deadline. The wait costs time only
// when Chrome is stuck, so it is generous.
const STARTUP_SECONDS = 30;
let chrome = null;
````

- [ ] **Step 4: Replace the spawn and the probe loop**

In `test/test-rendered-landing.js`, replace:

````js
  chrome = spawn(chromePath, [
    '--headless=new', `--remote-debugging-port=${port}`,
    '--no-first-run', '--no-default-browser-check', '--disable-gpu',
    '--hide-scrollbars', '--no-sandbox',
    `--user-data-dir=${userDataDir}`, 'about:blank',
  ], { stdio: 'ignore' });

  let wsUrl = null;
  for (let i = 0; i < 80; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`);
      wsUrl = (await res.json()).webSocketDebuggerUrl;
      break;
    } catch { await sleep(150); }
  }
  if (!wsUrl) throw new Error('Chrome did not expose a debugging port within 12s');
````

with:

````js
  // Port 0: Chrome picks a free port and prints its address on stderr, so no other process can
  // hold the port. Keep reading stderr for the whole run. A full pipe stops Chrome.
  chrome = spawn(chromePath, [
    '--headless=new', '--remote-debugging-port=0',
    '--no-first-run', '--no-default-browser-check', '--disable-gpu',
    '--hide-scrollbars', '--no-sandbox',
    `--user-data-dir=${userDataDir}`, 'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });

  let stderr = '';
  const lastOutput = () => stderr.trim().split('\n').slice(-3).join(' / ');
  const wsUrl = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(
      `Chrome did not open a debugging port within ${STARTUP_SECONDS}s. Last output: ${lastOutput()}`)),
      STARTUP_SECONDS * 1000);
    chrome.stderr.on('data', chunk => {
      stderr += chunk;
      const m = stderr.match(/DevTools listening on (ws:\/\/\S+)/);
      if (m) { clearTimeout(timer); resolve(m[1]); }
      stderr = stderr.slice(-2000);
    });
    chrome.on('error', err => { clearTimeout(timer); reject(err); });
    chrome.on('exit', (code, signal) => {
      clearTimeout(timer);
      reject(new Error(`Chrome stopped (${signal || `exit code ${code}`}) before it opened ` +
        `a debugging port. Last output: ${lastOutput()}`));
    });
  });
````

Keep `const sleep = …`. It is still used later (`await sleep(320)`).

- [ ] **Step 5: Run the tests and see them pass**

Run: `node test/test-rendered-landing.js; echo "exit $?"`
Expected: the pass line and `exit 0`.

Run: `printf '#!/bin/sh\necho "fake-chrome-startup-failure" >&2\nexit 3\n' > "$TMPDIR/fc" && chmod +x "$TMPDIR/fc" && CHROME_PATH="$TMPDIR/fc" node test/test-rendered-landing.js; echo "exit $?"`
Expected: in under 2 s, `rendered landing page test could not run: Chrome stopped (exit code 3) before it opened a debugging port. Last output: fake-chrome-startup-failure`, then `exit 1`.

Run: `./test/smoke-test.sh 2>&1 | grep -E "FAIL|Results"`
Expected: `Results: N/N passed, 0 failed`.

- [ ] **Step 6: Add mutation case 50**

Insert this block directly before the mutation-test footer (see Global Constraints):

````bash
# 50. The rendered landing test stops watching for a Chrome that stops at startup ->
# smoke-test must fail. Then that Chrome costs the full startup wait and the error
# does not give its exit code. Two CI failures left no clue in this way.
fresh
python3 - "$WORK/r/test/test-rendered-landing.js" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "    chrome.on('exit', (code, signal) => {\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "    chrome.on('no-such-event', (code, signal) => {\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
expect_fail "the rendered landing test ignores a Chrome that stops at startup" "$WORK/r/test/smoke-test.sh" "$WORK/r"
````

Run: `bash -n test/mutation-test.sh && echo ok`
Expected: `ok`. The full mutation run is in Task 5. This case adds about 30 s, because the mutated copy waits the full deadline.

- [ ] **Step 7: Commit**

```bash
git add test/test-rendered-landing.js test/smoke-test.sh test/mutation-test.sh
git commit -m "test: make the rendered landing test survive a slow Chrome start

Use port 0 and the DevTools line on stderr, wait 30s, and fail at once
with the exit code and last output when Chrome stops early. Mutation 50
guards the early-exit check.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The resolve chain finds the loaded plugin, and a missing checker is loud

**Why:** Claude Code never sets `CLAUDE_PLUGIN_ROOT` in the Bash tool's shell. In plugin skill text it replaces only the exact token `${CLAUDE_PLUGIN_ROOT}` with the plugin path. The docs say so, and `claude -p --plugin-dir` probes on 2.1.289 confirmed it for slash-command and Skill-tool runs.

idstack writes `"${CLAUDE_PLUGIN_ROOT:-}"`, which is never replaced. Every `$_IDSTACK/bin/...` call therefore falls through to the newest directory in `~/.claude/plugins/cache/idstack/idstack`. On the maintainer's machine that is a stale 3.5.1.0 copy with no `bin/idstack-ste-check`. This happens even though the loaded plugin is the 3.6.0.0 checkout (a directory marketplace) or a `--plugin-dir`.

The writing check step also folds "no checker at that install" into the same `STE_CHECK_UNAVAILABLE` token as "no python3". The user only hears "the check did not run".

The fix:
- Use the exact token in all six chain copies.
- When the token is not replaced (outside a plugin), bash sees an unset variable and the old order applies.
- Give the missing-checker case its own token, `STE_CHECK_MISSING: <path>`, and a preamble rule.

**Files:**
- Modify: `templates/snippets/idstack-resolve.sh` (header comment and the `for _p in` line)
- Modify: `templates/preamble.md` (header comment copy, 4 chain copies including the `for _dir in` consensus copy, rule 5 under "How to use the standard")
- Modify: `templates/manifest-schema.md` (header comment copy, chain copy)
- Modify: the 14 check-step lines in `skills/{accessibility-review,assessment-design,course-builder(x2),course-export(x2),course-import,course-quality-review,learn,learning-objectives,needs-analysis,pipeline,red-team(x2)}/SKILL.md.tmpl`
- Modify: `skills/learn/SKILL.md.tmpl` and `skills/course-export/SKILL.md.tmpl` (the prose after their check step)
- Modify: `test/smoke-test.sh` (two inserted blocks), `test/mutation-test.sh` (48a and 48c anchors, new cases 51a–51c), `CLAUDE.md` (resolve-order note)
- Regenerate: all 11 `skills/*/SKILL.md`

**Interfaces:**
- Produces: the chain line `for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do`. The consensus copy uses `_dir`.
- Produces: the check-step shape `if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; else "$_IDSTACK/bin/idstack-ste-check" ARG; fi`. Each step stays on one line, because smoke counts check steps by line.
- Produces: preamble rules 5 (`STE_CHECK_UNAVAILABLE`) and 6 (`STE_CHECK_MISSING:`) under "How to use the standard". Tasks 3 and 4 do not depend on them.

- [ ] **Step 1: Write the failing regression checks**

In `test/smoke-test.sh`, directly after the line that starts with `check "no legacy .claude/plugins/idstack path in skill templates"`, insert:

````bash
# Claude Code writes the plugin root into a skill's text only where it finds the
# exact token ${CLAUDE_PLUGIN_ROOT}. The Bash tool's shell does not have the
# variable, and a token with a default (":-") stays as it is. The chain used
# that form until this check, so every skill fell through to the newest cache
# dir: under --plugin-dir, and for a marketplace added from a local path, that
# was an old install with no bin/idstack-ste-check. Do to the generated text
# what Claude Code does, then run the first chain with a stale cache present.
RESOLVE_SIM=$(mktemp -d)
mkdir -p "$RESOLVE_SIM/plugin" "$RESOLVE_SIM/home/.claude/plugins/cache/idstack/idstack/0.0.1.0"
RESOLVE_SIM_GOT=$({ awk '/^_IDSTACK=""$/{f=1} f{print} f && /^done$/{exit}' "$IDSTACK_DIR/skills/learn/SKILL.md" \
    | sed "s|\${CLAUDE_PLUGIN_ROOT}|$RESOLVE_SIM/plugin|g"; echo 'printf "%s" "$_IDSTACK"'; } \
  | env -u CLAUDE_PLUGIN_ROOT -u IDSTACK_HOME HOME="$RESOLVE_SIM/home" bash)
check "the substituted plugin root wins over a stale cache install" "[ '$RESOLVE_SIM_GOT' = '$RESOLVE_SIM/plugin' ]"
rm -rf "$RESOLVE_SIM"
# The x3 count above pins only the preamble's "for _p in" copies. The consensus
# block ("for _dir in") and the longhand copy in manifest-schema.md need this.
check "no resolve chain gives the plugin root a default" "! grep -rlF '\${CLAUDE_PLUGIN_ROOT:-' '$IDSTACK_DIR/templates' $IDSTACK_DIR/skills/*/SKILL.md.tmpl $IDSTACK_DIR/skills/*/SKILL.md"
````

Directly after the `done` that closes the loop whose last check is `check "$skill SKILL.md.tmpl runs the ste checker at all $want check steps" "[ '$got' -eq $want ]"`, insert:

````bash
# A check step must tell an install with no checker apart from a missing
# python3. Under --plugin-dir the chain once found a 3.5.1.0 install with no
# checker, and the step printed the python3 token. The skill then said only
# "the check did not run", and nothing told the user that the install was old.
STE_NOCHK=$(mktemp -d)
for skill in $SKILLS; do
  check "$skill check steps name an install that has no checker" \
    "grep -F '\"\$_IDSTACK/bin/idstack-ste-check\"' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl' | while IFS= read -r l; do _IDSTACK='$STE_NOCHK' bash -c \"\$l\" | grep -qxF 'STE_CHECK_MISSING: $STE_NOCHK' || exit 1; done"
done
rm -rf "$STE_NOCHK"
````

- [ ] **Step 2: Run them and see them fail**

Run: `./test/smoke-test.sh 2>&1 | grep -E "FAIL|Results"`
Expected: 13 FAILs.
- `the substituted plugin root wins over a stale cache install`
- `no resolve chain gives the plugin root a default`
- one `<skill> check steps name an install that has no checker` for each of the 11 skills

No other FAIL.

- [ ] **Step 3: Fix the resolve chain in all six copies and the header comment**

Run this from the worktree root:

````bash
python3 - <<'PY'
import io
def edit(path, pairs):
    s = io.open(path, encoding="utf-8").read()
    for old, new, n in pairs:
        assert s.count(old) == n, "%s: %r occurs %d times, want %d" % (path, old, s.count(old), n)
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8").write(s)

TOKEN = ('"${CLAUDE_PLUGIN_ROOT:-}"', '"${CLAUDE_PLUGIN_ROOT}"')
OLD_HDR = ("# available here. Priority: explicit env overrides, then the Claude Code\n"
           "# marketplace cache. Empty if none found; guard \"$_IDSTACK/bin/...\" calls\n"
           "# accordingly.\n")
NEW_HDR = ("# available here. Priority: the plugin root that Claude Code writes into the\n"
           "# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache. Empty\n"
           "# if none found; guard \"$_IDSTACK/bin/...\" calls accordingly.\n")
# The preamble's copy of the header wraps differently and says "(highest version)".
OLD_HDR_PRE = ("# available here. Priority: explicit env overrides, then the Claude Code\n"
               "# marketplace cache (highest version). Empty if none found; guard\n"
               "# \"$_IDSTACK/bin/...\" calls accordingly.\n")
NEW_HDR_PRE = ("# available here. Priority: the plugin root that Claude Code writes into the\n"
               "# skill text, then IDSTACK_HOME, then the Claude Code marketplace cache\n"
               "# (highest version). Empty if none found; guard \"$_IDSTACK/bin/...\" calls\n"
               "# accordingly.\n")
CHAIN_OLD = 'for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do\n'
CHAIN_NEW = ("# CLAUDE_PLUGIN_ROOT has no \":-\" default on purpose. Claude Code replaces only\n"
             "# the exact braced token in skill text. The Bash tool's shell does not have it.\n"
             + CHAIN_OLD)

edit("templates/snippets/idstack-resolve.sh", [TOKEN + (1,), (OLD_HDR, NEW_HDR, 1)])
edit("templates/snippets/idstack-resolve.sh", [(CHAIN_OLD, CHAIN_NEW, 1)])
edit("templates/preamble.md", [TOKEN + (4,), (OLD_HDR_PRE, NEW_HDR_PRE, 1)])
edit("templates/manifest-schema.md", [TOKEN + (1,), (OLD_HDR, NEW_HDR, 1)])
print("resolve chain fixed")
PY
grep -rn 'CLAUDE_PLUGIN_ROOT:-' templates skills/*/SKILL.md.tmpl || echo "no default left"
````

Expected: `resolve chain fixed`, then `no default left`. The header comment's semicolon is in a code comment that the model reads, not text shown to a person. It is unchanged from the old comment.

- [ ] **Step 4: Give the check steps the distinct token**

````bash
python3 - <<'PY'
import glob, io, re
OLD = re.compile(r'if \[ -x "\$_IDSTACK/bin/idstack-ste-check" \] && command -v python3 >/dev/null 2>&1; '
                 r'then "\$_IDSTACK/bin/idstack-ste-check" (.+?); else echo "STE_CHECK_UNAVAILABLE"; fi')
NEW = (r'if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; '
       r'elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; '
       r'else "$_IDSTACK/bin/idstack-ste-check" \1; fi')
total = 0
for p in sorted(glob.glob("skills/*/SKILL.md.tmpl")):
    s = io.open(p, encoding="utf-8").read()
    s2, n = OLD.subn(lambda m: m.expand(NEW), s)
    total += n
    io.open(p, "w", encoding="utf-8").write(s2)
assert total == 14, "replaced %d check steps, want 14" % total
print("14 check steps updated")
PY
````

Expected: `14 check steps updated`.

- [ ] **Step 5: Add the preamble rules and update the two skills' prose**

````bash
python3 - <<'PY'
import io
def edit(path, old, new):
    s = io.open(path, encoding="utf-8").read()
    assert s.count(old) == 1, "%s: anchor occurs %d times" % (path, s.count(old))
    io.open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
edit("templates/preamble.md",
     "5. If the checker does not run, continue the skill. Tell the user one time that the check did not run.\n",
     '5. If the output is `STE_CHECK_UNAVAILABLE`, python3 is not available. Continue the skill. Tell the user one time that the check did not run.\n6. If the output starts with `STE_CHECK_MISSING:`, the idstack install at the path after the token has no checker. Continue the skill. Tell the user one time that the check did not run. Give the user the path and tell the user to update idstack. If the path is empty, tell the user that idstack did not find its install.\n')
edit("skills/learn/SKILL.md.tmpl",
     'If the output is `STE_CHECK_UNAVAILABLE`, tell the user one time that the check did not run. If the checker shows problems, show them to the user. Do not change the export file.',
     'If the output is `STE_CHECK_UNAVAILABLE` or starts with `STE_CHECK_MISSING:`, do step 5 or step 6 of "How to use the standard" in the preamble. If the checker shows problems, show them to the user. Do not change the export file.')
edit("skills/course-export/SKILL.md.tmpl",
     '1. If the output is `STE_CHECK_UNAVAILABLE`, tell the user one time that the check did not run. Continue the export.',
     '1. If the output is `STE_CHECK_UNAVAILABLE` or starts with `STE_CHECK_MISSING:`, do step 5 or step 6 of "How to use the standard" in the preamble. Continue the export.')
print("prose updated")
PY
````

Expected: `prose updated`. The preamble rules are outside the `ste-core` markers, so `extension/shared/ste-rules.js` does not change.

- [ ] **Step 6: Update the CLAUDE.md resolve-order note**

In `CLAUDE.md`, replace `the snippet is the single definition of that resolution order (\`CLAUDE_PLUGIN_ROOT\`, \`IDSTACK_HOME\`, then the Claude Code marketplace cache). \`templates/manifest-schema.md\` is spliced verbatim and so writes the resolution out longhand — smoke-test keeps the two in lockstep.` with:

```text
the snippet is the single definition of that resolution order (`${CLAUDE_PLUGIN_ROOT}`, `IDSTACK_HOME`, then the Claude Code marketplace cache). Claude Code writes the plugin path into skill text only where it finds the exact token `${CLAUDE_PLUGIN_ROOT}`, and the Bash tool's shell never has the variable, so never give it a `:-` default. `templates/manifest-schema.md` is spliced verbatim and so writes the resolution out longhand — smoke-test keeps the two in lockstep and fails on any `${CLAUDE_PLUGIN_ROOT:-` in templates or skills.
```

- [ ] **Step 7: Regenerate, check the wording, run the tests**

Run: `bin/idstack-gen-skills && bin/idstack-gen-skills --dry-run | tail -1`
Expected: the script writes 11 skill files, and the dry run reports them up to date.

Run: `grep -E '^(5|6)\. If the output' templates/preamble.md | bin/idstack-ste-check --format markdown -`
Expected: `no problems`. Check only the two new rules. The full section holds the word list, and the word list names the words that it forbids.

Run: `./test/smoke-test.sh 2>&1 | grep -E "FAIL|Results"; ./test/integration-test.sh 2>&1 | tail -1; ./test/test-preamble-python.sh 2>&1 | tail -1`
Expected: smoke `0 failed`, integration 51/51, preamble-python all pass.

- [ ] **Step 8: Update the mutation anchors that quote the old check step, and add cases 51a–51c**

Mutations 48a and 48c quote the old check-step text verbatim, and their anchor asserts fail until they are updated. Run:

````bash
python3 - <<'PY'
import io
p = "test/mutation-test.sh"
s = io.open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:90])
    s = s.replace(old, new, 1)
# 48a anchor: learn's check step line and the prose after it.
rep("""       'if [ -x "$_IDSTACK/bin/idstack-ste-check" ] && command -v python3 >/dev/null 2>&1; then "$_IDSTACK/bin/idstack-ste-check" '
       '".idstack/learnings-export.md"; else echo "STE_CHECK_UNAVAILABLE"; fi\\n```\\n\\n'
       'If the output is `STE_CHECK_UNAVAILABLE`, tell the user one time that the check did not run. '
       'If the checker shows problems, show them to the user. Do not change the export file.\\n\\n')""",
"""       'if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; '
       'elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; '
       'else "$_IDSTACK/bin/idstack-ste-check" ".idstack/learnings-export.md"; fi\\n```\\n\\n'
       'If the output is `STE_CHECK_UNAVAILABLE` or starts with `STE_CHECK_MISSING:`, do step 5 or step 6 '
       'of "How to use the standard" in the preamble. '
       'If the checker shows problems, show them to the user. Do not change the export file.\\n\\n')""")

# 48c anchor: course-builder's course-content check step.
rep("""       'if [ -x "$_IDSTACK/bin/idstack-ste-check" ] && command -v python3 >/dev/null 2>&1; then "$_IDSTACK/bin/idstack-ste-check" '
       '".idstack/course-content"; else echo "STE_CHECK_UNAVAILABLE"; fi\\n```\\n')""",
"""       'if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; '
       'elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; '
       'else "$_IDSTACK/bin/idstack-ste-check" ".idstack/course-content"; fi\\n```\\n')""")
io.open(p, "w", encoding="utf-8").write(s)
print("48a and 48c anchors updated")
PY
````

Then insert this block directly before the mutation-test footer:

````bash
# 51a-51c. Claude Code writes the plugin root into skill text only where it finds
# the exact token ${CLAUDE_PLUGIN_ROOT}. The Bash tool's shell does not have the
# variable. With a ":-" default the chain fell through to an old cache install that
# had no checker, and the check step said only that the check did not run.
# 51a. The chain gives the plugin root a ":-" default again in all five copies ->
# smoke-test must fail. All copies move together, so the x3 lockstep count passes
# and only the substitution checks can see it.
fresh
python3 - "$WORK/r" <<'PY'
import sys
r = sys.argv[1]
for rel, n in (("templates/snippets/idstack-resolve.sh", 1), ("templates/preamble.md", 4),
               ("templates/manifest-schema.md", 1)):
    p = r + "/" + rel; s = open(p, encoding='utf-8').read()
    old = '"${CLAUDE_PLUGIN_ROOT}"'
    assert s.count(old) == n, '%s: anchor count %d' % (rel, s.count(old))
    s = s.replace(old, '"${CLAUDE_PLUGIN_ROOT:-}"')
    open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "the resolve chain gives the plugin root a default again" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 51b. Only the longhand copy in manifest-schema.md gets the ":-" default again ->
# smoke-test must fail. The x3 count and the substitution run read only the
# preamble's copies, so only the repo-wide grep sees this copy.
fresh
python3 - "$WORK/r/templates/manifest-schema.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = 'for _p in "${CLAUDE_PLUGIN_ROOT}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do'
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, 'for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "the manifest-schema resolve chain gives the plugin root a default" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 51c. learn's check step folds a missing checker into the python3 token again ->
# smoke-test must fail. The step still calls the checker, so the count of check
# steps passes, and only the missing-checker run sees it.
fresh
python3 - "$WORK/r/skills/learn/SKILL.md.tmpl" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = ('if [ ! -x "$_IDSTACK/bin/idstack-ste-check" ]; then echo "STE_CHECK_MISSING: $_IDSTACK"; '
       'elif ! command -v python3 >/dev/null 2>&1; then echo "STE_CHECK_UNAVAILABLE"; '
       'else "$_IDSTACK/bin/idstack-ste-check" ".idstack/learnings-export.md"; fi')
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, 'if [ -x "$_IDSTACK/bin/idstack-ste-check" ] && command -v python3 >/dev/null 2>&1; '
                   'then "$_IDSTACK/bin/idstack-ste-check" ".idstack/learnings-export.md"; '
                   'else echo "STE_CHECK_UNAVAILABLE"; fi', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "a check step folds a missing checker into the python3 token" "$WORK/r/test/smoke-test.sh" "$WORK/r"
````

Run: `bash -n test/mutation-test.sh && echo ok`
Expected: `ok`.

- [ ] **Step 9: Commit**

```bash
git add templates/snippets/idstack-resolve.sh templates/preamble.md templates/manifest-schema.md skills CLAUDE.md test/smoke-test.sh test/mutation-test.sh
git commit -m "fix: resolve the loaded plugin and report a missing checker

Claude Code replaces only the exact token \${CLAUDE_PLUGIN_ROOT} in skill
text and never sets it in the Bash shell. The \":-\" form was never
replaced, so every skill ran the newest cached install, a stale one on
directory-marketplace and --plugin-dir setups. Check steps now print
STE_CHECK_MISSING with the path when that install has no checker.
Mutations 51a-51c guard the fix.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The report folder comes from the session's course title

**Why:**
- **needs-analysis.** Step 6 (Generate Report) reads `project_name` from `.idstack/project.json` to build the export folder slug. Step 7 is the first step that writes the manifest. On a first run the slug is `untitled-course`, but every later skill writes to `exports/<real-slug>/`. `bin/idstack-status` and the pipeline dashboard then miss the needs-analysis report.
- **course-import.** It has the same bug. Step 5 makes the report "before writing the manifest", and Step 6 writes `project_name`. A first import usually has no manifest, so it hits more often.

The fix takes the slug from the course title of the session. That is the same text that the manifest step then writes as `project_name`. The steps are not reordered, because `report_path` goes into the single manifest write and other step text refers to step numbers. Both skills keep Read-modify-Write, as `CLAUDE.md` requires.

The title goes through a top-level `IFS= read -r … <<'IDSTACK_PROJECT_NAME'` heredoc, not through `$(cat <<…)`. Inside `$(…)`, bash 3.2 fails on a title with an apostrophe.

**Files:**
- Modify: `skills/needs-analysis/SKILL.md.tmpl` (Step 6 slug block, Step 7 list)
- Modify: `skills/course-import/SKILL.md.tmpl` (Step 5 slug block, Step 6 `project_name` bullet)
- Modify: `test/smoke-test.sh` (after the `learning_preferences_note has the same words…` check), `test/mutation-test.sh` (cases 52a–52b)
- Regenerate: `skills/needs-analysis/SKILL.md`, `skills/course-import/SKILL.md`

**Interfaces:**
- Produces: in both templates, exactly one bash block that calls `idstack-slugify`. That block contains `<project name>` and not `.idstack/project.json`. The smoke check and mutations 52a–52b depend on this.

- [ ] **Step 1: Write the failing regression check**

In `test/smoke-test.sh`, directly after the line `check "learning_preferences_note has the same words in manifest-schema.md and needs-analysis" "python3 -c '$NOTE_SYNC_PY' '$IDSTACK_DIR'"`, insert:

````bash
# needs-analysis and course-import write project_name, and they write the
# report before the manifest. A slug read from the manifest at that point is
# empty on a first run: the report went to exports/untitled-course/ and every
# later skill wrote to exports/<real-slug>/. The slug must come from the
# course title of the session, the same text the skill then writes as project_name.
SLUG_SOURCE_PY='import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
blocks = [b for b in re.findall(r"```bash\n(.*?)```", s, re.S) if "idstack-slugify" in b]
ok = len(blocks) == 1 and ".idstack/project.json" not in blocks[0] and "<project name>" in blocks[0]
sys.exit(0 if ok else 1)'
for skill in needs-analysis course-import; do
  check "$skill takes the report slug from the course title, not the manifest it writes later" "python3 -c '$SLUG_SOURCE_PY' '$IDSTACK_DIR/skills/$skill/SKILL.md.tmpl'"
done
````

- [ ] **Step 2: Run it and see it fail**

Run: `./test/smoke-test.sh 2>&1 | grep -E "FAIL|Results"`
Expected: exactly two FAILs, `needs-analysis takes the report slug from the course title, not the manifest it writes later` and `course-import takes the report slug from the course title, not the manifest it writes later`.

- [ ] **Step 3: Change the slug blocks and tie `project_name` to them**

````bash
python3 - <<'PY'
import io
def edit(path, old, new):
    s = io.open(path, encoding="utf-8").read()
    assert s.count(old) == 1, "%s: anchor occurs %d times" % (path, s.count(old))
    io.open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
edit("skills/needs-analysis/SKILL.md.tmpl",
'Generate an HTML report so the designer has a single document to read. The report follows the **visual contract** in `templates/report.html.tmpl` (the skeleton) and the **content contract** in `templates/report-format.md` (severity ordering, citation format, what each placeholder must carry).\n\n```bash\n{{IDSTACK_RESOLVE}}\n# Compute the course slug from project_name and prepare the export folder.\n_PROJECT_NAME=$(python3 -c "import json; print(json.load(open(\'.idstack/project.json\')).get(\'project_name\',\'\'))" 2>/dev/null || echo "")\n_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")',
'Generate an HTML report so the designer has a single document to read. The report follows the **visual contract** in `templates/report.html.tmpl` (the skeleton) and the **content contract** in `templates/report-format.md` (severity ordering, citation format, what each placeholder must carry).\n\nIn this command, replace `<project name>` with the course title from Step 1. Then run the command.\n\n```bash\n{{IDSTACK_RESOLVE}}\n# Compute the course slug from this session\'s course title and prepare the export folder.\n# Do not read project_name from the manifest here. Step 7 writes it, so on a first run\n# the manifest has no name yet and the report lands in exports/untitled-course/.\nIFS= read -r _PROJECT_NAME <<\'IDSTACK_PROJECT_NAME\'\n<project name>\nIDSTACK_PROJECT_NAME\n_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")')
edit("skills/needs-analysis/SKILL.md.tmpl",
'6. If this is a new manifest, initialize ALL sections (including learning_objectives\n   and quality_review) with empty/default values so downstream skills find the\n   expected structure.',
'6. If this is a new manifest, initialize ALL sections (including learning_objectives\n   and quality_review) with empty/default values so downstream skills find the\n   expected structure.\n7. Set `project_name` to the text that you put in place of `<project name>` in\n   Step 6. The next skills use `project_name` to find the report folder.')
edit("skills/course-import/SKILL.md.tmpl",
'Before writing the manifest, generate an HTML report so the designer has a single document about what came in and where the quality flags are. The report follows the **visual contract** in `templates/report.html.tmpl` and the **content contract** in `templates/report-format.md`.\n\n```bash\n{{IDSTACK_RESOLVE}}\n# Compute the course slug from project_name and prepare the export folder.\n_PROJECT_NAME=$(python3 -c "import json; print(json.load(open(\'.idstack/project.json\')).get(\'project_name\',\'\'))" 2>/dev/null || echo "")\n_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")',
'Before writing the manifest, generate an HTML report so the designer has a single document about what came in and where the quality flags are. The report follows the **visual contract** in `templates/report.html.tmpl` and the **content contract** in `templates/report-format.md`.\n\nIn this command, replace `<project name>` with the course title from the import. Then run the command.\n\n```bash\n{{IDSTACK_RESOLVE}}\n# Compute the course slug from this session\'s course title and prepare the export folder.\n# Do not read project_name from the manifest here. Step 6 writes it, so on a first import\n# the manifest has no name yet and the report lands in exports/untitled-course/.\nIFS= read -r _PROJECT_NAME <<\'IDSTACK_PROJECT_NAME\'\n<project name>\nIDSTACK_PROJECT_NAME\n_SLUG=$("$_IDSTACK/bin/idstack-slugify" "$_PROJECT_NAME" 2>/dev/null || echo "untitled-course")')
edit("skills/course-import/SKILL.md.tmpl",
'- `project_name` — from course title',
'- `project_name` — from course title. Use the text that you put in place of `<project name>` in Step 5.')
print("slug blocks updated")
PY
````

Expected: `slug blocks updated`.

- [ ] **Step 4: Regenerate and run the tests**

Run: `bin/idstack-gen-skills && ./test/smoke-test.sh 2>&1 | grep -E "FAIL|Results"`
Expected: `0 failed`.

Then prove the block works end to end in bash 3.2. Use a title that has an apostrophe. Save this as `$TMPDIR/slug-e2e.sh` and run `bash "$TMPDIR/slug-e2e.sh"`:

````bash
#!/bin/bash
C=/Users/philippossavvides/github/idstack/.claude/worktrees/feat-ste-output
D=$(mktemp -d)
cd "$D" || exit 1
BLOCK=$(python3 - "$C/skills/needs-analysis/SKILL.md" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
b = [b for b in re.findall(r"```bash\n(.*?)```", s, re.S) if "idstack-slugify" in b][0]
print(b.replace("<project name>", "Bob's Intro to Biology 101"))
PY
)
IDSTACK_HOME="$C" /bin/bash -c "$BLOCK"
echo "exit $?"
````

Expected: `Report path: .idstack/exports/bob-s-intro-to-biology-101/needs-analysis.html`, then `exit 0`. No `untitled-course`. (Verified in a dry run of this plan with GNU bash 3.2.57.)

Run: `printf 'In this command, replace `<project name>` with the course title from Step 1. Then run the command.\nSet `project_name` to the text that you put in place of `<project name>` in Step 6. The next skills use `project_name` to find the report folder.\n' | bin/idstack-ste-check --format markdown -`
Expected: `no problems`.

- [ ] **Step 5: Add mutation cases 52a–52b**

Insert this block directly before the mutation-test footer:

````bash
# 52a-52b. needs-analysis and course-import write project_name, and they write the
# report before the manifest. A slug that comes from the manifest is empty on a
# first run, so the report goes to exports/untitled-course/ and each later skill
# writes to exports/<real-slug>/. Each skill has its own case, so a check that
# only reads the first skill cannot report GUARDED.
# 52a. needs-analysis reads the report slug from the manifest again -> smoke-test must fail.
fresh
python3 - "$WORK/r/skills/needs-analysis/SKILL.md.tmpl" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "IFS= read -r _PROJECT_NAME <<'IDSTACK_PROJECT_NAME'\n<project name>\nIDSTACK_PROJECT_NAME\n"
new = '''_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")\n'''
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "needs-analysis reads the report slug from the manifest" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 52b. course-import reads the report slug from the manifest again -> smoke-test must fail.
fresh
python3 - "$WORK/r/skills/course-import/SKILL.md.tmpl" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "IFS= read -r _PROJECT_NAME <<'IDSTACK_PROJECT_NAME'\n<project name>\nIDSTACK_PROJECT_NAME\n"
new = '''_PROJECT_NAME=$(python3 -c "import json; print(json.load(open('.idstack/project.json')).get('project_name',''))" 2>/dev/null || echo "")\n'''
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "course-import reads the report slug from the manifest" "$WORK/r/test/smoke-test.sh" "$WORK/r"
````

Run: `bash -n test/mutation-test.sh && echo ok`
Expected: `ok`.

- [ ] **Step 6: Commit**

```bash
git add skills/needs-analysis skills/course-import test/smoke-test.sh test/mutation-test.sh
git commit -m "fix: name the report folder from the course title on a first run

needs-analysis and course-import read project_name from the manifest
before they write it, so a first run put the report in
exports/untitled-course/. Take the slug from the session's course title,
the same text the manifest step writes. Mutations 52a-52b guard the fix.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Citations state the tier that references.md gives them

**Why:**
- **Wrong tiers.** Four skill templates cite the two Sweller papers as T1. `evidence/references.md` files them as T5: `[CogLoad-4]` is Sweller 1994 and `[CogLoad-19]` is Sweller 2024. That is 15 wrong citations, and reports copy them. `course-builder` also has `[Multimedia-6] [CogLoad-6] [T1] [T3]`, with the tiers in swapped positions: Multimedia-6 is T3 and CogLoad-6 is T1.
- **No check.** Nothing compares skill citations with `references.md`. `test/check-evidence-cards.py` covers only the landing cards, and `test/test-evidence-labels.mjs` covers only `extension/`.
- **No correction at run time.** `bin/idstack-consensus verify` corrects a tier at run time, but needs-analysis, course-builder and learning-objectives do not call it.
- **The new checker.** The repo's rule is "a code always has its references.md tier", the same rule that `idstack-consensus` and `test-evidence-labels.mjs` apply. So a new sibling checker applies it to skills, `templates/`, `README.md` and `docs/index.html`.
- **One wording change.** `references.md` has no T1 or T2 expertise-reversal source, so the needs-analysis "so the read isn't opinion" clause is changed, not only re-tiered.

**Files:**
- Create: `test/check-citation-tiers.py` (executable)
- Modify: `skills/needs-analysis/SKILL.md.tmpl` (5 lines), `skills/course-builder/SKILL.md.tmpl` (6), `skills/course-quality-review/SKILL.md.tmpl` (1), `skills/learning-objectives/SKILL.md.tmpl` (1)
- Modify: `test/smoke-test.sh` (before `check "doc accuracy check passes"`), `test/mutation-test.sh` (cases 53a–53c), `CLAUDE.md` (Tests list), `CONTRIBUTING.md` (test table)
- Regenerate: the four matching `skills/*/SKILL.md`

**Interfaces:**
- Produces: `python3 test/check-citation-tiers.py <repo-root>`. It prints one problem per line and exits 1, or prints nothing and exits 0. It also exits 1 if it matches no citation at all, so a broken pattern cannot pass. Accepted forms: `[A-1] [T1]`, and `[A-1] [B-2] [T1]` (every code at that tier). It refuses two or more tiers after a group of codes.

- [ ] **Step 1: Create the checker**

Create `test/check-citation-tiers.py`, then run `chmod +x test/check-citation-tiers.py`:

````python
#!/usr/bin/env python3
"""Assert every "[Code-N] [Tn]" citation states the tier evidence/references.md gives it.

Skills tell the model how to cite evidence, and the reports copy those citations.
needs-analysis, course-builder, course-quality-review and learning-objectives
cited the two Sweller papers ([CogLoad-4], [CogLoad-19]) as T1, but
references.md files both as T5. A citation that claims stronger evidence than
the repo holds is the error idstack can least afford, so the tier is read from
references.md here instead of trusted. bin/idstack-consensus applies the same
rule at run time: a code in references.md always gets its references.md tier.

Forms checked, after HTML tags are removed:
  [A-1] [T1]             the code must be T1 in references.md
  [A-1] [B-2] [T1]       each code must be T1 in references.md
  [A-1] [B-2] [T1] [T3]  refused: put the tier after each code instead
Each [Code-N] must also be an entry in references.md.

Scope: skills/*/SKILL.md.tmpl, templates/, README.md and docs/index.html. The
generated SKILL.md files are left out (they repeat the templates, and
smoke-test keeps them fresh). test/test-evidence-labels.mjs checks extension/.

Usage: check-citation-tiers.py <repo-root>
Prints one line per problem and exits 1; prints nothing and exits 0 when clean.
Runs on Python 3.9 (the macOS system interpreter).
"""

import glob
import io
import os
import re
import sys

# "- [CogLoad-4] Sweller, J. (1994). ... *Learning and Instruction*. T5"
REF_RE = re.compile(r"^- \[([A-Za-z]+-\d+)\] .* (T[1-5])\s*$")
CODE_RE = re.compile(r"\[([A-Z][A-Za-z]*-\d+)\]")
# One or more codes, then one or more tiers.
GROUP_RE = re.compile(r"((?:\[[A-Z][A-Za-z]*-\d+\]\s*)+)((?:\[T[1-5]\]\s*)+)")
# The landing page shows a tier as <span class="tier tier-1">T1</span>.
TIER_SPAN_RE = re.compile(r'<span class="tier tier-[1-5]">(T[1-5])</span>')
TAG_RE = re.compile(r"<[^>]+>")


def load_refs(path):
    refs = {}
    for line in io.open(path, encoding="utf-8"):
        m = REF_RE.match(line)
        if m:
            refs[m.group(1)] = m.group(2)
    return refs


def sources(root):
    paths = glob.glob(os.path.join(root, "skills", "*", "SKILL.md.tmpl"))
    paths += glob.glob(os.path.join(root, "templates", "**", "*"), recursive=True)
    paths += [os.path.join(root, "README.md"), os.path.join(root, "docs", "index.html")]
    return sorted(p for p in paths if os.path.isfile(p))


def plain(line):
    line = TIER_SPAN_RE.sub(r"[\1]", line)
    return TAG_RE.sub("", line).replace("&nbsp;", " ")


def main():
    if len(sys.argv) != 2:
        print("usage: check-citation-tiers.py <repo-root>")
        return 2
    root = sys.argv[1]
    refs_path = os.path.join(root, "evidence", "references.md")
    if not os.path.isfile(refs_path):
        print("missing file: %s" % refs_path)
        return 1
    refs = load_refs(refs_path)
    if not refs:
        print("no '- [Code-N] ... Tn' entries found in evidence/references.md")
        return 1

    problems = []
    cited = 0
    for path in sources(root):
        rel = os.path.relpath(path, root)
        lines = io.open(path, encoding="utf-8").read().split("\n")
        for n, raw in enumerate(lines, 1):
            line = plain(raw)
            where = "%s:%d" % (rel, n)
            for code in CODE_RE.findall(line):
                if code not in refs:
                    problems.append("%s: [%s] is not in evidence/references.md" % (where, code))
            for m in GROUP_RE.finditer(line):
                codes = CODE_RE.findall(m.group(1))
                tiers = re.findall(r"T[1-5]", m.group(2))
                cited += 1
                if len(tiers) > 1:
                    problems.append(
                        "%s: %s gives more than one tier. Put the tier after each code."
                        % (where, m.group(0).strip())
                    )
                    continue
                for code in codes:
                    if code in refs and refs[code] != tiers[0]:
                        problems.append(
                            "%s: [%s] is %s in evidence/references.md, not %s"
                            % (where, code, refs[code], tiers[0])
                        )

    # A pattern that stops matching would make every check above vacuous.
    if cited == 0:
        problems.append("no '[Code-N] [Tn]' citations found; the checker matched nothing")

    for line in problems:
        print(line)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
````

- [ ] **Step 2: Wire it into smoke-test**

In `test/smoke-test.sh`, replace the anchor:

````bash
check "doc accuracy check passes" "python3 '$IDSTACK_DIR/test/check-doc-accuracy.py' '$IDSTACK_DIR'"
````

with:

````bash
# Skills and templates cite evidence as "[Code-N] [Tn]", and the reports copy
# those citations. Four skills cited the two Sweller papers ([CogLoad-4],
# [CogLoad-19]) as T1, but references.md files both as T5. The tier is read
# from the reference file, as for the cards above. test-evidence-labels.mjs
# checks the extension. Same python3 guard and crash handling as the cards.
TIER_DRIFT=""
if command -v python3 &>/dev/null; then
  TIER_DRIFT="$(python3 "$IDSTACK_DIR/test/check-citation-tiers.py" "$IDSTACK_DIR" 2>&1)" \
    || TIER_DRIFT="citation-tier checker failed:
$TIER_DRIFT"
  check "skill and template citations state their evidence/references.md tier" \
    "if [ -n \"\$TIER_DRIFT\" ]; then printf '%s\n' \"\$TIER_DRIFT\"; false; fi"
fi

check "doc accuracy check passes" "python3 '$IDSTACK_DIR/test/check-doc-accuracy.py' '$IDSTACK_DIR'"
````

- [ ] **Step 3: Run the checker and see it fail**

Run: `python3 test/check-citation-tiers.py .; echo "exit $?"`
Expected: `exit 1` and exactly these 16 lines. Line numbers can be different by a few lines after Tasks 2–3. The files, codes and tiers must match.

````text
skills/course-builder/SKILL.md.tmpl:55: [CogLoad-4] is T5 in evidence/references.md, not T1
skills/course-builder/SKILL.md.tmpl:63: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/course-builder/SKILL.md.tmpl:89: [CogLoad-4] is T5 in evidence/references.md, not T1
skills/course-builder/SKILL.md.tmpl:89: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/course-builder/SKILL.md.tmpl:403: [CogLoad-4] is T5 in evidence/references.md, not T1
skills/course-builder/SKILL.md.tmpl:403: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/course-builder/SKILL.md.tmpl:411: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/course-builder/SKILL.md.tmpl:427: [Multimedia-6] [CogLoad-6] [T1] [T3] gives more than one tier. Put the tier after each code.
skills/course-quality-review/SKILL.md.tmpl:505: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/learning-objectives/SKILL.md.tmpl:214: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/needs-analysis/SKILL.md.tmpl:40: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/needs-analysis/SKILL.md.tmpl:238: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/needs-analysis/SKILL.md.tmpl:307: [CogLoad-4] is T5 in evidence/references.md, not T1
skills/needs-analysis/SKILL.md.tmpl:311: [CogLoad-19] is T5 in evidence/references.md, not T1
skills/needs-analysis/SKILL.md.tmpl:343: [CogLoad-4] is T5 in evidence/references.md, not T1
skills/needs-analysis/SKILL.md.tmpl:343: [CogLoad-19] is T5 in evidence/references.md, not T1
````

Run: `/usr/bin/python3 test/check-citation-tiers.py . | wc -l`
Expected: `16`. This proves that the checker runs on Python 3.9.

- [ ] **Step 4: Correct the citations**

````bash
python3 - <<'PY'
import io
EDITS = [
    ('skills/needs-analysis/SKILL.md.tmpl', [
        ('  What helps novices hurts experts (expertise reversal effect) [CogLoad-19] [T1].',
         '  What helps novices hurts experts (expertise reversal effect) [CogLoad-19] [T5].'),
        ('   [CogLoad-19] [T1]. The entire sequencing, scaffolding, and assessment strategy',
         '   [CogLoad-19] [T5]. The entire sequencing, scaffolding, and assessment strategy'),
        ('  structured guidance [CogLoad-4] [T1]',
         '  structured guidance [CogLoad-4] [T5]'),
        ('  avoid redundant information that adds extraneous cognitive load [CogLoad-19] [T1]',
         '  avoid redundant information that adds extraneous cognitive load [CogLoad-19] [T5]'),
        ("Cite the expertise-reversal evidence so the read isn't opinion: `[CogLoad-4] [T1]` for novices; `[CogLoad-19] [T1]` for advanced; `[Learner-16] [T1]` for mixed.",
         'Cite the expertise-reversal evidence at its references.md tier: `[CogLoad-4] [T5]` for novices; `[CogLoad-19] [T5]` for advanced; `[Learner-16] [T1]` for mixed.'),
    ]),
    ('skills/course-builder/SKILL.md.tmpl', [
        ('  within modules and the progression of complexity across a course [CogLoad-4] [T1].',
         '  within modules and the progression of complexity across a course [CogLoad-4] [T5].'),
        ("  adapted to the audience's expertise level, not generated one-size-fits-all\n  [CogLoad-19] [T1].",
         "  adapted to the audience's expertise level, not generated one-size-fits-all\n  [CogLoad-19] [T5]."),
        ('  that activate existing schemas. Module activities must reflect this distinction\n  [CogLoad-4] [CogLoad-19] [T1].',
         '  that activate existing schemas. Module activities must reflect this distinction\n  [CogLoad-4] [CogLoad-19] [T5].'),
        ('**Novice learners** [CogLoad-4] [CogLoad-19] [T1]:',
         '**Novice learners** [CogLoad-4] [CogLoad-19] [T5]:'),
        ('**Advanced learners** [CogLoad-19] [T1]:',
         '**Advanced learners** [CogLoad-19] [T5]:'),
        ('**Segmenting and spacing** [Multimedia-6] [CogLoad-6] [T1] [T3]:',
         '**Segmenting and spacing** [Multimedia-6] [T3] [CogLoad-6] [T1]:'),
    ]),
    ('skills/course-quality-review/SKILL.md.tmpl', [
        ('**Evidence:** [CogLoad-19] [T1]',
         '**Evidence:** [CogLoad-19] [T5]'),
    ]),
    ('skills/learning-objectives/SKILL.md.tmpl', [
        ('  already have this knowledge [CogLoad-19] [T1]. Recommend starting at apply or higher.',
         '  already have this knowledge [CogLoad-19] [T5]. Recommend starting at apply or higher.'),
    ]),
]
for path, pairs in EDITS:
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, "%s: %r occurs %d times" % (path, old, s.count(old))
        s = s.replace(old, new, 1)
    io.open(path, "w", encoding="utf-8").write(s)
print("citations corrected")
PY
````

Expected: `citations corrected`. Leave `test/fixtures/ste/clean-report.html` and `test/test-ste-check.py` alone. Their T1 citations are word-count test data for the STE checker, and the tier checker does not read `test/`.

- [ ] **Step 5: Document the checker**

In `CLAUDE.md`, after the line `python3 test/check-evidence-cards.py . # Verifies landing page evidence cards match evidence/references.md`, add:

```text
python3 test/check-citation-tiers.py . # Verifies each [Code-N] [Tn] in skills, templates, README and landing page has its references.md tier
```

In `CONTRIBUTING.md`, after the row `| `python3 test/check-evidence-cards.py .` | Verifies landing page evidence card study counts and tier ranges against `evidence/references.md` |`, add:

```text
| `python3 test/check-citation-tiers.py .` | Verifies that each `[Code-N] [Tn]` citation in the skill templates, `templates/`, README and landing page states the tier that `evidence/references.md` gives that code. `test/smoke-test.sh` runs it |
```

- [ ] **Step 6: Regenerate and run the tests**

Run: `bin/idstack-gen-skills && python3 test/check-citation-tiers.py .; echo "exit $?"`
Expected: no problem lines, `exit 0`.

Run: `./test/smoke-test.sh 2>&1 | grep -E "FAIL|Results"; python3 test/check-doc-accuracy.py . && echo doc-ok`
Expected: `0 failed`, `doc-ok`.

- [ ] **Step 7: Add mutation cases 53a–53c**

Insert this block directly before the mutation-test footer:

````bash
# 53a-53c. Skills cite evidence as "[Code-N] [Tn]" and the reports copy the
# citations. Four skills cited the two Sweller papers ([CogLoad-4], [CogLoad-19])
# as T1, but references.md files both as T5. check-citation-tiers.py reads each
# tier from references.md; each case puts back one wrong form.
# 53a. needs-analysis cites [CogLoad-19] as T1 again -> smoke-test must fail.
fresh
python3 - "$WORK/r/skills/needs-analysis/SKILL.md.tmpl" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "(expertise reversal effect) [CogLoad-19] [T5].\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "(expertise reversal effect) [CogLoad-19] [T1].\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "needs-analysis cites [CogLoad-19] as T1" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 53b. A group of codes with one tier claims T1 for two T5 papers -> smoke-test
# must fail. Each code in the group must be at the tier of the group.
fresh
python3 - "$WORK/r/skills/course-builder/SKILL.md.tmpl" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "**Novice learners** [CogLoad-4] [CogLoad-19] [T5]:\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "**Novice learners** [CogLoad-4] [CogLoad-19] [T1]:\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "course-builder cites a group of T5 papers as T1" "$WORK/r/test/smoke-test.sh" "$WORK/r"

# 53c. Two codes are followed by two tiers in the wrong order again -> smoke-test
# must fail. The checker refuses this form, because the order of the tiers does
# not show which tier belongs to which code.
fresh
python3 - "$WORK/r/skills/course-builder/SKILL.md.tmpl" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
old = "**Segmenting and spacing** [Multimedia-6] [T3] [CogLoad-6] [T1]:\n"
assert s.count(old) == 1, 'anchor not unique: %d' % s.count(old)
s = s.replace(old, "**Segmenting and spacing** [Multimedia-6] [CogLoad-6] [T1] [T3]:\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY
regen
expect_fail "course-builder gives two codes two tiers in one group" "$WORK/r/test/smoke-test.sh" "$WORK/r"
````

Run: `bash -n test/mutation-test.sh && echo ok`
Expected: `ok`.

- [ ] **Step 8: Commit**

```bash
git add test/check-citation-tiers.py skills CLAUDE.md CONTRIBUTING.md test/smoke-test.sh test/mutation-test.sh
git commit -m "fix: cite the Sweller papers at their references.md tier

Four skills cited [CogLoad-4] and [CogLoad-19] as T1, but references.md
files both as T5, and course-builder gave two codes swapped tiers. The
new test/check-citation-tiers.py reads each tier from references.md, and
smoke-test runs it. Mutations 53a-53c guard the fix.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Record the smoke total and run every suite

**Files:**
- Modify: `CLAUDE.md` (the smoke-test assertion count on the `./test/smoke-test.sh` line)

- [ ] **Step 1: Measure the real smoke total**

Run from this worktree, with no argument: `./test/smoke-test.sh 2>&1 | grep Results`
Expected: `Results: N/N passed, 0 failed`. N is about 401: 384, plus 1 (Task 1), 13 (Task 2), 2 (Task 3) and 1 (Task 4). Use the measured N, not the arithmetic.

- [ ] **Step 2: Write N into CLAUDE.md**

In `CLAUDE.md`, replace `./test/smoke-test.sh              # 384 assertions:` with the same text and N in place of 384. Run `python3 test/check-doc-accuracy.py . && echo doc-ok`.
Expected: `doc-ok`.

- [ ] **Step 3: Run every suite**

```bash
./test/integration-test.sh 2>&1 | tail -1
./test/test-setup.sh 2>&1 | tail -1
./test/test-doctor.sh 2>&1 | tail -1
./test/test-status.sh 2>&1 | tail -1
./test/test-preamble-python.sh 2>&1 | tail -1
./test/test-extension.sh 2>&1 | tail -1
python3 test/test-ste-check.py 2>&1 | tail -1
/usr/bin/python3 test/check-citation-tiers.py . && echo tiers-ok-3.9
python3 test/check-evidence-cards.py . && echo cards-ok
```

Expected: every suite passes, and `tiers-ok-3.9` and `cards-ok` print.

- [ ] **Step 4: Run the full mutation suite**

Run: `./test/mutation-test.sh 2>&1 | tail -15` (about 15 minutes. Run it in the background and wait for it.)
Expected: `NOT guarded: 0` and `skipped: 0`. The guarded count is 129 + 9 = 138. These new labels each show `GUARDED`:
- `the rendered landing test ignores a Chrome that stops at startup`
- `the resolve chain gives the plugin root a default again`
- `the manifest-schema resolve chain gives the plugin root a default`
- `a check step folds a missing checker into the python3 token`
- `needs-analysis reads the report slug from the manifest`
- `course-import reads the report slug from the manifest`
- `needs-analysis cites [CogLoad-19] as T1`
- `course-builder cites a group of T5 papers as T1`
- `course-builder gives two codes two tiers in one group`

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record the smoke-test total after the follow-up fixes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: PR, CI on Linux, merge

Two parts of this plan are verified only on macOS:
- Chrome printing `DevTools listening on` through the `/usr/bin/google-chrome` wrapper.
- The `awk`, `sed` and `env -u` calls in Task 2's smoke block on GNU tools.

A green badge alone does not prove them. Read the logs.

- [ ] **Step 1: Push and open the PR**

Push `fix/post-ste-followups` and open a PR against `main`. Run `bin/idstack-ste-check --format markdown` on the PR body before you create the PR. The body must say:
- **What each task fixes.**
- **Behavior change.** In plugin runs, the plugin root now wins over `IDSTACK_HOME`. The documented order is the same, but before, the first entry was always empty.
- **Who was affected.** A GitHub-marketplace install was not affected, because its newest cache directory is its installed version. A directory marketplace or `--plugin-dir` ran the stale cached copy. So no release is needed.
- **Manual step after merge.** The maintainer's directory marketplace at `/Users/philippossavvides/github/idstack` is behind `main` and has no `bin/idstack-ste-check`. Until someone runs `git pull` there, check steps print `STE_CHECK_MISSING: /Users/philippossavvides/github/idstack`. This is the intended loud result.

- [ ] **Step 2: Read the CI logs, not just the badges**

Wait for all checks: two ubuntu legs (3.9, 3.12), macOS 3.12, mutation, lint. For each ubuntu test job, run `gh run view <run-id> --log | grep -E "rendered landing|plugin root|no checker|Results:"`.
Expected:
- `PASS: rendered landing page tests pass`
- `PASS: rendered landing test reports why Chrome stopped at startup`
- `PASS: the substituted plugin root wins over a stale cache install`
- 11 `PASS: … check steps name an install that has no checker` lines
- `Results: N/N passed`, with N equal to the number in `CLAUDE.md`

The mutation job must show `NOT guarded: 0`.

If the rendered test fails on ubuntu with `did not open a debugging port within 30s`, the stderr tail in the message shows why. Stop and report. Do not add a retry.

- [ ] **Step 3: Ask before you merge**

The `main` ruleset requires one approving review. Ask the user to choose: admin merge (`gh pr merge <n> --merge --admin`), auto-merge, or leave open. Approval for an earlier PR does not carry over. After a merge, delete the remote branch with `git push origin --delete fix/post-ste-followups`. Do not use `--delete-branch`, because this worktree cannot check out `main`.

- [ ] **Step 4: Tell the user the manual step**

Tell the user to run `git pull` in `/Users/philippossavvides/github/idstack` so their sessions get the checker.
