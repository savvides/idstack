/**
 * idstack Side Panel HTML Renderer Helper (ES Module)
 */
export function renderAuditHTML(data) {
  if (!data) return '';
  const summary = data.summary || { bloomsLevel: 'N/A', alignmentScore: 'N/A', keyTakeaway: '' };
  const findings = data.findings || [];
  const improvedDraft = data.improvedDraft || { title: 'Improved Draft', content: '' };

  const findingsHTML = findings.map(f => {
    const tier = f.tier || 'T1';
    const tierClass = tier.toLowerCase();
    const severity = f.severity || 'info';
    const citation = f.citation || '';
    const observation = f.observation || '';
    const evidence = f.evidence || '';
    const recommendation = f.recommendation || '';

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

  return `
    <div class="context-card summary-card">
      <div class="score-row">
        <span class="chip">Bloom's: <strong>${summary.bloomsLevel || 'N/A'}</strong></span>
        <span class="chip">Alignment: <strong>${summary.alignmentScore || 'N/A'}</strong></span>
      </div>
      <p class="key-takeaway">${summary.keyTakeaway || ''}</p>
    </div>

    <h3 class="section-title">Evidence-Based Findings (${findings.length})</h3>
    <div class="findings-list">${findingsHTML}</div>

    <div class="improved-box">
      <div class="improved-header">
        <h4>${improvedDraft.title || 'Improved Draft'}</h4>
        <button id="copy-improved-btn" class="secondary-btn">📋 Copy to Clipboard</button>
      </div>
      <pre class="improved-content"><code>${improvedDraft.content || ''}</code></pre>
    </div>

    <div class="feedback-row">
      <span>Was this audit helpful?</span>
      <button class="feedback-btn" data-vote="up">👍</button>
      <button class="feedback-btn" data-vote="down">👎</button>
      <button id="re-audit-btn" class="link-btn">Audit Another Page</button>
    </div>
  `;
}
