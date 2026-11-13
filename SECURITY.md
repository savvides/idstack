# Security

## Report a problem privately

Do not open a public issue for a security problem. Use GitHub private vulnerability reporting:

1. Go to the [Security tab](https://github.com/savvides/idstack/security) of the repository.
2. Select **Report a vulnerability**.
3. Tell us what the problem is, how to make it occur, and which version of idstack you use (the `VERSION` file, or the plugin version in `claude plugin list`).

Only the maintainer can read the report. We reply in the report.

## What is sensitive

- **Canvas tokens.** `/idstack:course-import` and `/idstack:course-export` keep your Canvas token in `.idstack/canvas.env` in your course folder. Git ignores this file, and only you can read it. Do not paste a token in an issue, a pull request or a log. If a token goes public, remove it in Canvas and make a new one.
- **Course and student data.** The `.idstack/` folder in a course folder holds the manifest, the reports and the session history of that course. A course can include student names, grades or work. Do not attach these files to a public issue. Remove student data from an example before you share it.
- **The Chrome extension API key.** The extension keeps your Google AI Studio API key in your browser. See [PRIVACY.md](PRIVACY.md).

## Examples of security problems

- A skill or a script shows a token in the chat, in a report, in a log or in the process list.
- A script writes outside the course folder or `~/.idstack` when you did not tell it to.
- Course text or student data goes to a server when you did not start an integration.
