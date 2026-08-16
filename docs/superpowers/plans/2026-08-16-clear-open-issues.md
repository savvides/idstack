# Clear Open Repository Issues (#60, #61, #62) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all three open GitHub issues in the repo: #60 (atomic deletion in `idstack-learnings-delete` with permission preservation), #61 (local-over-global search precedence in `idstack-learnings-search`), and #62 (fill remaining test coverage gaps for slugify stdin/emoji, migrate fallback on malformed JSON, and comment accuracy).

**Architecture:** Implement atomic file writes using `tempfile.mkstemp` + `shutil.copymode` + `os.replace` in `idstack-learnings-delete`; reorder source search streams in `idstack-learnings-search` so local learnings consistently take precedence over global learnings across Python and shell fallback paths; add targeted regression tests to `test/integration-test.sh` and `test/smoke-test.sh`.

**Tech Stack:** Bash, Python 3, Shell test harnesses (`smoke-test.sh`, `integration-test.sh`).

---

### Task 1: Atomic Deletion and Exit Code Comment in `idstack-learnings-delete` (Issues #60 & #62.4)

**Files:**
- Modify: `bin/idstack-learnings-delete:1-47`
- Modify: `test/integration-test.sh:212-235`

- [ ] **Step 1: Add mode preservation test in `test/integration-test.sh`**

Modify `test/integration-test.sh` around lines 230-235 to add an assertion that `idstack-learnings-delete` preserves file mode (e.g. `chmod 600`):

```bash
# Setup data for delete tests
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key1","insight":"one"}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key2","insight":"two"}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key1","insight":"three"}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key3_mode","insight":"four"}'
chmod 600 .idstack/learnings.jsonl

check "preserves file mode on delete (mode 600)" \
  "$IDSTACK_DIR/bin/idstack-learnings-delete key3_mode && python3 -c \"import os, stat; m = stat.S_IMODE(os.stat('.idstack/learnings.jsonl').st_mode); assert oct(m) == oct(0o600), f'Expected 0o600, got {oct(m)}'\""
```

- [ ] **Step 2: Run test to verify behavior before fix**

Run:
```bash
./test/integration-test.sh
```
Expected: Verify whether mode is retained or if atomic replacement is needed.

- [ ] **Step 3: Implement atomic replacement with `shutil.copymode` in `bin/idstack-learnings-delete` and update header comment**

Update `bin/idstack-learnings-delete`:
```bash
#!/usr/bin/env bash
# Delete a learning by key from .idstack/learnings.jsonl.
# Usage: idstack-learnings-delete <key>
# Removes exactly one entry (the most recent with that key). Exits 0 on success, 1 on error.

set -e

KEY="${1:-}"
[ -z "$KEY" ] && { echo "Usage: idstack-learnings-delete <key>" >&2; exit 1; }

LEARNINGS=".idstack/learnings.jsonl"
[ -f "$LEARNINGS" ] || { echo "No learnings file found." >&2; exit 1; }

if ! command -v python3 &>/dev/null; then
  echo "python3 required for delete." >&2
  exit 1
fi

python3 -c "
import json, os, shutil, sys, tempfile

key = sys.argv[1]
learnings_file = '$LEARNINGS'

lines = open(learnings_file).readlines()
# Find the last line with this key and remove it
found_idx = -1
for i, line in enumerate(lines):
    try:
        d = json.loads(line)
        if d.get('key') == key:
            found_idx = i
    except:
        pass

if found_idx == -1:
    print(f'No learning found with key: {key}', file=sys.stderr)
    sys.exit(1)

# Remove that line
lines.pop(found_idx)

directory = os.path.dirname(os.path.abspath(learnings_file)) or '.'
fd, tmp_path = tempfile.mkstemp(prefix='.learnings-delete.', dir=directory, suffix='.tmp')
try:
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    shutil.copymode(learnings_file, tmp_path)
    os.replace(tmp_path, learnings_file)
except Exception as exc:
    try:
        os.unlink(tmp_path)
    except OSError:
        pass
    print(f'Failed to write learnings file {learnings_file}: {exc}', file=sys.stderr)
    sys.exit(1)

print(f'Deleted learning: {key}')
" "$KEY"
```

- [ ] **Step 4: Run integration tests to verify pass**

Run:
```bash
./test/integration-test.sh
```
Expected: PASS (all delete checks pass, including mode 600 preservation).

- [ ] **Step 5: Commit**

```bash
git add bin/idstack-learnings-delete test/integration-test.sh
git commit -m "fix(learnings): atomic delete with permissions preservation (#60, #62)"
```

---

### Task 2: Fix Cross-Project Search Precedence in `idstack-learnings-search` (Issue #61)

**Files:**
- Modify: `bin/idstack-learnings-search:30-36, 96-98`
- Modify: `test/integration-test.sh:97-133`

- [ ] **Step 1: Write failing test in `test/integration-test.sh` for local precedence ranking**

In `test/integration-test.sh` around line 105, add a check with colliding/multiple matching local and global entries to assert local learnings take precedence over global when `--limit` truncates results:

```bash
# Setup multi-entry cross-project precedence test
mkdir -p "$TEST_DIR/fake_home/.idstack/global"
cat > "$TEST_DIR/fake_home/.idstack/global/learnings.jsonl" <<'EOF'
{"skill":"review","type":"pattern","key":"g1","insight":"prec_test global 1","confidence":5}
{"skill":"review","type":"pattern","key":"g2","insight":"prec_test global 2","confidence":6}
EOF
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"review","type":"pattern","key":"l1","insight":"prec_test local 1","confidence":8}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"review","type":"pattern","key":"l2","insight":"prec_test local 2","confidence":9}'

check "cross-project: local learnings outrank global learnings on limit truncation" \
  "python3 -c \"
import subprocess, json
out = subprocess.check_output(['$IDSTACK_DIR/bin/idstack-learnings-search', '--cross-project', '--keyword', 'prec_test', '--limit', '2'], env={'HOME': '$TEST_DIR/fake_home', 'PATH': '$PATH'}).decode()
keys = [json.loads(line)['key'] for line in out.strip().splitlines() if line.strip()]
assert keys == ['l1', 'l2'], f'Expected local keys [l1, l2], got {keys}'
\""

check "cross-project: local learnings take precedence in fallback mode" \
  "python3 -c \"
import subprocess, json
out = subprocess.check_output(['$IDSTACK_DIR/bin/idstack-learnings-search', '--cross-project', '--keyword', 'prec_test', '--limit', '2'], env={'HOME': '$TEST_DIR/fake_home', 'PATH': '$TEST_DIR/nopy'}).decode()
keys = [json.loads(line)['key'] for line in out.strip().splitlines() if line.strip()]
assert keys == ['l1', 'l2'], f'Expected fallback local keys [l1, l2], got {keys}'
\""
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
./test/integration-test.sh
```
Expected: FAIL on `cross-project: local learnings outrank global learnings on limit truncation` because global items are currently appended last and take over `matches[-limit:]`.

- [ ] **Step 3: Update `bin/idstack-learnings-search` to order sources global-first, local-last**

In `bin/idstack-learnings-search`:
```bash
# Collect source files (global first if cross-project, so local comes last and takes precedence)
SOURCES=""
if [ "$CROSS_PROJECT" -eq 1 ] && [ -f "$GLOBAL_LEARNINGS" ]; then
  SOURCES="$GLOBAL_LEARNINGS"
fi
if [ -f "$LOCAL_LEARNINGS" ]; then
  SOURCES="$SOURCES $LOCAL_LEARNINGS"
fi
```
And update the comment before line 97:
```python
# Local learnings come last in sources, so matches[-limit:] gives local precedence, backfilled by global
for m in matches[-limit:]:
    print(m)
```

- [ ] **Step 4: Run integration test to verify it passes**

Run:
```bash
./test/integration-test.sh
```
Expected: PASS (all search tests pass, confirming local outranks global on limit truncation in both Python and fallback modes).

- [ ] **Step 5: Commit**

```bash
git add bin/idstack-learnings-search test/integration-test.sh
git commit -m "fix(learnings): prioritize local learnings over global in cross-project search (#61)"
```

---

### Task 3: Address Test Coverage Gaps for `idstack-slugify` and `idstack-migrate` (Issue #62 Items 2 & 3)

**Files:**
- Modify: `test/smoke-test.sh:144-154, 375-385`

- [ ] **Step 1: Add unit tests in `test/smoke-test.sh` for slugify stdin pipelines & unicode/emoji stripping**

In `test/smoke-test.sh` around lines 145-154, add assertions for:
1. Implicit stdin pipe (`echo "..." | idstack-slugify`)
2. Explicit `-` argument (`echo "..." | idstack-slugify -`)
3. Emoji and non-ASCII stripping (`idstack-slugify "Course 🚀 101: Intro to AI ✨"`)

```bash
check "idstack-slugify: implicit stdin pipeline" \
  "[ \"\$(echo 'Course via Implicit Stdin' | '$IDSTACK_DIR/bin/idstack-slugify')\" = 'course-via-implicit-stdin' ]"
check "idstack-slugify: explicit dash stdin pipeline" \
  "[ \"\$(echo 'Course via Dash Stdin' | '$IDSTACK_DIR/bin/idstack-slugify' -)\" = 'course-via-dash-stdin' ]"
check "idstack-slugify: emoji and non-ASCII characters stripped" \
  "[ \"\$('$IDSTACK_DIR/bin/idstack-slugify' 'Course 🚀 101: Intro to AI ✨')\" = 'course-101-intro-to-ai' ]"
```

- [ ] **Step 2: Add unit test in `test/smoke-test.sh` for migrate fallback on malformed JSON manifest**

In `test/smoke-test.sh` inside the `if [ -d "$FIXTURE_DIR" ] && command -v python3 &>/dev/null; then` block (around line 380):

```bash
  # Test malformed manifest cat-fallback (bin/idstack-migrate:84)
  MIG="$MIG_ROOT/malformed"; mkdir -p "$MIG"
  echo "INVALID { JSON" > "$MIG/project.json"
  check "migrate: malformed JSON falls back to raw cat and exits 0" \
    "[ \"\$('$IDSTACK_DIR/bin/idstack-migrate' '$MIG/project.json')\" = 'INVALID { JSON' ]"
```

- [ ] **Step 3: Run smoke test to verify all new assertions pass**

Run:
```bash
./test/smoke-test.sh
```
Expected: PASS (all slugify and migrate checks pass).

- [ ] **Step 4: Commit**

```bash
git add test/smoke-test.sh
git commit -m "test: add slugify stdin/emoji and migrate fallback coverage (#62)"
```

---

### Task 4: Full Suite Verification & Open Issues Closure Verification

**Files:**
- Test: `test/smoke-test.sh`
- Test: `test/integration-test.sh`
- Test: `test/test-*.sh`

- [ ] **Step 1: Run complete test suite**

Run:
```bash
./test/smoke-test.sh && ./test/integration-test.sh && for t in test/test-*.sh; do bash "$t"; done
```
Expected: PASS across all test suites with 0 failures.

- [ ] **Step 2: Verify git status and diff**

Run:
```bash
git status
```
Expected: Clean working tree with no uncommitted changes or untracked artifacts.

- [ ] **Step 3: Confirm resolution of issues #60, #61, and #62**
- Issue #60: Atomic file writes with `shutil.copymode` mode preservation implemented and verified in `idstack-learnings-delete`.
- Issue #61: Local-over-global precedence established in `idstack-learnings-search` across both Python and shell fallback paths.
- Issue #62: Covered all 4 gaps:
  - 1. Second-CLI / target isolation gap obsoleted & pinned by v3.4.0.0 Claude-Code-only invariants.
  - 2. `idstack-slugify` stdin implicit, explicit `-`, and emoji/non-ASCII tested.
  - 3. `idstack-migrate` malformed JSON cat-fallback tested.
  - 4. `idstack-learnings-delete` comment fixed to reflect actual exit codes.
