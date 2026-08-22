/**
 * Injected content script listener for extracting course content.
 * Relies on shared/extractor-core.js being loaded in the same context.
 */

// Listen for messages from Side Panel
if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'EXTRACT_CONTENT') {
      // extractPageContent is provided by shared/extractor-core.js
      const data = typeof extractPageContent !== 'undefined' ? extractPageContent() : null;
      sendResponse(data);
    }
    return true;
  });
}
