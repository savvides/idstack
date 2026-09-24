import assert from 'node:assert';
import {
  verifyFindingsWithConsensus,
  hashClaim,
  detectNeuromyth,
  autoCorrectNeuromyth
} from '../extension/shared/consensus-client.js';

async function runTests() {
  console.log('==> Starting Consensus Extension Client unit tests...');

  // Test 1: Passthrough when no Consensus API key is provided
  {
    const findings = [
      {
        severity: 'suggestion',
        tier: 'T1',
        citation: '[Assessment-8] Elaborated Feedback',
        observation: 'Rubric uses generic grading bands.',
        evidence: 'Elaborated criteria increase metacognitive monitoring.',
        recommendation: 'Add milestone descriptions for each level.'
      },
      {
        severity: 'info',
        tier: 'T2',
        citation: '[Alignment-2] Practice Alignment',
        observation: 'Practice questions match formative assessment items.',
        evidence: 'Retrieval practice strengthens consolidation.',
        recommendation: 'Maintain weekly practice questions.'
      }
    ];

    const result = await verifyFindingsWithConsensus(findings, '');
    assert.strictEqual(result.length, 2, 'Must return all findings');
    assert.strictEqual(result[0].citation, '[Assessment-8] Elaborated Feedback');
    assert.strictEqual(result[0].tier, 'T1', 'Must preserve original tier');
    assert.strictEqual(result[1].tier, 'T2', 'Must preserve original tier');
    assert.strictEqual(result[0].consensus, undefined, 'No consensus badge without cache hit or API response');
    console.log('  ✔ Test 1: Passthrough without API key passed');
  }

  // Test 2: Neuromyth auto-correction (Learning Styles)
  {
    const mythFinding = {
      severity: 'critical',
      tier: 'T3',
      citation: '[VARK] Learning Styles',
      observation: 'Content should cater to visual learners and auditory learners separately.',
      evidence: 'Adapting to individual learning styles improves retention according to the meshing hypothesis.',
      recommendation: 'Cater to individual learning styles with separate visual and auditory tracks.'
    };

    const detected = detectNeuromyth(mythFinding);
    assert.strictEqual(detected, 'learning_styles', 'Must detect learning_styles neuromyth');

    const result = await verifyFindingsWithConsensus([mythFinding], null);
    const corrected = result[0];

    assert.strictEqual(corrected.auto_corrected, true, 'Must flag auto_corrected as true');
    assert.strictEqual(corrected.qa_verified, true, 'Must flag qa_verified as true');
    assert.ok(
      corrected.recommendation.includes('multimodal presentation and dual coding'),
      'Recommendation must advise multimodal presentation and dual coding'
    );
    assert.ok(
      corrected.evidence.includes('[Auto-Corrected Neuromyth]'),
      'Evidence must prepend Auto-Corrected Neuromyth notice'
    );
    assert.ok(
      corrected.evidence.includes('Pashler et al., 2008') && corrected.evidence.includes('Mayer, 2021'),
      'Evidence must cite empirical literature debunking learning styles'
    );
    assert.ok(
      corrected.observation.includes('recognized neuromyth'),
      'Observation must note the debunked status'
    );
    console.log('  ✔ Test 2: Neuromyth auto-correction passed');
  }

  // Test 3: Neuromyth auto-correction (Hemisphere & 10% Brain)
  {
    const hemisphereFinding = {
      citation: '[Brain-1] Hemispheric Dominance',
      recommendation: 'Provide left-brain and right-brain activities.',
      evidence: 'Right-brain learners need creative tasks.'
    };
    const correctedHemisphere = autoCorrectNeuromyth(hemisphereFinding, 'hemisphere_learning');
    assert.ok(correctedHemisphere.recommendation.includes('integrated cognitive activities'));
    assert.ok(correctedHemisphere.evidence.includes('Hemispheric specialization'));

    const tenPercentFinding = {
      citation: '[Brain-2] Capacity Utilization',
      recommendation: 'Unlock the 90% dormant brain capacity.',
      evidence: 'Humans only use 10% of their brain.'
    };
    const correctedTen = autoCorrectNeuromyth(tenPercentFinding, 'ten_percent_brain');
    assert.ok(correctedTen.recommendation.includes('cognitive load'));
    assert.ok(correctedTen.evidence.includes('Cognitive Load Theory'));
    console.log('  ✔ Test 3: Additional neuromyths auto-corrected');
  }

  // Test 4: Cache hit in storage mock attaching consensus metadata
  {
    const claim = 'Elaborated criteria increase metacognitive monitoring.';
    const hash = await hashClaim(claim);
    const cacheKey = `consensus_cache_${hash}`;

    const mockStorageData = {
      [cacheKey]: {
        query: claim,
        consensus: {
          meter: 88,
          totalStudies: 34,
          verified: true,
          paperUrl: 'https://doi.org/10.1016/j.edurev.2019.100309'
        },
        cached_at: '2026-09-12T00:00:00Z'
      }
    };

    // Chrome storage-like mock (get/set)
    const mockStorage = {
      get: (keys, callback) => {
        const key = Array.isArray(keys) ? keys[0] : keys;
        const res = {};
        if (mockStorageData[key]) {
          res[key] = mockStorageData[key];
        }
        if (callback) callback(res);
        return Promise.resolve(res);
      },
      set: (items, callback) => {
        Object.assign(mockStorageData, items);
        if (callback) callback();
        return Promise.resolve();
      }
    };

    const finding = {
      severity: 'suggestion',
      tier: 'T1',
      citation: '[Assessment-8] Elaborated Feedback',
      observation: 'Rubric uses generic grading bands.',
      evidence: claim,
      recommendation: 'Add milestone descriptions for each level.'
    };

    const result = await verifyFindingsWithConsensus([finding], '', mockStorage);
    assert.strictEqual(result.length, 1);
    const verified = result[0];

    assert.ok(verified.consensus, 'Finding must have consensus object attached');
    assert.strictEqual(verified.consensus.meter, 88, 'Consensus meter must be 88');
    assert.strictEqual(verified.consensus.totalStudies, 34, 'Total studies must be 34');
    assert.strictEqual(verified.consensus.verified, true, 'Verified flag must be true');
    assert.strictEqual(verified.consensus.paperUrl, 'https://doi.org/10.1016/j.edurev.2019.100309', 'Paper URL must match');
    assert.strictEqual(verified.qa_verified, true, 'qa_verified flag must be true');
    console.log('  ✔ Test 4: Storage cache hit attaches consensus metadata');
  }

  // Test 5: Live API call simulation (when not in cache and API key is present)
  {
    const originalFetch = global.fetch;
    const storageStore = {};
    const mockStorage = {
      get: (keys, cb) => {
        const key = Array.isArray(keys) ? keys[0] : keys;
        const res = { [key]: storageStore[key] };
        if (cb) cb(res);
        return Promise.resolve(res);
      },
      set: (items, cb) => {
        Object.assign(storageStore, items);
        if (cb) cb();
        return Promise.resolve();
      }
    };

    let fetchCalled = false;
    global.fetch = async (url, options) => {
      fetchCalled = true;
      assert.strictEqual(url, 'https://api.consensus.app/v1/search');
      assert.strictEqual(options.method, 'POST');
      assert.strictEqual(options.headers['Authorization'], 'Bearer mock-consensus-key');
      const body = JSON.parse(options.body);
      assert.ok(body.query.length > 0);

      return {
        ok: true,
        status: 200,
        json: async () => ({
          consensus_meter: {
            yes_pct: 94,
            possibly_pct: 4,
            no_pct: 2,
            total_papers: 42
          },
          papers: [
            {
              title: 'Retrieval practice boosts long term retention',
              authors: ['Karpicke, J. D.', 'Roediger, H. L.'],
              year: 2008,
              study_type: 'Randomized Controlled Trial',
              doi_url: 'https://doi.org/10.1126/science.1152408'
            }
          ]
        })
      };
    };

    try {
      const finding = {
        severity: 'suggestion',
        tier: 'T2',
        citation: '[Cognitive-4] Retrieval Practice',
        evidence: 'Active retrieval practice stabilizes memory traces against decay.',
        recommendation: 'Embed frequent low-stakes retrieval quizzes.'
      };

      const result = await verifyFindingsWithConsensus([finding], 'mock-consensus-key', mockStorage);
      assert.ok(fetchCalled, 'fetch must be called when API key is present and item not cached');
      assert.ok(result[0].consensus, 'Consensus object must be attached from API response');
      assert.strictEqual(result[0].consensus.meter, 94);
      assert.strictEqual(result[0].consensus.totalStudies, 42);
      assert.strictEqual(result[0].consensus.paperUrl, 'https://doi.org/10.1126/science.1152408');

      // Verify it was saved to storageStore
      const hash = await hashClaim(finding.evidence);
      const cacheKey = `consensus_cache_${hash}`;
      assert.ok(storageStore[cacheKey], 'Result must be written to mock storage cache');
      assert.strictEqual(storageStore[cacheKey].consensus.meter, 94);
      console.log('  ✔ Test 5: Live API simulation and cache persistence passed');
    } finally {
      global.fetch = originalFetch;
    }
  }

  // Test 6: API failure graceful fallback (offline or 500)
  {
    const originalFetch = global.fetch;
    global.fetch = async () => {
      throw new Error('Network error / offline');
    };

    try {
      const finding = {
        severity: 'suggestion',
        tier: 'T2',
        citation: '[Models-1] ADDIE Model',
        evidence: 'Iterative design cycles improve instructional alignment.',
        recommendation: 'Apply formative evaluation across stages.'
      };

      const result = await verifyFindingsWithConsensus([finding], 'mock-key', {});
      assert.strictEqual(result.length, 1);
      assert.strictEqual(result[0].consensus, undefined, 'Consensus should be undefined on error');
      assert.strictEqual(result[0].tier, 'T2', 'Tier must remain intact');
      console.log('  ✔ Test 6: Network error graceful fallback passed');
    } finally {
      global.fetch = originalFetch;
    }
  }

  console.log('✅ All Consensus Extension Client tests passed successfully.');
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
