import { buildAuditPrompt, buildCourseAuditPrompt } from '../shared/prompts.js';
import { getSettings } from '../shared/storage.js';
import { cleanJsonResponse, getDemoAuditResult, getDemoCourseAuditResult } from './parser-helper.js';
import { crawlCanvasCourse } from './canvas-crawler.js';

const LLM_TIMEOUT_MS = 25000;   // Chrome kills an extension SW whose fetch response takes >30 s
// Fewer words than this means an unreadable page (browser page, PDF viewer,
// a single Modules item title); the model would return an audit of nothing.
const MIN_AUDIT_WORDS = 10;

// Extension 1.2.0 and earlier kept the last 20 audit results in
// chrome.storage.local, and nothing read them. Delete them on update, so an
// upgraded install keeps no more than PRIVACY.md says.
if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onInstalled) {
  chrome.runtime.onInstalled.addListener(() => {
    chrome.storage.local.remove('auditHistory').catch((err) => console.error(err));
  });
}

// Open the panel from action.onClicked, not openPanelOnActionClick: Chrome routes a
// side-panel-toggle click past its activeTab grant (crbug.com/40904917), and activeTab
// is how the panel reads pages now that no content script is declared. v1.0.0 stored
// `true` in the extension's prefs, so set it back to false explicitly.
if (typeof chrome !== 'undefined' && chrome.sidePanel && chrome.sidePanel.setPanelBehavior) {
  chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: false }).catch((err) => console.error(err));
}
if (typeof chrome !== 'undefined' && chrome.action && chrome.action.onClicked) {
  chrome.action.onClicked.addListener((tab) => {
    // No await before open(): it needs the click's user gesture.
    chrome.sidePanel.open({ windowId: tab.windowId });
    // An open panel re-reads the tab it can now access; if none is open yet, nothing listens.
    chrome.runtime.sendMessage({ action: 'TAB_ACCESS_GRANTED' }).catch(() => {});
  });
}

async function callLlmApi(apiKey, prompt) {
  const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'; // IDSTACK_CLI_LEAK_ALLOW
  const signal = AbortSignal.timeout(LLM_TIMEOUT_MS);
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.2
      }
    }),
    signal
  }).catch((err) => {
    // Chrome < 124 rejects a timed-out fetch with AbortError, so check the signal, not err.name.
    throw signal.aborted
      ? new Error(`The AI model did not send a result in ${LLM_TIMEOUT_MS / 1000} seconds. Try the audit again.`)
      : err;
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`AI API error (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) throw new Error('The AI model sent an empty response.');

  let result = null;
  try {
    result = cleanJsonResponse(rawText);
  } catch (e) {
    // Not JSON: the shape check below explains it.
  }
  // The renderer and dossier compiler read every finding and call string methods
  // on tier and severity; refuse a shape they cannot handle before it reaches them.
  const optionalString = (v) => v == null || typeof v === 'string';
  if (!Array.isArray(result?.findings) || !result.findings.every((f) => f && typeof f === 'object' && optionalString(f.tier) && optionalString(f.severity))) {
    throw new Error('The AI response is not in the audit format. Try the audit again.');
  }
  return result;
}

// One pipeline for both audits: the model, or the demo result when there is no
// key.
async function runAudit(input, buildPrompt, buildDemo) {
  const settings = await getSettings();
  const apiKey = settings?.apiKey?.trim();
  return apiKey ? callLlmApi(apiKey, buildPrompt(input)) : buildDemo(input);
}

if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    // Only the extension's own pages (the side panel) may start audits. A content-script
    // context shares sender.id, so compare the sender's URL with our origin instead.
    if (!String(sender.url || '').startsWith(chrome.runtime.getURL(''))) return;
    if (request.action === 'RUN_AUDIT') {
      (async () => {
        try {
          const wordCount = String(request.payload?.content || '').split(/\s+/).filter(Boolean).length;
          if (wordCount < MIN_AUDIT_WORDS) {
            // The extractor and side panel explain pages they could not or would not read.
            throw new Error(request.payload?.emptyReason || `This page does not have sufficient text to audit. It has ${wordCount} words, and an audit must have ${MIN_AUDIT_WORDS} words or more. Browser pages, PDF viewers and image-only pages do not give text to idstack. On Canvas, idstack reads only an assignment, a page, a syllabus, a rubric and the Modules view.`);
          }
          const auditResult = await runAudit(request.payload, buildAuditPrompt, getDemoAuditResult);

          sendResponse({ success: true, data: auditResult });
        } catch (err) {
          sendResponse({ success: false, error: err.message });
        }
      })();
      return true; // async reply
    }

    if (request.action === 'CRAWL_AND_AUDIT_COURSE') {
      (async () => {
        try {
          const { origin, courseId } = request.payload || {};
          // origin is spliced into a credentialed fetch URL: accept only a bare https
          // origin and a numeric course id, so no path or query can ride along.
          let target = null;
          try { target = new URL(origin); } catch (e) { /* not a URL */ }
          if (!target || target.protocol !== 'https:' || target.origin !== origin || !/^\d+$/.test(courseId)) {
            throw new Error('The Canvas course URL is not correct.');
          }
          const courseData = await crawlCanvasCourse(origin, courseId);
          if (!courseData.syllabus.trim() && courseData.assignments.length === 0) {
            throw new Error('This course has no syllabus text and no assignments for idstack to audit.');
          }
          const auditResult = await runAudit(courseData, buildCourseAuditPrompt, getDemoCourseAuditResult);

          sendResponse({ success: true, data: auditResult, courseData });
        } catch (err) {
          sendResponse({ success: false, error: err.message });
        }
      })();
      return true; // async reply
    }
  });
}



