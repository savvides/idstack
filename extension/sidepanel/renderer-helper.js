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
  const findings = data.findings || [];
  const improvedDraft = data.improvedDraft || { title: 'Improved Draft', content: '' };

  const findingsHTML = findings.map(f => {
    const tier = escapeHtml(f.tier || 'T1');
    const tierClass = escapeHtml((f.tier || 'T1').toLowerCase());
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

