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
