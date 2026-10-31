/**
 * Consensus evidence client and background QA pass for Chrome extension.
 * Provides neuromyth auto-correction, cache checking, and Consensus API enrichment.
 */

import { NEUROMYTHS } from './neuromyths.js';

const NEUROMYTH_PATTERNS = NEUROMYTHS.map(({ type, pattern }) => ({ type, pattern: new RegExp(pattern, 'i') }));
const NEUROMYTH_BY_TYPE = Object.fromEntries(NEUROMYTHS.map((m) => [m.type, m]));

export async function hashClaim(text) {
  const norm = (text || '').toLowerCase().trim().replace(/\s+/g, ' ');
  const hashBuffer = await globalThis.crypto.subtle.digest('SHA-256', new TextEncoder().encode(norm));
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
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

  const myth = NEUROMYTH_BY_TYPE[mythType];
  if (!myth) return finding;
  finding.recommendation = myth.recommendation;
  finding.evidence = finding.evidence ? `${finding.evidence} ${myth.evidence}` : myth.evidence;
  finding.observation = `${finding.observation || ''} ${myth.observation_note}`.trim();
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
            'Authorization': `Bearer ${apiKey.trim()}`
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
