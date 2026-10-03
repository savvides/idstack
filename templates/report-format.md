## Report Format Reference

Skills produce two artifacts: a JSON manifest section (system state) and an HTML report (the human view). The HTML report is what the instructional designer reads. This file defines the canonical **content contract** every per-skill report follows — which fields appear, which evidence rules apply, which severity ordering. The **visual contract** (HTML skeleton + CSS) lives in `templates/report.html.tmpl` and `templates/assets/idstack.css`. The two must stay in sync.

### Output contract

- **JSON.** `.idstack/project.json` — the manifest. The skill writes its section using `bin/idstack-manifest-merge`.
- **HTML.** `.idstack/exports/<course-slug>/<skill>.html` — the report. The skill writes it using the `Write` tool, following the structure in `templates/report.html.tmpl`.
- **Pointer.** The skill's manifest section sets `report_path` to the relative path of the HTML report so other skills can find it. (`bin/idstack-status` discovers reports independently by globbing `.idstack/exports/<course-slug>/*.html`, so the dashboard survives a stale `report_path`.)

`<course-slug>` is derived from the manifest's `project_name` via `bin/idstack-slugify`. Empty/missing `project_name` falls back to `untitled-course`. The slug is computed deterministically; skills don't cache it. Every skill that writes a report also ensures `.idstack/exports/<course-slug>/assets/idstack.css` exists by copying the canonical stylesheet (`$_IDSTACK/templates/assets/idstack.css`) on each run — cheap, keeps the folder self-contained when zipped or moved.

Re-runs overwrite the report. The timeline at `.idstack/timeline.jsonl` carries the run history; the report file always reflects the most recent run.

### Voice and stance

idstack works with the designer. It does not make the course. Each report gives evidence-based feedback to the designer. The designer makes the decisions about the course. Write all report text in ASD-STE100 Simplified Technical English, as the "Writing Standard (ASD-STE100)" section of `templates/preamble.md` tells you. Obey these three rules:

- **Problem, then evidence, then recommendation.** First show the problem that idstack found. Then show the evidence from the research. Then give the recommendation.
- **Recommend, do not give orders.** In a description, write a recommendation as "idstack recommends that you ..." or as "You can ...". In a numbered list of steps, write each step as a command. Do not use "consider", "may", "should" or "suggest". In the HTML, the label of the recommendation is "Recommendation".
- **Cite each recommendation.** Each finding has a `[Domain-N] [Tier]` citation. If you cannot cite a recommendation, do not put it in a finding. Put it in a "Limitations" or "Notes" section.

### Canonical content (what each placeholder must carry)

Skills emit the HTML structure from `templates/report.html.tmpl`. The data each placeholder must contain is fixed here. Every report contains, in order:

1. **Header** — `skill_title`, `skill_name`, `project_name`, `iso_timestamp`, `human_timestamp`, `run_id` (short id from timeline.jsonl), optional `mode`.
2. **Summary** — 2–3 sentences. The 30-second read for a designer scanning the file. Lead with the most important thing: a score, a top finding, a confidence statement. Don't bury the lede. Optional one-line scoreboard for skills with numeric outputs ("Quality 62/100 · Accessibility 71/100 · Confidence 4/5").
3. **Findings** — one `<article class="finding sev-{severity}">` block per finding, ordered by severity (`critical` → `warning` → `info`), then by impact within severity. Stable ids (`<dimension>-<n>`) so other skills and the designer can refer to findings deterministically across runs. Each block carries:
   - `severity` — `critical` (course will measurably fail learners) / `warning` (likely problem worth addressing) / `info` (worth knowing, not blocking).
   - `tier` — `T1` through `T5` per `evidence/references.md`. Stronger evidence wins when tiers conflict.
   - `finding_id`, `finding_title` (short).
   - `observation_html` — concrete observation grounded in the manifest or the imported course ("Module 4 has no rubric." / "Of 8 ILOs, 3 have no matching assessment.").
   - `evidence_html` — 1–2 sentences from the literature synthesis, plain language, followed by `<cite class="citation">[Domain-N] [Tier]</cite>`.
   - `why_it_matters_html` — bridge: explicitly connect observation → evidence → learner-outcome consequence. Without this, the citation reads as decoration.
   - `suggestion_html` — the recommendation, with the label "Recommendation". Write it as "idstack recommends that you ..." or as "You can ...". It can name a skill to run ("You can run /idstack:learning-objectives to correct the bidirectional gap.") or a change to the course.
4. **Top recommendations** — 3–5 highest-impact moves, ordered. Each carries an evidence citation and points to the skill/finding that would address it. Write each item as one command, with no period at the end of `{{action}}`. In a second sentence, tell why the change is necessary. Put the citation at the end of the item. `bin/idstack-status` and `/idstack:pipeline` may surface this section as a digest.
5. **Optional skill-specific sections** — e.g., needs-analysis adds "Training justification" + "Expertise-fit read"; accessibility-review may add a WCAG/UDL split. Use `<section>` with a clear `<h2>` heading.
6. **Limitations** — what this report didn't analyze, what's a proxy, what would change the read if available.
7. **Next steps** — one paragraph. What the designer might do next inside idstack — a specific skill to run, a specific finding to address first, or "rerun this skill after addressing X." Avoid generic advice.
8. **Footer** — "Generated by `/idstack:<skill>` · idstack v<version>" and a back-link to `index.html`.

### Notes for skill authors

- **Order matters.** Summary first; findings before recommendations; limitations before next steps. A designer scanning the top 200 words should know the verdict.
- **Severity taxonomy.** `critical` (course will measurably fail learners) / `warning` (likely problem worth addressing) / `info` (worth knowing, not blocking).
- **Tier taxonomy** comes from `evidence/references.md` — `T1` (RCTs/meta-analyses) through `T5` (expert opinion).
- **Don't pad.** Three solid findings beat ten thin ones. The designer's time is the binding constraint.
- **Match the manifest.** Every finding in the report must correspond to a finding in the manifest's structured arrays (`findings`, `wcag_violations`, `flags`, etc.) so downstream skills can read them programmatically.
- **No raw JSON in the report.** Use tables, prose, and lists. The JSON lives in the manifest; the HTML is for the human.
- **HTML, not Markdown.** Skills emit valid HTML5 — `<p>`, `<ul>`, `<table>`, `<code>` — not Markdown source. Embed structured fields directly into the elements that `templates/assets/idstack.css` styles (`sev-badge`, `tier-badge`, `citation`, etc.). When prose contains code, file paths, or skill names, wrap in `<code>`.
- **Copy the stylesheet, don't link out.** Each skill that writes a report copies `$_IDSTACK/templates/assets/idstack.css` to `.idstack/exports/<course-slug>/assets/idstack.css`. The folder must be self-contained — zipping it should produce a deliverable that opens correctly on a stakeholder's laptop with no network.
