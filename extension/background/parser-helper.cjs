/**
 * Helper to clean and parse JSON responses from LLM API.
 */
function cleanJsonResponse(rawText) {
  let cleaned = rawText.trim();
  if (cleaned.startsWith('```json')) cleaned = cleaned.replace(/^```json/, '');
  if (cleaned.startsWith('```')) cleaned = cleaned.replace(/^```/, '');
  if (cleaned.endsWith('```')) cleaned = cleaned.replace(/```$/, '');
  return JSON.parse(cleaned.trim());
}

function parseAuditResponse(rawText) {
  return cleanJsonResponse(rawText);
}

module.exports = {
  cleanJsonResponse,
  parseAuditResponse
};
