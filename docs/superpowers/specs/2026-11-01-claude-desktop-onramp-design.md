# Claude desktop on-ramp — design

Date: 2026-11-01
Status: approved design, not implemented

## Goal

Let an instructional designer who never uses a terminal install and use idstack
through the Claude desktop app's Code tab on a Mac. We do not build a native Mac
app. The desktop app already provides the agent loop, tool permissions, file
access and sign-in, so a native app would rebuild them.

Success: a designer with a fresh Mac and the Claude desktop app can go from
nothing to an open course-import report without typing a shell command.

## Facts this design depends on

From the Claude Code docs (desktop.md, plugins/install.md, sandboxing.md):

- The desktop app installs a plugin from a marketplace it already knows through
  **+ → Add plugins**. Adding a new marketplace in the GUI is not documented,
  and there is no install deep link.
- A plugin installed at user scope is shared between the CLI and desktop local
  sessions.
- Bash runs in the home folder, with the login shell's PATH.
- Clicking an HTML file path in chat opens it in the Browser pane (local
  sessions only).

Two facts are not documented and must be checked by hand first (Task 0):

1. Does `/plugin marketplace add savvides/idstack` work when typed into the
   desktop prompt box?
2. Does a clicked `.html` path under the hidden `.idstack/` folder open in the
   Browser pane?

## Components

| # | Unit | Responsibility | Location |
|---|---|---|---|
| 1 | Distribution | Get idstack into the desktop app with no terminal. Plan A: paste `/plugin marketplace add savvides/idstack` into the prompt box, then **+ → Add plugins**. Plan B, if Plan A fails: the official Anthropic plugin directory (tracked as an issue, outside this change). | README, `docs/index.html` |
| 2 | `/idstack:start` | New 12th skill. Front door: setup check, folder check, manifest detection, one `AskUserQuestion`, handoff with the Skill tool. Writes no manifest section and no files. | `skills/start/SKILL.md.tmpl` |
| 3 | Setup check | New `bin/idstack-doctor --quick` mode. Prints one machine-readable code: `OK`, `PYTHON_MISSING`, `PYTHON_OLD` or `PYTHON_STUB`. | `bin/idstack-doctor` |
| 4 | Clickable outputs | New preamble rule: the final message of every report-writing skill prints the absolute path of its report, and of the dashboard `index.html` when that file exists. | `templates/preamble.md` |
| 5 | Desktop guide | "Use idstack in the Claude desktop app": install, choose a course folder, run `/idstack:start`, open a report. With screenshots. | `README.md`, `docs/index.html` |

Not changed: the `.idstack/` layout, the manifest schema (`1.4`), the python3
dependency, the 8-skill pipeline order, and the Chrome extension.

## `/idstack:start` flow

1. Run `"$_IDSTACK/bin/idstack-doctor" --quick`.
   - `PYTHON_STUB` (python3 is the macOS stub, `xcode-select -p` fails): tell the
     user to click **Install** in the dialog that macOS shows, wait, then type
     `/idstack:start` again. Stop.
   - `PYTHON_MISSING` or `PYTHON_OLD`: tell the user to install python3 3.9 or
     later from python.org, then type `/idstack:start` again. Stop.
   - `OK`: continue.
2. Folder check. If the working folder is `$HOME` or `/`, tell the user to make
   a folder for the course and choose it with the folder button. Stop.
3. Read the manifest through `bin/idstack-status --context`.
   - No manifest: ask "Import an existing course" or "Design a new course".
   - Manifest exists: show the welcome-back line, then ask "Continue the
     pipeline", "Open the dashboard" or "Run one skill".
   - Malformed manifest: report it and stop (existing preamble rule). Never
     overwrite.
4. Hand off with the Skill tool to `/idstack:course-import`,
   `/idstack:needs-analysis` or `/idstack:pipeline`. "Open the dashboard" prints
   the dashboard path when the file exists, and otherwise says that
   `/idstack:pipeline` makes it.

Rules:

- Every blocker stops the skill with one fix. The user types `/idstack:start`
  again. No retry loop.
- All user-facing text follows ASD-STE100 (`templates/preamble.md`).
- `/idstack:start` writes no files, so it has zero `idstack-ste-check` steps.
  The smoke-test minimum-check-count rule gets an explicit zero entry for it.

## Clickable-output rule

Added to the preamble. At the end of a skill that wrote a report, print:

```
Report: <absolute path to .idstack/exports/<slug>/<skill>.html>
Dashboard: <absolute path to .idstack/exports/<slug>/index.html>
```

Print a line only when its file exists. In the CLI the same line is a path that
the user can copy, so the rule has no desktop-only branch.

## Error handling summary

| Condition | Detected by | Result |
|---|---|---|
| python3 is the macOS stub | `doctor --quick` → `PYTHON_STUB` | One-step fix, stop |
| python3 missing or older than 3.9 | `doctor --quick` | One-step fix, stop |
| Session started in home folder or `/` | `/idstack:start` folder check | Ask for a course folder, stop |
| Malformed manifest | Existing preamble rule | Report, stop, no overwrite |
| Skill failed before it wrote a report | File-exists check | No path line printed |

## Testing

| Change | Test | Suite |
|---|---|---|
| `doctor --quick` | One case per code. Fake `python3` on PATH for `PYTHON_MISSING` and `PYTHON_OLD`. Fake failing `xcode-select` for `PYTHON_STUB`. | `test/test-doctor.sh` |
| `/idstack:start` bash blocks | Run the doctor and folder-check blocks in bash and zsh, including the `$HOME` refusal | `test/test-skill-shell-zsh.sh` |
| New skill wiring | Existing frontmatter, freshness, namespacing and resolve-snippet checks. Update skill count assertions from 11 to 12. | `test/smoke-test.sh`, `test/check-doc-accuracy.py` |
| Clickable-output rule | Each report-writing template's final step names the absolute report path | `test/smoke-test.sh` |
| Regression proof | Mutations: remove stub detection, remove the `$HOME` guard, remove the path rule from one template | `test/mutation-test.sh` |

Manual journey (Task 0 and final check), in the Claude desktop app with a fresh
folder: add marketplace → install → `/idstack:start` → import a sample `.imscc`
→ click the report path.

## Release

Minor bump to `v3.10.0.0` (adds a skill): `VERSION`,
`.claude-plugin/plugin.json`, `CHANGELOG.md`, `README.md`, `docs/index.html`
(including the "Eleven skills" heading), the ROADMAP "Just shipped" entry, and
the skill count and test-count comments in `CLAUDE.md` (counts from a real
run). Find every other hard-coded skill count with grep at implementation time.

## Out of scope (open as GitHub issues)

- Submit idstack to the official Anthropic plugin directory (Plan B for
  distribution; outside the repo).
- Claude desktop on Windows (the stub detection is Mac-only).
