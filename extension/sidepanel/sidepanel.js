import { getSettings, saveSettings, getDossier, addToDossier, removeFromDossier, clearDossier } from '../shared/storage.js';
import { renderAuditHTML, renderDossierListHTML } from './renderer-helper.js';
import { detectCourseContext } from '../content/extractor-core.js';
import { compileSingleAuditToMarkdown, compileDossierToMarkdown } from '../shared/dossier-compiler.js';

let activePayload = null;
let activeCourseContext = null;
let activeAuditResult = null;
let activeAuditItem = null;

function sanitizeFilename(name) {
  return String(name || 'material')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '') || 'material';
}

function downloadMarkdownFile(filename, content) {
  const blob = new Blob([content], { type: 'text/markdown;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export async function updateDossierBadge() {
  const countEl = document.getElementById('dossier-count');
  if (!countEl) return;
  try {
    const dossier = await getDossier();
    countEl.textContent = String(dossier ? dossier.length : 0);
  } catch (e) {
    countEl.textContent = '0';
  }
}

export async function updateDossierUI() {
  await updateDossierBadge();
  const listEl = document.getElementById('dossier-list');
  if (!listEl) return;
  try {
    const dossier = await getDossier();
    listEl.innerHTML = renderDossierListHTML(dossier);

    listEl.querySelectorAll('.dossier-delete-btn').forEach((btn) => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const id = btn.getAttribute('data-dossier-id');
        if (id) {
          await removeFromDossier(id);
          await updateDossierUI();
        }
      });
    });
  } catch (e) {
    listEl.innerHTML = '<div class="dossier-empty"><p>Error loading dossier.</p></div>';
  }
}

export async function refreshActiveTab() {
  if (typeof chrome === 'undefined' || !chrome.tabs || !chrome.tabs.query) return;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab || !tab.id) return;

    const url = tab.url || '';
    activeCourseContext = detectCourseContext(url);
    const auditCourseBtn = document.getElementById('audit-course-btn');
    if (auditCourseBtn) {
      auditCourseBtn.style.display = activeCourseContext.isCourseRoot ? 'block' : 'none';
    }

    try {
      const response = await chrome.tabs.sendMessage(tab.id, { action: 'EXTRACT_CONTENT' });
      if (response) {
        activePayload = response;
        const pageTypeTag = document.getElementById('page-type-tag');
        const pageTitle = document.getElementById('page-title');
        if (pageTypeTag) pageTypeTag.textContent = activeCourseContext.isCourseRoot ? 'Canvas Course Root' : response.pageType;
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
            if (pageTypeTag) pageTypeTag.textContent = activeCourseContext.isCourseRoot ? 'Canvas Course Root' : retryResponse.pageType;
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
    if (pageTypeTag) pageTypeTag.textContent = activeCourseContext.isCourseRoot ? 'Canvas Course Root' : 'Web Page';
    if (pageTitle) pageTitle.textContent = tab.title || 'Current Tab';
    activePayload = {
      url: tab.url || '',
      title: tab.title || 'Current Tab',
      pageType: activeCourseContext.isCourseRoot ? 'Canvas Course Root' : 'Web Page',
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
  activeAuditResult = data;
  activeAuditItem = {
    id: activePayload?.url || `item-${Date.now()}`,
    title: activePayload?.title || 'Course Material',
    pageType: activePayload?.pageType || 'Web Page',
    url: activePayload?.url || '',
    result: data,
    timestamp: new Date().toISOString()
  };

  const addToDossierBtn = document.getElementById('add-to-dossier-btn');
  if (addToDossierBtn) {
    addToDossierBtn.textContent = '➕ Add to Dossier';
  }

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

  container.querySelectorAll('.feedback-btn').forEach(btn => {
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

// Result Action Bar: Add to Dossier & Export Single .md
const addToDossierBtn = document.getElementById('add-to-dossier-btn');
if (addToDossierBtn) {
  addToDossierBtn.addEventListener('click', async () => {
    if (!activeAuditItem) return;
    await addToDossier(activeAuditItem);
    await updateDossierBadge();
    addToDossierBtn.textContent = '✓ Added to Dossier';
    setTimeout(() => {
      addToDossierBtn.textContent = '➕ Add to Dossier';
    }, 2000);
  });
}

const exportSingleMdBtn = document.getElementById('export-single-md-btn');
if (exportSingleMdBtn) {
  exportSingleMdBtn.addEventListener('click', () => {
    if (!activeAuditItem) return;
    const md = compileSingleAuditToMarkdown(activeAuditItem);
    const safeTitle = sanitizeFilename(activeAuditItem.title);
    downloadMarkdownFile(`idstack-audit-${safeTitle}.md`, md);
  });
}

// Single-page Audit button click handler
const auditBtn = document.getElementById('audit-btn');
if (auditBtn) {
  auditBtn.addEventListener('click', async () => {
    if (!activePayload) await refreshActiveTab();

    const progressCard = document.getElementById('crawl-progress-card');
    if (progressCard) progressCard.style.display = 'none';

    const loaderStatus = document.getElementById('loader-status');
    if (loaderStatus) loaderStatus.textContent = 'Analyzing page content...';

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

// Course-level Audit button click handler
const auditCourseBtn = document.getElementById('audit-course-btn');
if (auditCourseBtn) {
  auditCourseBtn.addEventListener('click', async () => {
    if (!activePayload) await refreshActiveTab();

    const url = (activePayload && activePayload.url) || '';
    const courseCtx = activeCourseContext || detectCourseContext(url);
    const origin = courseCtx.origin || (url ? new URL(url).origin : '');
    const courseId = courseCtx.courseId;

    const progressCard = document.getElementById('crawl-progress-card');
    const statusText = document.getElementById('crawl-status-text');
    const progressFill = document.getElementById('crawl-progress-fill');
    const loaderStatus = document.getElementById('loader-status');

    if (loaderStatus) loaderStatus.textContent = 'Auditing Full Canvas Course...';
    if (progressCard) progressCard.style.display = 'block';
    if (statusText) statusText.textContent = 'Gathering syllabus...';
    if (progressFill) progressFill.style.width = '25%';

    showState('loading');

    const timer1 = setTimeout(() => {
      if (statusText) statusText.textContent = 'Fetching assignments...';
      if (progressFill) progressFill.style.width = '60%';
    }, 600);

    const timer2 = setTimeout(() => {
      if (statusText) statusText.textContent = 'Analyzing constructive alignment...';
      if (progressFill) progressFill.style.width = '85%';
    }, 1300);

    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
      try {
        chrome.runtime.sendMessage({
          action: 'CRAWL_AND_AUDIT_COURSE',
          payload: { origin, courseId }
        }, (response) => {
          clearTimeout(timer1);
          clearTimeout(timer2);
          if (progressFill) progressFill.style.width = '100%';
          if (chrome.runtime.lastError) {
            renderError(chrome.runtime.lastError.message);
            return;
          }
          if (response && response.success) {
            renderResults(response.data);
          } else {
            renderError(response?.error || 'Unknown error occurred during course audit.');
          }
        });
      } catch (err) {
        clearTimeout(timer1);
        clearTimeout(timer2);
        renderError(err.message);
      }
    }
  });
}

// Dossier Drawer Management & Actions
const dossierToggleBtn = document.getElementById('dossier-toggle-btn');
const closeDossier = document.getElementById('close-dossier');
const dossierDrawer = document.getElementById('dossier-drawer');
const exportDossierMdBtn = document.getElementById('export-dossier-md-btn');
const copyDossierMdBtn = document.getElementById('copy-dossier-md-btn');
const clearDossierBtn = document.getElementById('clear-dossier-btn');

if (dossierToggleBtn && dossierDrawer) {
  dossierToggleBtn.addEventListener('click', async () => {
    const settingsDrawer = document.getElementById('settings-drawer');
    if (settingsDrawer) settingsDrawer.classList.remove('open');
    dossierDrawer.classList.toggle('open');
    if (dossierDrawer.classList.contains('open')) {
      await updateDossierUI();
    }
  });
}

if (closeDossier && dossierDrawer) {
  closeDossier.addEventListener('click', () => {
    dossierDrawer.classList.remove('open');
  });
}

if (exportDossierMdBtn) {
  exportDossierMdBtn.addEventListener('click', async () => {
    const dossier = await getDossier();
    const courseTitle = (activeCourseContext && activeCourseContext.courseId)
      ? `Course ${activeCourseContext.courseId}`
      : (activePayload?.title || 'Canvas Course');
    const md = compileDossierToMarkdown(dossier, courseTitle);
    const safeTitle = sanitizeFilename(courseTitle);
    downloadMarkdownFile(`idstack-course-dossier-${safeTitle}.md`, md);
  });
}

if (copyDossierMdBtn) {
  copyDossierMdBtn.addEventListener('click', async () => {
    const dossier = await getDossier();
    const courseTitle = (activeCourseContext && activeCourseContext.courseId)
      ? `Course ${activeCourseContext.courseId}`
      : (activePayload?.title || 'Canvas Course');
    const md = compileDossierToMarkdown(dossier, courseTitle);
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(md);
    }
    copyDossierMdBtn.textContent = '✓ Copied!';
    setTimeout(() => {
      copyDossierMdBtn.textContent = '📋 Copy Markdown';
    }, 2000);
  });
}

if (clearDossierBtn) {
  clearDossierBtn.addEventListener('click', async () => {
    await clearDossier();
    await updateDossierUI();
  });
}

// Settings Drawer Management
const settingsToggle = document.getElementById('settings-toggle');
const closeSettings = document.getElementById('close-settings');
const settingsDrawer = document.getElementById('settings-drawer');
const saveSettingsBtn = document.getElementById('save-settings-btn');
const apiKeyInput = document.getElementById('api-key-input');
const consensusApiKeyInput = document.getElementById('consensus-api-key-input');

if (settingsToggle && settingsDrawer) {
  settingsToggle.addEventListener('click', () => {
    if (dossierDrawer) dossierDrawer.classList.remove('open');
    settingsDrawer.classList.toggle('open');
  });
}

if (closeSettings && settingsDrawer) {
  closeSettings.addEventListener('click', () => {
    settingsDrawer.classList.remove('open');
  });
}

if (saveSettingsBtn) {
  saveSettingsBtn.addEventListener('click', async () => {
    const key = apiKeyInput ? apiKeyInput.value.trim() : '';
    const consensusKey = consensusApiKeyInput ? consensusApiKeyInput.value.trim() : '';
    await saveSettings({ apiKey: key, consensusApiKey: consensusKey });
    saveSettingsBtn.textContent = 'Saved!';
    setTimeout(() => {
      saveSettingsBtn.textContent = 'Save Settings';
      if (settingsDrawer) settingsDrawer.classList.remove('open');
    }, 1200);
  });
}

// Load initial settings & dossier count
(async () => {
  try {
    const settings = await getSettings();
    if (settings) {
      if (apiKeyInput && settings.apiKey) {
        apiKeyInput.value = settings.apiKey;
      }
      if (consensusApiKeyInput && settings.consensusApiKey) {
        consensusApiKeyInput.value = settings.consensusApiKey;
      }
    }
  } catch (e) {
    console.warn('Error loading settings:', e);
    // Ignored if storage not initialized
  }
  await updateDossierBadge();
})();

// Listen for tab switching / updates
function handleTabActivated() {
  refreshActiveTab();
}

function handleTabUpdated(tabId, changeInfo, tab) {
  if (changeInfo.status === 'complete' && tab.active) {
    refreshActiveTab();
  }
}

if (typeof chrome !== 'undefined' && chrome.tabs) {
  if (chrome.tabs.onActivated) {
    chrome.tabs.onActivated.addListener(handleTabActivated);
  }
  if (chrome.tabs.onUpdated) {
    chrome.tabs.onUpdated.addListener(handleTabUpdated);
  }
}

// Initial tab detection on load
if (typeof chrome !== 'undefined' && chrome.tabs) {
  refreshActiveTab();
}


