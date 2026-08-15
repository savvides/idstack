import { getSettings, saveSettings } from '../shared/storage.js';
import { renderAuditHTML } from './renderer-helper.js';

let activePayload = null;

export async function refreshActiveTab() {
  if (typeof chrome === 'undefined' || !chrome.tabs || !chrome.tabs.query) return;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab || !tab.id) return;

    try {
      const response = await chrome.tabs.sendMessage(tab.id, { action: 'EXTRACT_CONTENT' });
      if (response) {
        activePayload = response;
        const pageTypeTag = document.getElementById('page-type-tag');
        const pageTitle = document.getElementById('page-title');
        if (pageTypeTag) pageTypeTag.textContent = response.pageType;
        if (pageTitle) pageTitle.textContent = response.title;
        return;
      }
    } catch (err) {
      // Content script not ready or page did not respond
    }

    // Fallback payload if content script extraction fails
    const pageTypeTag = document.getElementById('page-type-tag');
    const pageTitle = document.getElementById('page-title');
    if (pageTypeTag) pageTypeTag.textContent = 'Web Page';
    if (pageTitle) pageTitle.textContent = tab.title || 'Current Tab';
    activePayload = {
      url: tab.url || '',
      title: tab.title || 'Current Tab',
      pageType: 'Web Page',
      content: ''
    };
  } catch (e) {
    console.warn('Error refreshing active tab:', e);
  }
}

export function showState(stateName) {
  document.querySelectorAll('.state-panel').forEach(el => el.classList.remove('active'));
  const target = document.getElementById(`${stateName}-state`);
  if (target) target.classList.add('active');
}

export function renderResults(data) {
  const container = document.getElementById('results-container');
  if (!container) return;

  container.innerHTML = renderAuditHTML(data);

  const copyBtn = document.getElementById('copy-improved-btn');
  if (copyBtn) {
    copyBtn.addEventListener('click', () => {
      const contentToCopy = (data && data.improvedDraft && data.improvedDraft.content) || '';
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(contentToCopy);
      }
      copyBtn.textContent = '✓ Copied!';
      setTimeout(() => {
        copyBtn.textContent = '📋 Copy to Clipboard';
      }, 2000);
    });
  }

  const reAuditBtn = document.getElementById('re-audit-btn');
  if (reAuditBtn) {
    reAuditBtn.addEventListener('click', () => {
      showState('ready');
      refreshActiveTab();
    });
  }

  document.querySelectorAll('.feedback-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const parent = e.target.parentElement;
      if (parent) {
        parent.innerHTML = '<em>Thank you for your feedback!</em>';
      }
    });
  });

  showState('results');
}

// Audit button click handler
const auditBtn = document.getElementById('audit-btn');
if (auditBtn) {
  auditBtn.addEventListener('click', async () => {
    if (!activePayload) await refreshActiveTab();
    showState('loading');

    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
      chrome.runtime.sendMessage({ action: 'RUN_AUDIT', payload: activePayload }, (response) => {
        if (response && response.success) {
          renderResults(response.data);
        } else {
          alert(`Audit failed: ${response?.error || 'Unknown error'}`);
          showState('ready');
        }
      });
    }
  });
}

// Settings Drawer Management
const settingsToggle = document.getElementById('settings-toggle');
const closeSettings = document.getElementById('close-settings');
const settingsDrawer = document.getElementById('settings-drawer');
const saveSettingsBtn = document.getElementById('save-settings-btn');
const apiKeyInput = document.getElementById('api-key-input');

if (settingsToggle && settingsDrawer) {
  settingsToggle.addEventListener('click', () => {
    settingsDrawer.classList.toggle('open');
  });
}

if (closeSettings && settingsDrawer) {
  closeSettings.addEventListener('click', () => {
    settingsDrawer.classList.remove('open');
  });
}

if (saveSettingsBtn && apiKeyInput) {
  saveSettingsBtn.addEventListener('click', async () => {
    const key = apiKeyInput.value.trim();
    await saveSettings({ apiKey: key });
    saveSettingsBtn.textContent = 'Saved!';
    setTimeout(() => {
      saveSettingsBtn.textContent = 'Save Settings';
      if (settingsDrawer) settingsDrawer.classList.remove('open');
    }, 1200);
  });
}

// Load initial settings
(async () => {
  if (apiKeyInput) {
    try {
      const settings = await getSettings();
      if (settings && settings.apiKey) {
        apiKeyInput.value = settings.apiKey;
      }
    } catch (e) {
      // Ignored if storage not initialized
    }
  }
})();

// Listen for tab switching / updates
if (typeof chrome !== 'undefined' && chrome.tabs) {
  if (chrome.tabs.onActivated) {
    chrome.tabs.onActivated.addListener(() => {
      refreshActiveTab();
    });
  }
  if (chrome.tabs.onUpdated) {
    chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
      if (changeInfo.status === 'complete' && tab.active) {
        refreshActiveTab();
      }
    });
  }
}

// Initial tab detection on load
if (typeof chrome !== 'undefined' && chrome.tabs) {
  refreshActiveTab();
}
