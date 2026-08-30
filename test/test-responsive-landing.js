#!/usr/bin/env node
/**
 * test-responsive-landing.js
 * Validates responsive design, CSS media queries, fluid units, and mobile ergonomics in docs/index.html.
 *
 * Accumulating problems rather than throwing on the first means a direct run reports every
 * regression at once. Separately: check() (test/test-helper.sh, which smoke-test.sh sources) prints
 * only the first 5 lines of a failing command, so per-assertion "PASS:" logs would push the real
 * failure out of view — hence no PASS logging, and the problem count printed first so it survives
 * that truncation. Under CI the 5-line cap still elides the 5th problem onward.
 *
 * Three rules this file learned the hard way:
 *
 * 1. An assertion that REQUIRES a value pins the value the page actually ships. An alternation
 *    like (32|36|40|44)px reads as tolerance but lets the regression it exists to catch pass.
 *    In a PROHIBITION the reverse holds — widening the alternation forbids more, which is safe;
 *    that is why the overflow-x guard below legitimately lists (clip|hidden).
 * 2. Scan the <style> blocks — all of them — never the raw file. A rule inside an HTML comment
 *    or a <script> string is dead in every browser, and a raw-text scan cannot tell it from a
 *    live rule. A scoped floor is not a floor either: see unconditional().
 * 3. A regex cannot check that a rule lives INSIDE a given @media block: `[^}]*` stops at the first
 *    nested rule's brace and `[\s\S]*?` runs straight past the block's end, so both admit a rule
 *    that has been moved to a different breakpoint. Use mediaBlocks() for anything breakpoint-scoped.
 */

const fs = require('fs');
const path = require('path');

const landingPath = path.join(__dirname, '..', 'docs', 'index.html');

if (!fs.existsSync(landingPath)) {
  console.error(`${landingPath} does not exist`);
  process.exit(1);
}

const html = fs.readFileSync(landingPath, 'utf8');
const problems = [];

// expect(condition, message) — records a problem instead of throwing, so one run reports every
// responsive property that regressed.
function expect(condition, message) {
  if (!condition) problems.push(`docs/index.html: ${message}`);
}

// Separate channel for the parser self-tests below. Routing them through expect() would prefix
// them with "docs/index.html:" and blame the page for a bug in this file's own helpers.
const harnessProblems = [];
function harness(condition, message) {
  if (!condition) harnessProblems.push(`test harness: ${message}`);
}

// Every <style> element's contents, concatenated, with CSS comments, HTML comments and braces
// inside strings neutralised. Blanking rather than deleting keeps offsets and line counts truthful.
// Without it a `content: "{"` or a `/* } */` desynchronises the brace counter below and the suite
// blames a rule that is present. All blocks, not just the first: a second one was invisible to
// every assertion here, which defeated the --tap-min uniqueness check outright.
function stylesheet(doc) {
  const blocks = [...doc.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map(m => m[1]);
  if (!blocks.length) return '';
  const src = blocks.join('\n');
  const blank = s => s.replace(/[^\n]/g, ' ');
  let out = '';
  for (let i = 0; i < src.length; ) {
    if (src[i] === '/' && src[i + 1] === '*') {
      const end = src.indexOf('*/', i + 2);
      const stop = end === -1 ? src.length : end + 2;
      out += blank(src.slice(i, stop));
      i = stop;
    } else if (src.startsWith('<!--', i)) {
      // Measured in Chrome 151: an @media block wrapped in <!-- --> inside <style> does NOT apply
      // (and neither does one placed after the -->), so a breakpoint rule in here is dead and must
      // not satisfy an assertion. Note the narrower truth: a PLAIN rule between the markers does
      // still apply, since CDO/CDC are ignored tokens — blanking it is conservative, not exact.
      // docs/index.html carries no <!-- in its <style>, so this branch is unreached today.
      const end = src.indexOf('-->', i + 4);
      const stop = end === -1 ? src.length : end + 3;
      out += blank(src.slice(i, stop));
      i = stop;
    } else if (src[i] === '"' || src[i] === "'") {
      // Neutralise only braces inside the string. Blanking the whole literal would also erase
      // attribute selectors like input[type="email"], which the assertions below match on.
      const quote = src[i];
      let j = i + 1;
      while (j < src.length && src[j] !== quote && src[j] !== '\n') {
        if (src[j] === '\\') j++;
        j++;
      }
      const stop = Math.min(j + 1, src.length);
      out += src.slice(i, stop).replace(/[{}]/g, ' ');
      i = stop;
    } else {
      out += src[i];
      i++;
    }
  }
  return out;
}

// Concatenated bodies of every `@media (max-width: <px>)` block, brace-matched. The page carries
// several 480px blocks, each next to the component it styles, so a rule may legitimately be in any
// of them — but it must be in one of them, which is exactly what a regex cannot verify.
// Takes css as a parameter so it can be self-tested below against inputs other than the real page.
function mediaBlocks(css, maxWidthPx, rejected) {
  const open = new RegExp(`@media([^{]*max-width:\\s*${maxWidthPx}px[^{]*)\\{`, 'g');
  const bodies = [];
  let m;
  while ((m = open.exec(css)) !== null) {
    const prelude = m[1].trim();
    // `not` inverts the query, a non-screen media type never applies on screen, and a comma
    // introduces an unrelated alternative. None of these scope a rule to this breakpoint.
    const type = prelude.match(/^([a-zA-Z-]+)\s+and\b/);
    if (/\bnot\b/.test(prelude) || prelude.includes(',') ||
        (type && !/^(screen|all)$/i.test(type[1]))) {
      if (rejected) rejected.push(prelude);
      continue;
    }
    const bodyStart = m.index + m[0].length;
    let depth = 1;
    for (let j = bodyStart; j < css.length; j++) {
      if (css[j] === '{') depth++;
      else if (css[j] === '}' && --depth === 0) { bodies.push(css.slice(bodyStart, j)); break; }
    }
  }
  return bodies.join('\n');
}

// Everything OUTSIDE any @media block — the rules that apply at every viewport width. A floor
// declared only inside a media query is not a floor; that is the exact bug --tap-min replaced.
function unconditional(css) {
  const open = /@media[^{]*\{/g;
  let out = '', last = 0, m;
  while ((m = open.exec(css)) !== null) {
    if (m.index < last) continue;
    out += css.slice(last, m.index);
    let depth = 1, j = m.index + m[0].length;
    for (; j < css.length; j++) {
      if (css[j] === '{') depth++;
      else if (css[j] === '}' && --depth === 0) break;
    }
    last = Math.min(j + 1, css.length);
    open.lastIndex = last;
  }
  return out + css.slice(last);
}

// Concatenated bodies of EVERY @media block regardless of breakpoint, for asking "does any media
// query touch this property at all".
function allMediaBodies(css) {
  const open = /@media[^{]*\{/g;
  const bodies = [];
  let m;
  while ((m = open.exec(css)) !== null) {
    let depth = 1, j = m.index + m[0].length;
    const start = j;
    for (; j < css.length; j++) {
      if (css[j] === '{') depth++;
      else if (css[j] === '}' && --depth === 0) break;
    }
    bodies.push(css.slice(start, j));
    open.lastIndex = Math.min(j + 1, css.length);
  }
  return bodies.join('\n');
}

// Self-test the parser before trusting it. Every breakpoint-scoped assertion depends on it, so a
// refactor that made it return the whole document would silently make those assertions vacuous.
for (const [src, want, label] of [
  ['@media (max-width:480px){.a{x:1}}', '.a{x:1}', 'plain block'],
  ['@media (max-width:480px){.a{x:1}}@media (max-width:480px){.b{y:2}}', '.b{y:2}', 'second block of same width'],
  ['@supports(display:grid){@media (max-width:480px){.a{x:1}}}', '.a{x:1}', 'nested inside @supports'],
  ['@media (max-width:481px){.a{x:1}}', '', 'a different breakpoint must not match'],
  ['@media (min-width:480px){.a{x:1}}', '', 'min-width must not match max-width'],
]) {
  const got = mediaBlocks(src, 480).replace(/\s/g, '');
  const hit = want === '' ? got === '' : got.includes(want.replace(/\s/g, ''));
  harness(hit, `mediaBlocks self-test failed: ${label}`);
}

// unconditional() gates the touch-target assertions, so self-test it too.
for (const [src, keep, drop, label] of [
  ['a{x:1}@media (max-width:480px){b{y:2}}c{z:3}', ['a{x:1}', 'c{z:3}'], ['b{y:2}'], 'flat'],
  ['a{x:1}@media screen{@media (max-width:480px){b{y:2}}}c{z:3}', ['a{x:1}', 'c{z:3}'], ['b{y:2}'], 'nested @media'],
  ['@supports(display:grid){a{x:1}@media (max-width:480px){b{y:2}}}', ['a{x:1}'], ['b{y:2}'], 'inside @supports'],
]) {
  const got = unconditional(src).replace(/\s/g, '');
  const ok = keep.every(k => got.includes(k.replace(/\s/g, ''))) &&
             drop.every(d => !got.includes(d.replace(/\s/g, '')));
  harness(ok, `unconditional self-test failed: ${label}`);
}

// Fail fast: a broken parser makes every assertion below meaningless, so report it on its own
// terms rather than as a page regression.
if (harnessProblems.length) {
  console.error(`${harnessProblems.length} parser self-test failure(s) — this file's helpers are broken, not docs/index.html:`);
  for (const line of harnessProblems) console.error(line);
  process.exit(1);
}

const css = stylesheet(html);
expect(css.length > 0, 'no <style> block found in the page');

const rejectedPreludes = [];
const at480 = mediaBlocks(css, 480, rejectedPreludes);
const at880 = mediaBlocks(css, 880, rejectedPreludes);
const baseCss = unconditional(css);
const mediaCss = allMediaBodies(css);
expect(
  rejectedPreludes.length === 0,
  `@media prelude names a breakpoint but does not scope to it: ${rejectedPreludes.join(' | ')}`
);
// One stylesheet, inline. An external sheet would carry rules this file never sees.
expect(!/<link[^>]+rel=["']?stylesheet/i.test(html), 'page must not pull in an external stylesheet');
// A dropped block and a missing rule both look like "not found" downstream. Separate them here so
// a renamed breakpoint reports itself instead of blaming every rule inside it.
expect(at480.length > 0, 'no @media (max-width: 480px) block found — breakpoint renamed?');
expect(at880.length > 0, 'no @media (max-width: 880px) block found — breakpoint renamed?');

// present(selector, label) — a prohibition on a selector that no longer exists passes vacuously,
// which silently retires the guard. Assert the rule is there before asserting what it must not do.
function present(pattern, label) {
  expect(new RegExp(pattern, 's').test(css), `${label} rule must exist (guard would pass vacuously otherwise)`);
}

// viewport-fit=cover is what makes env(safe-area-inset-*) resolve to a non-zero value, so it is
// the enabling condition for every safe-area rule below, not a cosmetic addition.
expect(
  /<meta name="viewport"[^>]*width=device-width[^>]*viewport-fit=cover/.test(html),
  'viewport meta must set width=device-width and viewport-fit=cover'
);

// A vw term in the middle, not just the literal `clamp(` — clamp(2rem, 2rem, 2rem) is not fluid.
expect(
  /--pad-x:\s*clamp\([^)]*\dvw[^)]*\)/.test(css) && /--pad-y:\s*clamp\([^)]*\dvw[^)]*\)/.test(css),
  'root spacing tokens --pad-x/--pad-y must stay fluid clamp() values with a vw term'
);

expect(
  /\.hero h1\s*\{[^}]*font-size:\s*clamp\([^)]*\dvw[^)]*\)/s.test(css),
  'hero h1 must use a fluid font-size clamp() with a vw term'
);

// One shared rule, so a container cannot be added without the gutter. .section was missed while
// each container declared its own, which put every content region under the notch.
// The max(var(--pad-x), …) floor is pinned too: dropping it would collapse every container's
// inline padding to 0 on every device without a notch.
const gutterRule = (css.match(/[^{}]*\{[^{}]*padding-inline:[^{}]*\}/gs) || [])
  .find(r => ['\\.nav', '\\.section', '\\.hero', '\\.footer']
    .every(c => new RegExp(`(^|,)\\s*${c}\\s*(,|\\{)`, 's').test(r)));
expect(
  !!gutterRule && /padding-inline:\s*max\(var\(--pad-x\),\s*env\(safe-area-inset-left\)\)\s*max\(var\(--pad-x\),\s*env\(safe-area-inset-right\)\)/s.test(gutterRule),
  'nav, section, hero and footer must share one padding-inline rule with the max(var(--pad-x), env(...)) floor'
);

// Pins the rendered property, not one spelling: hiding the .nav-links container is the same
// regression as hiding individual links with nth-child.
present('\\.nav-links\\s*\\{', '.nav-links');
expect(
  !/\.nav-links[^{]*\{[^}]*(display:\s*none|visibility:\s*hidden|content-visibility:\s*hidden)/s.test(css),
  'navigation must keep all section links reachable (no display:none / visibility:hidden on .nav-links or its links)'
);

expect(
  /\.pipeline-flow\s*\{[^}]*grid-template-columns:\s*1fr\s*(;|\})/s.test(at480),
  'pipeline flow must collapse to a single column inside a 480px media block'
);

expect(
  /\.pipeline-aside\s*\{[^}]*align-items:\s*flex-start/s.test(css),
  'pipeline aside must align to flex-start so multi-line descriptions wrap cleanly'
);

expect(
  /\.btn-chrome\s*\{[^}]*width:\s*100%/s.test(at480),
  'CTA button must go full-width inside a 480px media block'
);

expect(
  /\.install-block code\s*\{[^}]*overflow-x:\s*auto/s.test(css) &&
  /\.install-pill code\s*\{[^}]*overflow-x:\s*auto/s.test(css),
  'install code snippets must scroll horizontally rather than widen the page'
);

expect(
  /\.footer-signup\s*\{[^}]*flex-direction:\s*column/s.test(at480),
  'footer signup form must stack vertically inside a 480px media block'
);

// Exactly one declaration, at 44px. An existence regex would pass while a later
// `@media { :root { --tap-min: 30px } }` override shipped 30px targets on the very viewport the
// token exists to protect. Uniqueness is what makes the value the one that wins the cascade.
const tapDecls = css.match(/--tap-min:\s*[^;]+/g) || [];
expect(
  tapDecls.length === 1,
  `--tap-min must be declared exactly once so no later rule can override it (found ${tapDecls.length})`
);
expect(
  /--tap-min:\s*44px/.test(tapDecls[0] || ''),
  'interactive minimum target must stay 44px (--tap-min)'
);

// Checked per selector, not by count, so a count-preserving swap back to a hardcoded floor
// cannot slip by. The page previously carried three ad-hoc floors: 36/40/42px.
for (const sel of ['\\.copy-btn', '\\.btn-chrome', '\\.footer-signup input\\[type="email"\\]', '\\.footer-signup button']) {
  const name = sel.replace(/\\/g, '');
  present(`${sel}\\s*\\{`, name);
  expect(
    new RegExp(`${sel}\\s*\\{[^}]*min-height:\\s*var\\(--tap-min\\)`, 's').test(baseCss),
    `${name} must size its touch target from var(--tap-min) unconditionally, not inside a media query`
  );
  // No media query may re-declare min-height on these controls, in any unit. Restricting this to
  // `\\d+px` over the whole sheet let a `min-height: 1.875rem` override below 480px ship 30px targets.
  expect(
    !new RegExp(`${sel}\\s*\\{[^}]*min-height:`, 's').test(mediaCss),
    `${name} must not have its touch-target floor overridden inside a media query`
  );
  // ...and exactly one min-height declaration sheet-wide, so a LATER base rule at equal specificity
  // cannot win the cascade behind the positive check above (which only sees the first match).
  const floors = css.match(new RegExp(`${sel}\\s*\\{[^}]*min-height:`, 'gs')) || [];
  expect(
    floors.length === 1,
    `${name} must declare min-height exactly once so no later rule outranks the token (found ${floors.length})`
  );
}

expect(
  /\.output-pair\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)\s*(;|\})/s.test(at880),
  'output preview pair must stack to a single column inside an 880px media block'
);

// The page must not clip its own viewport. overflow-x:clip on the root hides horizontal overflow
// instead of preventing it, so a regression becomes unreachable content rather than a visible bug.
// The grid-track rules below are what actually keep the page inside the viewport.
// (Widening this alternation broadens a prohibition, which is the safe direction.)
expect(
  !/(^|[\s,;}])(html|body|:root)[^{,\s]*\s*\{[^}]*overflow(-x)?:\s*(clip|hidden)/s.test(css),
  'html/body/:root must not mask overflow with overflow-x — fix the overflowing element instead'
);

// A grid item's automatic minimum size is its min-content width, so a bare 1fr track is widened by
// an unbreakable code string. Sizing the track with minmax(0, …) immunises every child at once.
expect(
  /\.output-pair\s*\{[^}]*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)/s.test(css) &&
  /\.install-tracks\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)/s.test(css),
  'output and install grids must size tracks with minmax(0, …) so long code cannot widen them'
);

if (problems.length) {
  // Count first: check() shows only the first 5 lines, so this line must survive truncation.
  console.error(`${problems.length} responsive problem(s) in docs/index.html:`);
  for (const line of problems) console.error(line);
  process.exit(1);
}
console.log('✅ Responsive landing page tests passed.');
