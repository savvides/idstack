import assert from 'node:assert';
import { installChrome, resetGlobals } from './extension-harness.mjs';
import {
  getSettings, saveSettings,
  getDossier, addToDossier, removeFromDossier, clearDossier
} from '../extension/shared/storage.js';

// Settings round-trip and defaults (independent of storage area, so the key can move)
installChrome();
assert.strictEqual((await getSettings()).apiKey, '', 'no key configured by default');
await saveSettings({ apiKey: 'test-key' });
assert.strictEqual((await getSettings()).apiKey, 'test-key');

// The key lives in chrome.storage.local, never sync (Chrome copies sync to the user's Google account).
let c = installChrome();
await saveSettings({ apiKey: 'k1' });
assert.deepStrictEqual(c.storage.local.apiKey, 'k1', 'key saved to local');
assert.ok(!('apiKey' in c.storage.sync), 'key not saved to sync');

// An older key in sync moves to local and is deleted from sync.
c = installChrome({ sync: { apiKey: 'old' } });
assert.strictEqual((await getSettings()).apiKey, 'old');
assert.strictEqual(c.storage.local.apiKey, 'old', 'migrated to local');
assert.ok(!('apiKey' in c.storage.sync), 'sync copy deleted');

// With a key in both areas, local wins and the sync copy is deleted.
c = installChrome({ sync: { apiKey: 'old' }, local: { apiKey: 'new' } });
assert.strictEqual((await getSettings()).apiKey, 'new');
assert.ok(!('apiKey' in c.storage.sync), 'sync copy deleted when local wins');

// Dossier: add, replace-by-url, remove, clear
const a = { url: 'https://canvas.instructure.com/courses/1/assignments/2', title: 'Lab 1', result: {} };
const b = { url: 'https://canvas.instructure.com/courses/1/assignments/3', title: 'Lab 2', result: {} };
await addToDossier(a);
await addToDossier(b);
await addToDossier({ ...a, title: 'Lab 1 (re-audited)' });
let dossier = await getDossier();
assert.strictEqual(dossier.length, 2, 're-auditing the same page replaces its entry');
assert.strictEqual(dossier[0].title, 'Lab 1 (re-audited)');
await removeFromDossier(dossier[1].id);
assert.deepStrictEqual((await getDossier()).map((d) => d.title), ['Lab 1 (re-audited)']);
await clearDossier();
assert.deepStrictEqual(await getDossier(), []);

// The previous version saved a full-course audit at the course URL with no fragment.
// Re-auditing the course replaces that item; a course-home page audit at the same URL stays.
const course = 'https://x.instructure.com/courses/5';
await addToDossier({ id: course, url: course, title: 'Old full audit', pageType: 'Canvas Course (Full Audit)', result: {} });
await addToDossier({ url: `${course}#full-course`, title: 'New full audit', pageType: 'Canvas Course (Full Audit)', result: {} });
assert.deepStrictEqual((await getDossier()).map((d) => d.title), ['New full audit'], 'a legacy full-course audit is replaced');
await clearDossier();
await addToDossier({ url: course, title: 'Course home', pageType: 'Canvas Course Home', result: {} });
await addToDossier({ url: `${course}#full-course`, title: 'Full audit', pageType: 'Canvas Course (Full Audit)', result: {} });
assert.deepStrictEqual((await getDossier()).map((d) => d.title), ['Course home', 'Full audit'], 'a course-home page audit is kept');
await clearDossier();

// Two removes in flight at once: neither item comes back.
await addToDossier(a);
await addToDossier(b);
await Promise.all((await getDossier()).map((d) => removeFromDossier(d.id)));
assert.deepStrictEqual(await getDossier(), [], 'concurrent removes do not bring an item back');
await Promise.all([addToDossier(a), addToDossier(b)]);
assert.strictEqual((await getDossier()).length, 2, 'concurrent adds keep both items');

// A failed write (quota) rejects, and the next write still runs.
const h = installChrome();
const realSet = h.chrome.storage.local.set;
h.chrome.storage.local.set = (items, cb) => { h.chrome.runtime.lastError = { message: 'QUOTA_BYTES quota exceeded' }; cb(); h.chrome.runtime.lastError = undefined; };
await assert.rejects(addToDossier(a), /QUOTA_BYTES/);
await assert.rejects(removeFromDossier('x'), /QUOTA_BYTES/);
await assert.rejects(clearDossier(), /QUOTA_BYTES/);
h.chrome.storage.local.set = realSet;
await addToDossier(a);
assert.strictEqual((await getDossier()).length, 1, 'a failed write does not block the next one');

resetGlobals();
console.log('✅ Storage helper tests passed.');
