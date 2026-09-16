const assert = require('assert');
const { cleanJsonResponse } = require('../extension/background/parser-helper.cjs');

console.log("==> Running parser-helper tests...");

// Test 1: Plain JSON object
const plainObj = '{"key": "value"}';
const parsedPlainObj = cleanJsonResponse(plainObj);
assert.deepStrictEqual(parsedPlainObj, { key: 'value' });

// Test 2: Plain JSON array
const plainArr = '["item1", "item2"]';
const parsedPlainArr = cleanJsonResponse(plainArr);
assert.deepStrictEqual(parsedPlainArr, ["item1", "item2"]);

// Test 3: Markdown fenced JSON with ```json
const fencedJson = '```json\n{"summary": {"bloomsLevel": "Remember"}}\n```';
const parsedFencedJson = cleanJsonResponse(fencedJson);
assert.deepStrictEqual(parsedFencedJson, { summary: { bloomsLevel: "Remember" } });

// Test 4: Markdown fenced JSON with ```
const fencedPlain = '```\n{"summary": {"bloomsLevel": "Analyze"}}\n```';
const parsedFencedPlain = cleanJsonResponse(fencedPlain);
assert.deepStrictEqual(parsedFencedPlain, { summary: { bloomsLevel: "Analyze" } });

// Test 5: JSON with leading and trailing whitespace
const whitespaceJson = '   \n\t{"key": "value"} \n  ';
const parsedWhitespace = cleanJsonResponse(whitespaceJson);
assert.deepStrictEqual(parsedWhitespace, { key: "value" });

// Test 6: Fenced JSON with leading and trailing whitespace
const whitespaceFenced = '   \n```json\n{"key": "value"}\n```\n  ';
const parsedWhitespaceFenced = cleanJsonResponse(whitespaceFenced);
assert.deepStrictEqual(parsedWhitespaceFenced, { key: "value" });

// Test 7: Invalid JSON should throw SyntaxError
const invalidJson = '```json\n{"key": "value",}\n```';
let threwError = false;
try {
  cleanJsonResponse(invalidJson);
} catch (e) {
  if (e instanceof SyntaxError) {
    threwError = true;
  }
}
assert.strictEqual(threwError, true, "Invalid JSON should throw SyntaxError");

console.log("==> parser-helper tests passed!");
