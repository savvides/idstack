# One spelling of "copilot": design

Date: 2026-11-12. Owner decision on savvides/idstack#165: "copilot" is the standard spelling on all surfaces.

## State before this change

The two efforts that this change completes are merged and need no more work:

- Framework alignment (savvides/idstack#162, spec `2026-11-11-framework-alignment-design.md`).
- Value proposition copy (savvides/idstack#164, spec `2026-11-12-value-prop-copy-design.md`). Its five review changes are all in `main`.

Two sessions prepared the same review fixes for #164. One session stopped before it committed, so no fix is in `main` twice. The one item that the two efforts left open is #165.

## Goal

The landing page, the README and the Chrome extension use the same term, "copilot" ("Copilot" in a title).

## Changes

Each change is implemented by one general-purpose subagent with the model below, then reviewed before the next one starts.

| # | Change | Files | Model | Reason for the model |
|---|--------|-------|-------|----------------------|
| 1 | "Co-Pilot" becomes "Copilot" and "co-pilot" becomes "copilot" in the four extension strings | `extension/manifest.json`, `extension/sidepanel/index.html`, `extension/shared/prompts.js`, `extension/shared/dossier-compiler.js` | haiku | Four exact string replacements; no test or mutation anchor quotes them. |
| 2 | Extension version 1.2.3 becomes 1.2.4, with one entry below `## Unreleased` in `CHANGELOG.md` | `extension/manifest.json`, `CHANGELOG.md` | sonnet | The entry must follow the CHANGELOG format and ASD-STE100, and must go in the correct section; this needs some judgment. |

Not a subagent change:

- The PR has `Closes #165` in its body.
- The owner changes the Chrome Web Store listing text.
- The worktrees and branches of the two merged PRs are removed (owner approval, 2026-11-12).

## Out of scope

- `CLAUDE.md` and `DESIGN.md` say "set of skills for evidence-based instructional design". That is an accurate description, not a second term.
- `scripts/idstack-ste-check docs/index.html` reports line 1391 (26 words). The checker joins the skill tag and the phase labels to a 22-word sentence. The text is correct.

## Verification

`grep -rniE 'co-pilot' extension README.md docs/index.html` finds nothing. `./test/test-extension.sh`, `./test/smoke-test.sh` and `scripts/idstack-ste-check --format markdown CHANGELOG.md` on the new entry.
