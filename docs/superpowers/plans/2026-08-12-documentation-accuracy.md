# Documentation Accuracy & Automated Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Perform a comprehensive audit and text reconciliation across all documentation surfaces in `idstack` and build automated validation gates in `test/smoke-test.sh` and `test/mutation-test.sh` to ensure docs remain 100% accurate.

**Architecture:** A standalone Python validator script `test/check-doc-accuracy.py` verifies version parity, binary/flag existence, template matching, and relative link validity. It is integrated into `smoke-test.sh` as a core check and guarded by `mutation-test.sh`.

**Tech Stack:** Python 3 (standard library `os`, `sys`, `re`, `html`), Bash.

## Global Constraints
- Version floor: Python 3.9 compatible (macOS system Python).
- Zero external Python dependencies (standard library only).
- All command options and binary paths referenced in docs must exist in the repo.
- Version string `3.4.0.1` and Manifest Schema version `1.4` must match across all files.

---

### Task 1: Create Validator Script (`test/check-doc-accuracy.py`) and Integrate into Smoke Test

**Files:**
- Create: `test/check-doc-accuracy.py`
- Modify: `test/smoke-test.sh`

**Interfaces:**
- Consumes: Repository root directory argument `sys.argv[1]`
- Produces: CLI exit code 0 if all doc assertions pass, exit code 1 with error diagnostic lines if any doc check fails.

- [ ] **Step 1: Write failing test case in smoke-test.sh for doc accuracy**

Modify `test/smoke-test.sh` to include the check:
```bash
check "doc accuracy check passes" python3 test/check-doc-accuracy.py "$REPO_ROOT"
```

- [ ] **Step 2: Run smoke-test.sh to verify it fails**

Run: `GIT_CONFIG_GLOBAL=/dev/null bash test/smoke-test.sh`
Expected: FAIL with "python3: test/check-doc-accuracy.py: No such file or directory"

- [ ] **Step 3: Implement `test/check-doc-accuracy.py`**

Create `test/check-doc-accuracy.py` with Python 3 standard library:
```python
#!/usr/bin/env python3
"""Validate documentation accuracy across version strings, binaries, flags, and links.

Usage: check-doc-accuracy.py <repo-root>
Prints diagnostic lines and exits 1 on mismatch; prints nothing and exits 0 when clean.
"""

import os
import re
import sys


def check_versions(root, problems):
    v_file = os.path.join(root, "VERSION")
    if not os.path.isfile(v_file):
        problems.append("missing VERSION file")
        return
    with open(v_file, "r") as f:
        version = f.read().strip()

    plugin_json = os.path.join(root, ".claude-plugin", "plugin.json")
    if os.path.isfile(plugin_json):
        with open(plugin_json, "r") as f:
            content = f.read()
            if ('"version": "%s"' % version) not in content and ('"version": "%s"' % version) not in content.replace(".0", ""):
                problems.append(".claude-plugin/plugin.json version does not match VERSION (%s)" % version)

    readme = os.path.join(root, "README.md")
    if os.path.isfile(readme):
        with open(readme, "r") as f:
            content = f.read()
            if ("v%s" % version) not in content:
                problems.append("README.md does not reference current version v%s" % version)


def check_binaries_and_flags(root, problems):
    readme = os.path.join(root, "README.md")
    if not os.path.isfile(readme):
        return
    with open(readme, "r") as f:
        text = f.read()

    # Look for bin/ paths referenced in README
    bin_refs = set(re.findall(r"\bbin/idstack-[a-z-]+", text))
    for ref in bin_refs:
        rel_path = os.path.join(root, ref)
        if not os.path.isfile(rel_path):
            problems.append("README.md references missing binary: %s" % ref)


def main():
    if len(sys.argv) != 2:
        print("usage: check-doc-accuracy.py <repo-root>")
        return 2
    root = sys.argv[1]
    problems = []

    check_versions(root, problems)
    check_binaries_and_flags(root, problems)

    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
```
Make executable: `chmod +x test/check-doc-accuracy.py`.

- [ ] **Step 4: Run smoke-test.sh to verify it passes**

Run: `GIT_CONFIG_GLOBAL=/dev/null bash test/smoke-test.sh`
Expected: PASS

- [ ] **Step 5: Commit Task 1**

```bash
git add test/check-doc-accuracy.py test/smoke-test.sh
git commit -m "feat: add check-doc-accuracy validator and integrate into smoke test"
```

---

### Task 2: Audit & Reconcile User & Public Documentation (`README.md`, `docs/index.html`, `PRIVACY.md`)

**Files:**
- Modify: `README.md`
- Modify: `docs/index.html`
- Modify: `PRIVACY.md`
- Modify: `test/check-doc-accuracy.py`

- [ ] **Step 1: Write test in `check-doc-accuracy.py` verifying landing page version & setup script flags**

Add check in `check-doc-accuracy.py`:
```python
def check_public_surfaces(root, problems):
    index_html = os.path.join(root, "docs", "index.html")
    if os.path.isfile(index_html):
        with open(index_html, "r") as f:
            content = f.read()
            if "v3.4" not in content and "v3.4.0.1" not in content:
                problems.append("docs/index.html carries stale version string")
```

- [ ] **Step 2: Run validator to verify checks execute**

Run: `python3 test/check-doc-accuracy.py .`
Expected: 0 output (clean)

- [ ] **Step 3: Audit and fix any text inconsistencies in README.md, docs/index.html, and PRIVACY.md**

Check `README.md` for setup options, CLI arguments, and file paths. Ensure single-host Claude Code instructions are consistent everywhere.

- [ ] **Step 4: Run smoke-test.sh to verify green**

Run: `GIT_CONFIG_GLOBAL=/dev/null bash test/smoke-test.sh`
Expected: PASS

- [ ] **Step 5: Commit Task 2**

```bash
git add README.md docs/index.html PRIVACY.md test/check-doc-accuracy.py
git commit -m "docs: reconcile public documentation surfaces and update accuracy assertions"
```

---

### Task 3: Audit & Reconcile Developer, Architecture & Planning Documentation (`CLAUDE.md`, `DESIGN.md`, `CONTRIBUTING.md`, `TODOS.md`, `ROADMAP.md`)

**Files:**
- Modify: `CLAUDE.md`
- Modify: `DESIGN.md`
- Modify: `CONTRIBUTING.md`
- Modify: `TODOS.md`
- Modify: `ROADMAP.md`

- [ ] **Step 1: Audit CLAUDE.md and CONTRIBUTING.md for test execution commands and version references**

Verify commands:
- `bash test/smoke-test.sh`
- `bash test/mutation-test.sh`
- `python3 test/check-evidence-cards.py .`
- `python3 test/check-doc-accuracy.py .`

- [ ] **Step 2: Audit DESIGN.md for architecture alignment**

Confirm plugin structure details match `.claude-plugin/plugin.json` and single-host Claude Code layout.

- [ ] **Step 3: Reconcile TODOS.md and ROADMAP.md task items**

Ensure completed tasks from recent versions (v3.4.0.0, v3.4.0.1) are accurately reflected and mutation counts match current numbers.

- [ ] **Step 4: Run smoke-test.sh to verify clean run**

Run: `GIT_CONFIG_GLOBAL=/dev/null bash test/smoke-test.sh`
Expected: PASS

- [ ] **Step 5: Commit Task 3**

```bash
git add CLAUDE.md DESIGN.md CONTRIBUTING.md TODOS.md ROADMAP.md
git commit -m "docs: reconcile developer, design, and roadmap documentation"
```

---

### Task 4: Add Mutation Test Protections & Final Suite Run

**Files:**
- Modify: `test/mutation-test.sh`

- [ ] **Step 1: Add mutation case in `test/mutation-test.sh` for doc version mismatch**

Add mutation 25:
```bash
mutate "VERSION/README.md version mismatch" \
  "sed -i.bak 's/v3.4.0.1/v9.9.9.9/g' README.md" \
  "smoke-test fails when README version is wrong"
```

- [ ] **Step 2: Add mutation case in `test/mutation-test.sh` for hallucinated binary in README**

Add mutation 26:
```bash
mutate "hallucinated binary reference in README" \
  "sed -i.bak 's/bin\/idstack-status/bin\/idstack-fake-binary/g' README.md" \
  "smoke-test fails when README names a non-existent binary"
```

- [ ] **Step 3: Run mutation-test.sh to verify all mutations pass**

Run: `GIT_CONFIG_GLOBAL=/dev/null bash test/mutation-test.sh`
Expected: `guarded: 26 NOT guarded: 0 skipped: 0`

- [ ] **Step 4: Commit Task 4**

```bash
git add test/mutation-test.sh
git commit -m "test: add mutation suite coverage for doc accuracy validator"
```
