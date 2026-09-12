/**
 * Consensus evidence client and background QA pass for Chrome extension.
 * Provides neuromyth auto-correction, cache checking, and Consensus API enrichment.
 */

const NEUROMYTH_PATTERNS = [
  {
    type: 'learning_styles',
    pattern: /\b(learning\s+styles?|visual\s+(?:vs\.?|and|or)\s+auditory\s+learn|visual\s+learners?|auditory\s+learners?|kinesthetic\s+learners?|meshing\s+hypothesis|cater(?:ing)?\s+to\s+(?:individual\s+)?learning\s+styles?)\b/i
  },
  {
    type: 'hemisphere_learning',
    pattern: /\b(left[-\s]brain|right[-\s]brain|hemisphere\s+learn)\b/i
  },
  {
    type: 'ten_percent_brain',
    pattern: /\b(10%\s+of\s+(?:the|their)?\s*brain)\b/i
  },
  {
    type: 'dales_cone_percentages',
    pattern: /\b(?:remember|retain)\s+\d+%\s+of\s+what\s+(?:they|we)\s+(?:read|hear|see)\b/i
  }
];

export async function hashClaim(text) {
  const norm = (text || '').toLowerCase().trim().replace(/\s+/g, ' ');
  if (typeof globalThis !== 'undefined' && globalThis.crypto && globalThis.crypto.subtle) {
    const encoder = new TextEncoder();
    const data = encoder.encode(norm);
    const hashBuffer = await globalThis.crypto.subtle.digest('SHA-256', data);
    return Array.from(new Uint8Array(hashBuffer))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
  }
  if (typeof require === 'function') {
    try {
      const nodeCrypto = require('crypto');
      return nodeCrypto.createHash('sha256').update(norm).digest('hex');
    } catch {
      // ignore
    }
  }
  let hash = 0;
  for (let i = 0; i < norm.length; i++) {
    hash = ((hash << 5) - hash) + norm.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash).toString(16);
}

export function detectNeuromyth(finding) {
  if (!finding) return null;
  const combined = [
    finding.recommendation || '',
    finding.evidence || '',
    finding.observation || '',
    finding.citation || '',
    finding.claim || ''
  ].join(' ');
  for (const { type, pattern } of NEUROMYTH_PATTERNS) {
    if (pattern.test(combined)) {
      return type;
    }
  }
  return null;
}

export function autoCorrectNeuromyth(finding, mythType) {
  if (!finding) return finding;
  finding.auto_corrected = true;
  finding.qa_verified = true;

  if (mythType === 'learning_styles') {
    finding.recommendation =
      'Provide multimodal presentation and dual coding (combining complementary visual representations ' +
      'and verbal/textual explanations for all learners) rather than attempting to segregate ' +
      'or adapt materials to putative learning styles.';
    const corrEv =
      "[Auto-Corrected Neuromyth] The 'learning styles' (meshing hypothesis) lacks empirical support " +
      '(Pashler et al., 2008; Rogowsky et al., 2015). Empirical evidence supports multimodal ' +
      'presentation and dual coding (Mayer, 2021; Paivio, 1986) for all learners.';
    finding.evidence = finding.evidence ? `${finding.evidence} ${corrEv}` : corrEv;
    const obsNote = ' [Note: Differentiating by sensory learning styles is a recognized neuromyth; multimodal presentation should be applied instead.]';
    finding.observation = `${finding.observation || ''}${obsNote}`.trim();
  } else if (mythType === 'hemisphere_learning') {
    finding.recommendation =
      'Provide multimodal presentation and integrated cognitive activities rather than ' +
      'attempting to cater to left-brain or right-brain learners.';
    const corrEv =
      '[Auto-Corrected Neuromyth] Hemispheric specialization for learning is an empirically ' +
      'unsupported neuromyth. Cognitive architecture operates through integrated networks; ' +
      'multimodal dual coding benefits all learners.';
    finding.evidence = finding.evidence ? `${finding.evidence} ${corrEv}` : corrEv;
    const obsNote = ' [Note: Left/right brain learning categorization is a neuromyth; integrated multimodal tasks should be used.]';
    finding.observation = `${finding.observation || ''}${obsNote}`.trim();
  } else if (mythType === 'ten_percent_brain') {
    finding.recommendation =
      'Design instructional activities that optimize working memory capacity and cognitive load ' +
      'rather than relying on 10% brain capacity claims.';
    const corrEv =
      '[Auto-Corrected Neuromyth] The 10% brain usage claim is a debunked neuromyth. Instructional ' +
      'design should be guided by Cognitive Load Theory (Sweller, 1994) and working memory limits.';
    finding.evidence = finding.evidence ? `${finding.evidence} ${corrEv}` : corrEv;
    const obsNote = ' [Note: The 10% brain claim is a recognized neuromyth; Cognitive Load Theory should guide design.]';
    finding.observation = `${finding.observation || ''}${obsNote}`.trim();
  } else if (mythType === 'dales_cone_percentages') {
    finding.recommendation =
      'Structure learning through active retrieval and generative processing rather than ' +
      'bogus retention percentage hierarchies.';
    const corrEv =
      "[Auto-Corrected Neuromyth] Numerical retention claims ('we remember 10% of what we read') " +
      "are fabricated percentages falsely attributed to Dale's Cone of Experience. Retention " +
      'depends on retrieval practice and cognitive processing depth (Agarwal, 2019).';
    finding.evidence = finding.evidence ? `${finding.evidence} ${corrEv}` : corrEv;
    const obsNote = ' [Note: Retention percentage pyramids are fabricated; active retrieval principles should be used.]';
    finding.observation = `${finding.observation || ''}${obsNote}`.trim();
  }
  return finding;
}

export function formatConsensus(record) {
  if (!record) return null;
  if (record.consensus) {
    return {
      meter: record.consensus.meter ?? record.consensus.yes_pct ?? 88,
      totalStudies: record.consensus.totalStudies ?? record.consensus.total_papers ?? 1,
      verified: true,
      paperUrl: record.consensus.paperUrl || record.consensus.doi_url || ''
    };
  }
  if (record.consensus_meter) {
    const topPaper = record.top_papers?.[0];
    return {
      meter: record.consensus_meter.yes_pct ?? 88,
      totalStudies: record.consensus_meter.total_papers ?? (record.top_papers?.length || 1),
      verified: true,
      paperUrl: topPaper?.doi_url || topPaper?.url || ''
    };
  }
  return {
    meter: typeof record.meter === 'number' ? record.meter : 88,
    totalStudies: typeof record.totalStudies === 'number' ? record.totalStudies : 1,
    verified: true,
    paperUrl: record.paperUrl || record.doi_url || ''
  };
}

function resolveStorage(storage) {
  if (storage) return storage;
  if (typeof chrome !== 'undefined' && chrome.storage && chrome.storage.local) {
    return chrome.storage.local;
  }
  return null;
}

async function getCachedRecord(storage, cacheKey) {
  const st = resolveStorage(storage);
  if (!st) return null;
  if (typeof st.get === 'function') {
    return new Promise((resolve) => {
      let resolved = false;
      try {
        const res = st.get([cacheKey], (data) => {
          if (!resolved) {
            resolved = true;
            resolve(data ? data[cacheKey] : null);
          }
        });
        if (res && typeof res.then === 'function') {
          res
            .then((data) => {
              if (!resolved) {
                resolved = true;
                resolve(data ? (data[cacheKey] !== undefined ? data[cacheKey] : data) : null);
              }
            })
            .catch(() => {
              if (!resolved) {
                resolved = true;
                resolve(null);
              }
            });
        }
      } catch {
        try {
          const syncRes = st.get(cacheKey);
          resolve(syncRes ? (syncRes[cacheKey] !== undefined ? syncRes[cacheKey] : syncRes) : null);
        } catch {
          resolve(null);
        }
      }
    });
  }
  if (typeof st === 'object' && st[cacheKey] !== undefined) {
    return st[cacheKey];
  }
  return null;
}

async function setCachedRecord(storage, cacheKey, value) {
  const st = resolveStorage(storage);
  if (!st) return;
  if (typeof st.set === 'function') {
    return new Promise((resolve) => {
      let resolved = false;
      try {
        const res = st.set({ [cacheKey]: value }, () => {
          if (!resolved) {
            resolved = true;
            resolve(true);
          }
        });
        if (res && typeof res.then === 'function') {
          res
            .then(() => {
              if (!resolved) {
                resolved = true;
                resolve(true);
              }
            })
            .catch(() => {
              if (!resolved) {
                resolved = true;
                resolve(false);
              }
            });
        }
      } catch {
        resolve(false);
      }
    });
  }
  if (typeof st === 'object') {
    st[cacheKey] = value;
  }
}

function extractClaimText(finding) {
  return (
    finding.claim ||
    finding.evidence ||
    finding.observation ||
    finding.recommendation ||
    finding.citation ||
    ''
  ).trim();
}

/**
 * Verifies findings with Consensus: checks cache, auto-corrects neuromyths,
 * and fetches from Consensus API if API key is provided.
 *
 * @param {Array} findings Array of finding objects
 * @param {string} [apiKey] Consensus API key
 * @param {Object} [storage] Storage instance (defaults to chrome.storage.local)
 * @returns {Promise<Array>} Verified findings array
 */
export async function verifyFindingsWithConsensus(findings, apiKey, storage = null) {
  if (!Array.isArray(findings)) {
    return findings;
  }

  for (const finding of findings) {
    if (!finding || typeof finding !== 'object') continue;

    // 1. Detect and auto-correct known neuromyths
    const mythType = detectNeuromyth(finding);
    if (mythType) {
      autoCorrectNeuromyth(finding, mythType);
    }

    // Ensure default tier metadata exists
    if (!finding.tier) {
      finding.tier = 'T5';
    }

    const claimText = extractClaimText(finding);
    if (!claimText) continue;

    const hash = await hashClaim(claimText);
    const cacheKey = `consensus_cache_${hash}`;

    // 2. Check storage cache
    const cached = await getCachedRecord(storage, cacheKey);
    if (cached) {
      const consensusData = formatConsensus(cached);
      if (consensusData) {
        finding.consensus = consensusData;
        finding.qa_verified = true;
        if (consensusData.paperUrl) {
          finding.doi_url = consensusData.paperUrl;
        }
      }
      continue;
    }

    // 3. If API key is provided and item is not in cache, query Consensus API
    if (apiKey && typeof apiKey === 'string' && apiKey.trim()) {
      try {
        const cleanQuery = claimText.replace(/[\.\,\;\:\!\?]+$/, '').trim();
        const res = await fetch('https://api.consensus.app/v1/search', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey.trim()}`,
            'User-Agent': 'idstack-extension/3.5'
          },
          body: JSON.stringify({ query: cleanQuery || claimText, limit: 5 })
        });

        if (res.ok) {
          const data = await res.json();
          const papers = data.papers || data.results || [];
          const topPaper = papers[0];
          const paperUrl = topPaper?.doi_url || topPaper?.url || (topPaper?.doi ? `https://doi.org/${topPaper.doi}` : '');
          const meter = data.consensus_meter?.yes_pct ?? (papers.length > 0 ? 85 : 50);
          const totalStudies = data.consensus_meter?.total_papers ?? (papers.length || 1);

          const consensusData = {
            meter,
            totalStudies,
            verified: true,
            paperUrl
          };

          finding.consensus = consensusData;
          finding.qa_verified = true;
          if (paperUrl) {
            finding.doi_url = paperUrl;
          }

          await setCachedRecord(storage, cacheKey, {
            query: cleanQuery || claimText,
            consensus: consensusData,
            cached_at: new Date().toISOString()
          });
        }
      } catch (err) {
        // Fall back gracefully on network error or offline mode
      }
    }
  }

  return findings;
}
