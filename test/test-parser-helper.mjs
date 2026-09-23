import assert from 'node:assert';
import { parseAuditResponse, cleanJsonResponse, getDemoAuditResult, getDemoCourseAuditResult } from '../extension/background/parser-helper.js';

// Test 1: Markdown fenced JSON with '```json'
const rawLlmResponse = "```json\n{\n  \"summary\": {\n    \"bloomsLevel\": \"Remember\",\n    \"alignmentScore\": \"Moderate\",\n    \"keyTakeaway\": \"Quiz focuses only on memorization.\"\n  },\n  \"findings\": [],\n  \"improvedDraft\": {\n    \"title\": \"Analysis Prompt\",\n    \"content\": \"Compare and contrast\"\n  }\n}\n```";

const parsed = parseAuditResponse(rawLlmResponse);
assert.strictEqual(parsed.summary.bloomsLevel, 'Remember');
assert.strictEqual(parsed.improvedDraft.title, 'Analysis Prompt');
assert.strictEqual(parsed.summary.alignmentScore, 'Moderate');

// Test 2: Markdown fenced JSON with '```' (without json tag)
const rawFencedNoTag = "```\n{\n  \"summary\": { \"bloomsLevel\": \"Analyze\" }\n}\n```";
const parsedNoTag = parseAuditResponse(rawFencedNoTag);
assert.strictEqual(parsedNoTag.summary.bloomsLevel, 'Analyze');

// Test 3: Raw clean JSON without fences
const rawPlainJson = '{"summary": {"bloomsLevel": "Create"}}';
const parsedPlain = parseAuditResponse(rawPlainJson);
assert.strictEqual(parsedPlain.summary.bloomsLevel, 'Create');

// Test 4: JSON with leading/trailing whitespace and fences
const rawWithWhitespace = '   \n```json\n{"summary": {"bloomsLevel": "Evaluate"}}\n```\n  ';
const parsedWhitespace = parseAuditResponse(rawWithWhitespace);
assert.strictEqual(parsedWhitespace.summary.bloomsLevel, 'Evaluate');

// Test 5: cleanJsonResponse alias
assert.strictEqual(typeof cleanJsonResponse, 'function');
const cleaned = cleanJsonResponse('{"key": "value"}');
assert.strictEqual(cleaned.key, 'value');

// Test 6: Demo fallback when API key is not configured
assert.strictEqual(typeof getDemoAuditResult, 'function', 'getDemoAuditResult must be a function');
const demoData = getDemoAuditResult({
  title: 'Enzymes Lab Analysis',
  pageType: 'Canvas Assignment'
});

assert.ok(demoData, 'Demo audit result must be returned');
assert.ok(demoData.summary.bloomsLevel.includes('Analyze'), "Demo result must demonstrate Bloom's classification");
assert.ok(demoData.summary.keyTakeaway.includes('Settings'), 'Demo result must note that Settings unlocks live audits');
assert.ok(demoData.findings.length >= 2, 'Demo result must provide multiple evidence-based findings');

const hasT1 = demoData.findings.some(f => f.tier === 'T1');
const hasT5 = demoData.findings.some(f => f.tier === 'T5');
assert.ok(hasT1, 'Demo findings must include T1 evidence tier badge');
assert.ok(hasT5, 'Demo findings must include T5 evidence tier badge');

assert.ok(demoData.improvedDraft.title, 'Demo draft must include title');
assert.ok(demoData.improvedDraft.content.includes('Settings'), 'Demo draft must remind user to configure API key in Settings');
assert.ok(demoData.improvedDraft.content.includes('Rubric'), 'Demo draft must provide an improved rubric draft');

// Test 7: Demo course-level audit fallback
assert.strictEqual(typeof getDemoCourseAuditResult, 'function', 'getDemoCourseAuditResult must be a function');
const demoCourseData = getDemoCourseAuditResult({
  title: 'Biology 101: Cell Systems'
});
assert.ok(demoCourseData, 'Demo course audit result must be returned');
assert.ok(demoCourseData.summary.keyTakeaway.includes('Course-Level Demo'));
assert.ok(demoCourseData.findings.length >= 2);
assert.ok(demoCourseData.improvedDraft.title.includes('Matrix'));

console.log('✅ Task 4 response parser & demo fallback tests passed.');


