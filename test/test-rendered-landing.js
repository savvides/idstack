#!/usr/bin/env node
/**
 * test-rendered-landing.js
 * Renders docs/index.html in headless Chrome and asserts what the page actually DOES, not what
 * its stylesheet says.
 *
 * test-responsive-landing.js scans CSS as text. That catches a rule being deleted, but six review
 * rounds found ways to ship a broken page past it — a selector list, an @container wrapper, an
 * @import, a <style> inside an HTML comment — because a text scanner can only forbid the spellings
 * someone thought of. This file forbids the OUTCOME instead: if the page overflows sideways or a
 * control is under the touch floor, it fails, no matter which spelling caused it.
 *
 * Keep both. The text suite is fast, runs everywhere, and names the exact rule that regressed;
 * this one is slower, needs a browser, and cannot be evaded.
 *
 * Chrome is located via $CHROME_PATH, then the usual macOS and Linux paths. With no browser this
 * exits 0 after printing a SKIP line — a silent pass would be worse than no test, so the line is
 * deliberately loud.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const landingPath = path.join(__dirname, '..', 'docs', 'index.html');

const CHROME_CANDIDATES = [
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome',
  '/usr/bin/google-chrome-stable',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
].filter(Boolean);

const chromePath = CHROME_CANDIDATES.find(p => { try { return fs.existsSync(p); } catch { return false; } });

if (!chromePath) {
  console.log('  SKIP: rendered landing page tests (no Chrome found; set CHROME_PATH to enable)');
  process.exit(0);
}
if (!fs.existsSync(landingPath)) {
  console.error(`${landingPath} does not exist`);
  process.exit(1);
}

// Widths worth asserting: the narrowest phone anyone still ships, the common iPhone/Android
// logical widths, both breakpoints the stylesheet declares, and a desktop width.
const WIDTHS = [320, 360, 375, 390, 414, 480, 640, 768, 880, 1024, 1280];
const TAP_MIN = 44;
const TAP_SELECTORS = ['.copy-btn', '.btn-chrome', '.footer-signup input[type="email"]', '.footer-signup button'];

const problems = [];
const sleep = ms => new Promise(r => setTimeout(r, ms));

const userDataDir = path.join(os.tmpdir(), `idstack-rendered-${process.pid}`);
const port = 9400 + (process.pid % 500);
let chrome = null;

function killChrome() {
  if (chrome && !chrome.killed) { try { chrome.kill('SIGKILL'); } catch { /* already gone */ } }
  try { fs.rmSync(userDataDir, { recursive: true, force: true }); } catch { /* best effort */ }
}
// A leaked headless Chrome survives the run and holds memory until reboot, so cover every exit.
process.on('exit', killChrome);
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => { killChrome(); process.exit(1); });

async function main() {
  chrome = spawn(chromePath, [
    '--headless=new', `--remote-debugging-port=${port}`,
    '--no-first-run', '--no-default-browser-check', '--disable-gpu',
    '--hide-scrollbars', '--no-sandbox',
    `--user-data-dir=${userDataDir}`, 'about:blank',
  ], { stdio: 'ignore' });

  let wsUrl = null;
  for (let i = 0; i < 80; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`);
      wsUrl = (await res.json()).webSocketDebuggerUrl;
      break;
    } catch { await sleep(150); }
  }
  if (!wsUrl) throw new Error('Chrome did not expose a debugging port within 12s');

  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => {
    ws.addEventListener('open', res);
    ws.addEventListener('error', () => rej(new Error('could not attach to Chrome')));
  });

  let id = 0;
  const pending = new Map();
  ws.addEventListener('message', e => {
    const msg = JSON.parse(e.data);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  });
  const send = (method, params = {}, sessionId) => new Promise(res => {
    const msg = { id: ++id, method, params };
    if (sessionId) msg.sessionId = sessionId;
    pending.set(msg.id, res);
    ws.send(JSON.stringify(msg));
  });

  const { result: { targetId } } = await send('Target.createTarget', { url: 'about:blank' });
  const { result: { sessionId } } = await send('Target.attachToTarget', { targetId, flatten: true });
  await send('Page.enable', {}, sessionId);
  await send('Runtime.enable', {}, sessionId);

  const fileUrl = 'file://' + landingPath;

  for (const width of WIDTHS) {
    await send('Emulation.setDeviceMetricsOverride',
      { width, height: 900, deviceScaleFactor: 1, mobile: width <= 640 }, sessionId);
    await send('Page.navigate', { url: fileUrl }, sessionId);
    await sleep(320);

    const expression = `(() => {
      const d = document.documentElement;
      // An element wider than the viewport is only a problem if it is not inside something that
      // scrolls it deliberately — the install command and the JSON panel are meant to scroll.
      const scrollsItself = el => {
        for (let n = el; n && n !== d; n = n.parentElement) {
          const o = getComputedStyle(n);
          if (/(auto|scroll)/.test(o.overflowX) || /(auto|scroll)/.test(o.overflow)) return true;
        }
        return false;
      };
      const offenders = [...document.querySelectorAll('body *')]
        .filter(el => el.getBoundingClientRect().right > d.clientWidth + 1 && !scrollsItself(el))
        .map(el => el.tagName.toLowerCase() +
          (typeof el.className === 'string' && el.className.trim()
            ? '.' + el.className.trim().split(/\\s+/).join('.') : ''))
        .slice(0, 5);
      const taps = {};
      for (const sel of ${JSON.stringify(TAP_SELECTORS)}) {
        const el = document.querySelector(sel);
        taps[sel] = el ? +el.getBoundingClientRect().height.toFixed(1) : null;
      }
      const bar = document.querySelector('.topbar');
      // Column counts, not declarations: a rule moved into a print-only, inverted, or
      // desktop-nested @media still reads as present in the stylesheet but stops applying here.
      const cols = sel => {
        const el = document.querySelector(sel);
        if (!el) return null;
        const t = getComputedStyle(el).gridTemplateColumns;
        return t && t !== 'none' ? t.trim().split(/\\s+/).length : null;
      };
      const cta = document.querySelector('.btn-chrome');
      const signup = document.querySelector('.footer-signup');
      return JSON.stringify({
        overflow: d.scrollWidth - d.clientWidth,
        offenders: [...new Set(offenders)],
        taps,
        navPosition: bar ? getComputedStyle(bar).position : null,
        pipelineCols: cols('.pipeline-flow'),
        outputCols: cols('.output-pair'),
        ctaFillsRow: cta ? Math.round(cta.getBoundingClientRect().width) >=
          Math.round(cta.parentElement.getBoundingClientRect().width) - 1 : null,
        signupDirection: signup ? getComputedStyle(signup).flexDirection : null,
        navLinksVisible: [...document.querySelectorAll('.nav-links a')]
          .filter(a => a.getBoundingClientRect().height > 0).length,
      });
    })()`;

    const { result: { result, exceptionDetails } } =
      await send('Runtime.evaluate', { expression, returnByValue: true }, sessionId);
    if (exceptionDetails) { problems.push(`w=${width}: page script threw while measuring`); continue; }
    const m = JSON.parse(result.value);

    if (m.overflow > 0) {
      problems.push(`w=${width}: page scrolls sideways by ${m.overflow}px` +
        (m.offenders.length ? ` — widest: ${m.offenders.join(', ')}` : ''));
    }
    for (const [sel, h] of Object.entries(m.taps)) {
      if (h === null) problems.push(`w=${width}: ${sel} is missing from the page`);
      else if (h < TAP_MIN) problems.push(`w=${width}: ${sel} renders ${h}px, under the ${TAP_MIN}px touch floor`);
    }
    if (m.navPosition !== 'sticky') {
      problems.push(`w=${width}: .topbar computes position:${m.navPosition}, expected sticky`);
    }
    if (width <= 480) {
      if (m.pipelineCols !== 1) problems.push(`w=${width}: .pipeline-flow renders ${m.pipelineCols} columns, expected 1`);
      if (m.ctaFillsRow === false) problems.push(`w=${width}: .btn-chrome does not fill its row`);
      if (m.signupDirection !== 'column') problems.push(`w=${width}: .footer-signup is ${m.signupDirection}, expected column`);
    }
    if (width <= 880 && m.outputCols !== 1) {
      problems.push(`w=${width}: .output-pair renders ${m.outputCols} columns, expected 1`);
    }
    if (width > 880 && m.outputCols !== 2) {
      problems.push(`w=${width}: .output-pair renders ${m.outputCols} columns, expected 2`);
    }
    if (m.navLinksVisible < 4) {
      problems.push(`w=${width}: only ${m.navLinksVisible} nav links are visible, expected 4`);
    }
  }
}

main()
  .then(() => {
    killChrome();
    if (problems.length) {
      console.error(`${problems.length} rendered problem(s) in docs/index.html:`);
      for (const line of problems) console.error(line);
      process.exit(1);
    }
    console.log(`✅ Rendered landing page tests passed (${WIDTHS.length} widths).`);
    process.exit(0);
  })
  .catch(err => {
    killChrome();
    console.error(`rendered landing page test could not run: ${err.message}`);
    process.exit(1);
  });
