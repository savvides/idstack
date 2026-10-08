#!/usr/bin/env python3
"""Assert every "[Code-N] [Tn]" citation states the tier evidence/references.md gives it.

Skills tell the model how to cite evidence, and the reports copy those citations.
needs-analysis, course-builder, course-quality-review and learning-objectives
cited the two Sweller papers ([CogLoad-4], [CogLoad-19]) as T1, but
references.md files both as T5. A citation that claims stronger evidence than
the repo holds is the error idstack can least afford, so the tier is read from
references.md here instead of trusted. bin/idstack-consensus applies the same
rule at run time: a code in references.md always gets its references.md tier.

Forms checked, after HTML tags are removed:
  [A-1] [T1]             the code must be T1 in references.md
  [A-1] [B-2] [T1]       each code must be T1 in references.md
  [A-1] [B-2] [T1] [T3]  refused: put the tier after each code instead
Each [Code-N] must also be an entry in references.md.

Scope: skills/*/SKILL.md.tmpl, templates/, README.md and docs/index.html. The
generated SKILL.md files are left out (they repeat the templates, and
smoke-test keeps them fresh). test/test-evidence-labels.mjs checks extension/.

Usage: check-citation-tiers.py <repo-root>
Prints one line per problem and exits 1; prints nothing and exits 0 when clean.
Runs on Python 3.9 (the macOS system interpreter).
"""

import glob
import io
import os
import re
import sys

# "- [CogLoad-4] Sweller, J. (1994). ... *Learning and Instruction*. T5"
REF_RE = re.compile(r"^- \[([A-Za-z]+-\d+)\] .* (T[1-5])\s*$")
CODE_RE = re.compile(r"\[([A-Z][A-Za-z]*-\d+)\]")
# One or more codes, then one or more tiers.
GROUP_RE = re.compile(r"((?:\[[A-Z][A-Za-z]*-\d+\]\s*)+)((?:\[T[1-5]\]\s*)+)")
# The landing page shows a tier as <span class="tier tier-1">T1</span>.
TIER_SPAN_RE = re.compile(r'<span class="tier tier-[1-5]">(T[1-5])</span>')
TAG_RE = re.compile(r"<[^>]+>")


def load_refs(path):
    refs = {}
    for line in io.open(path, encoding="utf-8"):
        m = REF_RE.match(line)
        if m:
            refs[m.group(1)] = m.group(2)
    return refs


def sources(root):
    paths = glob.glob(os.path.join(root, "skills", "*", "SKILL.md.tmpl"))
    paths += glob.glob(os.path.join(root, "templates", "**", "*"), recursive=True)
    paths += [os.path.join(root, "README.md"), os.path.join(root, "docs", "index.html")]
    return sorted(p for p in paths if os.path.isfile(p))


def plain(line):
    line = TIER_SPAN_RE.sub(r"[\1]", line)
    return TAG_RE.sub("", line).replace("&nbsp;", " ")


def main():
    if len(sys.argv) != 2:
        print("usage: check-citation-tiers.py <repo-root>")
        return 2
    root = sys.argv[1]
    refs_path = os.path.join(root, "evidence", "references.md")
    if not os.path.isfile(refs_path):
        print("missing file: %s" % refs_path)
        return 1
    refs = load_refs(refs_path)
    if not refs:
        print("no '- [Code-N] ... Tn' entries found in evidence/references.md")
        return 1

    problems = []
    cited = 0
    for path in sources(root):
        rel = os.path.relpath(path, root)
        lines = io.open(path, encoding="utf-8").read().split("\n")
        for n, raw in enumerate(lines, 1):
            line = plain(raw)
            where = "%s:%d" % (rel, n)
            for code in CODE_RE.findall(line):
                if code not in refs:
                    problems.append("%s: [%s] is not in evidence/references.md" % (where, code))
            for m in GROUP_RE.finditer(line):
                codes = CODE_RE.findall(m.group(1))
                tiers = re.findall(r"T[1-5]", m.group(2))
                cited += 1
                if len(tiers) > 1:
                    problems.append(
                        "%s: %s gives more than one tier. Put the tier after each code."
                        % (where, m.group(0).strip())
                    )
                    continue
                for code in codes:
                    if code in refs and refs[code] != tiers[0]:
                        problems.append(
                            "%s: [%s] is %s in evidence/references.md, not %s"
                            % (where, code, refs[code], tiers[0])
                        )

    # A pattern that stops matching would make every check above vacuous.
    if cited == 0:
        problems.append("no '[Code-N] [Tn]' citations found. The checker matched nothing.")

    for line in problems:
        print(line)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
