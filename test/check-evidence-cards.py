#!/usr/bin/env python3
"""Assert the landing page's evidence index agrees with evidence/references.md.

docs/index.html carries one row per research domain, each restating facts from
evidence/references.md: how many studies sit at each tier (the tier-mix bar's
data-tiers attribute; nothing renders it, since the bar is drawn by the inline segment
widths, which this check does not compare), the same mix as whole-number shares in the
bar's aria-label, and the span of evidence tiers across them. The page shows no number
of studies, because a literature review changes the numbers; the per-tier counts in
data-tiers, and their sum, are still compared with the reference file. The earlier
per-domain cards were hand-typed, and three had drifted by v3.4.0.0 — two advertised
T2 for domains whose strongest reference is T3.

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
# One index row: title, the tier-mix bar's opening tag, tier range. Order-independent;
# matched by title. The title and the bar tag are bounded by the row's own markup, so a
# row missing one of them cannot borrow the next row's value (a row with anything between
# the title and the bar, such as a count span, does not match and is reported missing).
# The tier-range field is reached with '.*?', so a row with no evidence-row-tiers span
# takes the next row's range.
CARD_RE = re.compile(
    r'evidence-row-title">([^<]*)</h3>'
    r'[^<]*(<span class="tier-mix"[^>]*>)'
    r'.*?evidence-row-tiers">([^<]*)</span>',
    re.S,
)
DATA_TIERS_RE = re.compile(r'\bdata-tiers="([0-9,]*)"')
ARIA_LABEL_RE = re.compile(r'\baria-label="([^"]*)"')


def tier_span(tiers):
    """Render a sorted tier set the way the cards do: 'T3' or 'T1-T4' (en dash)."""
    lo, hi = tiers[0], tiers[-1]
    if lo == hi:
        return "T%d" % lo
    return "T%d–T%d" % (lo, hi)


def shares_label(per_tier):
    """The bar's aria-label for per-tier counts: each tier's whole-number share, half up."""
    total = sum(per_tier)
    return "Tier mix: " + ", ".join(
        "%d%% at T%d" % ((200 * n + total) // (2 * total), i + 1)
        for i, n in enumerate(per_tier)
    )


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
        # Per-tier counts: each reference line ends with its tier ("... *Journal*. T3").
        per_tier = [0] * 5
        for ref in text[begin:end]:
            if CITATION_RE.match(ref.lstrip("- ")):
                found = TIER_RE.findall(ref)
                if found:
                    per_tier[int(found[-1]) - 1] += 1
        domains.append((name, len(CITATION_RE.findall(body)), tiers, per_tier))
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

    page = io.open(landing, encoding="utf-8").read()
    cards = CARD_RE.findall(page)
    by_title = {}
    for raw_title, bar, tier in cards:
        mix = DATA_TIERS_RE.search(bar)
        label = ARIA_LABEL_RE.search(bar)
        by_title[html.unescape(raw_title).strip()] = (
            mix.group(1) if mix else "",
            html.unescape(label.group(1)) if label else "",
            tier.strip(),
        )

    problems = []
    if 'class="evidence-row-count"' in page:
        problems.append(
            "docs/index.html has an evidence-row-count span; the cards show no number of studies"
        )
    if len(cards) != len(domains):
        problems.append(
            "index row count %d != domain count %d — a domain was added or removed "
            "without updating docs/index.html" % (len(cards), len(domains))
        )

    for name, count, tiers, per_tier in domains:
        if name not in by_title:
            problems.append("no evidence index row for domain %r" % name)
            continue
        card_mix, card_label, card_tier = by_title.pop(name)
        want_mix = ",".join(str(n) for n in per_tier)
        if card_mix != want_mix:
            problems.append(
                "%s: tier-mix bar says %s (T1..T5), references.md has %s"
                % (name, card_mix, want_mix)
            )
        # A reference line with no tier is in count but in no tier, so per_tier alone
        # would not see it.
        if sum(per_tier) != count:
            problems.append(
                "%s: references.md has %d references, but only %d have a tier"
                % (name, count, sum(per_tier))
            )
        # Shares come from the card's own data-tiers, so a label that disagrees with
        # the bar is reported even when data-tiers itself is wrong. The exact string
        # also rules out a count ("15 at T1") in the label. A data-tiers value that
        # is not five numbers is already reported above.
        card_counts = [int(n) for n in card_mix.split(",") if n]
        if len(card_counts) == 5 and sum(card_counts):
            want_label = shares_label(card_counts)
            if card_label != want_label:
                problems.append(
                    "%s: tier-mix aria-label says %r, data-tiers gives %r"
                    % (name, card_label, want_label)
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
                "%s: row says %s, references.md spans %s%s"
                % (name, card_tier, want, note)
            )

    for leftover in sorted(by_title):
        problems.append("evidence index row %r matches no domain in references.md" % leftover)

    for line in problems:
        print(line)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
