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

resetGlobals();
console.log('✅ Storage helper tests passed.');
