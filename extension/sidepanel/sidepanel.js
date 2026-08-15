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
      // Content script may not be injected on pre-existing tabs. Attempt programmatic injection.
      if (chrome.scripting && chrome.scripting.executeScript) {
        try {
          await chrome.scripting.executeScript({
            target: { tabId: tab.id },
            files: ['content/extractor.js']
          });
          const retryResponse = await chrome.tabs.sendMessage(tab.id, { action: 'EXTRACT_CONTENT' });
          if (retryResponse) {
            activePayload = retryResponse;
            const pageTypeTag = document.getElementById('page-type-tag');
            const pageTitle = document.getElementById('page-title');
            if (pageTypeTag) pageTypeTag.textContent = retryResponse.pageType;
            if (pageTitle) pageTitle.textContent = retryResponse.title;
            return;
          }
        } catch (injectionErr) {
          // Tab may be a chrome:// or restricted URL
        }
      }
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

export function renderError(errorMessage) {
  const container = document.getElementById('results-container');
  if (!container) return;

  const safeError = errorMessage
    ? String(errorMessage)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;')
    : 'Unknown error occurred during audit.';

  container.innerHTML = `
    <div class="context-card error-card">
      <div class="error-header">
        <span class="error-icon">⚠️</span>
        <h4>Audit Encountered an Issue</h4>
      </div>
      <p class="error-msg">${safeError}</p>
      <div class="error-actions">
        <button id="error-retry-btn" class="primary-btn">Retry Audit</button>
        <button id="error-settings-btn" class="secondary-btn">Open Settings</button>
      </div>
    </div>
  `;

  const retryBtn = document.getElementById('error-retry-btn');
  if (retryBtn) {
    retryBtn.addEventListener('click', () => {
      showState('ready');
      const btn = document.getElementById('audit-btn');
      if (btn) btn.click();
    });
  }

  const errorSettingsBtn = document.getElementById('error-settings-btn');
  if (errorSettingsBtn) {
    errorSettingsBtn.addEventListener('click', () => {
      const drawer = document.getElementById('settings-drawer');
      if (drawer) drawer.classList.add('open');
    });
  }

  showState('results');
}

// Audit button click handler
const auditBtn = document.getElementById('audit-btn');
if (auditBtn) {
  auditBtn.addEventListener('click', async () => {
    if (!activePayload) await refreshActiveTab();
    showState('loading');

    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
      try {
        chrome.runtime.sendMessage({ action: 'RUN_AUDIT', payload: activePayload }, (response) => {
          if (chrome.runtime.lastError) {
            renderError(chrome.runtime.lastError.message);
            return;
          }
          if (response && response.success) {
            renderResults(response.data);
          } else {
            renderError(response?.error || 'Unknown error occurred during audit.');
          }
        });
      } catch (err) {
        renderError(err.message);
      }
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
