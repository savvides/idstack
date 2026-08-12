#!/usr/bin/env python3
"""Assert the landing page's evidence cards agree with evidence/references.md.

docs/index.html carries one card per research domain, each restating two facts
from evidence/references.md: how many studies the domain holds, and the span of
evidence tiers across them. Both were hand-typed, and three had drifted by
v3.4.0.0 — two cards advertised T2 for domains whose strongest reference is T3.

Overstating tier strength is the one inaccuracy idstack cannot afford: the
product's entire claim is that it labels evidence honestly. So the cards are
derived from the reference file here rather than trusted.

Usage: check-evidence-cards.py <repo-root>
Prints one line per mismatch and exits 1; prints nothing and exits 0 when clean.
Runs on Python 3.9 (the macOS system interpreter) — see test/test-preamble-python.sh
for why that floor matters.
"""

import html
import io
import os
import re
import sys

# A domain heading: "## Domain 7: Learner Analysis & Differentiation"
DOMAIN_RE = re.compile(r"^## Domain \d+: (.+?)\s*$")
# A reference key: "[Alignment-14]" — one per study.
CITATION_RE = re.compile(r"\[[A-Za-z][A-Za-z-]*-\d+\]")
TIER_RE = re.compile(r"\bT([1-5])\b")
# One card: title, study count, tier range. Order-independent; matched by title.
CARD_RE = re.compile(
    r'evidence-card-title">(.*?)</h3>'
    r".*?"
    r'evidence-card-meta">(\d+)\s+studies'
    r".*?"
    r'meta-tier">(.*?)</span>',
    re.S,
)


def tier_span(tiers):
    """Render a sorted tier set the way the cards do: 'T3' or 'T1-T4' (en dash)."""
    lo, hi = tiers[0], tiers[-1]
    if lo == hi:
        return "T%d" % lo
    return "T%d–T%d" % (lo, hi)


def parse_domains(path):
    text = io.open(path, encoding="utf-8").read().split("\n")
    starts = []
    for i, line in enumerate(text):
        m = DOMAIN_RE.match(line)
        if m:
            starts.append((i, m.group(1)))
    starts.append((len(text), None))

    domains = []
    for k in range(len(starts) - 1):
        begin, name = starts[k]
        end = starts[k + 1][0]
        body = "\n".join(text[begin:end])
        tiers = sorted(set(int(t) for t in TIER_RE.findall(body)))
        domains.append((name, len(CITATION_RE.findall(body)), tiers))
    return domains


def main():
    if len(sys.argv) != 2:
        print("usage: check-evidence-cards.py <repo-root>")
        return 2
    root = sys.argv[1]
    refs = os.path.join(root, "evidence", "references.md")
    landing = os.path.join(root, "docs", "index.html")

    for p in (refs, landing):
        if not os.path.isfile(p):
            print("missing file: %s" % p)
            return 1

    domains = parse_domains(refs)
    if not domains:
        print("no '## Domain N:' sections found in evidence/references.md")
        return 1

    cards = CARD_RE.findall(io.open(landing, encoding="utf-8").read())
    by_title = {}
    for raw_title, count, tier in cards:
        by_title[html.unescape(raw_title).strip()] = (int(count), tier.strip())

    problems = []
    if len(cards) != len(domains):
        problems.append(
            "card count %d != domain count %d — a domain was added or removed "
            "without updating docs/index.html" % (len(cards), len(domains))
        )

    for name, count, tiers in domains:
        if name not in by_title:
            problems.append("no evidence card for domain %r" % name)
            continue
        card_count, card_tier = by_title.pop(name)
        if card_count != count:
            problems.append(
                "%s: card says %d studies, references.md has %d"
                % (name, card_count, count)
            )
        if not tiers:
            problems.append("%s: references.md lists no evidence tiers" % name)
            continue
        want = tier_span(tiers)
        if card_tier != want:
            note = ""
            card_tiers = [int(t) for t in TIER_RE.findall(card_tier)]
            if card_tiers and card_tiers[0] < tiers[0]:
                note = "  <- OVERSTATES: claims stronger evidence than the domain holds"
            problems.append(
                "%s: card says %s, references.md spans %s%s"
                % (name, card_tier, want, note)
            )

    for leftover in sorted(by_title):
        problems.append("evidence card %r matches no domain in references.md" % leftover)

    for line in problems:
        print(line)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
