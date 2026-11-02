"""Parse "[Code-N] [Tn]" citations and the tiers in evidence/references.md.

bin/idstack-report-section and test/check-citation-tiers.py both import this
file, so the test checks the same code that the skills run. Runs on Python 3.9.
"""

import io
import re

# "- [CogLoad-4] Sweller, J. (1994). ... *Learning and Instruction*. T5"
REF_RE = re.compile(r"^- \[([A-Za-z]+-\d+)\] .* (T[1-5])\s*$")
CODE_RE = re.compile(r"\[([A-Z][A-Za-z]*-\d+)\]")
# Between two items: spaces of any kind, an optional comma, and at most one line break.
SEP = r"[^\S\n]*(?:,[^\S\n]*)?(?:\n[^\S\n]*)?"
# One or more codes, then one or more tiers.
GROUP_RE = re.compile(r"((?:\[[A-Z][A-Za-z]*-\d+\]" + SEP + r")+)((?:\[T[1-5]\]" + SEP + r")+)")
TIER_RE = re.compile(r"T[1-5]")


def load_refs(path):
    """Return {code: tier} for each "- [Code-N] ... Tn" line in references.md."""
    refs = {}
    for line in io.open(path, encoding="utf-8"):
        m = REF_RE.match(line)
        if m:
            refs[m.group(1)] = m.group(2)
    return refs


def check_evidence(cell, refs):
    """Check one Evidence cell. It must hold only citations, each with one tier.

    Returns (problems, strongest_tier). strongest_tier is None if the cell has
    no valid citation.
    """
    text = cell.strip()
    problems = []
    tiers = []
    pos = 0
    for m in GROUP_RE.finditer(text):
        if text[pos:m.start()].strip(" ,"):
            break
        pos = m.end()
        codes = CODE_RE.findall(m.group(1))
        group_tiers = TIER_RE.findall(m.group(2))
        if len(group_tiers) > 1:
            problems.append("%s gives more than one tier. Put the tier after each code."
                            % " ".join(m.group(0).split()))
            continue
        tier = group_tiers[0]
        for code in codes:
            if code not in refs:
                problems.append("[%s] is not in evidence/references.md." % code)
            elif refs[code] != tier:
                problems.append("[%s] is %s in evidence/references.md, not %s."
                                % (code, refs[code], tier))
        tiers.append(tier)
    if not tiers or text[pos:].strip(" ,"):
        problems.append('the Evidence cell must have only citations, for example '
                        '"[Assessment-8] [T1]". It has "%s".' % text)
        return problems, None
    return problems, min(tiers)
