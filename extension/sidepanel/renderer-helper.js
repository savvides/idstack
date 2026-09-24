/**
 * idstack Side Panel HTML Renderer Helper (ES Module)
 */

export function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export function renderAuditHTML(data) {
  if (!data) return '';
  const summary = data.summary || { bloomsLevel: 'N/A', alignmentScore: 'N/A', keyTakeaway: '' };
  const findings = Array.isArray(data.findings) ? data.findings.filter((f) => f && typeof f === 'object') : [];
  const improvedDraft = data.improvedDraft || { title: 'Improved Draft', content: '' };

  const findingsHTML = findings.map(f => {
    const tierLabel = String(f.tier || 'T1');
    const tier = escapeHtml(tierLabel);
    const tierClass = escapeHtml(tierLabel.toLowerCase());
    const severity = escapeHtml(f.severity || 'info');
    const citation = escapeHtml(f.citation || '');
    const observation = escapeHtml(f.observation || '');
    const evidence = escapeHtml(f.evidence || '');
    const recommendation = escapeHtml(f.recommendation || '');

    return `
    <div class="finding-card severity-${severity}">
      <div class="finding-header">
        <span class="tier-badge tier-${tierClass}">${tier}</span>
        <span class="citation">${citation}</span>
      </div>
      <p class="finding-obs"><strong>Observation:</strong> ${observation}</p>
      <p class="finding-evi"><strong>Evidence:</strong> ${evidence}</p>
      <p class="finding-rec"><strong>Recommendation:</strong> ${recommendation}</p>
    </div>
  `;
  }).join('');

  const bloomsLevel = escapeHtml(summary.bloomsLevel || 'N/A');
  const alignmentScore = escapeHtml(summary.alignmentScore || 'N/A');
  const keyTakeaway = escapeHtml(summary.keyTakeaway || '');
  const draftTitle = escapeHtml(improvedDraft.title || 'Improved Draft');
  const draftContent = escapeHtml(improvedDraft.content || '');

  return `
    <div class="context-card summary-card">
      <div class="score-row">
        <span class="chip">Bloom's: <strong>${bloomsLevel}</strong></span>
        <span class="chip">Alignment: <strong>${alignmentScore}</strong></span>
      </div>
      <p class="key-takeaway">${keyTakeaway}</p>
    </div>

    <h3 class="section-title">Evidence-Based Findings (${findings.length})</h3>
    <div class="findings-list">${findingsHTML}</div>

    <div class="improved-box">
      <div class="improved-header">
        <h4>${draftTitle}</h4>
        <button id="copy-improved-btn" class="secondary-btn">📋 Copy to Clipboard</button>
      </div>
      <pre class="improved-content"><code>${draftContent}</code></pre>
    </div>

    <div class="feedback-row">
      <span>Was this audit helpful?</span>
      <button class="feedback-btn" data-vote="up">👍</button>
      <button class="feedback-btn" data-vote="down">👎</button>
      <button id="re-audit-btn" class="link-btn">Audit Another Page</button>
    </div>
  `;
}

export function renderDossierListHTML(dossierItems) {
  if (!Array.isArray(dossierItems) || dossierItems.length === 0) {
    return `
      <div class="dossier-empty">
        <p>No items in dossier yet.</p>
        <p class="help-text">Audit pages and click &ldquo;Add to Dossier&rdquo; to build your course dossier.</p>
      </div>
    `;
  }

  return dossierItems.map((item) => {
    const id = escapeHtml(item.id || '');
    const title = escapeHtml(item.title || 'Untitled Material');
    const pageType = escapeHtml(item.pageType || 'Page');
    const blooms = escapeHtml(item.result?.summary?.bloomsLevel || 'N/A');
    const alignment = escapeHtml(item.result?.summary?.alignmentScore || 'N/A');

    return `
      <div class="dossier-item" data-dossier-id="${id}">
        <div class="dossier-item-header">
          <span class="chip">${pageType}</span>
          <button class="dossier-delete-btn icon-btn" data-dossier-id="${id}" title="Remove from Dossier">✕</button>
        </div>
        <h4 class="dossier-item-title">${title}</h4>
        <div class="dossier-item-meta">
          <span>Bloom's: <strong>${blooms}</strong></span>
          <span>Alignment: <strong>${alignment}</strong></span>
        </div>
      </div>
    `;
  }).join('');
}

