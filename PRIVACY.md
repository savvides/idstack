# Privacy Policy

**Last updated:** September 24, 2026

## What idstack collects

Nothing. idstack has no servers of its own and receives none of your data. The Claude Code plugin runs on your machine and the Chrome extension runs in your browser. The extension sends page text to Google only when you run an audit with your own Google API key saved, and both send the text of findings to Consensus only when you have set up your own Consensus key (see below).

## Where your data lives

All course data stays in your project directory:

- `.idstack/project.json` — your course manifest
- `.idstack/timeline.jsonl` — session history (which skills ran, scores)
- `.idstack/learnings.jsonl` — project-specific discoveries
- `.idstack/course-content/` — generated course files

Designer profile and cross-project learnings are stored locally:

- `~/.idstack/profile.yaml` — your experience level preference
- `~/.idstack/global/learnings.jsonl` — learnings promoted across projects

idstack adds no analytics, no tracking, and no telemetry. In the Claude Code plugin, three things can reach the network, all listed under Third-party services below: the Canvas API calls made by `/idstack:course-import` and `/idstack:course-export`, an update check against this repository on GitHub, and Consensus lookups once you set up a Consensus key.

## Third-party services

idstack runs inside Claude Code, which is operated by Anthropic. Your conversation with Claude Code is subject to [Anthropic's privacy policy](https://www.anthropic.com/privacy). idstack itself does not add any data collection beyond what Claude Code already does.

**Canvas API.** Two skills talk to the Canvas instance you point them at, using the access token you supply:

- `/idstack:course-import` **downloads** your course data from Canvas.
- `/idstack:course-export` **uploads** generated course content to Canvas — modules, pages, assignments, and discussions are POSTed to your Canvas instance so they appear in the course.

Both run only when you invoke that skill and confirm the target course. Your token is used for those API calls and is neither stored by idstack nor sent anywhere else. The receiving Canvas instance is your institution's, not ours.

**Consensus API.** Only if you set up your own Consensus API key: `CONSENSUS_API_KEY` in your environment, `consensus_api_key` in `~/.idstack/profile.yaml` (where `bin/idstack-consensus configure` saves it), or `preferences.consensus_api_key` in `.idstack/project.json`. With a key, `bin/idstack-consensus` sends the text of each claim it checks to Consensus (`api.consensus.app`) under your key. Those claims are the findings from `/idstack:course-quality-review`, `/idstack:assessment-design`, and `/idstack:red-team`, which describe your course and can quote it, or the research domain you name to `idstack-consensus sync`. Answers are cached in `~/.idstack/cache/consensus/`, and a claim already in the cache is not sent again. A key kept in `.idstack/project.json` travels with that file, so if you share the project folder, consider the environment variable or your profile instead. Without a key, nothing is sent to Consensus.

**Update check.** On skill startup idstack runs `git fetch` against this repository to see whether a newer version exists, at most once an hour. That is a request to GitHub carrying nothing but the fetch itself; it never uploads your course data. It only runs for git installs, and removing the repo's `.git` directory disables it.

## idstack Chrome Extension

The extension is built to audit course materials, not student records. Here is what it reads, where that text goes, and what it keeps.

- **What it reads.** The extension reads a tab only when it has access: after you click the idstack toolbar icon on that tab, on Canvas pages at `instructure.com`, or on a Canvas site you allowed when Chrome asked. While the side panel is open it reads the title and main text of such a tab; that text stays in the panel until you click **Audit Page with Evidence**. On a Google Doc it downloads the document's plain text using your Google login. **Audit Entire Course** requests the course syllabus and assignments from your Canvas instance's API using your existing Canvas login. The extension will not read Canvas grades, Gradebook, SpeedGrader, People, groups, discussions, submissions, or Inbox pages. Other pages can still contain student names or work, so audit course materials rather than student work.
- **Demo mode.** With no Google API key saved, the page's text is not sent anywhere: every audit returns the same sample findings, whatever the page says. If a Consensus key is saved, those sample findings are still checked against Consensus.
- **Where the text goes with a key.** With your own Google AI Studio API key saved, the page title and text (or the syllabus and assignments) are sent directly from your browser to Google's Generative Language API (`generativelanguage.googleapis.com`) under your key and your agreement with Google. No idstack server is involved.
- **Google's free tier.** If your key's Google Cloud project has no active Cloud Billing account, Google's terms let Google use what you submit, and the responses, to improve its products, and human reviewers may read them. The same terms ask you not to submit personal information. On billed projects, and for users in the European Economic Area, Switzerland, and the United Kingdom, Google says it does not use prompts or responses to improve its products. See [Google's terms for this API](https://ai.google.dev/gemini-api/terms). <!-- IDSTACK_CLI_LEAK_ALLOW -->
- **Consensus, with a Consensus key.** If you also save a Consensus key in Settings, then after each audit the claim of every finding (its evidence text, or failing that its observation, recommendation, or citation) is sent from your browser to Consensus (`api.consensus.app`) under your key. Findings describe the audited page and can quote it. Answers are cached in `chrome.storage.local`, and a claim already in the cache is not sent again. Without a Consensus key, nothing goes to Consensus.
- **API keys.** Your Google API key and your Consensus key are saved in `chrome.storage.sync`. If Chrome sync is on, Chrome copies them to your Google account and to other browsers where you are signed in. The extension sends each key only to its own service, with each audit. To remove one, clear its field in Settings and save.
- **Audit history and dossier.** The last 20 audit results (page address, title, page type, and the full audit result) are kept in `chrome.storage.local`, as is the Course Dossier you build. Both stay on this device. **Clear Dossier** empties the dossier; removing the extension deletes both.
- **Fonts.** Opening the side panel loads its fonts from Google Fonts (`fonts.googleapis.com`, `fonts.gstatic.com`), so Google receives your IP address and browser details; no page or course content is sent.
- **No tracking.** The extension contains no analytics, tracking scripts, or telemetry.

## Questions

If you have questions about privacy, [open an issue](https://github.com/savvides/idstack/issues) or [contact us](https://forms.gle/6LDgDD1M6WWyYvME8).
