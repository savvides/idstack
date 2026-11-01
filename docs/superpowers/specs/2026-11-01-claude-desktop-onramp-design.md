# Claude desktop on-ramp — design

Date: 2026-11-01
Status: approved design, amended after codebase recon (same day), not implemented

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

Two facts are not documented and are checked by hand in the plan's Task 0 (a
user-only task):

1. Does `/plugin marketplace add savvides/idstack` work when typed into the
   desktop prompt box?
2. Which form of a path to an `.html` file under a dot-folder (bare path,
   backticked path, Markdown link) opens the page rendered in the Browser pane?

## Components

| # | Unit | Responsibility | Location |
|---|---|---|---|
| 1 | Distribution | Get idstack into the desktop app with no terminal. Plan A: paste `/plugin marketplace add savvides/idstack` into the prompt box, then **+ → Add plugins**. Plan B, if Plan A fails: paste an install request into the chat that clones into `~/idstack` (not the course folder) and runs `./setup`. A listing in the official Anthropic plugin directory is tracked as an issue, outside this change. | README, `docs/index.html` |
| 2 | `/idstack:start` | New 12th skill. Front door: setup check, folder check, manifest detection, one `AskUserQuestion`, handoff with the Skill tool. Writes no manifest section, no files and no timeline event. | `skills/start/SKILL.md.tmpl` |
| 3 | Setup check | New `bin/idstack-doctor --quick` mode. Prints one machine-readable code: `OK`, `PYTHON_MISSING`, `PYTHON_OLD` or `PYTHON_STUB`. Exit 0 for `OK`, 1 for the others, 2 for an unknown argument. | `bin/idstack-doctor` |
| 4 | Report links | Each report-preparation bash block also prints `Report link: <absolute path>`; the pipeline and `/idstack:start` print `Dashboard link: <absolute path>`. A new preamble section tells the skill to put that path in its final message, and each skill's closing message points at that line instead of a relative path. | `templates/preamble.md`, the 9 report-writing templates, `skills/pipeline/SKILL.md.tmpl` |
| 5 | Desktop guide | "Use idstack in the Claude desktop app": install, choose a course folder, run `/idstack:start`, open a report. README gets screenshots; the landing page gets text and a copyable command. | `README.md`, `docs/index.html` |

Not changed: the `.idstack/` layout, the manifest schema (`1.4`), the python3
dependency, the 8-skill pipeline order, and the Chrome extension.

## `bin/idstack-doctor --quick`

Order of checks (the order matters):

1. python3 is on PATH and is 3.9 or later → `OK`. This runs first, so a user who
   installed python3 from python.org but has no Command Line Tools is not
   blocked. On a stub Mac, running the stub here is also what opens the macOS
   install dialog.
2. python3 is not on PATH → `PYTHON_MISSING`.
3. `uname -s` is `Darwin` and `xcode-select -p` fails → `PYTHON_STUB`.
4. Otherwise → `PYTHON_OLD`.

`--quick` exits before doctor reads `.claude-plugin/`.

## `/idstack:start` flow

The skill gets the preamble through `{{PREAMBLE}}`, so the Project Manifest and
Context Recovery blocks run before its own steps.

1. Setup check: `"$_IDSTACK/bin/idstack-doctor" --quick`.
   - `PYTHON_STUB`: run `xcode-select --install` so that the macOS window
     opens, tell the user to click **Install**, wait, then type
     `/idstack:start` again. If the user cannot install the Apple tool, the
     python.org installer is the alternative. Stop.
   - `PYTHON_MISSING` or `PYTHON_OLD`: tell the user to install python3 3.9 or
     later from python.org, then type `/idstack:start` again. Stop.
   - `OK`: continue.
2. Folder check. If the physical working folder (`pwd -P`) is `/`, the
   physical home folder, or its `Documents`, `Desktop` or `Downloads`, tell the user to make a folder for the course and
   choose it with the folder button. Stop.
3. Manifest, from the preamble's Project Manifest block (`MANIFEST_EXISTS` or
   `NO_MANIFEST`). `bin/idstack-status --context` does not read the manifest, so
   it is not used for this. `/idstack:start` never writes the manifest; it
   overrides the preamble's "this skill will create or update the manifest".
   - `NO_MANIFEST`: ask "Import a course that you have" or "Design a new
     course".
   - `MANIFEST_EXISTS`: give the welcome-back line from Context Recovery, then
     ask "Continue the pipeline", "Open the course dashboard" or "Run one skill".
   - Malformed manifest: a small python3 block checks the JSON (the preamble's
     migrate step prints invalid JSON without an error). Give the parse error
     and ask whether idstack may repair the JSON syntax with the Edit tool,
     keeping all data. Check again after the repair. That is the only file this
     skill may change. If the user declines, or the repair fails, stop.
4. Hand off with the Skill tool (`skill: "idstack:<name>"`) to
   `/idstack:course-import`, `/idstack:needs-analysis`, `/idstack:pipeline`, or
   the skill that the user chose. "Open the course dashboard" prints a
   `Dashboard link:` line when the file exists, and says so when a report is
   newer than the dashboard. Otherwise it says that
   `/idstack:pipeline` makes the dashboard, gives a `Report link:` for each
   report in the course folder, and stops. If the Skill tool fails, tell the user the
   command to type, as `/idstack:pipeline` does.

Rules:

- Every blocker stops the skill with one fix. The user types `/idstack:start`
  again. No retry loop.
- All user-facing text follows ASD-STE100 (`templates/preamble.md`).
- `/idstack:start` writes no files, so it has zero `idstack-ste-check` steps.
  The smoke-test check-count map gets an explicit `start) want=0 ;;` entry.
- When the Skill tool starts another skill, `/idstack:start`'s limits stop; that
  skill writes its files and logs as usual. Its rules against terminal-only
  text (the update command, the profile note) and a second welcome-back stay.
- `/idstack:start` does not log to the timeline. A `completed` event would
  become `LAST_SKILL` and corrupt the welcome-back and next-step lines.

## Report links

Each report-preparation block already sets `_REPORT_PATH` (relative). Add,
directly after it prints the relative path:

```bash
echo "Report link: $(pwd -P)/$_REPORT_PATH"
```

Report skills do not print a dashboard link: only the pipeline rewrites the
dashboard, so a link from another skill could point at an old one.

The pipeline's dashboard block prints
`echo "Dashboard link: $(pwd -P)/$_EXPORT_DIR/index.html"`.

The relative `report_path` in the manifest does not change. The link is printed
in the block that already knows the slug, so needs-analysis and course-import
(which take the slug from the typed course name) print the right folder on a
first run. The red-team orchestrator returns the link to the parent, and the
manifest keeps the relative path. Each skill's closing message names the
`Report link:` line instead of a relative path. The final message uses a
Markdown link with the path in angle brackets, which works for folder names
with spaces; Task 0 can switch it to a bare path.

## Error handling summary

| Condition | Detected by | Result |
|---|---|---|
| python3 is the macOS stub | `doctor --quick` → `PYTHON_STUB` | Open the install window, stop |
| python3 missing or older than 3.9 | `doctor --quick` | One-step fix, stop |
| Session started in home folder or `/` | `/idstack:start` folder check | Ask for a course folder, stop |
| Malformed manifest | Existing preamble rule | Report, stop, no overwrite |
| Skill failed before it wrote a report | Preamble rule: link only to files you wrote | No link given |

## Testing

| Change | Test | Suite |
|---|---|---|
| `doctor --quick` | One case per code, plus: a Darwin machine with a failing `xcode-select` and a working python3 prints `OK`; an unknown argument exits 2. Fakes: `python3`, `uname`, `xcode-select` in the pinned `MOCK_BIN`. | `test/test-doctor.sh` |
| `/idstack:start` bash blocks | Doctor block prints `OK`; folder block refuses `$HOME` and `/` and accepts a course folder; in bash and zsh | `test/test-skill-shell-zsh.sh` |
| New skill wiring | Add `start` to smoke-test's `SKILLS` and `BARE_SLASH_RE`; check its Skill-tool handoff | `test/smoke-test.sh` |
| Report links | Each report template and the pipeline print the link line; a real report block prints an absolute path in bash and zsh | `test/smoke-test.sh`, `test/test-skill-shell-zsh.sh` |
| Regression proof | Mutations: stub check moved before the version check; stub code removed; `$HOME` guard removed; link line removed from one template | `test/mutation-test.sh` |

`test/check-doc-accuracy.py` has no skill count; it needs no change.

Manual journey (Task 0 and the final user-only task), in the Claude desktop app
with a fresh folder: add marketplace → install → `/idstack:start` → import a
sample `.imscc` → click the report link. The stub case cannot be reproduced on a
Mac that has the Command Line Tools; it is covered by fakes only.

## Release

Minor bump to `v3.10.0.0` (adds a skill): `VERSION`,
`.claude-plugin/plugin.json` (version and "11 skills"), `CHANGELOG.md`,
`README.md`, `docs/index.html` (`v3.10.0.0` and `"softwareVersion": "3.10.0.0"`,
4-part as smoke-test and check-doc-accuracy require), the ROADMAP "Just
shipped" entry, and `CLAUDE.md` (counts from a real run; its "3-part
`softwareVersion`" wording is corrected to 4-part).

Skill-count sites to update to 12: `.claude-plugin/plugin.json:4`,
`.claude-plugin/marketplace.json:3`, `DESIGN.md:7`, `bin/idstack-doctor:24-26`
and `:87`, `test/test-doctor.sh:51-53`, `setup:93-95` with `README.md:175-177`,
`README.md:93`, `:328`, `:487`, `docs/index.html:1154`, `:1295`, `:1303`,
`CLAUDE.md:89-99` and the routing list. Leave "11 domains" and the historical
lines (`CHANGELOG.md`, `README.md:485`, `docs/index.html:1348`).

## Out of scope (open as GitHub issues)

- Submit idstack to the official Anthropic plugin directory.
- Claude desktop on Windows (the stub detection is Mac-only).
