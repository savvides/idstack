# Privacy Policy

**Last updated:** April 21, 2026

## What idstack collects

Nothing. idstack runs entirely on your local machine.

## Where your data lives

All course data stays in your project directory:

- `.idstack/project.json` — your course manifest
- `.idstack/timeline.jsonl` — session history (which skills ran, scores)
- `.idstack/learnings.jsonl` — project-specific discoveries
- `.idstack/course-content/` — generated course files

Designer profile and cross-project learnings are stored locally:

- `~/.idstack/profile.yaml` — your experience level preference
- `~/.idstack/global/learnings.jsonl` — learnings promoted across projects

idstack adds no analytics, no tracking, and no telemetry. Two things do reach the network, both only when you ask for them, and both are listed under Third-party services below: the Canvas API calls made by `/idstack:course-import` and `/idstack:course-export`, and an update check against this repository on GitHub.

## Third-party services

idstack runs inside Claude Code, which is operated by Anthropic. Your conversation with Claude Code is subject to [Anthropic's privacy policy](https://www.anthropic.com/privacy). idstack itself does not add any data collection beyond what Claude Code already does.

**Canvas API.** Two skills talk to the Canvas instance you point them at, using the access token you supply:

- `/idstack:course-import` **downloads** your course data from Canvas.
- `/idstack:course-export` **uploads** generated course content to Canvas — modules, pages, assignments, and discussions are POSTed to your Canvas instance so they appear in the course.

Both run only when you invoke that skill and confirm the target course. Your token is used for those API calls and is neither stored by idstack nor sent anywhere else. The receiving Canvas instance is your institution's, not ours.

**Update check.** On skill startup idstack runs `git fetch` against this repository to see whether a newer version exists, at most once an hour. That is a request to GitHub carrying nothing but the fetch itself; it never uploads your course data. It only runs for git installs, and removing the repo's `.git` directory disables it.

## idstack Chrome Extension

The idstack Chrome Extension is designed with a strict privacy-first and FERPA-compliant architecture:

- **Curriculum-Only Processing:** The extension only reads public or instructor-accessible course materials (syllabi, module structures, assignment guidelines, and rubrics). It never accesses student rosters, student submissions, student grades, or any Personally Identifiable Information (PII).
- **Client-Side Storage:** Your optional Google AI Studio API key and saved course audit dossiers are stored locally on your device via `chrome.storage.local`. No audit history or credentials are ever sent to idstack servers.
- **Direct AI Inference:** If you provide your own Google AI Studio API key, requests are sent directly from your browser to Google's API (`generativelanguage.googleapis.com`). Zero data is routed through intermediary proxy servers.
- **No Tracking:** The extension contains zero analytics, tracking scripts, or telemetry.

## Questions

If you have questions about privacy, [open an issue](https://github.com/savvides/idstack/issues) or [contact us](https://forms.gle/6LDgDD1M6WWyYvME8).
