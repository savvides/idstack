#!/usr/bin/env bash
# Runs real bash blocks from the generated skills under bash AND zsh, the way
# Claude Code's Bash tool runs them: in the user's shell (zsh on macOS), with a
# new shell for each call. CI otherwise runs only bash, so a block that works in
# bash and breaks in zsh passes every other suite. That is how three skill
# blocks shipped broken: a bare-glob `ls` (zsh NOMATCH), an unquoted
# `for x in $VAR` (zsh does not word-split), and a packaging block that relied
# on a variable from an earlier call.
#
# Each skill block is extracted from skills/<name>/SKILL.md (what ships), its
# placeholders are filled in, and it runs in a scratch course project. The
# preamble blocks come from templates/preamble.md, with the resolve snippet
# spliced in as bin/idstack-gen-skills does. zsh runs with -f (no rc files),
# so default options such as NOMATCH apply.
set -u

. "$(dirname "$0")/test-helper.sh"

IDSTACK_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "test-skill-shell-zsh"

check "zsh is installed (CI installs it on Linux)" "command -v zsh"
command -v zsh >/dev/null 2>&1 || { echo ""; echo "Results: $PASS/$TOTAL passed, $FAIL failed"; exit 1; }

# A copy of the plugin, used as IDSTACK_HOME.
mkdir -p "$WORK/plugin"
cp -R "$IDSTACK_DIR/bin" "$IDSTACK_DIR/templates" "$IDSTACK_DIR/evidence" "$IDSTACK_DIR/VERSION" "$WORK/plugin/"
export IDSTACK_HOME="$WORK/plugin"
export HOME="$WORK/home"
mkdir -p "$HOME"

# block <skill> <marker> [placeholder=value ...]: print the first bash fence in
# skills/<skill>/SKILL.md that contains <marker>, with each placeholder replaced.
block() {
  python3 - "$IDSTACK_DIR/skills/$1/SKILL.md" "$2" "${@:3}" <<'PY'
import re, sys
text = open(sys.argv[1], encoding='utf-8').read()
for b in re.findall(r'```bash\n(.*?)```', text, re.S):
    if sys.argv[2] in b:
        for pair in sys.argv[3:]:
            k, v = pair.split('=', 1)
            assert k in b, 'placeholder %r not in block' % k
            b = b.replace(k, v)
        sys.stdout.write(b)
        sys.exit(0)
sys.exit('no bash block contains %r' % sys.argv[2])
PY
}

# Fake curl for the Canvas blocks: prints a JSON body and then the HTTP code
# on its own line, as `curl -s -w "\n%{http_code}"` does.
mkdir -p "$WORK/fakebin"
cat > "$WORK/fakebin/curl" <<'EOF'
#!/bin/sh
for a in "$@"; do
  case "$a" in
    "Authorization: Bearer secret-token-123") ok=1 ;;
  esac
done
[ "${ok:-0}" = 1 ] || { printf '{"error":"no token"}\n401'; exit 0; }
printf '{"id":42,"name":"Module 1"}\n200'
EOF
chmod +x "$WORK/fakebin/curl"

for sh in bash zsh; do
  run() { # run <dir> <script>: runs the script with this leg's shell in <dir>
    if [ "$sh" = zsh ]; then (cd "$1" && zsh -f -c "$2" 2>&1); else (cd "$1" && bash -c "$2" 2>&1); fi
  }
  P="$WORK/$sh"
  mkdir -p "$P"
  echo ""
  echo "--- $sh ---"

  # course-quality-review: file discovery finds .md files although no .docx exists.
  mkdir -p "$P/cqr" && touch "$P/cqr/week1.md"
  b=$(block course-quality-review 'NO_COURSE_FILES')
  out=$(run "$P/cqr" "$b")
  check "[$sh] course-quality-review finds week1.md with no .docx present" \
    "printf '%s' \"\$out\" | grep -q 'week1.md' && ! printf '%s' \"\$out\" | grep -q NO_COURSE_FILES"
  mkdir -p "$P/empty"
  out=$(run "$P/empty" "$b")
  check "[$sh] course-quality-review reports NO_COURSE_FILES in an empty folder" \
    "printf '%s' \"\$out\" | grep -q NO_COURSE_FILES"

  # course-import: the SCO loop reads every launch file, one per line.
  mkdir -p "$P/sco/m1" "$P/sco/m2"
  echo one > "$P/sco/m1/index.html"; echo two > "$P/sco/m2/index.html"
  b=$(block course-import 'sco_href' \
    "<IMPORT_DIR printed above>=$P/sco" \
    "<href of SCO 1>=m1/index.html" "<href of SCO 2>=m2/index.html")
  out=$(run "$P" "$b")
  check "[$sh] course-import reads both SCO launch files" \
    "[ \"\$(printf '%s' \"\$out\" | grep -c '=== SCO:')\" = 2 ]"

  # course-import: .docx text extraction.
  mkdir -p "$P/docx"
  python3 - "$P/docx/Course Plan.docx" <<'PY'
import sys, zipfile
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
doc = ('<w:document xmlns:w="%s"><w:body>'
       '<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Week 1</w:t></w:r></w:p>'
       '<w:p><w:r><w:t>Students will </w:t></w:r><w:r><w:t>analyze data.</w:t></w:r></w:p>'
       '</w:body></w:document>') % W
with zipfile.ZipFile(sys.argv[1], 'w') as z:
    z.writestr('word/document.xml', doc)
PY
  b=$(block course-import 'DOCX_PATH=' "<file path from the user>=Course Plan.docx")
  out=$(run "$P/docx" "$b")
  check "[$sh] course-import extracts .docx text with headings" \
    "grep -qx '## Week 1' '$P/docx/.idstack/import/Course Plan.txt' && grep -qx 'Students will analyze data.' '$P/docx/.idstack/import/Course Plan.txt'"

  # course-export: IMSCC staging, then packaging in a later, separate shell.
  mkdir -p "$P/exp/.idstack/exports/demo-course"
  b=$(block course-export 'mkdir -p "$_STAGE/modules"' "<export folder>=.idstack/exports/demo-course")
  run "$P/exp" "$b" >/dev/null
  echo '<manifest/>' > "$P/exp/.idstack/exports/demo-course/.imscc-staging/imsmanifest.xml"
  echo '<p>m1</p>' > "$P/exp/.idstack/exports/demo-course/.imscc-staging/modules/m1.html"
  b=$(block course-export 'course-export.imscc"' "<export folder>=.idstack/exports/demo-course")
  out=$(run "$P/exp" "$b")
  check "[$sh] course-export writes course-export.imscc into the export folder" \
    "unzip -l '$P/exp/.idstack/exports/demo-course/course-export.imscc' | grep -q imsmanifest.xml"
  check "[$sh] course-export removes the staging folder after packaging" \
    "[ ! -d '$P/exp/.idstack/exports/demo-course/.imscc-staging' ]"
  # A missing manifest must fail loudly and keep nothing half-made.
  mkdir -p "$P/exp2/.idstack/exports/demo-course/.imscc-staging"
  out=$(run "$P/exp2" "$b")
  check "[$sh] course-export reports PACKAGE_FAILED without imsmanifest.xml" \
    "printf '%s' \"\$out\" | grep -q PACKAGE_FAILED && ! printf '%s' \"\$out\" | grep -q 'Export saved'"

  # course-export: SCORM staging and packaging.
  b=$(block course-export 'mkdir -p "$_STAGE/content"' "<export folder>=.idstack/exports/demo-course")
  run "$P/exp" "$b" >/dev/null
  echo '<manifest/>' > "$P/exp/.idstack/exports/demo-course/.scorm-staging/imsmanifest.xml"
  echo '<p>m1</p>' > "$P/exp/.idstack/exports/demo-course/.scorm-staging/content/module-01.html"
  b=$(block course-export 'scorm-export.zip"' "<export folder>=.idstack/exports/demo-course")
  run "$P/exp" "$b" >/dev/null
  check "[$sh] course-export writes scorm-export.zip with the content folder" \
    "unzip -l '$P/exp/.idstack/exports/demo-course/scorm-export.zip' | grep -q content/module-01.html"

  # Canvas: settings file, then API blocks in later shells read it.
  mkdir -p "$P/canvas"
  b=$(block course-export "_TOKEN_LINE=" "<canvas url>=https://canvas.example.edu" "<course id>=123")
  run "$P/canvas" "$b" >/dev/null
  check "[$sh] Canvas settings file is private (mode 600)" \
    "ls -l '$P/canvas/.idstack/canvas.env' | grep -q '^-rw-------'"
  check "[$sh] Canvas settings file is git-ignored" \
    "grep -qx canvas.env '$P/canvas/.idstack/.gitignore'"
  # The user pastes the token between the quotes.
  sed "s/^CANVAS_TOKEN=''/CANVAS_TOKEN='secret-token-123'/" "$P/canvas/.idstack/canvas.env" > "$P/canvas/env.tmp" && mv "$P/canvas/env.tmp" "$P/canvas/.idstack/canvas.env"
  run "$P/canvas" "$(block course-export "_TOKEN_LINE=" "<canvas url>=https://canvas.example.edu" "<course id>=456")" >/dev/null
  check "[$sh] rewriting the Canvas settings keeps the token" \
    "grep -qx \"CANVAS_TOKEN='secret-token-123'\" '$P/canvas/.idstack/canvas.env'"
  b=$(block course-export 'module[name]=')
  out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas" "$b")
  check "[$sh] Canvas module block reads the token in a new shell and parses the id" \
    "printf '%s' \"\$out\" | grep -q 'HTTP: 200' && printf '%s' \"\$out\" | grep -qx 'MODULE_ID=42'"
  check "[$sh] Canvas module block does not print the token" \
    "! printf '%s' \"\$out\" | grep -q secret-token-123"
  mkdir -p "$P/canvas-none"
  out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas-none" "$(block course-import 'users/self')")
  check "[$sh] Canvas block stops with CANVAS_ENV_MISSING when there is no settings file" \
    "printf '%s' \"\$out\" | grep -q CANVAS_ENV_MISSING"

  # Report links: a real report block prints the relative path of the report.
  # An absolute path did not make a link in the Claude desktop app.
  mkdir -p "$P/links"
  b=$(block learning-objectives '_REPORT_PATH="$_EXPORT_DIR/learning-objectives.md"')
  out=$(run "$P/links" "$b")
  want="Report path: .idstack/exports/untitled-course/learning-objectives.md"
  check "[$sh] a report block prints a relative report path" \
    "printf '%s\n' \"\$out\" | grep -qxF \"\$want\" && [ -d '$P/links/.idstack/exports/untitled-course' ]"

  # Step Review: the real needs-analysis init block starts the report. Then the
  # check, append, approve and finish blocks of the preamble build it one
  # approved section at a time. Each block runs in a new shell, as the Bash tool runs it.
  mkdir -p "$P/rs/.idstack"
  RS_REPORT=.idstack/exports/bio-101/needs-analysis.md
  b=$(block needs-analysis 'idstack-report-section" init' "<project name>=Bio 101" "<mode>=design-new")
  out=$(run "$P/rs" "$b")
  check "[$sh] needs-analysis init block starts the report" \
    "printf '%s\n' \"\$out\" | grep -qxF 'REPORT_STARTED: $RS_REPORT' && grep -q '^# Needs Analysis Report' '$P/rs/$RS_REPORT'"
  cat > "$P/rs/.idstack/.report-section.md" <<'MD'
## Task analysis

| ID | Task | Priority | Justification | Evidence |
|----|------|----------|---------------|----------|
| T-1 | Write a lab report | High | Learners do this task each week. | [Needs-8] [T3] |
MD
  out=$(run "$P/rs" "$(block needs-analysis 'report-section" check .idstack')")
  check "[$sh] Step Review check block accepts a valid table" \
    "printf '%s\n' \"\$out\" | grep -qx CHECK_OK"
  b_append=$(block needs-analysis 'report-section" append' "<path>=$RS_REPORT")
  out=$(run "$P/rs" "$b_append")
  check "[$sh] Step Review append block adds the section as a draft and keeps the draft file" \
    "printf '%s\n' \"\$out\" | grep -qxF 'SECTION_ADDED: Task analysis' && grep -q '^| T-1 |' '$P/rs/$RS_REPORT' && grep -qF '**Draft:**' '$P/rs/$RS_REPORT' && [ -e '$P/rs/.idstack/.report-section.md' ]"
  check "[$sh] Step Review append block keeps the footer after the new section" \
    "tail -n 1 '$P/rs/$RS_REPORT' | grep -qF 'Generated by \`/idstack:needs-analysis\`' && awk '/^## Task analysis/{t=NR} /^---\$/{d=NR} END{exit !(t && d > t)}' '$P/rs/$RS_REPORT'"
  b_approve=$(block needs-analysis 'report-section" approve' "<path>=$RS_REPORT")
  out=$(run "$P/rs" "$b_approve")
  check "[$sh] Step Review approve block removes the draft mark and the draft file" \
    "printf '%s\n' \"\$out\" | grep -qxF 'SECTION_APPROVED: Task analysis' && ! grep -qF '**Draft:**' '$P/rs/$RS_REPORT' && [ ! -e '$P/rs/.idstack/.report-section.md' ]"
  # A tier that does not agree with evidence/references.md is refused, and the
  # report does not change.
  cp "$P/rs/$RS_REPORT" "$P/rs/before.md"
  cat > "$P/rs/.idstack/.report-section.md" <<'MD'
## Learner profile

| ID | Item | Justification | Evidence |
|----|------|---------------|----------|
| L-1 | Prior knowledge is low | Novices need worked examples. | [Needs-8] [T1] |
MD
  out=$(run "$P/rs" "$(block needs-analysis 'report-section" check .idstack')")
  check "[$sh] Step Review check block refuses a wrong tier" \
    "! printf '%s\n' \"\$out\" | grep -qx CHECK_OK && printf '%s\n' \"\$out\" | grep -q 'T3'"
  out=$(run "$P/rs" "$b_append")
  check "[$sh] Step Review append block refuses a wrong tier and keeps the report" \
    "! printf '%s\n' \"\$out\" | grep -q '^SECTION_' && cmp -s '$P/rs/before.md' '$P/rs/$RS_REPORT'"
  b_finish=$(block needs-analysis 'report-section" finish' "<path>=$RS_REPORT")
  out=$(run "$P/rs" "$b_finish")
  check "[$sh] Step Review finish block refuses a report with an empty Summary" \
    "printf '%s\n' \"\$out\" | grep -qF 'the section \"Summary\" has no text' && grep -q '^\*\*Status:\*\*' '$P/rs/$RS_REPORT'"
  cat > "$P/rs/.idstack/.report-section.md" <<'MD'
## Summary

The learners write lab reports each week. The course teaches this task first.
MD
  run "$P/rs" "$b_append" >/dev/null
  out=$(run "$P/rs" "$b_finish")
  check "[$sh] Step Review finish block refuses a draft section" \
    "printf '%s\n' \"\$out\" | grep -qF 'the section \"Summary\" is a draft' && grep -q '^\*\*Status:\*\*' '$P/rs/$RS_REPORT'"
  out=$(run "$P/rs" "$b_approve")
  check "[$sh] Step Review approve block approves the Summary" \
    "printf '%s\n' \"\$out\" | grep -qxF 'SECTION_APPROVED: Summary' && ! grep -qF '**Draft:**' '$P/rs/$RS_REPORT'"
  out=$(run "$P/rs" "$b_finish")
  check "[$sh] Step Review finish block completes the report" \
    "printf '%s\n' \"\$out\" | grep -qxF 'REPORT_COMPLETE: $RS_REPORT' && ! grep -q '^\*\*Status:\*\*' '$P/rs/$RS_REPORT'"

  # start: the setup check prints one machine-readable code.
  mkdir -p "$P/start"
  b=$(block start 'idstack-doctor" --quick')
  out=$(run "$P/start" "$b")
  check "[$sh] start setup check prints OK when python3 3.9 or later is present" \
    "printf '%s\n' \"\$out\" | grep -qx OK"

  # start: the folder check refuses the home folder, /, and the shared folders
  # a folder picker offers first; it accepts a course folder.
  mkdir -p "$HOME/Documents"
  b=$(block start 'NOT_A_COURSE_FOLDER')
  out=$(run "$HOME" "$b")
  check "[$sh] start refuses the home folder" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run / "$b")
  check "[$sh] start refuses /" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run "$HOME/Documents" "$b")
  check "[$sh] start refuses Documents" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  # The Claude desktop app can start a session in a temporary folder that it
  # made; course data there is hidden and can be deleted.
  scratch="$HOME/Library/Application Support/Claude/scratch-workspaces/a1b2/scratch-2026-11-02-630f71"
  mkdir -p "$scratch"
  out=$(run "$scratch" "$b")
  check "[$sh] start refuses a Claude app scratch workspace" \
    "printf '%s' \"\$out\" | grep -q '^NOT_A_COURSE_FOLDER: '"
  out=$(run "$P/start" "$b")
  check "[$sh] start accepts a course folder" \
    "printf '%s' \"\$out\" | grep -q '^COURSE_FOLDER: '"

  # start: with no dashboard, the dashboard step lists each report instead.
  mkdir -p "$P/startdash/.idstack/exports/untitled-course"
  touch "$P/startdash/.idstack/exports/untitled-course/course-import.md"
  b=$(block start 'NO_DASHBOARD')
  out=$(run "$P/startdash" "$b")
  want="Report path: .idstack/exports/untitled-course/course-import.md"
  check "[$sh] start lists the report paths when there is no dashboard" \
    "printf '%s\n' \"\$out\" | grep -qx NO_DASHBOARD && printf '%s\n' \"\$out\" | grep -qxF \"\$want\""

  # start: the dashboard is a .md file too, so the age check must not count
  # index.md as a report that is newer than itself.
  touch -t 202601010000 "$P/startdash/.idstack/exports/untitled-course/course-import.md"
  touch -t 202601020000 "$P/startdash/.idstack/exports/untitled-course/index.md"
  out=$(run "$P/startdash" "$b")
  check "[$sh] start gives the relative dashboard path and no DASHBOARD_OLD when the dashboard is current" \
    "printf '%s\n' \"\$out\" | grep -qxF 'Dashboard path: .idstack/exports/untitled-course/index.md' && ! printf '%s\n' \"\$out\" | grep -qx DASHBOARD_OLD"
  touch -t 202601030000 "$P/startdash/.idstack/exports/untitled-course/course-import.md"
  out=$(run "$P/startdash" "$b")
  check "[$sh] start prints DASHBOARD_OLD when a report is newer than the dashboard" \
    "printf '%s\n' \"\$out\" | grep -qx DASHBOARD_OLD"

  # Every preamble block exits 0 and prints the same output in both shells.
  mkdir -p "$P/pre/.idstack"
  printf '%s\n' '{"ts":"2026-08-04T00:00:00Z","skill":"needs-analysis","event":"completed"}' > "$P/pre/.idstack/timeline.jsonl"
  # The preamble carries {{IDSTACK_RESOLVE}} placeholders; splice the snippet in
  # as bin/idstack-gen-skills does, so each block runs as a skill sees it.
  awk -v snip="$IDSTACK_DIR/templates/snippets/idstack-resolve.sh" '
    /^```bash$/{f=1; n++; next} f && /^```$/{f=0}
    f && /\{\{IDSTACK_RESOLVE\}\}/{while ((getline l < snip) > 0) print l > ("'"$P"'/pre/block" n ".sh"); close(snip); next}
    f{print > ("'"$P"'/pre/block" n ".sh")}' "$IDSTACK_DIR/templates/preamble.md"
  # The Step Review blocks need a report and a draft. The tests above run them.
  for f in "$P"/pre/block*.sh; do grep -q 'idstack-report-section' "$f" && rm -f "$f"; done
  for f in "$P"/pre/block*.sh; do
    out=$(run "$P/pre" "$(cat "$f")"); rc=$?
    printf '%s' "$out" > "$f.$sh.out"
    check "[$sh] preamble $(basename "$f" .sh) exits 0 without shell errors" \
      "[ $rc = 0 ] && ! grep -qE '(zsh|bash): ' '$f.$sh.out'"
  done
done

for f in "$WORK"/zsh/pre/block*.sh; do
  b=$(basename "$f")
  check "preamble ${b%.sh} prints the same in bash and zsh" \
    "diff '$WORK/bash/pre/$b.bash.out' '$f.zsh.out'"
done

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
