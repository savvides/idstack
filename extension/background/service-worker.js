import { buildAuditPrompt, buildCourseAuditPrompt } from '../shared/prompts.js';
import { getSettings, saveAuditResult } from '../shared/storage.js';
import { cleanJsonResponse, getDemoAuditResult, getDemoCourseAuditResult } from './parser-helper.js';
import { crawlCanvasCourse } from './canvas-crawler.js';
import { verifyFindingsWithConsensus } from '../shared/consensus-client.js';

// Setup side panel behavior on action click
if (typeof chrome !== 'undefined' && chrome.sidePanel && chrome.sidePanel.setPanelBehavior) {
  chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch((err) => console.error(err));
}

async function callLlmApi(apiKey, prompt) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`; // IDSTACK_CLI_LEAK_ALLOW
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey
    },
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
          
          let auditResult;
          if (settings && settings.apiKey && settings.apiKey.trim()) {
            const prompt = buildAuditPrompt(request.payload);
            auditResult = await callLlmApi(settings.apiKey.trim(), prompt);
          } else {
            // Graceful demo fallback when no API key is provided
            auditResult = getDemoAuditResult(request.payload);
          }

          if (auditResult && auditResult.findings) {
            auditResult.findings = await verifyFindingsWithConsensus(auditResult.findings, settings?.consensusApiKey);
          }

          await saveAuditResult({
            url: request.payload?.url || '',
            title: request.payload?.title || 'Current Tab',
            pageType: request.payload?.pageType || 'Web Page',
            result: auditResult
          });

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
          const courseData = await crawlCanvasCourse(origin, courseId);
          const settings = await getSettings();

          let auditResult;
          if (settings && settings.apiKey && settings.apiKey.trim()) {
            const prompt = buildCourseAuditPrompt(courseData);
            auditResult = await callLlmApi(settings.apiKey.trim(), prompt);
          } else {
            // Graceful demo fallback for course audit
            auditResult = getDemoCourseAuditResult(courseData);
          }

          if (auditResult && auditResult.findings) {
            auditResult.findings = await verifyFindingsWithConsensus(auditResult.findings, settings?.consensusApiKey);
          }

          await saveAuditResult({
            url: `${origin}/courses/${courseId}`,
            title: courseData.title || 'Canvas Course',
            pageType: 'Canvas Course (Full Audit)',
            result: auditResult
          });

          sendResponse({ success: true, data: auditResult, courseData });
        } catch (err) {
          sendResponse({ success: false, error: err.message });
        }
      })();
      return true; // async reply
    }
  });
}

export { cleanJsonResponse, getDemoAuditResult, getDemoCourseAuditResult, crawlCanvasCourse, callLlmApi, verifyFindingsWithConsensus };


