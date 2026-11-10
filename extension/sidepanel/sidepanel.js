import { getSettings, saveSettings, getDossier, addToDossier, removeFromDossier, clearDossier, FULL_AUDIT_PAGE_TYPE } from '../shared/storage.js';
import { renderAuditHTML, renderDossierListHTML, escapeHtml } from './renderer-helper.js';
import { detectCourseContext } from '../content/extractor-core.js';
import { compileSingleAuditToMarkdown, compileDossierToMarkdown, dossierCourseLabel } from '../shared/dossier-compiler.js';

let activePayload = null;
let activeCourseContext = null;
let activeAuditResult = null;
let activeAuditItem = null;
let lastAuditBtn = null;
let lastCourseTarget = null; // `${origin}/courses/${id}` of the last course audit; null after a page audit
let refreshSeq = 0;

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

// A missing navigator.clipboard throws inside the try, so it is reported too.
async function copyWithFeedback(btn, text, idleLabel) {
  try {
    await navigator.clipboard.writeText(text);
    btn.textContent = '✓ Copied!';
  } catch (e) {
    btn.textContent = 'Not copied';
  }
  setTimeout(() => {
    btn.textContent = idleLabel;
  }, 2000);
}

async function updateDossierBadge() {
  const countEl = document.getElementById('dossier-count');
  if (!countEl) return;
  try {
    const dossier = await getDossier();
    countEl.textContent = String(dossier ? dossier.length : 0);
  } catch (e) {
    countEl.textContent = '0';
  }
}

async function updateDossierUI() {
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
          try {
            await removeFromDossier(id);
          } catch (err) {
            // updateDossierUI shows what the dossier still holds.
          }
          await updateDossierUI();
        }
      });
    });
  } catch (e) {
    listEl.innerHTML = '<div class="dossier-empty"><p>idstack cannot read the dossier.</p></div>';
  }
}

async function refreshActiveTab() {
  if (typeof chrome === 'undefined' || !chrome.tabs || !chrome.tabs.query) return;
  // Tab events can fire back to back; only the newest refresh may write state.
  const seq = ++refreshSeq;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (seq !== refreshSeq || !tab || !tab.id) return;

    const url = tab.url || '';
    activeCourseContext = detectCourseContext(url);
    const auditCourseBtn = document.getElementById('audit-course-btn');
    if (auditCourseBtn) {
      auditCourseBtn.style.display = activeCourseContext.isCourseRoot ? 'block' : 'none';
    }

    // No declarative content script: inject the extractor on demand. Its final
    // statement evaluates to the payload, which comes back as the injection result.
    // Needs access to the tab: activeTab (clicking the idstack icon on this tab) or a
    // host permission (*.instructure.com, or a site granted for a course audit).
    try {
      const [injection] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ['content/extractor.js']
      });
      if (seq !== refreshSeq) return;
      const response = injection && injection.result;
      if (response) {
        activePayload = response;
        const pageTypeTag = document.getElementById('page-type-tag');
        const pageTitle = document.getElementById('page-title');
        if (pageTypeTag) pageTypeTag.textContent = activeCourseContext.isCourseRoot ? 'Canvas Course Root' : response.pageType;
        if (pageTitle) pageTitle.textContent = response.title;
        return;
      }
    } catch (err) {
      // No access to this tab yet (switched to it without clicking the icon) or a
      // restricted page such as chrome:// or the Chrome Web Store.
    }

    if (seq !== refreshSeq) return;
    // Fallback payload if extraction fails. Without access Chrome hides tab.title too.
    const pageTypeTag = document.getElementById('page-type-tag');
    const pageTitle = document.getElementById('page-title');
    if (pageTypeTag) pageTypeTag.textContent = activeCourseContext.isCourseRoot ? 'Canvas Course Root' : 'Web Page';
    if (pageTitle) pageTitle.textContent = tab.title || 'Click the idstack toolbar icon to read this tab';
    activePayload = {
      url: tab.url || '',
      title: tab.title || 'Current Tab',
      pageType: activeCourseContext.isCourseRoot ? 'Canvas Course Root' : 'Web Page',
      content: '',
      // The service worker shows this instead of auditing an empty page.
      emptyReason: 'idstack cannot read this tab. If you moved to this tab from a different tab, click the idstack toolbar icon. Then audit again. idstack cannot read browser pages, for example chrome:// pages and the Chrome Web Store.'
    };
  } catch (e) {
    console.warn('Error refreshing active tab:', e);
  }
}

function showState(stateName) {
  document.querySelectorAll('.state-panel').forEach(el => el.classList.remove('active'));
  const target = document.getElementById(`${stateName}-state`);
  if (target) target.classList.add('active');
}

// source: the page (or course) the request was sent for. The active tab may
// have changed while the audit ran.
function renderResults(data, source) {
  activeAuditResult = data;
  activeAuditItem = {
    id: source?.url || `item-${Date.now()}`,
    title: source?.title || 'Course Material',
    pageType: source?.pageType || 'Web Page',
    url: source?.url || '',
    courseId: detectCourseContext(source?.url).courseId,
    courseOrigin: detectCourseContext(source?.url).origin,
    courseTitle: source?.courseTitle || null,
    result: data,
    timestamp: new Date().toISOString()
  };

  const addToDossierBtn = document.getElementById('add-to-dossier-btn');
  if (addToDossierBtn) {
    addToDossierBtn.textContent = '➕ Add to Dossier';
  }
  // renderError hides the bar; '' restores the stylesheet's display.
  const actionsBar = document.querySelector('.result-actions-bar');
  if (actionsBar) actionsBar.style.display = '';

  const container = document.getElementById('results-container');
  if (!container) return;

  container.innerHTML = renderAuditHTML(data);

  const copyBtn = document.getElementById('copy-improved-btn');
  if (copyBtn) {
    copyBtn.addEventListener('click', () => {
      const contentToCopy = (data && data.improvedDraft && data.improvedDraft.content) || '';
      copyWithFeedback(copyBtn, contentToCopy, '📋 Copy to Clipboard');
    });
  }

  const reAuditBtn = document.getElementById('re-audit-btn');
  if (reAuditBtn) {
    reAuditBtn.addEventListener('click', () => {
      showState('ready');
      refreshActiveTab();
    });
  }

  showState('results');
}

function renderError(errorMessage) {
  // Clear the last result so Add to Dossier / Export .md cannot act on it.
  activeAuditItem = null;
  const actionsBar = document.querySelector('.result-actions-bar');
  if (actionsBar) actionsBar.style.display = 'none';

  const container = document.getElementById('results-container');
  if (!container) return;

  const safeError = errorMessage ? escapeHtml(errorMessage) : 'An unknown error occurred during the audit.';

  container.innerHTML = `
    <div class="context-card error-card">
      <div class="error-header">
        <span class="error-icon">⚠️</span>
        <h4>Audit Error</h4>
      </div>
      <p class="error-msg">${safeError}</p>
      <div class="error-actions">
        <button id="error-retry-btn" class="primary-btn">Try Again</button>
        <button id="error-settings-btn" class="secondary-btn">Open Settings</button>
      </div>
    </div>
  `;

  const retryBtn = document.getElementById('error-retry-btn');
  if (retryBtn) {
    retryBtn.addEventListener('click', () => {
      showState('ready');
      // The course button reads activeCourseContext when clicked. After a tab switch to
      // another course, or off Canvas, re-clicking it would crawl, and ask for access
      // to, whatever is active now instead of the course that failed.
      const ctx = activeCourseContext || {};
      if (lastCourseTarget && lastCourseTarget !== `${ctx.origin}/courses/${ctx.courseId}`) return;
      if (lastAuditBtn) lastAuditBtn.click();
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
    try {
      await addToDossier(activeAuditItem);
      addToDossierBtn.textContent = '✓ Added to Dossier';
    } catch (e) {
      addToDossierBtn.textContent = 'Not added';
    }
    await updateDossierBadge();
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
    lastAuditBtn = auditBtn;
    lastCourseTarget = null;
    if (!activePayload) await refreshActiveTab();
    // Label the result with the page sent, not the tab active when the reply lands.
    const sent = activePayload;

    const progressCard = document.getElementById('crawl-progress-card');
    if (progressCard) progressCard.style.display = 'none';

    const loaderStatus = document.getElementById('loader-status');
    if (loaderStatus) loaderStatus.textContent = 'idstack examines the page...';

    showState('loading');

    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
      try {
        chrome.runtime.sendMessage({ action: 'RUN_AUDIT', payload: sent }, (response) => {
          if (chrome.runtime.lastError) {
            renderError(chrome.runtime.lastError.message);
            return;
          }
          if (response && response.success) {
            renderResults(response.data, sent);
          } else {
            renderError(response?.error || 'An unknown error occurred during the audit.');
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
    lastAuditBtn = auditCourseBtn;
    // Shown only after refreshActiveTab() found a course root, so the context is set.
    const { origin, courseId } = activeCourseContext || {};
    lastCourseTarget = `${origin}/courses/${courseId}`;
    // permissions.request needs this click's user gesture, so it comes before any other
    // await. Already-held access (*.instructure.com) resolves true with no prompt; other
    // Canvas hosts get a one-time Chrome prompt for that site only.
    let granted = false;
    try {
      granted = await chrome.permissions.request({ origins: [`${origin}/*`] });
    } catch (err) {
      // Not a requestable origin (optional_host_permissions covers https only)
    }
    if (!granted) {
      renderError(`idstack must have access to ${origin} to audit the full course.`);
      return;
    }

    const progressCard = document.getElementById('crawl-progress-card');
    const statusText = document.getElementById('crawl-status-text');
    const progressFill = document.getElementById('crawl-progress-fill');
    const loaderStatus = document.getElementById('loader-status');

    if (loaderStatus) loaderStatus.textContent = 'idstack audits the full Canvas course...';
    if (progressCard) progressCard.style.display = 'block';
    if (statusText) statusText.textContent = 'idstack reads the syllabus...';
    if (progressFill) progressFill.style.width = '25%';

    showState('loading');

    // These stages run on fixed timers (600 ms, 1300 ms), not on real progress: the
    // service worker sends one reply when the crawl and the audit both finish. A fast
    // reply skips the later stages; a slow crawl or model call stays at 85% until then.
    const timer1 = setTimeout(() => {
      if (statusText) statusText.textContent = 'idstack reads the assignments...';
      if (progressFill) progressFill.style.width = '60%';
    }, 600);

    const timer2 = setTimeout(() => {
      if (statusText) statusText.textContent = 'idstack examines the constructive alignment...';
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
            renderResults(response.data, {
              // Not the course home's URL: a course-home page audit has that id in the dossier.
              url: `${origin}/courses/${courseId}#full-course`,
              title: response.courseData?.title || 'Canvas Course',
              courseTitle: response.courseData?.title || null,
              pageType: FULL_AUDIT_PAGE_TYPE
            });
          } else {
            renderError(response?.error || 'An unknown error occurred during the course audit.');
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
    const courseTitle = dossierCourseLabel(dossier);
    const md = compileDossierToMarkdown(dossier, courseTitle);
    const safeTitle = sanitizeFilename(courseTitle);
    downloadMarkdownFile(`idstack-course-dossier-${safeTitle}.md`, md);
  });
}

if (copyDossierMdBtn) {
  copyDossierMdBtn.addEventListener('click', async () => {
    const dossier = await getDossier();
    const courseTitle = dossierCourseLabel(dossier);
    const md = compileDossierToMarkdown(dossier, courseTitle);
    await copyWithFeedback(copyDossierMdBtn, md, '📋 Copy Markdown');
  });
}

if (clearDossierBtn) {
  clearDossierBtn.addEventListener('click', async () => {
    if (!confirm('Remove all audits from the dossier? You cannot undo this.')) return;
    try {
      await clearDossier();
    } catch (e) {
      // updateDossierUI shows what the dossier still holds.
    }
    await updateDossierUI();
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
    await saveSettings({ apiKey: key });
    saveSettingsBtn.textContent = 'Saved!';
    setTimeout(() => {
      saveSettingsBtn.textContent = 'Save Settings';
      if (settingsDrawer) settingsDrawer.classList.remove('open');
    }, 1200);
  });
}

// The version badge shows v<major>.<minor> of the manifest version, so a
// manifest bump is the only change a release needs.
const versionBadge = document.querySelector('.badge-version');
if (versionBadge && typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.getManifest) {
  const [major, minor] = chrome.runtime.getManifest().version.split('.');
  versionBadge.textContent = `v${major}.${minor}`;
}

// Load initial settings & dossier count
(async () => {
  try {
    const settings = await getSettings();
    if (settings) {
      if (apiKeyInput && settings.apiKey) {
        apiKeyInput.value = settings.apiKey;
      }
    }
  } catch (e) {
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

// The service worker announces an icon click: activeTab now covers the current tab.
if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
  chrome.runtime.onMessage.addListener((msg) => {
    if (msg && msg.action === 'TAB_ACCESS_GRANTED') refreshActiveTab();
  });
}

// Initial tab detection on load
if (typeof chrome !== 'undefined' && chrome.tabs) {
  refreshActiveTab();
}


