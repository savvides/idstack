/**
 * idstack storage helper for Chrome sync and local storage.
 */
// The side panel saves a full-course audit with this page type.
export const FULL_AUDIT_PAGE_TYPE = 'Canvas Course (Full Audit)';

export async function getSettings() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(['apiKey'], (result) => {
      resolve({
        apiKey: result.apiKey || ''
      });
    });
  });
}

export async function saveSettings(settings) {
  return new Promise((resolve) => {
    chrome.storage.sync.set(settings, () => resolve(true));
  });
}

export async function getDossier() {
  return new Promise((resolve) => {
    chrome.storage.local.get(['activeDossier'], (result) => {
      resolve(result.activeDossier || []);
    });
  });
}

// Dossier writes are read-modify-write, so they run one at a time: two removes in
// flight would each write back the item the other removed.
let dossierQueue = Promise.resolve();
function queueDossierWrite(fn) {
  const run = dossierQueue.then(fn);
  dossierQueue = run.catch(() => {});
  return run;
}

// Rejects when Chrome refuses the write, for example over the storage quota.
function setDossier(dossier, value) {
  return new Promise((resolve, reject) => {
    chrome.storage.local.set({ activeDossier: dossier }, () => {
      if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
      else resolve(value);
    });
  });
}

export async function addToDossier(item) {
  return queueDossierWrite(async () => {
    const dossier = await getDossier();
    const id = item.id || (item.url ? item.url : `dossier-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`);
    const newItem = {
      ...item,
      id,
      timestamp: item.timestamp || new Date().toISOString()
    };
    // The previous version saved a full-course audit at the course URL with no '#full-course'.
    const legacyUrl = item.url && item.url.endsWith('#full-course') ? item.url.slice(0, -'#full-course'.length) : null;
    const existingIdx = dossier.findIndex((d) => (item.id && d.id === item.id) || (item.url && d.url && d.url === item.url)
      || (legacyUrl && d.url === legacyUrl && d.pageType === FULL_AUDIT_PAGE_TYPE));
    if (existingIdx >= 0) {
      dossier[existingIdx] = newItem;
    } else {
      dossier.push(newItem);
    }
    return setDossier(dossier, dossier);
  });
}

export async function removeFromDossier(id) {
  return queueDossierWrite(async () => {
    const dossier = (await getDossier()).filter((d) => d.id !== id);
    return setDossier(dossier, dossier);
  });
}

export async function clearDossier() {
  return queueDossierWrite(() => setDossier([], true));
}
