// Evidence labels shipped in the extension must agree with evidence/references.md
// (codes, studies, tiers) and CLAUDE.md (tier meanings). The extension shipped a
// tier scale that put randomized trials in T2, demo findings citing Biggs (T5,
// [Alignment-1]) as "[Alignment-3] ... [T2]" and a nonexistent [Cognitive-2],
// uncoded prompt citations to studies references.md does not contain, and a page
// prompt asking for a "suggestion" severity. Expected values are parsed from the
// canonical files, never restated here.
import assert from 'node:assert';
import fs from 'node:fs';
import { TIER_METADATA } from '../extension/shared/evidence-base.js';
import { getDemoAuditResult, getDemoCourseAuditResult } from '../extension/background/parser-helper.js';
import { buildAuditPrompt, buildCourseAuditPrompt } from '../extension/shared/prompts.js';

const read = (rel) => fs.readFileSync(new URL(`../${rel}`, import.meta.url), 'utf8');
const SEVERITIES = ['critical', 'warning', 'info'];
const SOURCES = ['extension/shared/prompts.js', 'extension/background/parser-helper.js', 'extension/shared/evidence-base.js'];
const CODE = /\[([A-Z][A-Za-z]+-\d+)\](?: \[(T[1-5])\])?/g; // capitalized, so arr[i-1] is no code
// "[Code-N] Author (Year) [Tn]", "Author et al. Year [Tn", "Author (Year)": code and tier optional.
const STUDY = /(?:\[([A-Z][A-Za-z]+-\d+)\] )?([A-Z][A-Za-z'-]+)(?: et al\.)? \(?((?:19|20)\d{2})\)?(?: \[(T[1-5])\b)?/g;

const refsText = read('evidence/references.md');
const refs = {}; // 'Alignment-1' -> { line, tier }
for (const m of refsText.matchAll(/^- \[([A-Za-z]+-\d+)\] (.+) (T[1-5])\s*$/gm)) refs[m[1]] = { line: m[2], tier: m[3] };
const tierDefs = {}; // references.md "Definition" column
for (const m of refsText.matchAll(/^\| (T[1-5]) \| ([^|]+?) \|/gm)) tierDefs[m[1]] = m[2];
const tierMeanings = {}; // CLAUDE.md "Evidence standards" "Meaning" column
for (const m of read('CLAUDE.md').matchAll(/^\| (T[1-5]) \| ([^|]+?) \|\s*$/gm)) tierMeanings[m[1]] = m[2];
// A parse that finds nothing would make every check below vacuous.
assert.ok(Object.keys(refs).length >= 100, 'parsed too few references from evidence/references.md');
assert.strictEqual(Object.keys(tierDefs).length, 5, 'references.md tier table not parsed');
assert.strictEqual(Object.keys(tierMeanings).length, 5, 'CLAUDE.md tier table not parsed');

// Collect every disagreement so one run names them all.
const problems = new Set();
const check = (ok, msg) => { if (!ok) problems.add(msg); };
const names = (line, author, year) => line.includes(author) && line.includes(`(${year})`);

// A code must be a references.md entry at the stated tier, naming the stated study.
function cite(where, code, tier, author, year) {
  const ref = refs[code];
  if (!ref) return check(false, `${where}: [${code}] is not in evidence/references.md`);
  if (tier) check(tier === ref.tier, `${where}: [${code}] is ${ref.tier} in references.md, not ${tier}`);
  if (author) check(names(ref.line, author, year), `${where}: ${author} (${year}) is not [${code}] ${ref.line}`);
}
// An uncoded "Author (Year)" must still be a references.md entry, at the stated tier.
function study(where, author, year, tier) {
  const entries = Object.values(refs).filter((r) => names(r.line, author, year));
  check(entries.length, `${where}: ${author} (${year}) is not in evidence/references.md`);
  if (entries.length && tier) check(entries.some((r) => r.tier === tier), `${where}: ${author} (${year}) is ${entries[0].tier} in references.md, not ${tier}`);
}

// 1. Every [Code-N] and every "Author (Year)" in the shipped files is a
//    references.md entry, at whatever tier the text states beside it.
for (const rel of SOURCES) {
  const text = read(rel);
  for (const m of text.matchAll(CODE)) cite(rel, m[1], m[2]);
  for (const m of text.matchAll(STUDY)) {
    if (m[1]) cite(rel, m[1], m[4], m[2], m[3]);
    else study(rel, m[2], m[3], m[4]);
  }
}

// 2. The tier scale restates the canonical tables.
for (const t of Object.keys(tierDefs)) {
  check(TIER_METADATA[t]?.description === tierDefs[t], `TIER_METADATA.${t}.description must be references.md's "${tierDefs[t]}"`);
  check(TIER_METADATA[t]?.label === tierMeanings[t], `TIER_METADATA.${t}.label must be CLAUDE.md's "${tierMeanings[t]}"`);
}

// 3. Demo findings: canonical severity; the citation's code is at the finding's
//    tier; the evidence names that code's study and states the same tier.
for (const [where, result] of [['page demo', getDemoAuditResult({})], ['course demo', getDemoCourseAuditResult({})]]) {
  for (const f of result.findings) {
    const at = `${where} "${f.citation}"`;
    check(SEVERITIES.includes(f.severity), `${at}: severity "${f.severity}" is not ${SEVERITIES.join('|')}`);
    const code = (f.citation.match(/^\[([A-Za-z]+-\d+)\]/) || [])[1];
    const named = f.evidence.match(/^([A-Z][A-Za-z'-]+)[^(]*\((\d{4})\)/) || [];
    check(named[1], `${at}: evidence names no "Author (Year)"`);
    cite(at, code, f.tier, named[1], named[2]);
    for (const t of f.evidence.matchAll(/\[(T[1-5])\b/g)) check(t[1] === f.tier, `${at}: evidence says ${t[1]}, finding says ${f.tier}`);
  }
}

// 4. Prompts: one severity vocabulary; every tiered citation carries its code;
//    both define the canonical tier scale.
for (const [where, prompt] of [['page prompt', buildAuditPrompt({ title: 't' })], ['course prompt', buildCourseAuditPrompt({})]]) {
  const vocab = ((prompt.match(/"severity": (.*)/) || [])[1] || '').match(/[a-z]+/g) || [];
  check(vocab.join('|') === SEVERITIES.join('|'), `${where}: severity vocabulary is ${vocab.join('|')}, not ${SEVERITIES.join('|')}`);
  for (const m of prompt.matchAll(STUDY)) check(m[1] || !m[4], `${where}: "${m[0]}" states a tier without a references.md code`);
  for (const t of Object.keys(tierDefs)) check(prompt.includes(`${t}: ${tierDefs[t]}`), `${where} must define ${t} as "${tierDefs[t]}"`);
}

// 5. The side panel styles exactly the canonical severities (rules and tokens).
const css = read('extension/sidepanel/sidepanel.css');
const styled = [...new Set([...css.matchAll(/(?:\.severity|--sev(?:erity)?)-([a-z]+)/g)].map((m) => m[1]))].sort();
check(styled.join('|') === [...SEVERITIES].sort().join('|'), `sidepanel.css styles severities ${styled.join('|')}, not ${SEVERITIES.join('|')}`);

assert.ok(problems.size === 0, `Extension evidence labels disagree with evidence/references.md or CLAUDE.md:\n  ${[...problems].join('\n  ')}`);
console.log('✅ Evidence label tests passed.');
