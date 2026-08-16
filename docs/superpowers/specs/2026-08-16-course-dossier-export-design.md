# idstack Course Dossier & Compiled Markdown Export

## Overview
Instructional designers (IDs) often evaluate a course incrementally across multiple pages (syllabus, individual assignments, module rubrics, and discussion prompts). Rather than exporting individual files for every page, this feature introduces an **Audit Dossier** that collects findings as the ID navigates through the course. When ready, the ID can compile and export the entire collection into a single, cohesive Markdown document (`.md`) or copy it directly to the clipboard.

## Requirements & Scope

### 1. In-Scope
- **Dossier Session Collection:**
  - Capability to add any single-page or full-course audit result to the active Course Dossier.
  - Header badge in the Side Panel indicating the active dossier item count (e.g., `📁 Dossier (3)`).
- **Dossier Management Drawer:**
  - Drawer view listing all collected audits in the active session with title, page type, timestamp, and remove (trash) action.
  - "Clear Dossier" action to reset the session.
- **Compiled Markdown Export Engine:**
  - Generates a structured multi-section Markdown document combining all collected audits:
    1. Executive Course Summary (Course title, date, total audited components, overall Bloom's distribution, and alignment score).
    2. Consolidated Cross-Course Action Items (Grouped T1 & T2 research-backed findings).
    3. Itemized Section Breakdowns (Individual page findings with empirical citations and rewritten rubrics/prompts).
  - "📥 Download Compiled Dossier (.md)" triggers a browser file download.
  - "📋 Copy Compiled Markdown" copies the full formatted document to clipboard with visual confirmation.
- **Single-Page Quick Export:**
  - Quick action on any audit result to download that individual page's Markdown or copy it.
- **Client-Side Persistence:**
  - Persisted in `chrome.storage.local` under `activeDossier` so navigation across tabs and page reloads never lose collected audits.

### 2. Out-of-Scope (Deferred)
- Branded PDF generation or dedicated print preview tabs (explicitly deferred per user request).

---

## Architecture & Data Flow

### 1. Storage Schema (`storage.js`)
```javascript
// Dossier item structure
{
  id: string, // UUID or timestamp
  url: string,
  title: string,
  pageType: string,
  timestamp: string, // ISO string
  result: {
    summary: { bloomsLevel, alignmentScore, keyTakeaway },
    findings: [ { severity, tier, citation, observation, evidence, recommendation } ],
    improvedDraft: { title, content }
  }
}

// Storage helpers
export async function getDossier(): Promise<Array<DossierItem>>
export async function addToDossier(item: DossierItem): Promise<Array<DossierItem>>
export async function removeFromDossier(id: string): Promise<Array<DossierItem>>
export async function clearDossier(): Promise<void>
```

### 2. UI Structure (`index.html` & `sidepanel.css`)
- **Header Badge:**
  ```html
  <button id="dossier-toggle-btn" class="dossier-pill" title="View Course Audit Dossier">
    <span class="dossier-icon">📁</span>
    <span id="dossier-count">0</span>
  </button>
  ```
- **Audit Results Actions:**
  ```html
  <div class="result-actions-bar">
    <button id="add-to-dossier-btn" class="secondary-btn">➕ Add to Dossier</button>
    <button id="export-single-md-btn" class="ghost-btn">📥 Export .md</button>
  </div>
  ```
- **Dossier Drawer (`#dossier-drawer`):**
  - Slide-out or overlay drawer listing collected items.
  - Action buttons: "Download Compiled .md", "Copy Markdown", "Clear Dossier".

### 3. Markdown Compiler Engine (`dossier-compiler.js` / `.cjs`)
- Pure function `compileDossierToMarkdown(dossierItems, courseTitle)` returning clean GitHub-flavored markdown with structured tables, blockquotes, and citation links.
- Single-page export function `compileSingleAuditToMarkdown(auditItem)`.

---

## Error Handling & Edge Cases
- **Duplicate Prevention:** Adding the same page multiple times updates the existing entry rather than duplicating, or provides a clear visual indication.
- **Empty Dossier:** The export buttons are disabled or prompt the user if the dossier is empty.
- **Sanitization & Safety:** Markdown formatting safely handles code fences, special characters, and long assignment descriptions.

---

## Testing Strategy
- Unit tests for `dossier-compiler.js` testing multi-audit markdown synthesis, header generation, and formatting.
- Unit tests for `storage.js` dossier helper functions (add, remove, clear, persistence).
- DOM & logic tests for Side Panel dossier drawer toggling, item count updates, and export click handlers.
