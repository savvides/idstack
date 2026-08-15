import { buildAuditPrompt } from '../shared/prompts.js';
import { getSettings, saveAuditResult } from '../shared/storage.js';
import { cleanJsonResponse } from './parser-helper.js';

// Setup side panel behavior on action click
if (typeof chrome !== 'undefined' && chrome.sidePanel && chrome.sidePanel.setPanelBehavior) {
  chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch((err) => console.error(err));
}

async function callGeminiApi(apiKey, prompt) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.2
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`AI API error (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) throw new Error('Empty response from AI model.');

  return cleanJsonResponse(rawText);
}

if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'RUN_AUDIT') {
      (async () => {
        try {
          const settings = await getSettings();
          const prompt = buildAuditPrompt(request.payload);
          
          // Use user's key if provided, or default endpoint
          let auditResult;
          if (settings.apiKey) {
            auditResult = await callGeminiApi(settings.apiKey, prompt);
          } else {
            // Fallback demo mock or proxy endpoint
            auditResult = await callGeminiApi('YOUR_DEFAULT_API_KEY_OR_PROXY', prompt);
          }

          await saveAuditResult({
            url: request.payload.url,
            title: request.payload.title,
            pageType: request.payload.pageType,
            result: auditResult
          });

          sendResponse({ success: true, data: auditResult });
        } catch (err) {
          sendResponse({ success: false, error: err.message });
        }
      })();
      return true; // async reply
    }
  });
}

export { cleanJsonResponse, callGeminiApi };
