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

No data is sent to external servers by idstack. No analytics, no tracking, no telemetry.

## Third-party services

idstack runs inside Claude Code, which is operated by Anthropic. Your conversation with Claude Code is subject to [Anthropic's privacy policy](https://www.anthropic.com/privacy). idstack itself does not add any data collection beyond what Claude Code already does.

If you use `/idstack:course-import` with the Canvas API, your Canvas access token is used locally to fetch course data. idstack does not store or transmit your token beyond the API call.

## Questions

If you have questions about privacy, [open an issue](https://github.com/savvides/idstack/issues) or [contact us](https://forms.gle/6LDgDD1M6WWyYvME8).
