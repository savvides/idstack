/**
 * idstack storage helper for Chrome sync and local storage.
 */
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

export async function addToDossier(item) {
  return new Promise((resolve) => {
    chrome.storage.local.get(['activeDossier'], (result) => {
      let dossier = result.activeDossier || [];
      const id = item.id || (item.url ? item.url : `dossier-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`);
      const newItem = {
        ...item,
        id,
        timestamp: item.timestamp || new Date().toISOString()
      };
      const existingIdx = dossier.findIndex((d) => (item.id && d.id === item.id) || (item.url && d.url && d.url === item.url));
      if (existingIdx >= 0) {
        dossier[existingIdx] = newItem;
      } else {
        dossier.push(newItem);
      }
      chrome.storage.local.set({ activeDossier: dossier }, () => resolve(dossier));
    });
  });
}

export async function removeFromDossier(id) {
  return new Promise((resolve) => {
    chrome.storage.local.get(['activeDossier'], (result) => {
      const dossier = (result.activeDossier || []).filter((d) => d.id !== id);
      chrome.storage.local.set({ activeDossier: dossier }, () => resolve(dossier));
    });
  });
}

export async function clearDossier() {
  return new Promise((resolve) => {
    chrome.storage.local.set({ activeDossier: [] }, () => resolve(true));
  });
}
