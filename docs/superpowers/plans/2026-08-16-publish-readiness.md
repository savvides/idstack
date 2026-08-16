# Publishing Readiness & Documentation Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the idstack repository and public landing page (idstack.org) for publishing release v3.5.0.0, synchronizing all documentation, version strings, changelog entries, roadmap/todos records, and landing page surfaces.

**Architecture:** Bump version to `3.5.0.0` across all metadata manifests and documentation files; draft the comprehensive `v3.5.0.0` changelog release entry covering the Chrome Extension, Canvas Crawler, Course Dossier export, Web Store packaging script, and bug fixes (#60, #61, #62); update `docs/index.html` (idstack.org) with the new release note and Chrome Extension highlights; adapt mutation test 20 to dynamically read `VERSION`; and verify all doc accuracy and test gates pass cleanly.

**Tech Stack:** HTML/CSS (idstack.org), Markdown, Python 3, Bash, Chrome Extension Manifest V3.

---

### Task 1: Version Bump & Release Notes across Core Metadata & Docs

**Files:**
- Modify: `VERSION`
- Modify: `.claude-plugin/plugin.json:1-10`
- Modify: `README.md:1-10, 180-230`
- Modify: `CHANGELOG.md:1-40`
- Modify: `CLAUDE.md:20-50`

- [ ] **Step 1: Update `VERSION` and `.claude-plugin/plugin.json` to 3.5.0.0**

Update `VERSION`:
```
3.5.0.0
```

Update `.claude-plugin/plugin.json`:
```json
{
  "name": "idstack",
  "version": "3.5.0.0",
  "description": "Evidence-based instructional design skills for Claude Code. 11 skills covering analysis, design, quality review, accessibility, and export, backed by 108 peer-reviewed studies.",
  "author": {
    "name": "Philippos Savvides"
  },
  "homepage": "https://idstack.org",
  "repository": "https://github.com/savvides/idstack",
  "license": "MIT"
}
```

- [ ] **Step 2: Add `v3.5.0.0` section to `CHANGELOG.md`**

Insert at line 3 of `CHANGELOG.md`:
```markdown
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
```

- [ ] **Step 3: Update `README.md` status badge and developer workflow commands**

In `README.md` line 3:
Update status badge to `> **Status: beta (v3.5.0.0).**`

In `README.md` under the Chrome Extension section (around line 210), document packaging:
```markdown
#### Packaging for Chrome Web Store

To create a distribution bundle:
```bash
./bin/package-extension.sh
```
Produces `build/idstack-chrome-extension-v1.0.0.zip` ready for submission to the Chrome Web Store Developer Console.
```

- [ ] **Step 4: Update `CLAUDE.md` test and command references**

In `CLAUDE.md` under `## Commands`:
Add `bin/package-extension.sh` and `./test/test-extension.sh`.

- [ ] **Step 5: Run doc accuracy checker to verify initial version consistency**

Run:
```bash
python3 test/check-doc-accuracy.py .
```
Expected: Note if `docs/index.html` mismatch is reported (will be resolved in Task 3).

- [ ] **Step 6: Commit**

```bash
git add VERSION .claude-plugin/plugin.json CHANGELOG.md README.md CLAUDE.md
git commit -m "docs: bump version to 3.5.0.0 and document Chrome extension and bug fixes"
```

---

### Task 2: Synchronize Roadmap and Todos

**Files:**
- Modify: `ROADMAP.md:1-50`
- Modify: `TODOS.md:1-40`

- [ ] **Step 1: Update `ROADMAP.md` to reflect v3.5.0.0 shipped items**

In `ROADMAP.md` under `## Recent releases`:
Add `### Chrome Extension, Course Dossier & Robustness (v3.5.0.0)` highlighting:
- Native Chrome Side Panel extension for Canvas LMS & Google Docs
- Automated background Canvas course crawler
- Course Dossier multi-page compiler & Markdown exporter
- Atomic learnings deletion with permission preservation (#60)
- Cross-project local-over-global search precedence (#61)
- Comprehensive test coverage for slugify stdin/emojis & migrate malformed manifest fallback (#62)

- [ ] **Step 2: Update `TODOS.md` marking v3.5 items complete**

In `TODOS.md`:
Mark the Chrome Extension experiment, Canvas course crawler, Course Dossier export, and open issues (#60, #61, #62) as SHIPPED in v3.5.0.0.

- [ ] **Step 3: Verify no broken links or dropped items**

Run:
```bash
python3 test/check-doc-accuracy.py .
```

- [ ] **Step 4: Commit**

```bash
git add ROADMAP.md TODOS.md
git commit -m "docs: update ROADMAP and TODOS for v3.5.0.0 release"
```

---

### Task 3: Update Landing Page for idstack.org (`docs/index.html`)

**Files:**
- Modify: `docs/index.html:40-60, 900-920, 1145-1180`

- [ ] **Step 1: Update JSON-LD softwareVersion and header version badge in `docs/index.html`**

In `docs/index.html`:
Line 45:
`"softwareVersion": "3.5.0.0",`

In nav/header version badge around line 904:
`<span>v3.5.0.0 — Claude Code &amp; Chrome Extension</span>`

- [ ] **Step 2: Add `v3.5.0.0` release card under What's New section**

In `docs/index.html` under `<section class="section" id="whats-new">` (line 1150):
```html
      <article class="release-card">
        <p class="release-meta">August 16, 2026 · v3.5.0.0</p>
        <h3>Chrome Side Panel co-pilot &amp; Course Dossier export.</h3>
        <p>For instructional designers working directly in the browser, idstack now includes a native Chrome Side Panel extension. Audit Canvas assignments, syllabi, Google Docs, and web course materials with 1-click Bloom's classification, constructive alignment reviews, and empirical citations (T1–T5) without touching the terminal.</p>
        <p>Also in this release: an automated Canvas course crawler for whole-course audits, an active Course Dossier drawer that compiles multi-page findings into synthesized institutional Markdown (<code>.md</code>) reports, atomic file writes for project learnings logs (Issue #60), and local-over-global search precedence (Issue #61).</p>
      </article>
```

- [ ] **Step 3: Verify absence of forbidden date properties**

Ensure no `dateModified` in `docs/index.html` or `<lastmod>` in `docs/sitemap.xml`.

- [ ] **Step 4: Run doc accuracy and evidence card checks**

Run:
```bash
python3 test/check-doc-accuracy.py . && python3 test/check-evidence-cards.py .
```
Expected: PASS (0 errors).

- [ ] **Step 5: Commit**

```bash
git add docs/index.html
git commit -m "docs(web): update idstack.org landing page for v3.5.0.0 release"
```

---

### Task 4: Dynamic Mutation Test Adaptation & Full Automated Verification

**Files:**
- Modify: `test/mutation-test.sh:370-380`
- Test: `test/smoke-test.sh`
- Test: `test/integration-test.sh`
- Test: `test/test-extension.sh`
- Test: `test/mutation-test.sh`

- [ ] **Step 1: Make mutation 20 in `test/mutation-test.sh` dynamically read `VERSION`**

In `test/mutation-test.sh` around lines 370-380, update mutation 20:
```bash
# 20. version string in README mutated -> smoke-test must fail
fresh
python3 - "$WORK/r" <<'PY'
import sys, os
root = sys.argv[1]
with open(os.path.join(root, "VERSION")) as vf:
    v = vf.read().strip()
p = os.path.join(root, "README.md")
s = open(p).read()
s = s.replace(f"v{v}", "v9.9.9.9")
open(p, 'w').write(s)
PY
expect_fail "version string in README mutated" "$WORK/r/test/smoke-test.sh" "$WORK/r"
```

- [ ] **Step 2: Run all test suites and validators**

Run:
```bash
python3 test/check-doc-accuracy.py . && \
python3 test/check-evidence-cards.py . && \
./test/smoke-test.sh && \
./test/integration-test.sh && \
./test/test-extension.sh && \
for t in test/test-*.sh; do bash "$t"; done
```
Expected: All suites pass with 0 failures.

- [ ] **Step 3: Run mutation tests**

Run:
```bash
./test/mutation-test.sh
```
Expected: All 24 mutations caught and verified.

- [ ] **Step 4: Commit**

```bash
git add test/mutation-test.sh
git commit -m "test: make mutation 20 dynamically read VERSION and verify all suites"
```

---

### Task 5: Final Sanity Check & Web Bundle Verification

**Files:**
- Test: `docs/index.html`
- Test: `bin/package-extension.sh`

- [ ] **Step 1: Test extension package creation**

Run:
```bash
./bin/package-extension.sh
```
Expected: `build/idstack-chrome-extension-v1.0.0.zip` created cleanly.

- [ ] **Step 2: Final git status check**

Run:
```bash
git status
```
Expected: Clean working tree.
