# Landing Page Accuracy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all 11 accuracy defects between idstack.org and the repo, and guard the two that would otherwise silently return.

**Architecture:** Five tasks, each with its own test cycle. Task 1 is a genuine red-green cycle — the new validator check fails against the current files, and deleting the two stale date fields turns it green. Tasks 2 and 3 are content edits to `docs/index.html` gated by `smoke-test.sh`. Task 4 changes what GitHub Pages publishes, verified by simulating the staging step locally before the workflow is touched. Task 5 is the full-suite sweep plus the post-merge live checks.

**Tech Stack:** Static HTML (no build step for the page), Python 3.9-compatible validators, bash test suites, GitHub Actions.

**Spec:** `superpowers/specs/2026-08-14-github-page-accuracy-design.md`. Read D1–D4 before starting; this plan implements them and does not restate their rationale.

**Branch:** `docs/landing-page-accuracy` (already created, spec already committed).

## Global Constraints

- **No new CSS, no new visual patterns, no new components.** `DESIGN.md` decisions log (2026-06-12) records the landing page as an intentional separate dark/indigo surface that no longer tracks the report token system. Every addition reuses existing classes: `.install-prose`, `.footer-links a`, `.lede`. `DESIGN.md` and `templates/assets/idstack.css` are **not** modified.
- **Skill references use the namespaced form** `/idstack:<skill>`. A bare `/pipeline` does not resolve and `smoke-test.sh` fails on one.
- **`docs/og-template.html` must stay at that exact path.** `test/smoke-test.sh:136-141` asserts it exists and lints its gradient-text fallbacks. It is removed from the published site at build time only — never moved or deleted.
- **Python must parse on 3.9** (the version macOS ships). No `match`, no PEP 604 unions, no PEP 701 f-string quote reuse.
- **Do not add a local PASS/FAIL counter to any test suite.** `test/test-helper.sh` owns `PASS`/`FAIL`/`TOTAL` and `check()`; smoke-test fails on a local counter block.
- **`README.md` is not modified.** It is already internally consistent at "30 seconds"; the page reconciles to it.
- **VERSION is `3.4.0.1`** and must keep appearing as `v3.4.0.1` in `docs/index.html` and in README's first 10 lines. Do not touch version strings.

---

### Task 1: Delete the stale date fields and guard their return

Implements spec D2 and D3. Closes findings 2 and 3.

**Files:**
- Modify: `test/check-doc-accuracy.py` (add function after `check_binaries_and_flags`, ~line 76; register in `main()`, ~line 190)
- Modify: `docs/index.html:47` (delete)
- Modify: `docs/sitemap.xml:5` (delete)
- Modify: `test/mutation-test.sh` (append mutation 22 before the summary `echo`)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `check_no_stale_dates(root, problems) -> None` in `test/check-doc-accuracy.py`. Appends strings to `problems`; returns nothing. Follows the exact signature of the four existing check functions.

- [ ] **Step 1: Write the failing check**

Add to `test/check-doc-accuracy.py`, immediately after `check_binaries_and_flags` ends (before `def check_public_surfaces`):

```python
def check_no_stale_dates(root, problems):
    """Assert two deleted date fields have not come back.

    docs/index.html carried a JSON-LD "dateModified" and docs/sitemap.xml a
    <lastmod>. Both were deleted rather than corrected: no CI check can assert
    such a date is current without failing on commits that did not introduce
    the defect (a PR left open a week, a merge dated after the docs edit), and
    a check that cries wolf is one people learn to bypass. Absence is the only
    assertion here that cannot false-positive.

    See superpowers/specs/2026-08-14-github-page-accuracy-design.md, D2 and D3.
    """
    index_html = os.path.join(root, "docs", "index.html")
    if os.path.isfile(index_html):
        with open(index_html, "r", encoding="utf-8") as f:
            if "dateModified" in f.read():
                problems.append(
                    "docs/index.html reintroduced dateModified; it was removed "
                    "because it cannot be kept accurate (spec D2)"
                )

    sitemap = os.path.join(root, "docs", "sitemap.xml")
    if os.path.isfile(sitemap):
        with open(sitemap, "r", encoding="utf-8") as f:
            if "lastmod" in f.read():
                problems.append(
                    "docs/sitemap.xml reintroduced lastmod; it was removed "
                    "because it cannot be kept accurate (spec D2)"
                )
```

Register it in `main()`, after the `check_public_surfaces(root, problems)` line:

```python
    check_public_surfaces(root, problems)
    check_no_stale_dates(root, problems)
    check_developer_surfaces(root, problems)
```

- [ ] **Step 2: Run the check to verify it fails**

```bash
python3 test/check-doc-accuracy.py . ; echo "exit=$?"
```

Expected: `exit=1` and both lines printed —
```
docs/index.html reintroduced dateModified; it was removed because it cannot be kept accurate (spec D2)
docs/sitemap.xml reintroduced lastmod; it was removed because it cannot be kept accurate (spec D2)
```

This is the red state. The fields are still present; the check is doing its job.

- [ ] **Step 3: Delete the two fields**

In `docs/index.html`, delete line 47 in its entirety:

```
    "dateModified": "2026-08-06",
```

The preceding line `"datePublished": "2026-04-20",` keeps its trailing comma — `"offers"` follows, so the JSON stays valid. **Do not delete `datePublished`**; it is a historical fact that cannot go stale.

In `docs/sitemap.xml`, delete line 5 in its entirety:

```
    <lastmod>2026-05-13</lastmod>
```

Leave `<changefreq>` and `<priority>` alone.

- [ ] **Step 4: Run the check to verify it passes**

```bash
python3 test/check-doc-accuracy.py . ; echo "exit=$?"
```

Expected: `exit=0`, no output.

Confirm the JSON-LD is still parseable:

```bash
python3 -c "
import json, re
s = open('docs/index.html').read()
m = re.search(r'<script type=\"application/ld\+json\">(.*?)</script>', s, re.S)
d = json.loads(m.group(1))
print('datePublished:', d['datePublished'])
print('dateModified present:', 'dateModified' in d)
"
```

Expected: `datePublished: 2026-04-20` and `dateModified present: False`.

- [ ] **Step 5: Add mutation 22**

In `test/mutation-test.sh`, insert immediately before the final `echo ""` / summary block (after mutation 21):

```bash
# 22. dateModified reintroduced into the landing page -> smoke-test must fail.
# The field was deleted rather than corrected (spec D2); this proves the
# absence assertion in check-doc-accuracy.py actually guards that decision.
fresh
python3 - "$WORK/r/docs/index.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace('"datePublished": "2026-04-20",',
              '"datePublished": "2026-04-20",\n    "dateModified": "2026-08-06",', 1)
open(p, 'w').write(s)
PY
expect_fail "dateModified reintroduced into docs/index.html" "$WORK/r/test/smoke-test.sh" "$WORK/r"
```

No `regen` call is needed — no template or spliced file is mutated.

- [ ] **Step 6: Run the mutation suite**

```bash
./test/mutation-test.sh
```

Expected: a line reading `GUARDED: dateModified reintroduced into docs/index.html (test failed as it should)`, every prior mutation still `GUARDED`, and the summary reporting `NOT guarded: 0`.

If it reports `NOT-GUARDED`, the check is not wired into `smoke-test.sh`'s run — confirm `test/smoke-test.sh:133` still invokes `check-doc-accuracy.py`.

- [ ] **Step 7: Run the full gate suite**

```bash
./test/smoke-test.sh && python3 test/check-evidence-cards.py . && echo ALL-GREEN
```

Expected: `ALL-GREEN`.

- [ ] **Step 8: Commit**

```bash
git add test/check-doc-accuracy.py test/mutation-test.sh docs/index.html docs/sitemap.xml
git commit -m "fix(docs): delete unmaintainable date fields and guard their return

dateModified in the JSON-LD and lastmod in sitemap.xml were both stale --
2026-08-06 and 2026-05-13 against docs changed through 2026-08-12. They are
deleted rather than corrected: any check asserting such a date is current
fails on commits that did not introduce the defect, and a check that cries
wolf gets bypassed. check-doc-accuracy.py now asserts neither field returns,
which cannot false-positive. Mutation 22 proves the guard bites."
```

---

### Task 2: Correct the false claims in docs/index.html

Closes findings 1, 4, and 9, plus the secondary half of 5.

**Files:**
- Modify: `docs/index.html:44` (operatingSystem), `:1013` (pipeline lede), `:1127` (install headline), `:1153` (release note)

**Interfaces:**
- Consumes: nothing. Task 1 already removed line 47, so **line numbers below have shifted by one** — anchor on the quoted text, not the number.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Fix the install-time contradiction (finding 1)**

Replace:

```html
        <h2 id="install-title">Install in about five minutes.</h2>
```

with:

```html
        <h2 id="install-title">Install in 30 seconds.</h2>
```

README says "30 seconds" at lines 15 and 95 and describes the same command the page displays. The page's separate "New to Claude Code?" paragraph already accounts for installing Claude Code itself, which is where the extra time went.

- [ ] **Step 2: Make the eleven-skills count add up (finding 9)**

Replace the `.lede` paragraph under `<h2 id="pipeline-title">`:

```html
        <p class="lede">Eight of them run end-to-end as the standard sequence; two utilities (course-import and learn) sit outside it. Use one command for the full pipeline, or invoke any skill on its own — none of them require an existing manifest.</p>
```

with:

```html
        <p class="lede">Eight run end-to-end as the standard sequence, <code>/idstack:pipeline</code> orchestrates them, and two utilities (course-import and learn) sit outside the chain. Invoke any skill on its own — none of them require an existing manifest.</p>
```

That is 8 + 1 + 2 = 11, so a reader who counts reaches the eleven the headline promises. The dropped "Use one command for the full pipeline" clause is now redundant with naming the orchestrator, and `.pipeline-foot` further down already says it.

- [ ] **Step 3: Add the Windows caveat to the JSON-LD (finding 5, secondary)**

Replace:

```html
    "operatingSystem": "macOS, Linux, Windows",
```

with:

```html
    "operatingSystem": "macOS, Linux, Windows (WSL or Git Bash)",
```

This is a precision improvement, not the fix for finding 5 — Task 3 Step 1 carries that. Schema.org expects OS names here, so a parenthetical is not machine-readable.

- [ ] **Step 4: Complete the v3.4.0.1 release note (finding 4)**

Replace:

```html
        <p>Patched in v3.4.0.1 (August 7): three evidence cards on this page overstated their domain's evidence tier. They are derived from <code>evidence/references.md</code> now, and the test suite fails if they ever disagree again.</p>
```

with:

```html
        <p>Patched in v3.4.0.1 (August 7): three evidence cards on this page overstated their domain's evidence tier. They are derived from <code>evidence/references.md</code> now, and the test suite fails if they ever disagree again. The same patch added the outbound Canvas API upload in <code>/idstack:course-export</code> and the <code>git fetch</code> in <code>bin/idstack-update-check</code> to <a href="https://github.com/savvides/idstack/blob/main/PRIVACY.md" rel="noopener">the privacy policy</a>, and named WSL or Git Bash in the Windows install instructions.</p>
```

Both additions are drawn from `ROADMAP.md`'s "Documentation accuracy & automated verification (v3.4.0.1)" section — do not invent items beyond the two listed there.

- [ ] **Step 5: Verify the JSON-LD still parses and the page is unchanged structurally**

```bash
python3 -c "
import json, re
s = open('docs/index.html').read()
m = re.search(r'<script type=\"application/ld\+json\">(.*?)</script>', s, re.S)
d = json.loads(m.group(1))
print('os:', d['operatingSystem'])
"
grep -c "about five minutes" docs/index.html
```

Expected: `os: macOS, Linux, Windows (WSL or Git Bash)` and a count of `0`.

- [ ] **Step 6: Run the gate suite**

```bash
./test/smoke-test.sh && python3 test/check-evidence-cards.py . && python3 test/check-doc-accuracy.py . && echo ALL-GREEN
```

Expected: `ALL-GREEN`. `check-evidence-cards.py` must stay green — Step 4 touches a release card, not an evidence card, so any failure there means the wrong block was edited.

- [ ] **Step 7: Commit**

```bash
git add docs/index.html
git commit -m "fix(docs): correct false claims on the landing page

- Install headline said five minutes; README says 30 seconds for the same
  command. Reconciled to README.
- Pipeline lede accounted for ten skills under an 'Eleven skills' headline;
  /idstack:pipeline is the eleventh and now appears in the count.
- JSON-LD claimed plain Windows support; ./setup is a bash script.
- v3.4.0.1 release note covered only the evidence-card fix; ROADMAP lists
  two more items shipped in that patch."
```

---

### Task 3: Add the material omissions to docs/index.html

Closes findings 5 (primary), 6, 7, and 8.

**Files:**
- Modify: `docs/index.html` — install section (after the `./setup` prose paragraph), footer `.footer-links` block

**Interfaces:**
- Consumes: nothing from Tasks 1–2.
- Produces: nothing consumed by Task 4.

- [ ] **Step 1: State the prerequisites (findings 5 primary, 8)**

In the install section, insert **between** the `./setup` prose paragraph and the "New to Claude Code?" paragraph. The block currently reads:

```html
      <p class="install-prose"><code>./setup</code> registers idstack with Claude Code and installs all 11 skills. Re-run it after a <code>git pull</code> to update.</p>

      <p class="install-prose">New to Claude Code? <a href="https://claude.ai/download" rel="noopener">Download it first</a> (free), then paste the command above. When Claude Code starts, run <code>/idstack:pipeline</code>.</p>
```

Insert these two paragraphs between them:

```html
      <p class="install-prose">Requires a bash shell — Terminal on macOS or Linux, WSL or Git Bash on Windows. <code>./setup</code> is a bash script, so PowerShell and <code>cmd</code> can't run it. python3 is recommended but not required; without it, quality-score trends and search filtering are unavailable.</p>

      <p class="install-prose">If something looks wrong afterwards, <code>bin/idstack-doctor</code> diagnoses the plugin registration, and <code>bin/idstack-status</code> reports course health from inside a project directory.</p>
```

Both reuse the existing `.install-prose` class. No new CSS.

The first paragraph is the primary fix for finding 5 — a Windows visitor is stopped by prose they read, not by the JSON-LD string from Task 2. Its wording follows `README.md:126-127` and the python3 FAQ at `README.md:383-384`; do not overstate what python3 unlocks.

- [ ] **Step 2: Link the privacy policy (finding 6)**

The page collects email addresses through a Formspree form in the footer and never links the `PRIVACY.md` that exists in the repo. In the `.footer-links` block, add a `Privacy` link after `MIT License`:

```html
      <div class="footer-links">
        <a href="https://github.com/savvides/idstack" rel="noopener">GitHub</a>
        <a href="https://github.com/savvides/idstack/blob/main/LICENSE" rel="noopener">MIT License</a>
        <a href="https://github.com/savvides/idstack/blob/main/PRIVACY.md" rel="noopener">Privacy</a>
        <a href="https://github.com/savvides/idstack/blob/main/CONTRIBUTING.md" rel="noopener">Contribute</a>
        <a href="https://github.com/savvides/idstack/blob/main/ROADMAP.md" rel="noopener">Roadmap</a>
        <a href="https://forms.gle/6LDgDD1M6WWyYvME8" rel="noopener">Feedback</a>
      </div>
```

`.footer-links a` is already styled (`docs/index.html:800-804`). No new CSS.

- [ ] **Step 3: Verify every outbound link resolves**

```bash
grep -oE 'href="https?://[^"]+"' docs/index.html | sed 's/href="//;s/"//' | sort -u | while read u; do
  printf '%s  %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 12 "$u")" "$u"
done
```

Expected: every line starts `200`, and the list now includes
`https://github.com/savvides/idstack/blob/main/PRIVACY.md` (added twice — the footer here and the release note in Task 2 — but `sort -u` collapses it to one row).

That URL was verified against `main` while writing this plan: `PRIVACY.md` is tracked at the repo root and the blob URL returns 200. If the sweep 404s on it, the link was mistyped, not missing upstream.

- [ ] **Step 4: Confirm no new CSS was introduced**

```bash
git diff docs/index.html | grep -E '^\+' | grep -E '^\+\s*(\.|@media|--)' || echo "NO-NEW-CSS"
```

Expected: `NO-NEW-CSS`. Any output here violates the global constraint — the additions must reuse `.install-prose` and `.footer-links a`.

- [ ] **Step 5: Run the gate suite**

```bash
./test/smoke-test.sh && python3 test/check-evidence-cards.py . && python3 test/check-doc-accuracy.py . && echo ALL-GREEN
```

Expected: `ALL-GREEN`.

- [ ] **Step 6: Commit**

```bash
git add docs/index.html
git commit -m "feat(docs): state prerequisites, tooling, and privacy policy on the landing page

The page asked visitors to paste a bash script without saying a bash shell
is required, never mentioned bin/idstack-doctor or bin/idstack-status, and
collected email addresses without linking the privacy policy that already
exists in the repo."
```

---

### Task 4: Stop publishing internal files on idstack.org

Implements spec D1. Closes findings 10 and 11.

**Files:**
- Move: `docs/superpowers/specs/2026-08-12-documentation-accuracy-design.md` → `superpowers/specs/`
- Move: `docs/superpowers/plans/2026-08-12-documentation-accuracy.md` → `superpowers/plans/`
- Modify: `.github/workflows/static.yml:36-40`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing from Tasks 1–3.
- Produces: a staged `_site` directory at deploy time; nothing later depends on it.

- [ ] **Step 1: Ignore the staging directory**

The dry-runs below create `_site` in the working tree. Add it to `.gitignore` first, so a forgotten
cleanup cannot be committed. Append after the existing `.gstack/` line:

```
_site/
```

Verify:

```bash
mkdir -p _site && git status --porcelain | grep -q "_site" && echo "LEAKING" || echo "IGNORED"
rmdir _site
```

Expected: `IGNORED`.

- [ ] **Step 2: Dry-run the staging logic before touching the workflow**

Run the exact shell the workflow will run, against the current tree:

```bash
rm -rf _site && cp -R docs _site && rm -rf _site/superpowers && rm -f _site/og-template.html
ls -A _site
```

Expected exactly these entries and no others:
```
CNAME
favicon.png
favicon.svg
index.html
og-image.png
robots.txt
sitemap.xml
why-ai-native.md
```

`why-ai-native.md` is intended public content, linked from README — see the spec's Non-goals. `superpowers/` and `og-template.html` must both be absent.

Confirm the source tree is untouched:

```bash
test -f docs/og-template.html && test -d docs/superpowers && echo "SOURCE-INTACT"
rm -rf _site
```

Expected: `SOURCE-INTACT`. Running the dry-run first means a staging bug costs nothing; discovering it after a deploy costs a live site.

- [ ] **Step 3: Relocate the two design documents**

`superpowers/specs/` and `superpowers/plans/` already exist (this plan and its spec live there). `git mv` will not create a missing directory, so verify first:

```bash
test -d superpowers/specs && test -d superpowers/plans && echo DIRS-OK
git mv docs/superpowers/specs/2026-08-12-documentation-accuracy-design.md superpowers/specs/
git mv docs/superpowers/plans/2026-08-12-documentation-accuracy.md superpowers/plans/
rmdir docs/superpowers/specs docs/superpowers/plans docs/superpowers
```

Verified safe: nothing in the repo references `docs/superpowers/`. Confirm that still holds:

```bash
grep -rn "docs/superpowers" --include="*.md" --include="*.sh" --include="*.py" --include="*.yml" --include="*.html" . || echo "NO-REFERENCES"
```

Expected: `NO-REFERENCES`.

- [ ] **Step 4: Add the staging step to the Pages workflow**

In `.github/workflows/static.yml`, replace:

```yaml
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          # Upload entire repository
          path: 'docs'
```

with:

```yaml
      - name: Stage publishable files
        # docs/ holds two things that must exist in the repo but not on the
        # site: internal design docs (the brainstorming skill writes specs to
        # docs/superpowers/ by default, so relocating them is not enough --
        # its next run recreates the directory) and og-template.html (the OG
        # card's regenerable source, which smoke-test.sh asserts exists at
        # that exact path, so it cannot be moved). Stage a copy and drop both.
        run: |
          rm -rf _site
          cp -R docs _site
          rm -rf _site/superpowers
          rm -f _site/og-template.html
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: '_site'
```

Order matters: this step must sit after `actions/checkout@v4` and `actions/configure-pages@v5`, and before `actions/deploy-pages@v5`. Quote `'_site'` the same way `'docs'` was quoted.

- [ ] **Step 5: Re-run the dry-run against the relocated tree**

```bash
rm -rf _site && cp -R docs _site && rm -rf _site/superpowers && rm -f _site/og-template.html
ls -A _site
rm -rf _site
```

Expected: the same eight entries as Step 2. `rm -rf _site/superpowers` is now a no-op on this tree — that is intentional. It is the backstop that catches the next brainstorming run, not a cleanup of today's files.

- [ ] **Step 6: Validate the workflow YAML parses**

```bash
python3 -c "
import sys
try:
    import yaml
except ImportError:
    sys.exit('SKIP: pyyaml not installed, inspect the file by eye')
d = yaml.safe_load(open('.github/workflows/static.yml'))
steps = d['jobs']['deploy']['steps']
names = [s.get('name') for s in steps]
print(names)
up = [s for s in steps if 'upload-pages-artifact' in str(s.get('uses'))][0]
print('upload path:', up['with']['path'])
assert names.index('Stage publishable files') < names.index('Upload artifact')
print('ORDER-OK')
"
```

Expected: the step list in order, `upload path: _site`, and `ORDER-OK`. If pyyaml is unavailable, confirm by reading the file that staging precedes upload.

- [ ] **Step 7: Run the gate suite**

```bash
./test/smoke-test.sh && python3 test/check-doc-accuracy.py . && echo ALL-GREEN
```

Expected: `ALL-GREEN`. This is the check that matters most in this task — `smoke-test.sh:136-141` asserts `docs/og-template.html` still exists. If it fails, the file was moved or deleted instead of excluded at build time.

- [ ] **Step 8: Commit**

```bash
git add .github/workflows/static.yml .gitignore superpowers/ docs/
git commit -m "fix(pages): stop publishing internal design docs and the OG template

static.yml uploaded docs/ verbatim, so design specs and og-template.html
were served at idstack.org. Stage a copy and drop both instead of moving
them: the brainstorming skill writes specs to docs/superpowers/ by default
so a move alone gets undone on its next run, and smoke-test.sh asserts
docs/og-template.html exists at that exact path so it cannot move at all."
```

---

### Task 5: Full verification sweep

No production changes. Confirms all 11 findings are closed and nothing regressed.

**Files:** none modified.

**Interfaces:**
- Consumes: the complete state after Tasks 1–4.
- Produces: a merge-ready branch.

- [ ] **Step 1: Run every suite**

```bash
./test/smoke-test.sh          && \
./test/integration-test.sh    && \
./test/test-setup.sh          && \
./test/test-doctor.sh         && \
./test/test-status.sh         && \
./test/test-manifest-merge.sh && \
./test/test-version-classifier.sh && \
./test/test-plugin-status.sh  && \
./test/test-preamble-python.sh && \
python3 test/check-evidence-cards.py . && \
python3 test/check-doc-accuracy.py .   && \
echo ALL-SUITES-GREEN
```

Expected: `ALL-SUITES-GREEN`.

- [ ] **Step 2: Run the mutation suite**

```bash
./test/mutation-test.sh
```

Expected: `NOT guarded: 0`, and mutation 22 reports `GUARDED`.

- [ ] **Step 3: Confirm the working tree is clean and the suites left nothing behind**

```bash
git status --porcelain
```

Expected: empty output. The integration suite is documented to leave the working tree untouched; anything here is a bug worth reporting before merge.

One exception: if `_site/` appears, that is an uncleaned staging dry-run from Task 4, not a suite bug. `rm -rf _site` and re-run. (It is gitignored as of Task 4 Step 1, so it should not appear at all.)

- [ ] **Step 4: Walk the findings list**

```bash
echo "--- 1 install time (expect 'Install in 30 seconds.', and 0 for five minutes)"
grep -c "about five minutes" docs/index.html; grep -o "Install in 30 seconds." docs/index.html
echo "--- 2 dateModified (expect 0)"; grep -c "dateModified" docs/index.html
echo "--- 3 lastmod (expect 0)"; grep -c "lastmod" docs/sitemap.xml
echo "--- 4 release note (expect 1)"; grep -c "named WSL or Git Bash in the Windows install" docs/index.html
echo "--- 5 windows caveat (expect 1 each)"; grep -c "WSL or Git Bash on Windows" docs/index.html; grep -c "Windows (WSL or Git Bash)" docs/index.html
echo "--- 6 privacy link (expect 2: footer + release note)"; grep -o "blob/main/PRIVACY.md" docs/index.html | wc -l
echo "--- 7 tooling (expect 1 each)"; grep -c "bin/idstack-doctor" docs/index.html; grep -c "bin/idstack-status" docs/index.html
echo "--- 8 python3 note (expect 1)"; grep -c "python3 is recommended" docs/index.html
echo "--- 9 eleventh skill (expect 1)"; grep -c "orchestrates them" docs/index.html
echo "--- 10/11 excluded at build (expect _site path)"; grep -c "_site" .github/workflows/static.yml
echo "--- 10 relocated (expect NO-REFERENCES)"; grep -rn "docs/superpowers" --include="*.md" --include="*.sh" --include="*.py" --include="*.yml" --include="*.html" . || echo NO-REFERENCES
echo "--- 11 og-template still in repo (expect the file)"; ls docs/og-template.html
```

Every line must match its stated expectation.

- [ ] **Step 5: Push and open the pull request**

```bash
git push -u origin docs/landing-page-accuracy
gh pr create --title "docs: close 11 accuracy defects between idstack.org and the repo" --body "$(cat <<'BODY'
Implements `superpowers/specs/2026-08-14-github-page-accuracy-design.md`.

An audit of idstack.org against the repo found 11 defects that the two
existing validators do not cover. All 11 are closed here.

**Corrected** — install time contradicted README, the JSON-LD claimed plain
Windows support for a bash script, the v3.4.0.1 release note covered one of
three shipped items, and an "Eleven skills" headline accounted for ten.

**Added** — prerequisites, `bin/idstack-doctor` / `bin/idstack-status`, and a
link to the privacy policy under the email signup form.

**Unpublished** — internal design docs and `og-template.html` are excluded
from the Pages artifact at build time. Excluded rather than moved: the
brainstorming skill writes specs to `docs/superpowers/` by default, and
`smoke-test.sh` asserts `docs/og-template.html` exists at that exact path.

**Guarded** — `dateModified` and sitemap `lastmod` were both stale. They are
deleted rather than corrected, because any check asserting such a date is
current fails on commits that did not introduce the defect. The new check
asserts absence, which cannot false-positive, and mutation 22 proves it bites.

Verified accurate and left alone: all version strings, the 108-studies /
11-domains claim, all 11 evidence cards, every per-skill capability claim,
`og-image.png`, and the repo's About/topics/homepage.
BODY
)"
```

- [ ] **Step 6: Confirm the deploy after merge**

The Pages workflow runs on push to `main`. Once it completes:

```bash
for u in \
  "https://idstack.org/" \
  "https://idstack.org/superpowers/specs/2026-08-12-documentation-accuracy-design.md" \
  "https://idstack.org/og-template.html" ; do
  printf '%s  %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 15 "$u")" "$u"
done
```

Expected: `200` for the site root, `404` for both others.

If either returns 200, the staging step did not take effect — check the workflow run's "Stage publishable files" step output before assuming the exclusion logic is wrong.

---

## Rollback

Every task is a single commit on `docs/landing-page-accuracy`. `git revert` any one independently; none depends on another's output. The only change with a live-site effect is Task 4, and reverting it restores the previous `path: 'docs'` upload on the next push to `main`.
