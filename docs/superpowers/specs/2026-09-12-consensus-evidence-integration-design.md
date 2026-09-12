# Consensus API Evidence Integration & Pre-Response QA Gate

## Overview
idstack is built on the premise that instructional design recommendations must be backed by empirical evidence rather than folklore. This specification introduces the **Consensus API Integration**: a cache-first evidence engine that ensures course recommendations are actively grounded in peer-reviewed literature, prevents "neuromyth" pedagogical suggestions, keeps research up to date, and enforces an automated **Evidence QA Gate** before the system responds to the user across both Claude Code skills and the Chrome Extension.

Because scientific consensus in education evolves deliberately, the architecture is strictly **cache-first**, guaranteeing zero wasted API calls while maintaining academic rigor.

---

## Requirements & Scope

### 1. Goals & User Requirements
- **Up-to-Date Literature**: Enable idstack to discover and reference contemporary seminal papers, meta-analyses, and systematic reviews (2024–2026).
- **Literature-Grounded Recommendations**: Ensure that findings produced during course quality audits, assessment redesigns, and red-teaming directly align with scientific consensus.
- **Pre-Response Evidence QA Gate**: An automated verification checkpoint that audits staged findings before they are rendered to the user, written to reports, or committed to `.idstack/project.json`.
- **Zero-Waste / API Call Conservation**: Never burn API calls for queries that have already been resolved. Caching is persistent, cross-project, and deterministic.
- **Full Platform Coverage**: Unified evidence quality across both Claude Code skills (`/idstack:*`) and the Chrome Extension sidepanel.
- **Graceful Degradation**: Full functionality continues offline or without an API key by falling back to the curated static evidence catalog (`evidence/references.md`).

### 2. Out of Scope
- Automatic background polling or uncontrolled scheduled scraping of Consensus API.
- Replacing the core LLM reasoning engine with Consensus search (Consensus acts as the evidence verifier and source, not the pedagogical synthesizer).

---

## System Architecture

```
+-------------------------------------------------------------------------------+
|                                 idstack Platform                              |
|                                                                               |
|   Claude Code Skills                                 Chrome Extension         |
|   (course-quality-review, red-team,                  (Canvas & Web Audits:    |
|    assessment-design, needs-analysis)                 service-worker.js)      |
|                   \                                      /                    |
|                    \                                    /                     |
|                     v                                  v                      |
|           [ bin/idstack-consensus ]           [ shared/consensus-client.js ]  |
+---------------------------|----------------------------------|----------------+
                            |                                  |
                            v                                  v
              +---------------------------+      +----------------------------+
              | Global Local File Cache   |      | Extension Storage Cache    |
              | ~/.idstack/cache/consensus|      | chrome.storage.local       |
              +-------------|-------------+      +--------------|-------------+
                            \                                  /
                       Cache Miss                         Cache Miss
                              \                              /
                               v                            v
                      +--------------------------------------------+
                      |             Consensus REST API             |
                      |     (Search, Consensus Meter, Papers)      |
                      +--------------------------------------------+
```

---

## Detailed Components

### 1. Persistent Caching & Storage

#### Global CLI Cache (`~/.idstack/cache/consensus/`)
- Indexed by SHA-256 hash of normalized claim text: `~/.idstack/cache/consensus/<claim_hash>.json`.
- Record Schema:
  ```json
  {
    "query": "elaborated feedback learning gains",
    "query_hash": "a1b2c3d4...",
    "cached_at": "2026-09-12T05:40:00Z",
    "consensus_meter": {
      "yes_pct": 88,
      "possibly_pct": 10,
      "no_pct": 2,
      "total_papers": 34
    },
    "top_papers": [
      {
        "title": "The Power of Feedback Revisited: A Meta-Analysis",
        "authors": ["Wisniewski, B.", "Zierer, K.", "Hattie, J."],
        "year": 2020,
        "journal": "Frontiers in Psychology",
        "study_design": "Meta-analysis",
        "tier": "T1",
        "doi_url": "https://doi.org/10.3389/fpsyg.2019.03087",
        "key_finding": "Elaborated feedback shows higher effect sizes (d = 0.48) than simple verification."
      }
    ]
  }
  ```
- **Cross-Course Reuse**: Because this cache is global, verifying a claim in one course ensures 0 API calls when auditing another course referencing the same instructional principle.

#### Chrome Extension Storage Cache
- Mirrored in `chrome.storage.local` under keys `consensus_cache_<claim_hash>` with equivalent schema.

---

### 2. Pre-Response Evidence QA Gate

#### The Verification Workflow
Before findings are delivered to the user or rendered into `.idstack/exports/<course-slug>/<skill>.html`:
1. **Local Catalog Check**: Does the citation already exist in `evidence/references.md`?
   - If YES: Pass immediately with the verified tier (0 API calls).
2. **Novel / Subject-Specific Claims**:
   - Extract the core pedagogical claim.
   - Check local cache (`<claim_hash>.json`).
   - If cache miss and `CONSENSUS_API_KEY` is present: query Consensus API and write to cache.
3. **Consensus Analysis & Auto-Correction**:
   - **Supported (Consensus >= 70% or T1/T2 paper)**: Finding passes. Evidence field is enriched with the exact citation, Consensus agreement percentage, and DOI.
   - **Contradicted (Neuromyth Guard)**: If Consensus indicates negative consensus (e.g. learning styles, left/right brain tailoring), the QA gate auto-rewrites the recommendation to an evidence-based alternative (e.g. dual coding) or strips the finding.
   - **Weak / Mixed Consensus**: Down-calibrates the tier to `T5` (Expert Guidance) and softens recommendation wording from an empirical mandate to "Consider...".
   - **Tier Calibration**: Prevents overclaiming. If the cited study is observational or qualitative, the tier is capped at `T3` or `T4`.

---

### 3. CLI Engine: `bin/idstack-consensus`

A zero-dependency Python 3.9+ script with three primary interfaces:
- `bin/idstack-consensus query --claim "<text>"`:
  Queries local cache or API, returning normalized JSON.
- `bin/idstack-consensus verify --findings "<path-to-staged-findings.json>" --output "<path-to-verified.json>"`:
  Runs the pre-response QA gate, updates tiers, corrects claims, and outputs verified findings.
- `bin/idstack-consensus sync [--domain "<domain-name>"] [--dry-run]`:
  On-demand utility that queries Consensus for recent (2024–2026) meta-analyses in the 11 research domains, formats candidates for `evidence/references.md`, and runs `test/check-evidence-cards.py` to preserve consistency.
- `bin/idstack-consensus status`:
  Reports cache statistics (number of cached claims, total API calls saved, API key configuration status).

---

### 4. Chrome Extension Integration

#### Settings (`extension/sidepanel/index.html` & `storage.js`)
- Adds `consensusApiKey` input to the Settings Drawer alongside the Google AI Studio key.
- Stored via `chrome.storage.sync.set({ consensusApiKey })`.

#### Background Verification Pass (`extension/background/service-worker.js`)
- When handling `RUN_AUDIT` or `CRAWL_AND_AUDIT_COURSE`:
  - After LLM generation, `shared/consensus-client.js` runs the QA gate over `data.findings`.
  - Attaches `f.consensus = { meter: 88, totalStudies: 34, verified: true, paperUrl: "..." }`.
  - Persists and sends verified results.

#### Sidepanel Findings UI (`extension/sidepanel/renderer-helper.js`)
- Renders a clean Consensus badge on finding cards:
  - `<span class="consensus-badge">✓ 88% Consensus (34 papers)</span>`
  - Turns citations into clickable links to the verified paper DOI.

---

### 5. Error Handling & Offline Fallbacks

- **Missing API Key**: Falls back silently to static `references.md` and `evidence-base.js`. No error alerts or broken audits.
- **Network Outage / API 5xx / Timeout**: Gracefully falls back to local cache or unverified pass-through with tier capped at T5.
- **Rate Limit (429)**: Logs `Consensus rate limit reached; using local evidence cache` and serves existing cache.

---

### 6. Testing & Verification Strategy

- **CLI Unit Tests (`test/test-consensus-cli.py`)**:
  - Validated under Python 3.9 (macOS default interpreter floor).
  - Tests cache hit/miss semantics (asserts 0 network calls on repeat query).
  - Tests tier calibration (asserts downgrading of overclaimed tiers).
  - Tests neuromyth auto-correction (asserts learning styles recommendations are caught).
- **Extension Tests (`test/test-sidepanel-logic.js` & `test/test-service-worker.js`)**:
  - Tests `consensus-client.js` with mock responses and `chrome.storage.local` caching.
  - Tests graceful handling of empty or invalid keys.
- **CI Smoke Test Integration (`test/smoke-test.sh`)**:
  - Asserts `bin/idstack-consensus` help and doctor checks succeed.
  - Asserts `check-evidence-cards.py` remains 100% clean.
