# idstack command-line reference

This page gives the options, exit codes and files of `./setup` and of each tool in `scripts/`. It is a reference. For the design of the reports and the manifest, read the [README](../README.md) and [CONTRIBUTING.md](../CONTRIBUTING.md) (the dual-output contract and the manifest-write rules).

The skills call these tools through `$_IDSTACK/scripts/<tool>`. The snippet in [`templates/snippets/idstack-resolve.sh`](../templates/snippets/idstack-resolve.sh) sets `$_IDSTACK`. It tries the plugin root, the folder two levels above the skill, `IDSTACK_HOME`, then the Claude Code marketplace cache. The tools themselves do not read `IDSTACK_HOME`.

To run a tool yourself, go to the course folder and type `<your idstack clone>/scripts/<tool>`. The course tools read and write `.idstack/` in the current folder. `./setup`, `idstack-doctor`, `idstack-gen-skills` and `package-extension.sh` act on the clone, from any folder. In the synopses and examples, `scripts/` is `<your idstack clone>/scripts/`.

Requirements: bash and python3 3.9 or later. `package-extension.sh` also needs `node` and `zip`.

| Tool | Purpose | Who calls it |
|------|---------|--------------|
| [`setup`](#setup) | Installs idstack as a Claude Code plugin | You, one time for each clone |
| [`idstack-doctor`](#idstack-doctor) | Examines the install and python3 | You, `/idstack:start` (`--quick`) |
| [`idstack-gen-skills`](#idstack-gen-skills) | Writes each `SKILL.md` from its `.tmpl` | Contributors, `./setup`, smoke-test (`--dry-run`) |
| [`idstack-status`](#idstack-status) | Prints the course health dashboard | You, the preamble (`--context`), `/idstack:pipeline`, `/idstack:course-export` |
| [`idstack-migrate`](#idstack-migrate) | Updates the manifest to schema 1.4 | The preamble, `idstack-manifest-merge --create` |
| [`idstack-manifest-merge`](#idstack-manifest-merge) | Replaces manifest sections in one atomic write | Each skill that writes a manifest section |
| [`idstack-slugify`](#idstack-slugify) | Makes the `<course-slug>` folder name | Each skill that writes to `.idstack/exports/` |
| [`idstack-report-section`](#idstack-report-section) | Builds a report one approved section at a time | The skills that write a report |
| [`idstack-ste-check`](#idstack-ste-check) | Finds some ASD-STE100 problems in a file | Each skill, `idstack-report-section`, the tests |
| [`idstack-timeline-log`](#idstack-timeline-log) | Adds one event to the timeline | The skills, at the end of a run |
| [`idstack-learnings`](#idstack-learnings) | Logs, finds, deletes and promotes learnings | The skills, `/idstack:learn` |
| [`package-extension.sh`](#package-extensionsh) | Makes the Chrome extension zip file | Maintainers, before a Web Store upload |

## setup

`./setup` writes the generated skill files, then installs the clone as a Claude Code plugin.

```bash
./setup [--local]
```

| Option | Effect |
|--------|--------|
| (none) | Installs at user scope (`--scope user`). |
| `--local` | Installs at project scope (`--scope project`). |
| `-h`, `--help` | Prints the usage and exits 0. |

The steps, in sequence:

1. Run `scripts/idstack-gen-skills`. Its standard output is discarded.
2. Stop if `.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json` is missing.
3. Run `claude plugin marketplace add <clone>`, then `claude plugin marketplace update idstack`.
4. Run `claude plugin install idstack@idstack --scope <scope>`, then `claude plugin update`.

A failed `update` command does not stop setup. If `claude` is not on `PATH`, setup prints a WARNING and the two manual commands, and exits 0. The clone path is the physical path (`pwd -P`), not a symlink.

| Exit | Meaning |
|------|---------|
| 0 | Installed, `--help`, or `claude` is not on `PATH` |
| 1 | `idstack-gen-skills` failed, or a plugin manifest is missing. Also a failed `marketplace add` or `plugin install`: then setup prints the manual command on stderr. |
| 2 | An unknown argument |

Files: reads `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Writes `skills/<name>/SKILL.md` and `extension/shared/ste-rules.js` in the clone.

```bash
$ ./setup --help
Command: ./setup [--local]
  --local  Installs idstack at project scope (./.claude/), not at user scope.
```

## idstack-doctor

`idstack-doctor` examines python3, the plugin manifests, the skill files and the Claude Code install.

```bash
scripts/idstack-doctor [--quick]
```

| Option | Effect |
|--------|--------|
| (none) | Full diagnosis. The last line is `OK` or `BROKEN (<n> problem group(s) above)`. |
| `--quick` | Prints one code and nothing more: `OK`, `PYTHON_MISSING`, `PYTHON_OLD` or `PYTHON_STUB`. |

There is no `--help`. Any other argument exits 2.

The full diagnosis has four groups. Each `PROBLEM` line adds one to the count.

| Group | PROBLEM when |
|-------|--------------|
| Requirements | python3 is missing or older than 3.9 |
| Plugin manifests | `plugin.json` is missing or has no version that can be read, or `marketplace.json` is missing |
| Skill files | One of the 16 `skills/<name>/SKILL.md` files is missing |
| Claude Code install | `claude plugin list` has no `idstack@idstack`, or its entry is not enabled |

If `claude` is not on `PATH`, the last group prints a WARNING and does not add a problem. If python3 is on `PATH` but fails the check, `--quick` prints `PYTHON_STUB` on macOS when `xcode-select -p` fails. In other cases it prints `PYTHON_OLD`.

| Exit | Meaning |
|------|---------|
| 0 | No problems (`--quick`: `OK`) |
| 1 | One or more problems (`--quick`: a code other than `OK`) |
| 2 | An unknown argument |

Files: reads `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` and `skills/*/SKILL.md` in the clone. Loads `scripts/lib/plugin-status.sh`. Writes nothing.

```bash
$ scripts/idstack-doctor --quick
OK
$ scripts/idstack-doctor
idstack doctor
  repo: <your idstack clone>

...
Claude Code install:
  idstack@idstack is installed and enabled.

OK
```

## idstack-gen-skills

`idstack-gen-skills` writes each `skills/<name>/SKILL.md` from its `SKILL.md.tmpl`, and writes `extension/shared/ste-rules.js` from the preamble.

```bash
scripts/idstack-gen-skills [--dry-run]
```

| Option | Effect |
|--------|--------|
| (none) | Writes each file and prints `GENERATED: <path>`. |
| `--dry-run` | Writes nothing. Prints `OK:`, `STALE:` or `MISSING:` for each file. |
| `-h`, `--help` | Prints the header comment and exits 0. |

The script replaces `{{PREAMBLE}}`, `{{MANIFEST_SCHEMA}}` and `{{IDSTACK_RESOLVE}}`. It adds the AUTO-GENERATED header after the frontmatter. It leaves the comment lines of the resolve snippet out. A template without `{{PREAMBLE}}` gets an `ERROR` line on stderr, and the script does not write its `SKILL.md`.

| Exit | Meaning |
|------|---------|
| 0 | All files written, or all files up to date (`--dry-run`) |
| 1 | A template has no `{{PREAMBLE}}`, or a file is stale or missing (`--dry-run`). Also: no `.tmpl` file, a missing source file, or no text between the `ste-core` markers. |
| 2 | An unknown argument |

Files: reads `templates/preamble.md`, `templates/manifest-schema.md`, `templates/snippets/idstack-resolve.sh` and `skills/*/SKILL.md.tmpl`. It stops if `templates/report.md.tmpl`, `templates/index.md.tmpl` or `templates/report-format.md` is missing. Writes `skills/*/SKILL.md` and `extension/shared/ste-rules.js`.

```bash
$ scripts/idstack-gen-skills --dry-run
...
  OK: skills/storyboard/SKILL.md (up to date)
  OK: extension/shared/ste-rules.js (up to date)

The script examined 16 templates. 0 have problems.
```

## idstack-status

`idstack-status` prints the course health dashboard for the course folder.

```bash
scripts/idstack-status [--readiness | --context]
```

| Option | Output |
|--------|--------|
| (none) | The dashboard: project name, skills completed, quality trend, presence scores, next skill, learnings count, reports, then the readiness table if a manifest exists |
| `--readiness` | The readiness table only |
| `--context` | The lines that the preamble's Context Recovery reads (see the next table) |

The script reads only the first argument. It ignores other arguments, so `--help` prints the dashboard.

| `--context` line | Content |
|------------------|---------|
| `QUALITY_TREND:` | The last five `course-quality-review` scores from the timeline |
| `LAST_PRESENCE:` | `T=`, `S=` and `C=` presence scores of the last quality review |
| `SKILLS_COMPLETED:` | Each skill with a `completed` event, in alphabetical order |
| `LAST_SKILL:` | The skill and `ts` of the last `completed` event |
| `SUGGESTED_NEXT:` | The next skill in the pipeline |
| `LEARNINGS:` | The number of lines in the learnings file, then up to three learnings |

`--context` prints nothing when there is no learnings file and the timeline is missing or has no readable entries.

The readiness table uses the skill completion from the timeline and the scores from the manifest. A skill without a `completed` event is `NOT RUN`.

| Row | READY when |
|-----|------------|
| Quality Review | `quality_review.overall_score` is 70 or more |
| Red Team Audit | `red_team_audit.findings_summary.critical` is 0 |
| Accessibility Review | `accessibility_review.score.overall` is 80 or more, and no item in `wcag_violations` has `"level": "A"` |

The verdict is `INCOMPLETE (run <skills>)` if a review is not run, `NOT-READY (<reasons>)` if a row fails, and `READY TO EXPORT` in other cases. The constants at the top of the script set the thresholds.

The dashboard and the readiness table read all of the lines of the timeline. Without a timeline, the dashboard prints `There is no course data.` and the commands to start.

| Exit | Meaning |
|------|---------|
| 0 | Output printed |
| 2 | python3 is missing |

Files: reads `.idstack/timeline.jsonl`, `.idstack/learnings.jsonl` and `.idstack/project.json`. Lists the `.md` files, `course-export.imscc` and `scorm-export.zip` in `.idstack/exports/<course-slug>/`. It gets the slug from `idstack-slugify --from-manifest`. If that folder is missing and `.idstack/exports/` has only one subfolder, it uses that subfolder. A report that still has the `init` status line shows `(in progress)`. Writes nothing.

In this example the timeline has a quality score of 72, but the manifest still has the default `quality_review.overall_score` of 0:

```bash
$ scripts/idstack-status --context
QUALITY_TREND: 72
LAST_PRESENCE: T=7 S=5 C=6
SKILLS_COMPLETED: course-quality-review,needs-analysis
LAST_SKILL: course-quality-review at 2026-11-12T15:09:25Z
SUGGESTED_NEXT: learning-objectives
LEARNINGS: 1
{"skill": "course-import", "type": "operational", "key": "canvas-rubrics", "insight": "Rubrics use HTML", "confidence": 8, "ts": "2026-11-12T15:09:25Z"}
$ scripts/idstack-status --readiness

─── Course Readiness ───

  Quality Review:       NEEDS-WORK  Score: 0/100  (READY threshold: 70)
  Red Team Audit:       NOT RUN     Critical: 0  (READY threshold: <= 0)
  Accessibility Review: NOT RUN     Score: 0/100  (READY threshold: 80)

  Verdict: INCOMPLETE (run /idstack:red-team, /idstack:accessibility-review)
```

## idstack-migrate

`idstack-migrate` updates `.idstack/project.json` to schema version 1.4 and prints the manifest.

```bash
scripts/idstack-migrate [--init] [path]
```

| Option | Effect |
|--------|--------|
| `path` | The manifest. Default: `.idstack/project.json`. Only the first path is used. |
| `--init` | If the manifest is missing, write a v1.0 seed and migrate it. Prints `INITIALIZED <path>` on stderr. The seed has the mode of the umask. If the folder that holds `.idstack/` is the home folder, it makes nothing and exits 9. |
| `-h`, `--help` | Prints the header comment and exits 0. |

| Manifest | Result |
|----------|--------|
| Missing, no `--init` | No output |
| Version 1.4 | The manifest on stdout, not changed |
| Version 1.0 to 1.3 | Each step runs. The new manifest goes to the file and to stdout. stderr gets `MIGRATED <from> 1.4`. |
| A version above 1.4 | The file on stdout, not changed. stderr gets `NEWER_SCHEMA <version>`. |
| Other version, or not valid JSON | The file on stdout, not changed |

A section with the value `null` is treated as absent, so a step fills its defaults. The steps add sections and fields with defaults, and keep the values that exist. The full shape is in [`templates/manifest-schema.md`](../templates/manifest-schema.md).

| Step | Change |
|------|--------|
| 1.0 to 1.1 | Adds `assessments`, `course_content`, `import_metadata`, `export_metadata` and fields in `quality_review` |
| 1.1 to 1.2 | Adds `red_team_audit`, `accessibility_review` and `export_metadata.readiness_check`. Changes an integer `export_metadata.failed_items` to an empty list. |
| 1.2 to 1.3 | Adds `preferences` |
| 1.3 to 1.4 | Moves `red_team_audit.summary` to `findings_summary`, and `_import_quality_flags` to `import_metadata.quality_flag_details` |

The write is atomic: a tempfile in the folder of the real file, then a rename. A symlinked manifest stays a link.

| Exit | Meaning |
|------|---------|
| 0 | Done, or nothing to do |
| 1 | The script cannot write the manifest. stdout is empty and the manifest does not change. |
| 2 | An unknown flag |
| 3 | python3 is missing |
| 9 | `--init` in the home folder. Nothing is made. |

```bash
$ scripts/idstack-migrate --init
INITIALIZED .idstack/project.json
MIGRATED 1.0 1.4
{
  "version": "1.4",
  "project_name": "",
...
```

## idstack-manifest-merge

`idstack-manifest-merge` replaces one or more top-level sections of the manifest in one atomic write.

```bash
scripts/idstack-manifest-merge [--create] [--set project_name=<value>] \
  --section <name> --payload <path|-> [--section <name> --payload <path|-> ...] \
  [--manifest <path>] [--expect-updated <ts>] [--quiet]
```

| Option | Effect |
|--------|--------|
| `--section <name>` | A section to replace. Give it one time for each section. |
| `--payload <path\|->` | The JSON object for the `--section` in the same position. `-` reads stdin, for one payload only. |
| `--set project_name=<value>` | Sets `project_name`. No other key is accepted. |
| `--create` | If the manifest is missing, run `idstack-migrate --init` first. |
| `--manifest <path>` | The manifest. Default: `.idstack/project.json`. |
| `--expect-updated <ts>` | The `updated` value that the skill read. If the manifest has another value when the merge has its lock, it writes nothing and exits 8. The value has a resolution of one second. |
| `--quiet` | Prints only errors. |
| `-h`, `--help` | Prints the argparse help and exits 0. |

The section names are `context`, `needs_analysis`, `learning_objectives`, `assessments`, `course_content`, `import_metadata`, `export_metadata`, `quality_review`, `red_team_audit`, `accessibility_review` and `preferences`.

The merge replaces each named section. It does not merge the fields inside a section. It keeps all other top-level keys and sets `updated` to the current UTC time. The script examines all input before it writes. The sequence is the section names, the `--set` keys, each payload, then the manifest. A bad payload thus leaves the manifest, or its absence, unchanged.

From its read to its write, the merge holds an exclusive lock on `.idstack/.manifest.lock`. Two merges at the same time thus lose no section. The merge keeps the mode of the manifest. It refuses to write when the folder that holds `.idstack/` is the home folder, because the global profile is in `~/.idstack/`.

| Exit | Meaning |
|------|---------|
| 0 | Written |
| 1 | A payload is not valid JSON, or its root is not an object |
| 2 | The manifest is not valid JSON, or its root is not an object. Also a command error: a missing `--section` or `--payload`, unequal counts, a repeated `--section`, or two `-` payloads. |
| 3 | An unknown section name or `--set` key |
| 4 | The manifest is missing and there is no `--create` |
| 5 | A payload file is missing |
| 6 | A read or write error, or `--create` cannot make the manifest |
| 7 | The manifest version is above the latest version that `idstack-migrate` knows: a newer idstack wrote it. Nothing is written. |
| 8 | `--expect-updated` does not match the manifest. Nothing is written. |
| 9 | The folder that holds `.idstack/` is the home folder. Nothing is written. |

Errors go to stderr as `idstack-manifest-merge: error: <message>`. Files: reads the payloads, the manifest, and `LATEST_VERSION` in `scripts/idstack-migrate`. Writes the manifest through a tempfile in the folder of the real file and a rename. A symlinked manifest stays a link. It keeps `.manifest.lock` in that folder and lists it in the `.gitignore` there (a write error only gives a warning). Makes `.idstack/.manifest.lock`, which stays after the run.

```bash
$ echo '{"audience":"New teachers"}' > ctx.json
$ printf '%s' '{"verbosity":"brief"}' | scripts/idstack-manifest-merge --create \
    --set "project_name=Intro to Biology 101" \
    --section context --payload ctx.json --section preferences --payload -
idstack made the manifest .idstack/project.json
idstack replaced the section 'context' in .idstack/project.json
idstack replaced the section 'preferences' in .idstack/project.json
```

## idstack-slugify

`idstack-slugify` makes the `<course-slug>` for `.idstack/exports/<course-slug>/` from a course name.

```bash
scripts/idstack-slugify "<name>"
scripts/idstack-slugify -                       # read the name from stdin
scripts/idstack-slugify --from-manifest [path]  # read the name from the manifest
```

The rule: NFKD-fold, then remove combining marks and other non-ASCII characters, then change to lowercase. Replace each run of characters other than `a-z` and `0-9` with one `-`. Then remove a `-` at the start or the end. An empty result gives `untitled-course`.

`--from-manifest` reads `project_name`, then `needs_analysis.project_name`, from the manifest (default `.idstack/project.json`). A missing or unreadable manifest gives `untitled-course`. Any other first argument, `--help` too, is the name.

| Exit | Meaning |
|------|---------|
| 0 | The slug is on stdout |
| 2 | python3 is missing |
| 3 | No argument, and stdin is a terminal |

Files: reads the manifest with `--from-manifest`. Writes nothing.

```bash
$ scripts/idstack-slugify "Géographie I"
geographie-i
$ echo "Intro to Biology 101" | scripts/idstack-slugify -
intro-to-biology-101
$ scripts/idstack-slugify --from-manifest
intro-to-biology-101
```

## idstack-report-section

`idstack-report-section` builds a Markdown report one section at a time. Each section stays a draft until the user approves it. The content rules are in [`templates/report-format.md`](../templates/report-format.md).

```bash
scripts/idstack-report-section init <report> --skill <name> --title <title> \
  [--project <name>] [--mode <mode>] [--run-id <id>] [--reserve <heading>]...
scripts/idstack-report-section check <draft>
scripts/idstack-report-section append <report> <draft>
scripts/idstack-report-section approve <report> [--draft <draft>]
scripts/idstack-report-section finish <report> [--stopped]
```

| Subcommand | Effect | stdout on success |
|------------|--------|-------------------|
| `init` | Writes the title, the meta line, the status line, a Summary placeholder, one placeholder for each `--reserve` heading and the footer. Replaces an earlier report. | `REPORT_STARTED: <report>` |
| `check` | Examines a draft (see the next table). Writes nothing. | `CHECK_OK` |
| `append` | Runs `check`, then adds each draft section with a draft mark. A section with the same heading is replaced in place. A new section goes before the footer. | `SECTION_ADDED:` or `SECTION_REPLACED:` for each section, then `Report path: <report>` |
| `approve` | Removes each draft mark. `--draft` also deletes the draft file. | `SECTION_APPROVED: <heading>` for each section |
| `finish` | Fails on a placeholder or a draft mark that remains. Then removes the status line. | `REPORT_COMPLETE: <report>` |

`init` options: `--skill` and `--title` are necessary. `--project` is the course name in the meta line. Without it, `init` reads `project_name` from `.idstack/project.json`, or uses `Untitled course`. `--mode` adds `mode: <mode>`. `--run-id` sets the run ID. The default is six random hex characters.

`finish --stopped` puts `idstack did not write this section because the skill stopped.` in each reserved section that has its placeholder. The Summary placeholder does not change, so the Summary must have text.

`check` refuses a draft for these problems:

- Structure: a `# ` title, a `### Finding` block, a `---` line, text before the first `## `, or text that only the script writes. Also an empty or repeated section, or a section with no table (Summary, Limitations and Next steps can have no table).
- Tables: the first column is not `ID`, no rows, a wrong number of cells or a repeated ID. Outside the fact sections, the last columns must be `Justification | Evidence`, with a justification in each row.
- Evidence: text other than citations, a code that is not in `evidence/references.md`, or a different tier.
- Findings: a severity other than `critical`, `warning` or `info`, or rows that are not in that sequence.
- Writing: a problem from `idstack-ste-check --format markdown`.

The fact sections are Project context, Course information, Imported structure, Readiness, Export contents and Generated artifacts. For a findings table (`ID | Severity | What we saw | Recommendation | Justification | Evidence`), `append` also writes one `### Finding <ID>` block for each row.

| Exit | Meaning |
|------|---------|
| 0 | Done |
| 1 | `check` or `append` found problems, `approve` found no draft, or `finish` found a placeholder or a draft. The problems go to stdout, and the report does not change. |
| 2 | No subcommand, a bad argument, or a `<placeholder>` left in `--title`, `--project` or `--mode`. Also: a missing draft, a missing or empty `evidence/references.md`, or `idstack-ste-check` did not run. |
| 3 | The report does not exist (`append`, `approve`, `finish`) |
| 4 | A write error. stdout gets `REPORT_WRITE_FAILED: <error>`, and the report does not change. |

`append` examines the draft file before the report. A missing draft thus gives 2, not 3. Files: reads `evidence/references.md` and `VERSION` in the clone, and runs `scripts/idstack-ste-check`. Writes the report through a tempfile in the folder of the real file and a rename, and makes its folder (`init`). A symlinked report stays a link.

```bash
$ cat draft.md
## Findings

| ID | Severity | What we saw | Recommendation | Justification | Evidence |
|----|----------|-------------|----------------|---------------|----------|
| F1 | warning | The quiz has no feedback. | idstack recommends that you add feedback to each item. | Feedback increases learning. | [Assessment-8] [T1] |
$ scripts/idstack-report-section init .idstack/exports/intro-to-biology-101/needs-analysis.md \
    --skill needs-analysis --title "Needs analysis" --reserve "Limitations"
REPORT_STARTED: .idstack/exports/intro-to-biology-101/needs-analysis.md
$ sed 's/\[T1\]/[T3]/' draft.md > bad.md
$ scripts/idstack-report-section check bad.md
bad.md:5: row "F1": [Assessment-8] is T1 in evidence/references.md, not T3. If you cannot cite the row, put the text in Limitations.
idstack-report-section: 1 problem(s). The report did not change.
$ scripts/idstack-report-section append .idstack/exports/intro-to-biology-101/needs-analysis.md draft.md
SECTION_ADDED: Findings
Report path: .idstack/exports/intro-to-biology-101/needs-analysis.md
$ scripts/idstack-report-section approve .idstack/exports/intro-to-biology-101/needs-analysis.md --draft draft.md
SECTION_APPROVED: Findings
```

## idstack-ste-check

`idstack-ste-check` finds some ASD-STE100 writing-rule problems in files that idstack writes.

```bash
scripts/idstack-ste-check [--format auto|html|markdown|text] [--word-list <path>] <path>...
```

| Option | Effect |
|--------|--------|
| `<path>` | A file, a folder, or `-` for stdin. A folder gives each `.html`, `.htm`, `.md` and `.markdown` file below it. |
| `--format` | Default `auto`: `.html` and `.htm` are HTML, `.md` and `.markdown` are Markdown, and all other input (stdin too) is text. |
| `--word-list <path>` | The file with the `ste-core` word list. Default: `templates/preamble.md` in the clone. |
| `-h`, `--help` | Prints the argparse help and exits 0. |

| Rule | Problem |
|------|---------|
| `sentence-length` | More than 20 words in a numbered step, or more than 25 words in other text. Headings and table headers are not examined. |
| `paragraph-length` | More than 6 sentences in a paragraph |
| `semicolon` | A semicolon in text |
| `contraction` | A contraction, for example "don't" |
| `verb-form` | "has been", "have been", "had been" or "having been" |
| `word` | A word from the word list |
| `html` | An element whose text the checker skips has no end tag |

The checker does not examine code, quotations, citations, URLs, placeholders, HTML script and style, Markdown block quotations, fenced code or YAML frontmatter. Each code span, quotation, citation, URL and placeholder counts as one word.

Each problem is one stdout line, `<path>:<line>: <rule>: <message>`, then a summary line. A Markdown paragraph reports its problems on its first line. Errors go to stderr.

| Exit | Meaning |
|------|---------|
| 0 | No problems |
| 1 | One or more problems |
| 2 | A command error, a bad word list or no text to examine. Also a file that the script cannot read, when the other files have no problems. |

Files: reads each path and the word list. Writes nothing.

```bash
$ printf 'You should not run this; it has been broken.\n' > note.txt
$ scripts/idstack-ste-check note.txt
note.txt:1: semicolon: write two sentences: "You should not run this; it has been broken."
note.txt:1: verb-form: use a simple tense, not "has been"
note.txt:1: word: "should": use "must" or "idstack recommends that you"
idstack-ste-check: 3 problem(s) in 1 file(s)
```

## idstack-timeline-log

`idstack-timeline-log` adds one event to `.idstack/timeline.jsonl`.

```bash
scripts/idstack-timeline-log '<json>'
```

The argument is one JSON object. The script adds `"ts"` (UTC) if the object has none, and keeps a `ts` that the caller gives. Input that is not a JSON object becomes `{"raw": "<input>", "ts": "<time>"}`. An empty argument or no argument writes nothing. `-h` or `--help` prints the header comment.

| Exit | Meaning |
|------|---------|
| 0 | Always, so a skill never stops here. Without python3, the script writes nothing and prints a message on stderr. |

Files: makes `.idstack/` if necessary, and adds one line to `.idstack/timeline.jsonl`.

```bash
$ scripts/idstack-timeline-log '{"skill":"needs-analysis","event":"completed"}'
$ scripts/idstack-timeline-log 'not json'
$ cat .idstack/timeline.jsonl
{"skill": "needs-analysis", "event": "completed", "ts": "2026-11-12T15:09:25Z"}
{"raw": "not json", "ts": "2026-11-12T15:09:25Z"}
```

## idstack-learnings

`idstack-learnings` keeps the course learnings in `.idstack/learnings.jsonl` and the global learnings in `~/.idstack/global/learnings.jsonl`.

```bash
scripts/idstack-learnings log '<json>'
scripts/idstack-learnings search [--limit N] [--type T] [--keyword K] [--cross-project]
scripts/idstack-learnings delete <key>
scripts/idstack-learnings promote <key>
```

| Subcommand | Effect |
|------------|--------|
| `log` | Adds one line with a `ts` (UTC). A `ts` from the caller is kept, as in `idstack-timeline-log`. Input that is not a JSON object becomes `{"raw": ..., "ts": ...}`. `log --help` prints the header comment. |
| `search` | Prints the matching lines as JSON, in file sequence. |
| `delete` | Removes the most recent course entry with the key, atomically. Prints `idstack removed the learning: <key>`. |
| `promote` | Adds the most recent course entry with the key to the global file, with `_source_project` and `"_promoted": true`. |

| `search` option | Effect |
|-----------------|--------|
| `--limit N` | The maximum number of lines. Default 3. A value that is not a number gives 3. A value below 1 gives 1. |
| `--type T` | Only entries whose `type` is `T` |
| `--keyword K` | Only entries whose `insight` or `key` contains `K`, case-insensitive |
| `--cross-project` | Also reads the global file. Course entries come last, so they stay when the limit cuts the list. Global entries get `"_source": "global"`. |

`--limit`, `--type` and `--keyword` also accept the `--option=value` form. `search` ignores options that it does not know. `promote` gets `_source_project` from `project_name` in `.idstack/project.json`, or uses `unknown`.

| Exit | Meaning |
|------|---------|
| 0 | Done. `log` always exits 0. |
| 1 | No subcommand or an unknown one (the usage line goes to stderr), or a missing option value. Also: no key, no course learnings file, no entry with the key, or a write error. |
| 2 | python3 is missing (all subcommands except `log`) |

Files: reads and writes `.idstack/learnings.jsonl`, and makes `.idstack/` for `log`. `search --cross-project` reads, and `promote` writes, `$HOME/.idstack/global/learnings.jsonl`.

```bash
$ scripts/idstack-learnings log '{"skill":"course-import","type":"operational","key":"canvas-rubrics","insight":"Rubrics use HTML","confidence":8}'
$ scripts/idstack-learnings search --keyword rubric
{"skill": "course-import", "type": "operational", "key": "canvas-rubrics", "insight": "Rubrics use HTML", "confidence": 8, "ts": "2026-11-12T15:09:25Z"}
```

## package-extension.sh

`package-extension.sh` tests the Chrome extension and puts it in a zip file for the Chrome Web Store.

```bash
scripts/package-extension.sh
```

The script has no options. It reads the version from `extension/manifest.json` with `node`, then runs `test/test-extension.sh`. Then it makes `build/`, deletes an earlier zip with the same name, and puts the contents of `extension/` in the zip. `manifest.json` is at the root of the zip. Last, it prints the zip path, its size and the Web Store upload steps. The zip does not contain `.DS_Store`, `__MACOSX`, `.git` files or `icons/generate-icons.js`.

| Exit | Meaning |
|------|---------|
| 0 | The zip file is ready |
| other | A step failed, for example an extension test (the script runs with `set -euo pipefail`) |

Files: reads `extension/`. Writes `build/idstack-chrome-extension-v<version>.zip` in the clone.

## Libraries in scripts/lib

These files are not tools. Other scripts load them.

| File | Loaded by | Content |
|------|-----------|---------|
| `scripts/lib/plugin-status.sh` | `idstack-doctor` | `plugin_entry_window` and `plugin_is_enabled`: read the idstack entry from `claude plugin list` |
| `scripts/lib/citations.py` | `idstack-report-section`, `test/check-citation-tiers.py` | `load_refs` and `check_evidence`: read the tiers in [`evidence/references.md`](../evidence/references.md) and examine an Evidence cell |
