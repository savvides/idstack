// The extension's model prompts carry the ASD-STE100 writing rules that
// templates/preamble.md gives every skill, between the ste-core markers.
// scripts/idstack-gen-skills writes extension/shared/ste-rules.js from that block,
// and smoke-test's freshness check fails on a stale copy. This suite checks
// that both prompts carry the rules.
import assert from 'node:assert';
import { STE_RULES } from '../extension/shared/ste-rules.js';
import { buildAuditPrompt, buildCourseAuditPrompt } from '../extension/shared/prompts.js';

// An empty block would make the checks below vacuous.
assert.ok(STE_RULES.trim(), 'extension/shared/ste-rules.js has no rules text');

// Collect every disagreement so one run names them all.
const problems = new Set();
const check = (ok, msg) => { if (!ok) problems.add(msg); };

for (const [where, prompt] of [['page prompt', buildAuditPrompt({ title: 't' })], ['course prompt', buildCourseAuditPrompt({})]]) {
  check(prompt.includes(STE_RULES), `${where} does not contain STE_RULES`);
}

assert.ok(problems.size === 0, `Extension prompts do not carry the writing rules:\n  ${[...problems].join('\n  ')}`);
console.log('✅ STE rules tests passed.');
