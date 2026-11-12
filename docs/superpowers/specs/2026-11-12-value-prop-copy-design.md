# Value proposition copy: design and review changes

Date: 2026-11-12. Owner request (2026-11-11): the website must say at once that idstack is a copilot for instructional designers. It supports their work with the literature, helps them apply instructional design frameworks, and helps them do their job. PR: savvides/idstack#164.

## Goal

An instructional designer who opens idstack.org reads, in the headline and the first paragraph, what idstack is (a copilot), who it is for, and the two kinds of help (frameworks and literature).

## Rule for the copy

Each claim must be true of the product today. The pipeline runs one fixed sequence (ADDIE phases, with the backward design sequence in Design and Develop). idstack does not ask for a framework and does not store one. The copy can say that idstack helps you apply your framework and that each skill does the work of one phase. It cannot say that idstack applies or keeps a framework for you.

## Changes from the review of `b96f471`

Each change is implemented by one general-purpose subagent with the model below, then reviewed before the next one starts.

| # | Change | File | Model | Reason for the model |
|---|--------|------|-------|----------------------|
| 1 | "Why" lede: replace "It keeps the work in sequence in your framework." with "Each skill does the work of one phase of your framework." | `docs/index.html` | haiku | The reviewer gave the exact replacement text; one line, low risk. |
| 2 | Hero lede and README intro: "applies the framework" becomes "helps you apply the framework" (same defect as change 1, found during verification) | `docs/index.html`, `README.md` | haiku | Two exact string replacements; no judgment needed. |
| 3 | JSON-LD `description`: split the 26-word sentence at ", and it supports" | `docs/index.html` | haiku | One mechanical sentence split, but the JSON must stay valid, so the result is parsed in review. |
| 4 | CHANGELOG entry names the README intro | `CHANGELOG.md` | haiku | One short sentence added to an entry that exists; the STE checker verifies it. |
| 5 | Decisions log row for the copilot headline (owner request), with the cost against "Memorable thing" (Proof) and the "Built for X" anti-pattern | `DESIGN.md` | sonnet | The row must match the log format and state the tradeoff accurately in the design contract; this needs judgment. |

Not a subagent change:

- The PR description is corrected by hand after change 5 (it says "README is not changed").
- "copilot" (page, README) and "Co-Pilot" (Chrome extension) differ. The extension has its own version and store listing, so this is deferred to a GitHub issue.

## Verification

`./test/smoke-test.sh`, `scripts/idstack-ste-check` on the changed text, and the JSON-LD block parsed with `json.loads`.
