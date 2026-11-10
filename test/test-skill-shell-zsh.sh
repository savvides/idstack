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
# preamble blocks come from templates/preamble.md, with the whole resolve
# snippet spliced in (bin/idstack-gen-skills also leaves out the snippet's
# comment lines, which does not change what runs). zsh runs with -f (no rc files),
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
# on its own line, as `curl -s -w "\n%{http_code}"` does. It takes the token
# only from a config on stdin (`-K -`): a token in argv shows in `ps`. It logs
# its argv to $CURL_LOG and the text of each `name@file` field to $CURL_LOG.data.
mkdir -p "$WORK/fakebin"
export CURL_LOG="$WORK/curl.log"
cat > "$WORK/fakebin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$CURL_LOG"
prev= cfg=
for a in "$@"; do
  [ "$prev" = -K ] && [ "$a" = - ] && cfg=$(cat)
  case "$prev:$a" in --data-urlencode:*@*) cat "${a#*@}" >> "$CURL_LOG.data"; echo >> "$CURL_LOG.data" ;; esac
  prev=$a
done
case "$cfg" in *'header = "Authorization: Bearer secret-token-123"'*) ;; *) printf '{"error":"no token"}\n401'; exit 0 ;; esac
printf '{"id":42,"name":"Module 1"}\n200'
EOF
chmod +x "$WORK/fakebin/curl"
# Text with characters that the shell changes when it is put in a command.
HOSTILE='Q&A and Review+Practice: $HOME costs $50, `touch pwned` $(touch pwned) it'"'"'s "done"'

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
  # The hrefs come from an untrusted imsmanifest.xml: no shell expansion, and
  # no file outside the import folder.
  echo top-secret > "$P/secret.txt"
  mkdir -p "$P/scohost"
  b=$(block course-import 'sco_href' \
    "<IMPORT_DIR printed above>=$P/sco" \
    "<href of SCO 1>=../secret.txt" "<href of SCO 2>=$P/secret.txt
a.html'\$(touch pwned)'\`touch pwned\`
m1/index.html")
  out=$(run "$P/scohost" "$b")
  check "[$sh] course-import SCO loop skips '..' and absolute hrefs" \
    "! printf '%s' \"\$out\" | grep -q top-secret && [ \"\$(printf '%s\n' \"\$out\" | grep -c '^SCO_HREF_SKIPPED: ')\" = 2 ] && printf '%s' \"\$out\" | grep -qx one"
  check "[$sh] course-import SCO hrefs do not run commands" "[ ! -e '$P/scohost/pwned' ]"
  # A package can hold symlinks (Info-ZIP restores them): a symlinked file or
  # folder must not let the loop read a file outside the import folder.
  mkdir -p "$P/scolnk/ok" && echo three > "$P/scolnk/ok/index.html"
  ln -s "$P" "$P/scolnk/up"; ln -s "$P/secret.txt" "$P/scolnk/ok/leak.html"
  b=$(block course-import 'sco_href' \
    "<IMPORT_DIR printed above>=$P/scolnk" \
    "<href of SCO 1>=up/secret.txt" "<href of SCO 2>=ok/leak.html
ok/index.html")
  out=$(run "$P" "$b")
  check "[$sh] course-import SCO loop skips symlinked files and folders" \
    "! printf '%s' \"\$out\" | grep -q top-secret && [ \"\$(printf '%s\n' \"\$out\" | grep -c '^SCO_HREF_SKIPPED: ')\" = 2 ] && printf '%s' \"\$out\" | grep -qx three"

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
  b=$(block course-import 'read -r DOCX_PATH' "<file path from the user>=Course Plan.docx")
  out=$(run "$P/docx" "$b")
  check "[$sh] course-import extracts .docx text with headings" \
    "grep -qx '## Week 1' '$P/docx/.idstack/import/Course Plan.txt' && grep -qx 'Students will analyze data.' '$P/docx/.idstack/import/Course Plan.txt'"
  # A file name is not trusted: the shell must not run a command in it.
  cp "$P/docx/Course Plan.docx" "$P/docx/Bio\$(touch pwned).docx"
  b=$(block course-import 'read -r DOCX_PATH' "<file path from the user>=Bio\$(touch pwned).docx")
  out=$(run "$P/docx" "$b")
  check "[$sh] course-import does not run a command in a file name" \
    "[ ! -e '$P/docx/pwned' ] && grep -qx '## Week 1' '$P/docx/.idstack/import/Bio\$(touch pwned).txt'"

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
  # A .gitignore with no newline at the end: the new line must not join the last one.
  for s in course-export course-import; do
    for last in 'exports/' 'canvas.env'; do
      d="$P/gi-$s-${last%[./]*}"
      mkdir -p "$d/.idstack" && (cd "$d" && git init -q) && printf '%s' "$last" > "$d/.idstack/.gitignore"
      run "$d" "$(block $s "_TOKEN_LINE=" "<canvas url>=https://canvas.example.edu" "<course id>=123")" >/dev/null
      check "[$sh] $s git-ignores canvas.env after a .gitignore that ends in '$last' with no newline" \
        "(cd '$d' && git check-ignore -q .idstack/canvas.env && git check-ignore -q .idstack/$last)"
      [ $s = course-export ] && check "[$sh] course-export git-ignores canvas-push/ after '$last' with no newline" \
        "(cd '$d' && git check-ignore -q .idstack/canvas-push/x)"
    done
  done
  # The token must not go over plain http.
  for s in course-export course-import; do
    for u in http://canvas.example.edu canvas.example.edu; do
      mkdir -p "$P/canvas-http"
      out=$(run "$P/canvas-http" "$(block $s "_TOKEN_LINE=" "<canvas url>=$u" "<course id>=123")")
      check "[$sh] $s Canvas settings refuse $u" \
        "printf '%s' \"\$out\" | grep -q '^CANVAS_URL_NOT_HTTPS' && [ ! -e '$P/canvas-http/.idstack/canvas.env' ]"
    done
  done
  # The user pastes the token between the quotes.
  sed "s/^CANVAS_TOKEN=''/CANVAS_TOKEN='secret-token-123'/" "$P/canvas/.idstack/canvas.env" > "$P/canvas/env.tmp" && mv "$P/canvas/env.tmp" "$P/canvas/.idstack/canvas.env"
  run "$P/canvas" "$(block course-export "_TOKEN_LINE=" "<canvas url>=https://canvas.example.edu" "<course id>=456")" >/dev/null
  check "[$sh] rewriting the Canvas settings keeps the token" \
    "grep -qx \"CANVAS_TOKEN='secret-token-123'\" '$P/canvas/.idstack/canvas.env'"
  b=$(block course-export 'module[name]@')
  rm -f "$CURL_LOG" "$CURL_LOG.data"
  mkdir -p "$P/canvas/.idstack/canvas-push"
  printf '%s' "$HOSTILE" > "$P/canvas/.idstack/canvas-push/title.txt"
  out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas" "$b")
  check "[$sh] Canvas module block reads the token in a new shell and parses the id" \
    "printf '%s' \"\$out\" | grep -q 'HTTP: 200' && printf '%s' \"\$out\" | grep -qx 'MODULE_ID=42'"
  check "[$sh] Canvas module block does not print the token" \
    "! printf '%s' \"\$out\" | grep -q secret-token-123"
  check "[$sh] Canvas module block keeps the token out of curl's argv" \
    "[ -s '$CURL_LOG' ] && ! grep -q secret-token-123 '$CURL_LOG'"
  check "[$sh] Canvas module block sends the title unchanged and deletes the push files" \
    "[ \"\$(cat '$CURL_LOG.data')\" = \"\$HOSTILE\" ] && [ ! -e '$P/canvas/.idstack/canvas-push' ] && [ ! -e '$P/canvas/pwned' ]"
  # Page: the title and the HTML body go from files, unchanged.
  rm -f "$CURL_LOG" "$CURL_LOG.data"
  mkdir -p "$P/canvas/.idstack/canvas-push"
  printf '%s' "$HOSTILE" > "$P/canvas/.idstack/canvas-push/title.txt"
  printf '<p>%s</p>' "$HOSTILE" > "$P/canvas/.idstack/canvas-push/body.html"
  out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas" "$(block course-export 'wiki_page[body]@')")
  check "[$sh] Canvas page block sends the title and body unchanged" \
    "printf '%s' \"\$out\" | grep -q 'HTTP: 200' && [ \"\$(cat '$CURL_LOG.data')\" = \"\$(printf '%s\n<p>%s</p>' \"\$HOSTILE\" \"\$HOSTILE\")\" ] && [ ! -e '$P/canvas/pwned' ]"
  out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas" "$(block course-export 'wiki_page[body]@')")
  check "[$sh] Canvas page block stops with PUSH_FILE_MISSING when the files are not there" \
    "printf '%s' \"\$out\" | grep -qx PUSH_FILE_MISSING && ! printf '%s' \"\$out\" | grep -q 'HTTP:'"
  # A settings file from an older idstack can have an http URL.
  sed "s|^CANVAS_BASE_URL=.*|CANVAS_BASE_URL='http://canvas.example.edu'|" "$P/canvas/.idstack/canvas.env" > "$P/canvas/old.env"
  mkdir -p "$P/canvas-old/.idstack" && mv "$P/canvas/old.env" "$P/canvas-old/.idstack/canvas.env"
  rm -f "$CURL_LOG"
  out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas-old" "$(block course-export 'users/self')")
  check "[$sh] Canvas validate block refuses an http URL and does not run curl" \
    "printf '%s' \"\$out\" | grep -q '^CANVAS_URL_NOT_HTTPS' && [ ! -e '$CURL_LOG' ]"
  # A token with a quotation mark or a backslash would break the curl config
  # line that carries it, so the validate blocks refuse it before curl runs.
  for bad in 'tok"en' 'tok\en'; do
    mkdir -p "$P/canvas-badtok/.idstack"
    BAD="$bad" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace("CANVAS_TOKEN='"'"'secret-token-123'"'"'", "CANVAS_TOKEN='"'"'"+os.environ["BAD"]+"'"'"'"))' \
      "$P/canvas/.idstack/canvas.env" "$P/canvas-badtok/.idstack/canvas.env"
    for s in course-import course-export; do
      rm -f "$CURL_LOG"
      out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas-badtok" "$(block $s 'users/self')")
      check "[$sh] $s refuses a Canvas token that has $bad in it, before curl runs" \
        "printf '%s' \"\$out\" | grep -q '^CANVAS_TOKEN_BAD' && [ ! -e '$CURL_LOG' ]"
    done
  done
  mkdir -p "$P/canvas-none"
  out=$(PATH="$WORK/fakebin:$PATH" run "$P/canvas-none" "$(block course-import 'users/self')")
  check "[$sh] Canvas block stops with CANVAS_ENV_MISSING when there is no settings file" \
    "printf '%s' \"\$out\" | grep -q CANVAS_ENV_MISSING"

  # Learnings and timeline events: model text with an apostrophe, quotes, $
  # and backticks reaches the log unchanged.
  INSIGHT='LMS doesn'"'"'t keep \"rubrics\" at $50 or `id` $(id)'
  for s in needs-analysis learning-objectives assessment-design course-builder course-quality-review accessibility-review red-team course-export course-import; do
    mkdir -p "$P/learn-$s"
    out=$(run "$P/learn-$s" "$(block $s 'idstack-learnings" log' "DESCRIPTION=$INSIGHT")")
    check "[$sh] $s logs a learning with an apostrophe unchanged" \
      "python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).read().splitlines()[-1]); sys.exit(r[\"insight\"]!=sys.argv[2])' '$P/learn-$s/.idstack/learnings.jsonl' \"\$(printf '%s' \"\$INSIGHT\" | sed 's/\\\\\"/\"/g')\""
  done
  # A learning that the model writes on two lines is logged whole, not cut at
  # the first line.
  mkdir -p "$P/learn-multi"
  out=$(run "$P/learn-multi" "$(block needs-analysis 'idstack-learnings" log' '"source":"observed"}="source":"observed"
}')")
  check "[$sh] a learning on two lines is logged whole" \
    "python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).read().splitlines()[-1]); sys.exit(r.get(\"source\")!=\"observed\")' '$P/learn-multi/.idstack/learnings.jsonl'"
  # learn: the keyword and the key are user text: whole phrase, no command runs.
  mkdir -p "$P/lrn"
  PHRASE='rubric design $(touch pwned)'
  for kv in "hit|use $PHRASE early" "miss|rubric only" "$PHRASE|gone"; do
    (cd "$P/lrn" && "$IDSTACK_HOME/bin/idstack-learnings" log "$(python3 -c 'import json,sys; k,i=sys.argv[1].split("|"); print(json.dumps({"skill":"learn","type":"operational","key":k,"insight":i,"confidence":8,"source":"observed"}))' "$kv")")
  done
  out=$(run "$P/lrn" "$(block learn 'search --keyword "$_KEYWORD" --limit' "<keyword>=$PHRASE")")
  check "[$sh] learn searches the whole keyword phrase" \
    "printf '%s' \"\$out\" | grep -q '\"hit\"' && ! printf '%s' \"\$out\" | grep -q '\"miss\"'"
  run "$P/lrn" "$(block learn 'delete "$_KEY"' "<key>=$PHRASE")" >/dev/null
  check "[$sh] learn deletes a key with a space and \$( )" "! grep -qF '\"gone\"' '$P/lrn/.idstack/learnings.jsonl'"
  check "[$sh] learn keyword and key do not run commands" "[ ! -e '$P/lrn/pwned' ]"
  mkdir -p "$P/tl"
  out=$(run "$P/tl" "$(block red-team 'idstack-timeline-log' '"event":"completed"="event":"completed","focus":"learner'"'"'s view"')")
  check "[$sh] a timeline event with an apostrophe is logged" \
    "grep -qF '\"focus\": \"learner'\"'\"'s view\"' '$P/tl/.idstack/timeline.jsonl' || grep -qF '\"focus\":\"learner'\"'\"'s view\"' '$P/tl/.idstack/timeline.jsonl'"

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
  # (comments included, which gen-skills leaves out), so each block runs the
  # commands a skill runs.
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
