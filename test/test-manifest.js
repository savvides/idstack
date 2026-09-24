const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Test manifest.json
const manifestPath = path.join(__dirname, '../extension/manifest.json');
assert.ok(fs.existsSync(manifestPath), 'manifest.json must exist');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

assert.strictEqual(manifest.manifest_version, 3);
assert.strictEqual(manifest.name, 'idstack — Evidence-Based Course Design');
assert.ok(manifest.permissions.includes('sidePanel'));
assert.ok(manifest.permissions.includes('storage'));
assert.ok(manifest.permissions.includes('activeTab'));
assert.ok(manifest.host_permissions && manifest.host_permissions.includes('https://generativelanguage.googleapis.com/*'), 'host_permissions for AI API required');
assert.ok(manifest.host_permissions && manifest.host_permissions.includes('*://*.instructure.com/*'), 'host_permissions for Canvas API required');

// F4: no declarative content script (its <all_urls> match put "all your data on all
// websites" on the install prompt). The panel injects the extractor on demand under
// activeTab; non-instructure Canvas hosts are requested per site at runtime.
assert.strictEqual(manifest.content_scripts, undefined, 'no declarative content_scripts');
assert.ok(manifest.permissions.includes('scripting'), 'scripting permission required for on-demand extraction');
assert.deepStrictEqual(manifest.optional_host_permissions, ['https://*/*'], 'custom-domain Canvas hosts are requested per site');
assert.ok(!manifest.host_permissions.some((h) => ['<all_urls>', '*://*/*', 'https://*/*', 'http://*/*'].includes(h)),
  'required host_permissions must stay narrow');
// chrome.sidePanel.open, called from the icon click, needs Chrome 116.
assert.ok(Number(manifest.minimum_chrome_version) >= 116, 'minimum_chrome_version must be at least 116 for sidePanel.open');

// The side panel's version badge shows v<major>.<minor> of the manifest version.
// The badge is hand-written, so a manifest bump alone would leave the panel showing the old version.
const sidepanelHtml = fs.readFileSync(path.join(__dirname, '../extension/sidepanel/index.html'), 'utf8');
const badge = sidepanelHtml.match(/<span class="badge-version">([^<]*)<\/span>/);
assert.ok(badge, 'side panel must show a version badge');
const [major, minor] = manifest.version.split('.');
assert.strictEqual(badge[1], `v${major}.${minor}`, `side panel badge ${badge[1]} must match manifest version ${manifest.version}`);

// Storage helper check
const storagePath = path.join(__dirname, '../extension/shared/storage.js');
assert.ok(fs.existsSync(storagePath), 'storage.js must exist');
const storageContent = fs.readFileSync(storagePath, 'utf8');
assert.ok(storageContent.includes('export async function getSettings()'), 'getSettings export required');
assert.ok(storageContent.includes('export async function saveSettings('), 'saveSettings export required');
assert.ok(storageContent.includes('export async function getAuditHistory()'), 'getAuditHistory export required');
assert.ok(storageContent.includes('export async function saveAuditResult('), 'saveAuditResult export required');

// Icons check
assert.ok(fs.existsSync(path.join(__dirname, '../extension/icons/icon-16.png')), 'icon-16.png must exist');
assert.ok(fs.existsSync(path.join(__dirname, '../extension/icons/icon-48.png')), 'icon-48.png must exist');
assert.ok(fs.existsSync(path.join(__dirname, '../extension/icons/icon-128.png')), 'icon-128.png must exist');

console.log('✅ Task 1 manifest checks passed.');
