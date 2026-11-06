## Report Format Reference

Skills produce two artifacts: a JSON manifest section (system state) and a Markdown report (the human view). The Markdown report is what the instructional designer reads. This file defines the canonical **content contract** every per-skill report follows — which fields appear, which evidence rules apply, which severity ordering. The **skeleton** (the order of the headings and the shape of each finding) lives in `templates/report.md.tmpl`. The two must stay in sync.

### Output contract

- **JSON.** `.idstack/project.json` — the manifest. The skill writes its section using `bin/idstack-manifest-merge`.
- **Markdown.** `.idstack/exports/<course-slug>/<skill>.md` — the report. The skill builds it one section at a time with `bin/idstack-report-section`, as the "Step Review" section of `templates/preamble.md` tells. `init` starts the file, and `append` adds each section as a draft, which the user reads in the report file and not in the chat. When the user approves the section, `approve` removes the draft mark. `finish` refuses a report that has a draft section, and it removes the in-progress status line.
- **Pointer.** The skill's manifest section sets `report_path` to the relative path of the Markdown report so other skills can find it. (`bin/idstack-status` discovers reports independently by globbing `.idstack/exports/<course-slug>/*.md`, so the dashboard survives a stale `report_path`.)

`<course-slug>` is derived from the manifest's `project_name` via `bin/idstack-slugify`. Empty/missing `project_name` falls back to `untitled-course`. The slug is computed deterministically; skills don't cache it. The slug is ASCII kebab-case, so the relative report path never has a space. The skill gives the user that relative path as the link to the report.

Re-runs overwrite the report. The timeline at `.idstack/timeline.jsonl` carries the run history; the report file always reflects the most recent run.

### Voice and stance

idstack works with the designer. It does not make the course. Each report gives evidence-based feedback to the designer. The designer makes the decisions about the course. Write all report text in ASD-STE100 Simplified Technical English, as the "Writing Standard (ASD-STE100)" section of `templates/preamble.md` tells you. Obey these three rules:

- **Problem, then evidence, then recommendation.** First show the problem that idstack found. Then show the evidence from the research. Then give the recommendation.
- **Recommend, do not give orders.** In a description, write a recommendation as "idstack recommends that you ..." or as "You can ...". In a numbered list of steps, write each step as a command. Do not use "consider", "may", "should" or "suggest". In the report, the label of the recommendation is "Recommendation".
- **Cite each recommendation.** Each finding has a `[Domain-N] [Tier]` citation. If you cannot cite a recommendation, do not put it in a finding. Put it in a "Limitations" or "Notes" section.

### Canonical content (what each placeholder must carry)

Skills build the Markdown structure from `templates/report.md.tmpl`. The data each placeholder must contain is fixed here. A report contains these sections, in this order. A step section, Findings or Top recommendations is left out when it has no rows, for example Findings in a report with no problems, or Top recommendations in a stopped run:

1. **Header** — `skill_title`, `skill_name`, `project_name`, `human_timestamp`, `run_id`, optional `mode`. `init` writes it.
2. **Summary** — 2–3 sentences. The 30-second read for a designer scanning the file. Lead with the most important thing: a score, a top finding, a confidence statement. Don't bury the lede. `init` writes a placeholder, and the last Step Review replaces it. Reserved score sections (`init --reserve`) come next.
3. **Step sections** — one `## ` section for each Step Review, in the order of the steps. Each section is a table. The first column is `ID` (stable ids, for example `T-1`). The last two columns are `Justification` (one sentence that tells why the row is correct for this course, from the research) and `Evidence` (only the `[Domain-N] [Tier]` citation, with the tier that `evidence/references.md` gives). A row that cannot be cited goes to Limitations. The fact sections (`Project context`, `Course information`, `Imported structure`, `Readiness`, `Export contents`, `Generated artifacts`) have no Justification or Evidence columns.
4. **Findings** — a table with the columns `ID | Severity | What we saw | Recommendation | Justification | Evidence`, ordered by severity (`critical` → `warning` → `info`), then by impact within severity. Stable ids (`<dimension>-<n>`) so other skills and the designer can refer to findings deterministically across runs. When it adds the section, `bin/idstack-report-section` writes one `### Finding <id>` block for each row from the cells. The skill never writes these blocks.
   - `severity` — `critical` (course will measurably fail learners) / `warning` (likely problem worth addressing) / `info` (worth knowing, not blocking).
   - `What we saw` — concrete observation grounded in the manifest or the imported course ("Module 4 has no rubric." / "Of 8 ILOs, 3 have no matching assessment.").
   - `Recommendation` — "idstack recommends that you ..." or "You can ...". It can name a skill to run or a change to the course.
   - `Justification` — the bridge: connect the observation and the evidence to the learner outcome, in one sentence.
   - `Evidence` — the citation. The block's tier is the strongest tier in the cell.
5. **Top recommendations** — a table `ID | Action | Justification | Evidence`, 3–5 highest-impact moves, ordered. Write each action as one command. `/idstack:pipeline` reads each report, this section included, when it writes the course dashboard.
6. **Limitations** — text. What this report didn't analyze, what's a proxy, what would change the read if available. Each removed finding adds "You removed finding `<ID>`."
7. **Next steps** — text, one paragraph. What the designer might do next inside idstack — a specific skill to run, a specific finding to address first, or "rerun this skill after addressing X." Avoid generic advice.
8. **Footer** — "Generated by `/idstack:<skill>` · idstack v<version>" and a link to `index.md`. `init` writes it.

### Notes for skill authors

- **Order matters.** Summary first; step sections in step order; findings before recommendations; limitations before next steps. A designer scanning the top 200 words should know the verdict.
- **Severity taxonomy.** `critical` (course will measurably fail learners) / `warning` (likely problem worth addressing) / `info` (worth knowing, not blocking).
- **Tier taxonomy** comes from `evidence/references.md` — `T1` (RCTs/meta-analyses) through `T5` (expert opinion).
- **Don't pad.** Three solid findings beat ten thin ones. The designer's time is the binding constraint.
- **Match the manifest where it has findings.** When the skill's manifest section holds its findings (`quality_review` in its `recommendations` array, `red_team_audit` in `dimensions.<name>.findings`, `accessibility_review` in `wcag_violations` and `udl_recommendations`), each finding in the report corresponds to an item in one of those arrays, so downstream skills can read it programmatically. needs-analysis, course-builder, course-export and course-import keep their findings only in the report; their manifest sections hold counts and state, not the findings.
- **No raw JSON in the report.** Use tables, prose, and lists. The JSON lives in the manifest; the Markdown is for the human.
- **Markdown, not HTML.** Skills write plain Markdown: headings, paragraphs, lists, pipe tables and code spans. Do not write HTML elements, classes or styles. Write the citation as plain text (`[Alignment-14] [T1]`). When prose contains code, file paths, or skill names, put them in a code span (`` ` ``).
- **Self-contained folder.** A report has no stylesheet, scripts or images. Links between reports are relative (`[Course dashboard](index.md)`), so the folder still works when it is zipped or moved.
