# Privacy Policy

**Last updated:** November 2, 2026

## What idstack collects

Nothing. idstack has no servers of its own and receives none of your data. The plugin runs on your machine in Claude Code, and the Chrome extension runs in your browser. The extension sends page text to Google only when you run an audit with your own Google API key saved (see below).

## Where your data lives

All course data stays on your machine, in your project directory:

- `.idstack/project.json` — your course manifest
- `.idstack/timeline.jsonl` — session history (which skills ran, scores)
- `.idstack/learnings.jsonl` — project-specific discoveries
- `.idstack/course-content/` — generated course files
- `.idstack/exports/<course-slug>/` — the Markdown reports, the course dashboard and the LMS packages
- `.idstack/import/` — the text that `/idstack:course-import` takes from a Word file
- While `/idstack:course-import` reads an IMS Common Cartridge or a SCORM package, it unpacks the package into a temporary folder that your system makes, outside the project directory. The skill deletes that folder when the import step ends.
- `.idstack/canvas.env` — your Canvas URL, course ID and access token, when you use the Canvas API (see below)
- `.idstack/learnings-export.md` — learnings that you export with `/idstack:learn`

Designer profile and cross-project learnings are stored locally:

- `~/.idstack/profile.yaml` — your experience level preference
- `~/.idstack/global/learnings.jsonl` — learnings promoted across projects

idstack adds no analytics, no tracking, and no telemetry. In the Claude Code plugin, two things can reach the network, both listed under Third-party services below: the Canvas API calls made by `/idstack:course-import` and `/idstack:course-export`, and the citation currency check in `/idstack:red-team`. idstack does not check for updates.

## Third-party services

idstack runs inside Claude Code, which is operated by Anthropic. Your conversation with Claude Code is subject to [Anthropic's privacy policy](https://www.anthropic.com/privacy). idstack itself does not add any data collection beyond what Claude Code already does.

**Canvas API.** Two skills talk to the Canvas instance you point them at, using the access token you supply:

- `/idstack:course-import` **downloads** your course data from Canvas.
- `/idstack:course-export` **uploads** generated course content to Canvas — modules, pages, assignments, and discussions are POSTed to your Canvas instance so they appear in the course.

Both run only when you invoke that skill and give it the Canvas URL and course ID. `/idstack:course-export` also changes Canvas only after you approve its export plan. You paste your token into `.idstack/canvas.env` in your course folder, not into the chat. idstack makes that file readable only by you and adds it to `.idstack/.gitignore`, so git does not add it. The token is used for those API calls and is not sent anywhere else. When you are done, delete the file or revoke the token in Canvas. The receiving Canvas instance is your institution's, not ours.

**Citation currency check.** `/idstack:red-team` uses Claude Code's WebSearch tool when it is available. It searches the web for newer meta-analyses, trials or retractions for each T1 or T2 citation that the course uses. The search terms come from the cited studies, not from your course text. Without WebSearch, the audit runs without this check.

## idstack Chrome Extension

The extension is built to audit course materials, not student records. Here is what it reads, where that text goes, and what it keeps.

- **What it reads.** The extension reads a tab only when it has access: after you click the idstack toolbar icon on that tab, on Canvas pages at `instructure.com`, or on a Canvas site you allowed when Chrome asked. While the side panel is open it reads the title and main text of such a tab; that text stays in the panel until you click **Audit Page with Evidence**. On a Google Doc it downloads the document's plain text using your Google login. **Audit Full Course** requests the course syllabus and assignments from your Canvas instance's API using your existing Canvas login. The extension will not read Canvas grades, Gradebook, SpeedGrader, People, groups, discussions, submissions, Classic Quizzes answers, New Quizzes moderation and reports, or Inbox pages. Other pages can still contain student names or work, so audit course materials rather than student work.
- **Demo mode.** With no Google API key saved, the page's text is not sent anywhere: every audit returns the same sample findings, whatever the page says.
- **Where the text goes with a key.** With your own Google AI Studio API key saved, the page title and text (or the syllabus and assignments) are sent directly from your browser to Google's Generative Language API (`generativelanguage.googleapis.com`) under your key and your agreement with Google. No idstack server is involved.
- **Google's free tier.** If your key's Google Cloud project has no active Cloud Billing account, Google's terms let Google use what you submit, and the responses, to improve its products, and human reviewers may read them. The same terms ask you not to submit personal information. On billed projects, and for users in the European Economic Area, Switzerland, and the United Kingdom, Google says it does not use prompts or responses to improve its products. See [Google's terms for this API](https://ai.google.dev/gemini-api/terms). <!-- IDSTACK_CLI_LEAK_ALLOW -->
- **API keys.** Your Google API key is saved in `chrome.storage.local`, on this device only. Chrome does not copy it to other devices. An older key in `chrome.storage.sync` moves to this device and Chrome deletes the old copy. The extension sends the key only to Google, with each audit. To remove it, clear its field in Settings and save.
- **Dossier.** The Course Dossier you build is kept in `chrome.storage.local` and stays on this device. **Remove All from Dossier** empties it; removing the extension deletes it. The extension keeps no audit history. Versions 1.2.0 and earlier kept up to 20 past audits there; updating the extension deletes them.
- **Fonts.** Opening the side panel loads its fonts from Google Fonts (`fonts.googleapis.com`, `fonts.gstatic.com`), so Google receives your IP address and browser details; no page or course content is sent.
- **No tracking.** The extension contains no analytics, tracking scripts, or telemetry.

## Questions

If you have questions about privacy, [open an issue](https://github.com/savvides/idstack/issues) or [contact us](https://forms.gle/6LDgDD1M6WWyYvME8).
