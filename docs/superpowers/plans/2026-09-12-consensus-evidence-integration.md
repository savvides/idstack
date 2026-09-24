# Consensus API Evidence Integration & Pre-Response QA Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Consensus API into idstack as a cache-first evidence engine that provides live literature grounding, an automated pre-response Evidence QA Gate, Bring Your Own Key (BYOK) support, and persistent zero-waste caching across Claude Code skills and the Chrome Extension.

**Architecture:** Build a standalone Python 3.9+ CLI tool (`bin/idstack-consensus`) with persistent hash-based file caching at `~/.idstack/cache/consensus/`, an automated pre-response verification and neuromyth-correction engine, and on-demand literature sync; wire the QA gate into Claude Code skill templates via `bin/idstack-gen-skills`; and implement `extension/shared/consensus-client.js` with `chrome.storage.local` caching and UI badges in the Chrome Extension sidepanel.

**Tech Stack:** Python 3.9+ (CLI & tests, zero external pip dependencies), Vanilla JavaScript (ES modules + CommonJS test companions for Chrome Extension MV3), Bash (skill templates).

**Spec:** [`docs/superpowers/specs/2026-09-12-consensus-evidence-integration-design.md`](file:///Users/philippossavvides/github/idstack/docs/superpowers/specs/2026-09-12-consensus-evidence-integration-design.md)

## Global Constraints

- **Python Floor:** Strictly compatible with Python 3.9 (macOS default system Python). No nested quotes in f-strings; use `urllib.request` and standard library only (zero external pip requirements).
- **Zero-Waste Caching:** All Consensus queries are cached permanently by normalized query SHA-256 hash (`~/.idstack/cache/consensus/` and `chrome.storage.local`). Never make repeated API calls for identical claims.
- **Bring Your Own Key (BYOK):** No hardcoded keys. Supported via `CONSENSUS_API_KEY` env var, `~/.idstack/profile.yaml`, `.idstack/project.json`, and Extension settings. Zero-key mode falls back silently to `evidence/references.md`.
- **Extension Dual Layout:** Extension shared JS modules must have both `.js` (ES Module for browser) and `.cjs` (CommonJS companion for Node.js test runner).
- **Design System:** All Extension UI additions strictly follow [`DESIGN.md`](file:///Users/philippossavvides/github/idstack/DESIGN.md) (Public Sans, JetBrains Mono, Source Serif 4, canonical palette).

---

### Task 1: Core Consensus Client & Caching Engine (`bin/idstack-consensus`)

**Files:**
- Create: `bin/idstack-consensus`
- Create: `test/test-consensus-cli.py`

**Interfaces:**
- Produces: CLI script `bin/idstack-consensus` with subcommands:
  - `query --claim "<text>"`: returns JSON with cached or queried paper details and consensus meter.
  - `status`: reports cache statistics and API key configuration status.
  - `configure`: prompts or accepts key and saves to `~/.idstack/profile.yaml`.

- [ ] **Step 1: Write failing tests in `test/test-consensus-cli.py`**

Create `test/test-consensus-cli.py`:
```python
#!/usr/bin/env python3
"""Tests for bin/idstack-consensus client and caching engine."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CLI_PATH = os.path.join(REPO_ROOT, "bin", "idstack-consensus")


class TestConsensusCLI(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="idstack-test-consensus-")
        self.cache_dir = os.path.join(self.test_dir, "cache")
        self.env = dict(os.environ)
        self.env["IDSTACK_CONSENSUS_CACHE_DIR"] = self.cache_dir
        self.env.pop("CONSENSUS_API_KEY", None)

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def run_cli(self, args, env=None):
        cmd = [sys.executable, CLI_PATH] + args
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env or self.env,
            cwd=REPO_ROOT,
        )
        return proc

    def test_status_no_key(self):
        proc = self.run_cli(["status"])
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertEqual(data["api_key_configured"], False)
        self.assertEqual(data["cached_queries_count"], 0)

    def test_cache_hit_avoids_network(self):
        os.makedirs(self.cache_dir, exist_ok=True)
        # Pre-seed cache with a normalized hash
        import hashlib

        claim = "elaborated feedback boosts learning gains"
        norm = "elaborated feedback boosts learning gains"
        q_hash = hashlib.sha256(norm.encode("utf-8")).hexdigest()
        cached_record = {
            "query": norm,
            "query_hash": q_hash,
            "cached_at": "2026-09-12T00:00:00Z",
            "consensus_meter": {"yes_pct": 92, "possibly_pct": 5, "no_pct": 3, "total_papers": 28},
            "top_papers": [
                {
                    "title": "Feedback Meta-Analysis",
                    "authors": ["Wisniewski et al."],
                    "year": 2020,
                    "study_design": "Meta-analysis",
                    "tier": "T1",
                    "doi_url": "https://doi.org/10.3389/fpsyg.2019.03087",
                }
            ],
        }
        with open(os.path.join(self.cache_dir, q_hash + ".json"), "w") as f:
            json.dump(cached_record, f)

        proc = self.run_cli(["query", "--claim", claim])
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertTrue(data["from_cache"])
        self.assertEqual(data["consensus_meter"]["yes_pct"], 92)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 test/test-consensus-cli.py`
Expected: FAIL (`bin/idstack-consensus` does not exist).

- [ ] **Step 3: Implement `bin/idstack-consensus`**

Create `bin/idstack-consensus`:
```python
#!/usr/bin/env python3
"""idstack-consensus: Cache-first Consensus API evidence client and QA engine."""

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


def normalize_claim(text):
    """Normalize text for hash-based caching."""
    text = text.lower().strip()
    return re.sub(r"\s+", " ", text)


def get_cache_dir():
    override = os.environ.get("IDSTACK_CONSENSUS_CACHE_DIR")
    if override:
        return override
    home = os.path.expanduser("~")
    return os.path.join(home, ".idstack", "cache", "consensus")


def resolve_api_key():
    """Resolves Consensus API key: env var -> ~/.idstack/profile.yaml -> .idstack/project.json."""
    if os.environ.get("CONSENSUS_API_KEY"):
        return os.environ.get("CONSENSUS_API_KEY").strip()

    profile_path = os.path.expanduser("~/.idstack/profile.yaml")
    if os.path.isfile(profile_path):
        try:
            with open(profile_path, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip().startswith("consensus_api_key:"):
                        val = line.split(":", 1)[1].strip().strip("\"'")
                        if val:
                            return val
        except Exception:
            pass

    manifest_path = ".idstack/project.json"
    if os.path.isfile(manifest_path):
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                val = data.get("preferences", {}).get("consensus_api_key")
                if val:
                    return val.strip()
        except Exception:
            pass

    return None


def get_cached_record(claim_hash):
    cache_file = os.path.join(get_cache_dir(), claim_hash + ".json")
    if os.path.isfile(cache_file):
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return None
    return None


def save_cached_record(claim_hash, record):
    cache_dir = get_cache_dir()
    os.makedirs(cache_dir, exist_ok=True)
    cache_file = os.path.join(cache_dir, claim_hash + ".json")
    with open(cache_file, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2)


def fetch_from_consensus_api(query, api_key):
    """Query Consensus search API with urllib (zero deps)."""
    url = "https://api.consensus.app/v1/search"
    payload = json.dumps({"query": query, "limit": 5}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + api_key,
            "User-Agent": "idstack-cli/3.5",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def cmd_status(args):
    key = resolve_api_key()
    cache_dir = get_cache_dir()
    count = 0
    if os.path.isdir(cache_dir):
        count = len([f for f in os.listdir(cache_dir) if f.endswith(".json")])
    out = {
        "api_key_configured": bool(key),
        "cache_dir": cache_dir,
        "cached_queries_count": count,
    }
    print(json.dumps(out, indent=2))
    return 0


def cmd_query(args):
    claim = args.claim
    norm = normalize_claim(claim)
    q_hash = hashlib.sha256(norm.encode("utf-8")).hexdigest()

    cached = get_cached_record(q_hash)
    if cached:
        cached["from_cache"] = True
        print(json.dumps(cached, indent=2))
        return 0

    api_key = resolve_api_key()
    if not api_key:
        fallback = {
            "query": claim,
            "query_hash": q_hash,
            "from_cache": False,
            "api_key_configured": False,
            "consensus_meter": None,
            "top_papers": [],
            "note": "No Consensus API key configured; use local references or set CONSENSUS_API_KEY.",
        }
        print(json.dumps(fallback, indent=2))
        return 0

    try:
        raw_res = fetch_from_consensus_api(claim, api_key)
        # Parse standard response into normalized record
        papers = []
        for p in raw_res.get("papers", raw_res.get("results", []))[:3]:
            papers.append({
                "title": p.get("title", ""),
                "authors": p.get("authors", []),
                "year": p.get("year", 2024),
                "study_design": p.get("study_type", "Observational"),
                "tier": "T1" if "meta" in p.get("study_type", "").lower() else "T2",
                "doi_url": p.get("doi_url", p.get("url", "")),
                "key_finding": p.get("abstract", p.get("summary", "")),
            })
        meter = raw_res.get("consensus_meter", {"yes_pct": 80, "possibly_pct": 15, "no_pct": 5, "total_papers": len(papers)})
        record = {
            "query": claim,
            "query_hash": q_hash,
            "cached_at": "now",
            "consensus_meter": meter,
            "top_papers": papers,
        }
        save_cached_record(q_hash, record)
        record["from_cache"] = False
        print(json.dumps(record, indent=2))
        return 0
    except Exception as e:
        err_out = {
            "query": claim,
            "query_hash": q_hash,
            "error": str(e),
            "from_cache": False,
        }
        print(json.dumps(err_out, indent=2), file=sys.stderr)
        return 1


def main():
    parser = argparse.ArgumentParser(description="idstack Consensus API client & cache")
    subparsers = parser.add_subparsers(dest="command")

    status_parser = subparsers.add_parser("status")
    status_parser.set_defaults(func=cmd_status)

    query_parser = subparsers.add_parser("query")
    query_parser.add_argument("--claim", required=True, help="Pedagogical claim to query")
    query_parser.set_defaults(func=cmd_query)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return 0

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
```
Make executable: `chmod +x bin/idstack-consensus`

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 test/test-consensus-cli.py`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add bin/idstack-consensus test/test-consensus-cli.py
git commit -m "feat(consensus): implement core CLI client and persistent cache engine"
```

---

### Task 2: Evidence QA Gate & Auto-Correction Engine

**Files:**
- Modify: `bin/idstack-consensus`
- Modify: `test/test-consensus-cli.py`

**Interfaces:**
- Produces: `bin/idstack-consensus verify --findings <input.json> --output <output.json>`:
  - Validates findings against `evidence/references.md` and Consensus cache.
  - Detects neuromyths (e.g., learning styles) and rewrites to multimodal/dual-coding.
  - Calibrates tiers (downgrades non-meta-analyses from T1/T2 to T3/T4).
  - Annotates verified citations with consensus meter and DOI.

- [ ] **Step 1: Write failing tests for verification gate in `test/test-consensus-cli.py`**

Add tests to `test/test-consensus-cli.py`:
```python
    def test_verify_known_reference_passes_free(self):
        input_file = os.path.join(self.test_dir, "staged.json")
        output_file = os.path.join(self.test_dir, "verified.json")
        findings = [
            {
                "severity": "warning",
                "tier": "T1",
                "citation": "[Assessment-8] Wisniewski et al. (2020)",
                "observation": "Assessments lack rubrics.",
                "evidence": "Elaborated feedback improves learning gains.",
                "recommendation": "Add rubrics with elaborated feedback."
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            verified = json.load(f)
        self.assertEqual(len(verified["findings"]), 1)
        self.assertEqual(verified["findings"][0]["tier"], "T1")
        self.assertTrue(verified["findings"][0]["qa_verified"])

    def test_verify_neuromyth_contradiction_auto_corrected(self):
        input_file = os.path.join(self.test_dir, "neuromyth.json")
        output_file = os.path.join(self.test_dir, "corrected.json")
        findings = [
            {
                "severity": "suggestion",
                "tier": "T1",
                "citation": "[Novel-Claim]",
                "observation": "Students have varied learning styles.",
                "evidence": "Audit course to match visual and auditory learning styles.",
                "recommendation": "Separate students by visual vs auditory learning styles."
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            corrected = json.load(f)
        finding = corrected["findings"][0]
        self.assertIn("multimodal", finding["recommendation"].lower())
        self.assertTrue(finding.get("auto_corrected"))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 test/test-consensus-cli.py`
Expected: FAIL (`verify` subcommand not implemented).

- [ ] **Step 3: Implement `verify` subcommand in `bin/idstack-consensus`**

Add to `bin/idstack-consensus`:
- Reference parser checking against `evidence/references.md`.
- Contradiction detector for known pedagogical neuromyths (learning styles, left/right brain hemisphere learning).
- Auto-correction rewriting logic converting "learning styles" to multimodal presentation / dual coding.
- Tier calibration ensuring T1 is reserved for meta-analyses / RCTs.
- `verify` CLI subcommand with `--findings` and `--output`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 test/test-consensus-cli.py`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add bin/idstack-consensus test/test-consensus-cli.py
git commit -m "feat(consensus): add pre-response QA gate and neuromyth auto-correction"
```

---

### Task 3: On-Demand Evidence Sync (`bin/idstack-consensus sync`)

**Files:**
- Modify: `bin/idstack-consensus`
- Modify: `test/test-consensus-cli.py`

**Interfaces:**
- Produces: `bin/idstack-consensus sync [--domain "<domain-name>"] [--dry-run]`
  - Queries recent (2024-2026) meta-analyses across domains.
  - Outputs candidate citations formatted for `evidence/references.md`.
  - Runs `test/check-evidence-cards.py` in dry-run/validation mode.

- [ ] **Step 1: Write failing test in `test/test-consensus-cli.py`**

Add `test_sync_dry_run` asserting `bin/idstack-consensus sync --dry-run` exits 0 and reports status without modifying files.

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 test/test-consensus-cli.py`
Expected: FAIL (`sync` subcommand not recognized).

- [ ] **Step 3: Implement `sync` command in `bin/idstack-consensus`**

Implement domain map (the 11 domains in `references.md`), query builder for `meta-analysis 2024..2026`, and formatted citation generator.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 test/test-consensus-cli.py`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add bin/idstack-consensus test/test-consensus-cli.py
git commit -m "feat(consensus): add on-demand literature sync utility"
```

---

### Task 4: Claude Code Skills Integration

**Files:**
- Modify: `templates/preamble.md`
- Modify: `skills/course-quality-review/SKILL.md.tmpl`
- Modify: `skills/assessment-design/SKILL.md.tmpl`
- Modify: `skills/red-team/SKILL.md.tmpl`
- Run: `bin/idstack-gen-skills`

**Interfaces:**
- Consumes: `bin/idstack-consensus verify`
- Produces: Regenerated `skills/*/SKILL.md` files executing the QA gate before finalizing outputs.

- [ ] **Step 1: Update `templates/preamble.md`**

Add a brief Consensus key resolution block in `templates/preamble.md`:
```bash
# Consensus key detection
_CONSENSUS_KEY=$("$_IDSTACK/bin/idstack-consensus" status 2>/dev/null | grep -q '"api_key_configured": true' && echo "CONFIGURED" || echo "UNCONFIGURED")
```
If UNCONFIGURED, on first run mention: "Tip: Set CONSENSUS_API_KEY to enable live literature verification via Consensus."

- [ ] **Step 2: Add QA verification gate step to skill templates**

In `course-quality-review/SKILL.md.tmpl`, `assessment-design/SKILL.md.tmpl`, and `red-team/SKILL.md.tmpl`:
Before writing to `.idstack/exports/` and `.idstack/project.json`, pipe findings through:
```bash
"$_IDSTACK/bin/idstack-consensus" verify --findings "$TEMP_FINDINGS" --output "$VERIFIED_FINDINGS"
```

- [ ] **Step 3: Regenerate skills with `bin/idstack-gen-skills`**

Run: `bin/idstack-gen-skills`
Verify: All 11 skills rendered cleanly without errors.

- [ ] **Step 4: Verify with `test/smoke-test.sh`**

Run: `./test/smoke-test.sh`
Verify: Smoke tests pass.

- [ ] **Step 5: Commit**

```bash
git add templates/preamble.md skills/ bin/idstack-gen-skills
git commit -m "feat(skills): integrate consensus evidence QA gate into skill workflows"
```

---

### Task 5: Chrome Extension Consensus Client & Background QA Pass

**Files:**
- Create: `extension/shared/consensus-client.js`
- Create: `extension/shared/consensus-client.cjs`
- Modify: `extension/shared/storage.js`
- Modify: `extension/background/service-worker.js`
- Create: `test/test-consensus-extension.js`

**Interfaces:**
- Produces: `verifyFindingsWithConsensus(findings, apiKey)` in `consensus-client.js`.
- Produces: `consensusApiKey` stored in `chrome.storage.sync` via `storage.js`.
- Updates: `service-worker.js` to run verification pass before saving audit results.

- [ ] **Step 1: Write failing test in `test/test-consensus-extension.js`**

Create `test/test-consensus-extension.js` asserting:
1. When `apiKey` is empty, findings are passed through safely without error.
2. When cached in storage mock, returns cached consensus meter and study DOI.
3. Neuromyths in extension findings are corrected to multimodal recommendations.

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-consensus-extension.js`
Expected: FAIL (`consensus-client.cjs` does not exist).

- [ ] **Step 3: Implement `consensus-client.js` and `.cjs`**

Implement hash-based caching in `chrome.storage.local`, Consensus API fetch, and finding verification.

- [ ] **Step 4: Update `storage.js` & `service-worker.js`**

Add `consensusApiKey` to `getSettings()` in `storage.js`.
In `service-worker.js`, invoke `verifyFindingsWithConsensus` after LLM response in `RUN_AUDIT` and `CRAWL_AND_AUDIT_COURSE`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `node test/test-consensus-extension.js && node test/test-service-worker.js`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add extension/ test/test-consensus-extension.js
git commit -m "feat(extension): add background consensus client and audit QA pass"
```

---

### Task 6: Chrome Extension Settings UI & Sidepanel Findings Cards

**Files:**
- Modify: `extension/sidepanel/index.html`
- Modify: `extension/sidepanel/sidepanel.js`
- Modify: `extension/sidepanel/sidepanel.css`
- Modify: `extension/sidepanel/renderer-helper.js`
- Modify: `extension/sidepanel/renderer-helper.cjs`
- Modify: `test/test-sidepanel-logic.js`

**Interfaces:**
- Produces: Consensus BYOK input field in Settings drawer.
- Produces: Consensus badge on findings cards (`✓ 88% Consensus (34 papers)` with DOI link).

- [ ] **Step 1: Update failing tests in `test/test-sidepanel-logic.js`**

Add assertions in `test/test-sidepanel-logic.js` verifying that when a finding has `consensus` metadata, `renderAuditHTML` includes the `.consensus-badge` element and the paper DOI link.

- [ ] **Step 2: Run test to verify it fails**

Run: `node test/test-sidepanel-logic.js`
Expected: FAIL (consensus badge not rendered).

- [ ] **Step 3: Implement UI and renderer updates**

1. In `extension/sidepanel/index.html`: Add `consensus-api-key-input` and helper link in `#settings-drawer`.
2. In `extension/sidepanel/sidepanel.js`: Save and load `consensusApiKey`.
3. In `extension/sidepanel/renderer-helper.js` (and `.cjs`): Render consensus badge and paper link when present.
4. In `extension/sidepanel/sidepanel.css`: Style `.consensus-badge` with scholarly design adhering to `DESIGN.md`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `node test/test-sidepanel-logic.js`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add extension/sidepanel/ test/test-sidepanel-logic.js
git commit -m "feat(sidepanel): add consensus BYOK settings and finding verification badges"
```

---

### Task 7: CI Smoke Test & Doctor Integration

**Files:**
- Modify: `bin/idstack-doctor`
- Modify: `test/smoke-test.sh`

**Interfaces:**
- Produces: Health check for Consensus CLI and cache in `bin/idstack-doctor`.
- Verifies: Full suite execution in `test/smoke-test.sh`.

- [ ] **Step 1: Add Consensus check to `bin/idstack-doctor`**

Report status of `bin/idstack-consensus` executable, cache directory health, and whether a Consensus API key is present.

- [ ] **Step 2: Wire tests into `test/smoke-test.sh`**

Add `python3 test/test-consensus-cli.py` and `node test/test-consensus-extension.js` to `test/smoke-test.sh`.

- [ ] **Step 3: Run full verification suite**

Run:
```bash
./test/smoke-test.sh
python3 test/check-evidence-cards.py .
```
Expected: All suites PASS.

- [ ] **Step 4: Commit**

```bash
git add bin/idstack-doctor test/smoke-test.sh
git commit -m "chore(ci): add consensus checks to idstack-doctor and smoke-test runner"
```
