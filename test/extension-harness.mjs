// Loads the SHIPPED extension files under Node with stubbed browser globals.
// Tests import extension/**/*.js directly; never copy a module into test/ or
// keep a hand-maintained twin (that is how the old .cjs copies worked).
//
// Fake-DOM limits: no entity decoding in text, innerText is not layout-aware,
// no event bubbling, selectors are limited to tag, #id, .a.b, [attr] and
// [attr="v"] with descendant combinators and comma lists. The parser expects
// well-formed markup: a close tag that does not match the open element is
// ignored, `<x />` on a non-void tag stays open, and an attribute value must
// not contain the other quote character.
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const EXT = new URL('../extension/', import.meta.url);
const require = createRequire(import.meta.url);

// ES modules (service worker, side panel, shared/*): each call re-runs the
// module's top-level code. Its imports stay cached, which is fine: they read
// chrome/fetch/document at call time, not at load time.
let freshCount = 0;
export function importFresh(relPath) {
  return import(`${new URL(relPath, EXT).href}?fresh=${++freshCount}`);
}

// Classic content scripts carry no ESM syntax, so Node loads them as CommonJS
// (via extractor.js's module.exports guard). A query string does not bust the
// CommonJS cache, hence require + cache delete. vm.Script first: Chrome runs
// content scripts as classic scripts, so import/export must fail here rather
// than be quietly accepted by Node's require(esm).
export function loadContentScript(relPath) {
  const file = fileURLToPath(new URL(relPath, EXT));
  new vm.Script(readFileSync(file, 'utf8'), { filename: file });
  delete require.cache[file];
  return require(file);
}

// Resolves after every already-queued promise callback has run.
export const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

export const EXTENSION_ID = 'idstackextensionidfortests';
// What chrome.runtime.onMessage sees for a message from the side panel page.
const PANEL_SENDER = { id: EXTENSION_ID, url: `chrome-extension://${EXTENSION_ID}/sidepanel/index.html` };

function storageArea(data) {
  return {
    // keys: string | string[] | null (everything) | { key: default }.
    // Callbacks run asynchronously, as in Chrome: two get-then-set sequences
    // in flight at once interleave here exactly as they do in the browser.
    get(keys, callback) {
      const defaults = keys && typeof keys === 'object' && !Array.isArray(keys) ? keys : {};
      const wanted = keys == null ? Object.keys(data) : typeof keys === 'string' ? [keys] : Array.isArray(keys) ? keys : Object.keys(keys);
      const out = {};
      for (const k of wanted) {
        if (k in data) out[k] = structuredClone(data[k]);
        else if (k in defaults) out[k] = defaults[k];
      }
      const done = Promise.resolve(out);
      if (callback) done.then(callback);
      return done;
    },
    set(items, callback) {
      Object.assign(data, structuredClone(items));
      const done = Promise.resolve();
      if (callback) done.then(() => callback());
      return done;
    }
  };
}

// Installs globalThis.chrome. Options:
//   sync, local       initial chrome.storage contents
//   tabs              what chrome.tabs.query resolves to
//   onTabMessage      (tabId, message) => response for chrome.tabs.sendMessage;
//                     omitted = reject like a tab with no content script
//   onRuntimeMessage  (message) => response for chrome.runtime.sendMessage
// Returns { chrome, storage, listeners, sent, dispatch }. storage.sync/.local
// are the live backing objects; sent records runtime.sendMessage calls;
// dispatch(message, sender = PANEL_SENDER) delivers to the registered
// runtime.onMessage listeners and resolves with the sendResponse value
// (undefined if no listener keeps the channel open and none responds).
export function installChrome({ sync = {}, local = {}, tabs = [], onTabMessage, onRuntimeMessage } = {}) {
  const storage = { sync: structuredClone(sync), local: structuredClone(local) };
  const listeners = { message: [], tabActivated: [], tabUpdated: [] };
  const sent = [];
  const chrome = {
    runtime: {
      id: EXTENSION_ID,
      getURL: (p = '') => `chrome-extension://${EXTENSION_ID}/${p}`,
      lastError: undefined,
      onMessage: { addListener: (fn) => listeners.message.push(fn) },
      sendMessage(message, callback) {
        sent.push(message);
        const reply = Promise.resolve(onRuntimeMessage ? onRuntimeMessage(message) : undefined);
        if (!callback) return reply; // MV3 promise form
        reply.then(callback);
      }
    },
    storage: { sync: storageArea(storage.sync), local: storageArea(storage.local) },
    tabs: {
      query: async () => tabs,
      sendMessage: async (tabId, message) => {
        if (!onTabMessage) throw new Error('Could not establish connection. Receiving end does not exist.');
        return onTabMessage(tabId, message);
      },
      onActivated: { addListener: (fn) => listeners.tabActivated.push(fn) },
      onUpdated: { addListener: (fn) => listeners.tabUpdated.push(fn) }
    },
    scripting: { executeScript: async () => [] },
    sidePanel: { setPanelBehavior: async () => {} }
  };
  globalThis.chrome = chrome;

  function dispatch(message, sender = PANEL_SENDER) {
    return new Promise((resolve) => {
      let responded = false;
      const sendResponse = (response) => {
        if (!responded) { responded = true; resolve(response); }
      };
      const keepOpen = listeners.message
        .map((fn) => fn(message, sender, sendResponse))
        .some((r) => r === true);
      if (!keepOpen && !responded) resolve(undefined);
    });
  }
  return { chrome, storage, listeners, sent, dispatch };
}

// Replaces globalThis.fetch; handler(url, init) returns a Response or throws.
// Returns the array of recorded { url, init } calls.
const realFetch = globalThis.fetch;
export function installFetch(handler) {
  const calls = [];
  globalThis.fetch = async (url, init = {}) => {
    calls.push({ url: String(url), init });
    return handler(String(url), init);
  };
  return calls;
}

export function jsonResponse(body, init = {}) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
    ...init
  });
}

// ---- Minimal DOM: enough for extractor.js selectors and sidepanel.js. ----
// Results come in document order, as in Chrome. Assigning innerHTML re-parses,
// so rendered buttons are live. Text is not entity-decoded: assert on structure
// (querySelector) rather than on decoded text.
const VOID_TAGS = new Set(['meta', 'link', 'img', 'br', 'hr', 'input']);

class FakeElement {
  constructor(tagName, attrs = {}) {
    this.tagName = tagName.toLowerCase();
    this.attrs = attrs;
    this.children = [];
    this.parentElement = null;
    this.listeners = {};
    this.value = attrs.value || '';
    this.style = {};
    for (const decl of (attrs.style || '').split(';')) {
      const [prop, val] = decl.split(':').map((s) => s && s.trim());
      if (prop && val) this.style[prop] = val;
    }
    const el = this;
    this.classList = {
      contains: (c) => el._classes().includes(c),
      add: (c) => { if (!el.classList.contains(c)) el.attrs.class = [...el._classes(), c].join(' '); },
      remove: (c) => { el.attrs.class = el._classes().filter((x) => x !== c).join(' '); },
      toggle: (c) => (el.classList.contains(c) ? (el.classList.remove(c), false) : (el.classList.add(c), true))
    };
  }
  _classes() { return (this.attrs.class || '').split(/\s+/).filter(Boolean); }
  get id() { return this.attrs.id || ''; }
  getAttribute(name) { return name in this.attrs ? this.attrs[name] : null; }
  get textContent() {
    return this.children.map((c) => (typeof c === 'string' ? c : c.textContent)).join(' ').trim();
  }
  set textContent(text) { this.children = [String(text)]; }
  get innerText() { return this.textContent; }
  set innerHTML(html) {
    this.children = parseHtml(String(html)).children;
    for (const c of this.children) if (typeof c !== 'string') c.parentElement = this;
  }
  appendChild(child) { child.parentElement = this; this.children.push(child); return child; }
  removeChild(child) { this.children = this.children.filter((c) => c !== child); return child; }
  addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn); }
  click() {
    const event = { type: 'click', target: this, currentTarget: this, stopPropagation() {}, preventDefault() {} };
    for (const fn of this.listeners.click || []) fn(event);
  }
  _descendants() {
    const out = [];
    const walk = (el) => { for (const c of el.children) if (typeof c !== 'string') { out.push(c); walk(c); } };
    walk(this);
    return out;
  }
  _matches(part) {
    if (part.startsWith('#')) return this.attrs.id === part.slice(1);
    if (part.startsWith('.')) return part.split('.').filter(Boolean).every((c) => this._classes().includes(c));
    if (part.startsWith('[')) {
      const m = part.match(/\[([a-zA-Z0-9_-]+)(?:="([^"]*)")?\]/);
      return !!m && (m[2] === undefined ? m[1] in this.attrs : this.attrs[m[1]] === m[2]);
    }
    return this.tagName === part.toLowerCase();
  }
  // Document order, like the real DOM: querySelector('a, b') returns whichever
  // matching element comes first in the page, not the first selector's match.
  querySelectorAll(selectorList) {
    const selectors = selectorList.split(',').map((s) => s.trim().split(/\s+/));
    return this._descendants().filter((el) => selectors.some((parts) => el._matchesSelector(parts)));
  }
  querySelector(selectorList) { return this.querySelectorAll(selectorList)[0] || null; }
  _matchesSelector(parts) {
    if (!this._matches(parts[parts.length - 1])) return false;
    let i = parts.length - 2;
    for (let anc = this.parentElement; anc && i >= 0; anc = anc.parentElement) {
      if (anc._matches(parts[i])) i--;
    }
    return i < 0;
  }
}

function parseHtml(html) {
  const root = new FakeElement('#root');
  const stack = [root];
  const tagRe = /<(\/)?([a-zA-Z0-9]+)([^>]*)>|([^<]+)/g;
  let m;
  while ((m = tagRe.exec(html)) !== null) {
    const [, isClose, tag, attrStr, text] = m;
    const top = stack[stack.length - 1];
    if (text) {
      if (text.trim()) top.children.push(text.trim());
    } else if (isClose) {
      if (stack.length > 1 && top.tagName === tag.toLowerCase()) stack.pop();
    } else {
      const attrs = {};
      const attrRe = /([a-zA-Z0-9_-]+)(?:=["']([^"']*)["'])?/g;
      let a;
      while ((a = attrRe.exec(attrStr)) !== null) attrs[a[1]] = a[2] || '';
      const el = new FakeElement(tag, attrs);
      top.appendChild(el);
      if (!VOID_TAGS.has(el.tagName)) stack.push(el);
    }
  }
  return root;
}

// Builds a document from an HTML string (does not touch globals).
export function createDocument(html) {
  const root = parseHtml(html);
  const titleEl = root.querySelector('title');
  return {
    title: titleEl ? titleEl.textContent : '',
    body: root.querySelector('body') || root,
    getElementById: (id) => root._descendants().find((el) => el.id === id) || null,
    querySelector: (s) => root.querySelector(s),
    querySelectorAll: (s) => root.querySelectorAll(s),
    createElement: (tag) => new FakeElement(tag)
  };
}

// Installs globalThis.document; defaults to the shipped side panel page.
export function installDocument(html = readFileSync(new URL('sidepanel/index.html', EXT), 'utf8')) {
  globalThis.document = createDocument(html);
  return globalThis.document;
}

export function resetGlobals() {
  delete globalThis.chrome;
  delete globalThis.document;
  delete globalThis.window;
  globalThis.fetch = realFetch;
}
