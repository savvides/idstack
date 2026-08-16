# idstack Chrome Extension Experiment — Design Specification

**Date:** 2026-08-15  
**Status:** Approved for Implementation  
**Topic:** Frictionless Evidence-Based Course Design Chrome Extension for Educators & Instructional Designers  

---

## 1. Executive Summary & Problem Statement

### 1.1 Context
`idstack` provides evidence-based instructional design skills powered by 108 peer-reviewed studies across 11 research domains, classifying learning objectives with Bloom's taxonomy and grading recommendations with evidence tiers (T1–T5).

While the existing Claude Code CLI plugin works well for terminal-proficient users, the vast majority of educators, faculty members, and instructional designers (IDs) work exclusively in graphical environments—primarily Learning Management Systems (Canvas LMS, Blackboard, Brightspace, Moodle), document processors (Google Docs, Microsoft Word), and web browsers.

### 1.2 The Opportunity
Building institutional LMS integrations (LTI 1.3, Canvas Developer Keys) introduces severe bureaucratic friction (IT security reviews, procurement cycles, administrator access requirements). A **Manifest V3 Chrome Extension** eliminates all institutional gatekeeping:
- An educator installs the extension directly from the Chrome Web Store in seconds.
- It operates directly on their active browser tab using their existing authenticated session.
- It provides a native Chrome Side Panel co-pilot that audits course material and produces actionable, evidence-backed improvements in seconds.

---

## 2. Core User Experience & Workflows

### 2.1 The 1-Click Audit Workflow
```
[Educator in Canvas / Google Doc]
       │
       ▼ (Clicks idstack extension icon)
[Chrome Side Panel Opens]
       │
       ▼ (Automatic platform detection: "Canvas Assignment Detected")
[User clicks "Audit with Evidence"]
       │
       ▼ (2-3s fast analysis via Gemini 3.7 Flash)
[Results Displayed in Side Panel]
 ├── Bloom's Taxonomy Level & Alignment Summary
 ├── Finding Cards with [T1]–[T5] Evidence Badges
 ├── 1-Click Improved Revision (Objective, Rubric, Prompt)
 └── "Copy to Clipboard" / "View Full Stakeholder Report"
```

### 2.2 Micro-Interactions & States
1. **Ready State:** Shows detected context (e.g. `[Canvas LMS] Intro to Biology - Module 2 Assignment`) with a clear call-to-action button: **"Audit Page with Evidence"**.
2. **Auditing State:** Displays an elegant skeleton loader with dynamic progress text (*"Extracting learning outcomes..."* → *"Checking Bloom's taxonomy..."* → *"Synthesizing research evidence..."*).
3. **Results State:**
   - **Summary Banner:** High-level Bloom's tier (e.g., *Remember / Understand vs. Analyze / Evaluate*) and alignment rating.
   - **Finding Cards:** Categorized by severity (Critical / Warning / Suggestion) with mono-tagged citation chips (e.g. `[Assessment-8] [T1]`).
   - **Actionable Rewrite Box:** Formatted revised rubric criteria or rewritten measurable learning objectives with a **"📋 Copy to Clipboard"** button.
   - **Feedback Mechanism:** Instant 1-click **"Helpful? 👍 / 👎"** toggle to collect experiment signal.
4. **Settings / Privacy State:** Clean drawer allowing users to view privacy commitments (zero student PII stored) and optionally enter a custom Gemini / Claude API key for BYOK mode.

---

## 3. System Architecture & Components

```
idstack/
├── extension/
│   ├── manifest.json              # Chrome MV3 configuration
│   ├── icons/                     # Branded icon assets (16x16, 48x48, 128x128)
│   ├── sidepanel/
│   │   ├── index.html             # Side panel DOM structure
│   │   ├── sidepanel.css          # Styled with idstack DESIGN.md design system
│   │   └── sidepanel.js           # UI logic, view transitions, clipboard operations
│   ├── content/
│   │   ├── extractor.js           # DOM content extractors (Canvas, Google Docs, generic web)
│   │   └── extractor.css          # Injected visual indicators (if applicable)
│   ├── background/
│   │   └── service-worker.js      # Background worker, message broker & API client
│   └── shared/
│       ├── evidence-base.js       # Curated T1-T5 evidence citations from evidence/references.md
│       ├── prompts.js             # Structured audit prompts and JSON output schemas
│       └── storage.js             # Chrome sync/local storage helpers
```

### 3.1 Content Script (`content/extractor.js`)
The content script is injected on demand or on target domains to extract course content without requiring Canvas API tokens:
- **Canvas LMS (`*.instructure.com` / `canvas.*.edu`):**
  - Targets `#assignment_show`, `.description.user_content`, `#rubrics`, `.module-item-title`, `#syllabusContainer`.
  - Captures title, learning outcomes, assignment instructions, and existing rubric grids.
- **Google Docs (`docs.google.com/document/*`):**
  - Extracts text from the active document container or user selection.
- **Generic Web Syllabi / Pages:**
  - Extracts semantic `<main>`, `<article>`, or high-density text containers while pruning navigational noise and footers.

### 3.2 Background Worker (`background/service-worker.js`)
- Receives audit requests from the Side Panel.
- Formats prompt with extracted DOM text + idstack research criteria.
- Dispatches request to the configured LLM endpoint (Gemini 3.7 Flash default proxy or local BYOK endpoint).
- Validates and parses the returned JSON schema and forwards results to the Side Panel.

---

## 4. Visual Design & Aesthetics (`DESIGN.md` Adherence)

The extension UI strictly complies with the existing `DESIGN.md` specification:

- **Typography:**
  - Body & headings: `Source Serif 4` for publication-grade, authoritative feel.
  - UI labels & buttons: `Public Sans` (clean official record aesthetic).
  - Citations, badges, & code: `JetBrains Mono` for `[Alignment-14] [T1]` evidence marks.
- **Color Tokens:**
  - Background: `#faf8f3` (pristine ivory).
  - Raised surfaces / cards: `#ffffff`.
  - Primary text: `#1a1815` (warm near-black).
  - Borders / Dividers: `#e6e0d2` hairline rules.
  - Evidence Tiers:
    - `T1` (Meta-analysis): Prussian blue `#1d4e89`
    - `T2` (Controlled trials): Teal `#007791`
    - `T3` (Observational): Olive `#588157`
    - `T4` (Case studies): Ochre `#c97a22`
    - `T5` (Expert guidance): Slate `#6c757d`
- **Zero Cliché Tropes:**
  - No purple gradients, no glowing neon borders, no emoji spam, no generic SaaS templates.

---

## 5. Security, Privacy & FERPA Compliance

1. **No Student Data Collection:** The extension operates solely on instructional design artifacts (syllabi, assignment prompts, rubrics, learning outcomes).
2. **Zero Permanent Storage on External Servers:** Prompts sent to the AI backend are processed ephemerally with zero data retention for training.
3. **Client-Side Manifest Memory:** Course manifests and audit history are persisted locally in `chrome.storage.local`.

---

## 6. Success Metrics & Validation Gate

For this experiment to be considered successful before expanding into larger features:
1. **Frictionless Completion:** A first-time user can install the extension and receive an audit in < 30 seconds.
2. **Utility Signal:** > 40% of audit runs result in the educator clicking **"Copy to Clipboard"** for the revised rubric/objective.
3. **Qualitative Rating:** > 80% positive ("👍") feedback on finding relevance and accuracy.

---

## 7. Implementation Plan Sequence

1. **Phase 1: Project Scaffolding & Manifest:** Create `extension/manifest.json`, icon assets, and baseline extension setup.
2. **Phase 2: Content Extraction Engine:** Implement `content/extractor.js` for Canvas LMS and general web pages.
3. **Phase 3: Side Panel UI & Design System:** Implement `sidepanel/index.html`, `sidepanel.css` (using `DESIGN.md` tokens), and interactive state rendering.
4. **Phase 4: LLM Audit Engine & Prompts:** Implement `background/service-worker.js` with structured Gemini 3.7 Flash prompting and JSON schema enforcement.
5. **Phase 5: Copy Actions & Stakeholder Report Generator:** Wire 1-click clipboard revision copying and standalone HTML report generation.
6. **Phase 6: Testing & Verification:** Verify on real Canvas pages and web syllabi.
