# Canvas API fixtures

Used by `test/test-canvas-diff.py`. The fake `curl` in that test serves
`<api path after /api/v1/, with / as __>.json` and answers 404 for a file that is
not here.

- `import/` is the course when the snapshot runs.
- `now/` is the course when the dry run runs. `syllabus-notes` changed in Canvas
  (a conflict), `new-page` is new (no baseline) and assignment 9 is gone (404).
  Outcome 303 belongs to a different course, assignment 11 belongs to a quiz and
  assignment 12 belongs to a graded discussion, assignment 13 to an external tool
  and assignment 14 to New Quizzes (all blocked). Outcome 404 belongs to account
  42, which has the same number as the course (blocked).

A file `<name>.link` next to a fixture makes the fake curl send a `Link` header
with `rel="next"`, as Canvas does when a list has more pages.

The data is made up. These files follow the shapes in the Canvas REST API
documentation (Pages, Assignments, Outcomes, Outcome Groups). They are not
recorded from a live Canvas.
