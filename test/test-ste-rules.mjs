// The extension's model prompts carry a copy of the ASD-STE100 writing rules
// that templates/preamble.md gives every skill, between the ste-core markers.
// The copy must stay word for word the same as the preamble text, and both
// prompts must carry it. Expected text is parsed from the preamble, never
// restated here.
import assert from 'node:assert';
import fs from 'node:fs';
import { STE_RULES } from '../extension/shared/ste-rules.js';
import { buildAuditPrompt, buildCourseAuditPrompt } from '../extension/shared/prompts.js';

const preamble = fs.readFileSync(new URL('../templates/preamble.md', import.meta.url), 'utf8');
const BEGIN = '<!-- ste-core:begin -->';
const END = '<!-- ste-core:end -->';
assert.strictEqual(preamble.split(BEGIN).length, 2, `templates/preamble.md must contain ${BEGIN} once`);
assert.strictEqual(preamble.split(END).length, 2, `templates/preamble.md must contain ${END} once`);
assert.ok(preamble.indexOf(BEGIN) < preamble.indexOf(END), `${BEGIN} must come before ${END}`);
const norm = (s) => s.replace(/\s+/g, ' ').trim();
const canonical = norm(preamble.slice(preamble.indexOf(BEGIN) + BEGIN.length, preamble.indexOf(END)));
// An empty block would make the comparison below vacuous.
assert.ok(canonical, 'no text between the ste-core markers in templates/preamble.md');

// Collect every disagreement so one run names them all.
const problems = new Set();
const check = (ok, msg) => { if (!ok) problems.add(msg); };

const copy = norm(STE_RULES);
let at = 0;
while (at < canonical.length && canonical[at] === copy[at]) at++;
check(copy === canonical, `extension/shared/ste-rules.js differs from the ste-core block in templates/preamble.md at "${canonical.slice(at, at + 40)}" (copy: "${copy.slice(at, at + 40)}")`);

for (const [where, prompt] of [['page prompt', buildAuditPrompt({ title: 't' })], ['course prompt', buildCourseAuditPrompt({})]]) {
  check(prompt.includes(STE_RULES), `${where} does not contain STE_RULES`);
}

assert.ok(problems.size === 0, `Extension writing rules disagree with templates/preamble.md:\n  ${[...problems].join('\n  ')}`);
console.log('✅ STE rules tests passed.');
