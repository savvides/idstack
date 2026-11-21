# LMS sync: design and dry run

Issue: [#132](https://github.com/savvides/idstack/issues/132). Status: design, plus a dry run that only reads from Canvas. No idstack code changes a live Canvas course with this feature. The write path needs a separate approval from the owner and a test course.

## The problem

`/idstack:course-import` reads a live Canvas course. Then `/idstack:learning-objectives`, `/idstack:course-quality-review` and `/idstack:accessibility-review` make better objectives and find problems in the pages and assignments. Today the designer copies each improvement into Canvas by hand.

`/idstack:course-export` Path B already writes to Canvas, but it only creates items in an empty course shell. It looks for an item with the same title and does not change an item that exists. Sync is different: it changes items that teachers and students use now. A bug can remove a teacher's work. Thus the design starts with a dry run.

**Measurable outcome.** Before a push, the designer sees each change as a diff, with each conflict marked. No push changes a text that someone edited in Canvas after the import, unless the designer approves that row after they read the diff.

## What idstack pushes

| Improvement | From | Canvas item and field | Canvas write call (later, not in this PR) |
|-------------|------|-----------------------|-------------------------------------------|
| Better objective text | `learning_objectives.ilos[].objective` | Outcome `title` or `description` | `PUT /api/v1/outcomes/:id` |
| Accessibility fix (alt text, headings, link text, tables) | `accessibility-review` report | Page `body`, assignment `description` | `PUT /api/v1/courses/:course/pages/:url` (`wiki_page[body]`), `PUT /api/v1/courses/:course/assignments/:id` (`assignment[description]`) |
| Quality fix (clear instructions, objective in a module page) | `course-quality-review` report | Page `body`, page `title`, assignment `description`, assignment `name` | Same as above |

Not in the first version: rubrics, quizzes (Classic Quizzes and New Quizzes have different APIs), discussion topics, files, module order, points, dates and the published state. Each of these has more risk (grades, submissions) or a different API.

## The proposal file

The dry run reads a proposal: a JSON file that names each change. The proposal gives no URL. A file source is a path in the course folder. The script makes each URL from a fixed template for the `kind` and validates the ID.

```json
{
  "changes": [
    {"id": "C-1", "kind": "outcome", "canvas_id": "101", "field": "description",
     "source": {"ilo": "ILO-1"}, "reason": "learning-objectives"},
    {"id": "C-2", "kind": "page", "canvas_id": "week-1-overview", "field": "body",
     "source": {"file": "fixes/week-1.html"}, "reason": "accessibility-review wcag-1"}
  ]
}
```

| Key | Values |
|-----|--------|
| `id` | A short ID for the row: letters, digits, `.`, `_` or `-` |
| `kind` | `page`, `assignment` or `outcome` |
| `canvas_id` | The page URL name (`week-1-overview`), or the number of the assignment or outcome |
| `field` | `page`: `title`, `body`. `assignment`: `name`, `description`. `outcome`: `title`, `description` |
| `source` | `{"ilo": "ILO-n"}` reads the objective from `.idstack/project.json`. `{"file": "<path>"}` reads a file in the course folder. In `.idstack/` it reads only `course-content/`. It refuses a path outside the folder and a file that contains the token |
| `reason` | Optional text for the report, for example the finding ID |

Today a person or Claude writes the proposal. In the next step, a skill makes it from the reports (see the open questions). The model makes the proposal (judgment). The script does the comparison (no judgment). An empty proposed text is refused, because a push must not clear a field.

## How the dry run finds a conflict

A conflict is a text that someone changed in Canvas after idstack read it. A push over a conflict removes that change.

1. **Baseline.** `scripts/idstack-canvas-diff snapshot` runs right after an import. It reads each page, assignment and course outcome and writes `.idstack/canvas-baseline.json`. For each item it keeps the Canvas ID, the title and `updated_at`. It also keeps a sha256 of each field that a push can change. It keeps the title, but no body or description text.
2. **Hash, not date.** The decision uses the hash of the field. Before the hash, the script changes CRLF to LF and removes the spaces at the two ends. `updated_at` is in the baseline for people to read, but it does not decide. It changes when someone publishes an item or changes a date. Outcomes do not have it.
3. **Compare.** `scripts/idstack-canvas-diff diff <proposal>` reads each named item with one GET, then gives each row one state:

| State | Rule | Result of a push |
|-------|------|------------------|
| `NOT FOUND` | Canvas answers 404 | Nothing |
| `BLOCKED` | An outcome of the account or of a different course, or the assignment of a quiz, a graded discussion or an external tool (LTI) | Never pushed. An account outcome is in more than one course, and quizzes are out of scope |
| `NO CHANGE` | The Canvas text is the same as the proposed text | Nothing |
| `NO BASELINE` | The baseline has no hash for this field | Never pushed. idstack cannot find a change that someone made |
| `CONFLICT` | The Canvas text hash is not the baseline hash | Pushed only after the designer reads the diff and approves the row |
| `CHANGE` | The Canvas text hash is the baseline hash | Pushed after approval |

The script writes `.idstack/exports/<course-slug>/canvas-sync-dry-run.md`: a summary, one table row for each change, and a unified diff for each change. The diff breaks HTML at each tag, so a changed `alt` attribute shows as one line. Long course text is only in fenced code blocks. Titles and the course name in the tables are escaped, so they cannot make a link, an image or HTML. A zero-width space breaks a bare URL, a `www.` name and an e-mail address. GitHub and other GFM renderers make a link from them also after a backslash.

A baseline that is for a different Canvas course is refused. Each run first reads the course itself, so a wrong course ID stops the run. It does not give an empty baseline. A Canvas error (401, 403, 429, 5xx, timeout, an answer that is not JSON) stops the run with exit 5 and writes no file.

Before it reads its inputs, each run of `diff` or `snapshot` deletes the report of an earlier run. Thus a failed run leaves no report, and a new baseline leaves no report made against the old one. Thus a report never shows a part of the course as all of it.

curl gets `-q` as its first option, so `~/.curlrc` cannot add a method, a redirect or a trace file.

## The write path (later)

These rules are for the push. They are not in this PR.

1. **Read again just before each write.** Between the dry run and the push, a teacher can edit the item. The push reads the item again and computes the state again. If the state changed, the push skips the row and tells the designer.
2. **Undo snapshot.** Before each write, the push keeps the full JSON of the item in `.idstack/canvas-undo/<run-id>/<kind>-<id>.json` (mode 600, in `.idstack/.gitignore`). An undo writes the old field back, but only if the Canvas hash is still the hash that idstack wrote. Pages also have Canvas revisions (`GET /api/v1/courses/:course/pages/:url/revisions`), which a teacher can restore in the Canvas interface. Assignments and outcomes have no revision API, so the undo file is the only copy.
3. **New baseline after each write.** Canvas cleans the HTML when it saves a page. The text that Canvas keeps can be different from the text that idstack sent. After each write, the push reads the item again and puts that hash in the baseline. Thus the next dry run shows `NO CHANGE` and not a false conflict.
4. **One item for each call.** The push stops at the first error and reports which rows it wrote. It never sends a batch.
5. **Same security rules as today.** The token goes on stdin (`curl -K -`). Course text goes in a file (`--data-urlencode "field@file"`), never in a quoted shell string. A test fails if a read-only script gets a write call.

## Open questions for the owner

1. **Baseline at import.** The baseline is a manual step today. To make it automatic, `/idstack:course-import` Path C must run `snapshot` after step C3. This PR does not change that skill, because the Moodle work (#129) changes the same file now. Do you approve this change after #129 merges?
2. **ILO to outcome link.** The manifest does not record which Canvas outcome an imported ILO came from. Option (a): course-import writes a `canvas_outcome_id` in each item of `learning_objectives.ilos[]`. `/idstack:learning-objectives` keeps it when it writes the ILOs again. Option (b): the designer selects the outcome for each ILO at push time. Option (a) is a schema change (an optional field, no version change). Which do you prefer?
3. **Which outcome field gets the ILO text.** Canvas outcomes have a short `title` and a longer `description`. Imported courses use them in different ways. Do we write the ILO to `description` and keep the title, or ask each time?
4. **Account outcomes.** The dry run marks them `BLOCKED`. Do we stop there, or offer to make a course copy of the outcome and link it to the rubric? A copy changes how the outcome results roll up.
5. **Where the push lives.** A new option in `/idstack:course-export` ("update an existing Canvas course"), or a new skill `/idstack:course-sync`? course-export already has the Canvas settings and the export plan step. A new skill keeps course-export simpler.
6. **Push over a conflict.** After the designer reads the diff, can they push a `CONFLICT` row? Or must they run the import again first?
7. **Live courses.** Do we push to a course that has students in it, or only to an unpublished course or a copy? Canvas can copy a course (Course Copy) for a safe first push.
8. **Test course.** The write path needs a Canvas test course and a token that can only change that course. Which instance do we use (for example a free-for-teacher account or an institution sandbox)?
9. **Large courses.** The snapshot reads only the first page of each list (`per_page=100`). When Canvas sends a `Link` header with `rel="next"`, it prints `BASELINE_PARTIAL`. An item after the first page has no baseline, so it gets `NO BASELINE` and is not pushed. Is that sufficient for the courses you see, or do we add paging now?
10. **Other LMS.** Moodle (#129) and other LMS have different write APIs. Do we keep this design Canvas-only until the Canvas push is stable?

## Verification status

The fixtures in `test/fixtures/canvas/` follow the shapes in the Canvas REST API documentation (Pages, Assignments, Outcomes, Outcome Groups). They are not recorded from a live Canvas. Before the write path, run `snapshot` and `diff` against a real test course. Then compare these fields with the fixtures: `body`, `description` and `updated_at`. Also compare `context_type` and `context_id` of an outcome, and the `outcome` object in the `outcome_group_links` list.

## Run it

```bash
cd <course folder>
<your idstack clone>/scripts/idstack-canvas-diff snapshot
<your idstack clone>/scripts/idstack-canvas-diff diff proposal.json
```

Options and exit codes are in the [CLI reference](cli-reference.md#idstack-canvas-diff).
