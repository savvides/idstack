const assert = require('assert');
const { parseAuditResponse, cleanJsonResponse } = require('../extension/background/parser-helper.cjs');

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

console.log('✅ Task 4 response parser tests passed.');
