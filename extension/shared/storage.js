/**
 * idstack storage helper for Chrome sync and local storage.
 */
export async function getSettings() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(['apiKey', 'apiEndpoint', 'autoAudit'], (result) => {
      resolve({
        apiKey: result.apiKey || '',
        apiEndpoint: result.apiEndpoint || 'https://api.idstack.org/v1/audit',
        autoAudit: result.autoAudit ?? false
      });
    });
  });
}

export async function saveSettings(settings) {
  return new Promise((resolve) => {
    chrome.storage.sync.set(settings, () => resolve(true));
  });
}

export async function getAuditHistory() {
  return new Promise((resolve) => {
    chrome.storage.local.get(['auditHistory'], (result) => {
      resolve(result.auditHistory || []);
    });
  });
}

export async function saveAuditResult(entry) {
  return new Promise((resolve) => {
    chrome.storage.local.get(['auditHistory'], (result) => {
      const history = result.auditHistory || [];
      history.unshift({
        ...entry,
        timestamp: new Date().toISOString()
      });
      // Keep last 20 audits
      chrome.storage.local.set({ auditHistory: history.slice(0, 20) }, () => resolve(true));
    });
  });
}
