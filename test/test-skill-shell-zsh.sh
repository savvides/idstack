#!/usr/bin/env bash
# Runs real bash blocks from the generated skills under bash AND zsh, the way
# Claude Code's Bash tool runs them: in the user's shell (zsh on macOS), with a
# new shell for each call. CI otherwise runs only bash, so a block that works in
# bash and breaks in zsh passes every other suite. That is how three skill
# blocks shipped broken: a bare-glob `ls` (zsh NOMATCH), an unquoted
# `for x in $VAR` (zsh does not word-split), and a packaging block that relied
# on a variable from an earlier call.
#
# Each block is extracted from skills/<name>/SKILL.md (what ships), its
# placeholders are filled in, and it runs in a scratch course project. zsh runs
# with -f (no rc files), so default options such as NOMATCH apply.
set -u

. "$(dirname "$0")/test-helper.sh"

IDSTACK_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "test-skill-shell-zsh"

check "zsh is installed (CI installs it on Linux)" "command -v zsh"
command -v zsh >/dev/null 2>&1 || { echo ""; echo "Results: $PASS/$TOTAL passed, $FAIL failed"; exit 1; }

# A copy of the plugin without .git, so the update check makes no network call.
mkdir -p "$WORK/plugin"
cp -R "$IDSTACK_DIR/bin" "$IDSTACK_DIR/templates" "$IDSTACK_DIR/VERSION" "$WORK/plugin/"
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

  # Every preamble block exits 0 and prints the same output in both shells.
  mkdir -p "$P/pre/.idstack"
  printf '%s\n' '{"ts":"2026-08-04T00:00:00Z","skill":"needs-analysis","event":"completed"}' > "$P/pre/.idstack/timeline.jsonl"
  awk '/^```bash$/{f=1; n++; next} f && /^```$/{f=0} f{print > ("'"$P"'/pre/block" n ".sh")}' "$IDSTACK_DIR/templates/preamble.md"
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
