#!/usr/bin/env bash
# idstack integration tests — behavioral tests for bin scripts
set -e

. "$(dirname "$0")/test-helper.sh"

IDSTACK_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
TEST_DIR=$(mktemp -d)
# Single-quoted so expansion happens at trap time and a path with spaces survives.
trap 'rm -rf "$TEST_DIR"' EXIT

# Snapshot the working-tree state so the suite can prove it mutated nothing —
# compared before/after rather than against a clean tree, so a developer's own
# uncommitted work doesn't trip the check.
TREE_BEFORE=$(git -C "$IDSTACK_DIR" status --porcelain 2>/dev/null || true)

echo "idstack integration tests"
echo "  test dir: $TEST_DIR"
echo ""

cd "$TEST_DIR"

# --- idstack-timeline-log ---
echo "## idstack-timeline-log"

check "creates .idstack/ and timeline.jsonl" \
  "$IDSTACK_DIR/bin/idstack-timeline-log '{\"skill\":\"test\",\"event\":\"completed\",\"score\":72}' && [ -f .idstack/timeline.jsonl ]"

check "appends valid JSON with ts field" \
  "python3 -c \"import json; d=json.loads(open('.idstack/timeline.jsonl').readline()); assert 'ts' in d and d['skill']=='test'\""

check "preserves caller-supplied ts field" \
  "$IDSTACK_DIR/bin/idstack-timeline-log '{\"skill\":\"test\",\"ts\":\"2020-01-01T00:00:00Z\"}' && grep -q '\"ts\": \"2020-01-01T00:00:00Z\"' .idstack/timeline.jsonl"

check "handles invalid JSON gracefully" \
  "$IDSTACK_DIR/bin/idstack-timeline-log '{\"skill\":\"bad\",}' && grep -q '\"raw\": \"{\\\\\\\"skill\\\\\\\":\\\\\\\"bad\\\\\\\",}\"' .idstack/timeline.jsonl"

check "fallback to bash works when python3 is missing" \
  "mkdir -p mockbin && for cmd in bash sed date mkdir env tr wc grep echo cat ls rm pwd dirname chmod; do ln -s \$(which \$cmd) mockbin/\$cmd 2>/dev/null || true; done && PATH=\"\$PWD/mockbin\" $IDSTACK_DIR/bin/idstack-timeline-log '{\"skill\":\"no_py\"}' && grep -q '\"skill\":\"no_py\",\"ts\":' .idstack/timeline.jsonl"

check "handles empty arg without error" \
  "$IDSTACK_DIR/bin/idstack-timeline-log ''"

check "handles no arg without error" \
  "$IDSTACK_DIR/bin/idstack-timeline-log"

# Exact count, not `-gt 1`. Every preceding write in this section contributes a
# line (5 by here); a loose comparison still passes when four of the five are
# lost, which is the regression this assertion exists to catch.
check "multiple appends create exactly one line each" \
  "$IDSTACK_DIR/bin/idstack-timeline-log '{\"skill\":\"second\",\"event\":\"completed\"}' && [ \$(wc -l < .idstack/timeline.jsonl | tr -d ' ') -eq 5 ]"

echo ""

# --- idstack-learnings-log ---
echo "## idstack-learnings-log"

check "creates learnings.jsonl" \
  "$IDSTACK_DIR/bin/idstack-learnings-log '{\"skill\":\"import\",\"type\":\"operational\",\"key\":\"test\",\"insight\":\"test insight\",\"confidence\":8}' && [ -f .idstack/learnings.jsonl ]"

check "appends valid JSON with ts field" \
  "python3 -c \"import json; d=json.loads(open('.idstack/learnings.jsonl').readline()); assert 'ts' in d and d['type']=='operational'\""

check "handles empty arg without error" \
  "$IDSTACK_DIR/bin/idstack-learnings-log ''"

echo ""

# --- idstack-learnings-search ---
echo "## idstack-learnings-search"

# Add a second learning of different type
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"review","type":"pattern","key":"test2","insight":"pattern insight","confidence":7}'

# Add more learnings to test keyword search
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"export","type":"technical","key":"canvas_export","insight":"Canvas requires specific API tokens","confidence":9}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"review","type":"pattern","key":"rubric_design","insight":"Rubrics should be simple","confidence":8}'

check "returns results with --limit" \
  "[ \$($IDSTACK_DIR/bin/idstack-learnings-search --limit 1 | wc -l | tr -d ' ') -eq 1 ]"

check "returns all when limit exceeds count" \
  "[ \$($IDSTACK_DIR/bin/idstack-learnings-search --limit 99 | wc -l | tr -d ' ') -eq 4 ]"

check "filters by --type" \
  "$IDSTACK_DIR/bin/idstack-learnings-search --limit 10 --type operational | python3 -c \"import json,sys; d=json.loads(sys.stdin.readline()); assert d['type']=='operational'\""

check "filters by --keyword (hit)" \
  "$IDSTACK_DIR/bin/idstack-learnings-search --keyword canvas | grep -q 'canvas_export'"

check "filters by --keyword (case insensitive)" \
  "$IDSTACK_DIR/bin/idstack-learnings-search --keyword RuBrIc | grep -q 'rubric_design'"

check "filters by --keyword (miss)" \
  "[ -z \"\$($IDSTACK_DIR/bin/idstack-learnings-search --keyword nonexistent_string)\" ]"

# Setup fake home and global learnings
mkdir -p "$TEST_DIR/fake_home/.idstack/global"
echo '{"skill":"import","type":"technical","key":"global_canvas","insight":"Global canvas insight","confidence":5}' > "$TEST_DIR/fake_home/.idstack/global/learnings.jsonl"

check "cross-project includes global learnings" \
  "HOME=\"$TEST_DIR/fake_home\" $IDSTACK_DIR/bin/idstack-learnings-search --cross-project --keyword global_canvas | grep -q '\"_source\": \"global\"'"

check "without cross-project excludes global learnings" \
  "[ -z \"\$(HOME=\"$TEST_DIR/fake_home\" $IDSTACK_DIR/bin/idstack-learnings-search --keyword global_canvas)\" ]"

# Setup multi-entry cross-project precedence test
mkdir -p "$TEST_DIR/fake_home/.idstack/global"
cat > "$TEST_DIR/fake_home/.idstack/global/learnings.jsonl" <<'EOF'
{"skill":"review","type":"pattern","key":"g1","insight":"prec_test global 1","confidence":5}
{"skill":"review","type":"pattern","key":"g2","insight":"prec_test global 2","confidence":6}
EOF
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"review","type":"pattern","key":"l1","insight":"prec_test local 1","confidence":8}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"review","type":"pattern","key":"l2","insight":"prec_test local 2","confidence":9}'

check "cross-project: local learnings outrank global learnings on limit truncation" \
  "python3 -c \"
import subprocess, json
out = subprocess.check_output(['$IDSTACK_DIR/bin/idstack-learnings-search', '--cross-project', '--keyword', 'prec_test', '--limit', '2'], env={'HOME': '$TEST_DIR/fake_home', 'PATH': '$PATH'}).decode()
keys = [json.loads(line)['key'] for line in out.strip().splitlines() if line.strip()]
assert keys == ['l1', 'l2'], f'Expected local keys [l1, l2], got {keys}'
\""

# --- grep fallback (python3 absent) ---
# Both call sites share one search_fallback function. Nothing exercised this
# path before, so the dedupe that created the function was unverifiable. Drive
# it by putting a PATH in front that has no python3.
mkdir -p "$TEST_DIR/nopy"
for _c in bash sh cat grep tail sed tr wc mkdir date env dirname ls rm pwd chmod; do
  ln -sf "$(command -v $_c)" "$TEST_DIR/nopy/$_c" 2>/dev/null || true
done

check "cross-project: local learnings take precedence in fallback mode" \
  "python3 -c \"
import subprocess, json
out = subprocess.check_output(['$IDSTACK_DIR/bin/idstack-learnings-search', '--cross-project', '--keyword', 'prec_test', '--limit', '2'], env={'HOME': '$TEST_DIR/fake_home', 'PATH': '$TEST_DIR/nopy'}).decode()
keys = [json.loads(line)['key'] for line in out.strip().splitlines() if line.strip()]
assert keys == ['l1', 'l2'], f'Expected fallback local keys [l1, l2], got {keys}'
\""

check "fallback: --keyword matches when python3 is absent" \
  "PATH=\"$TEST_DIR/nopy\" $IDSTACK_DIR/bin/idstack-learnings-search --keyword canvas | grep -q 'canvas_export'"

check "fallback: --type matches when python3 is absent" \
  "PATH=\"$TEST_DIR/nopy\" $IDSTACK_DIR/bin/idstack-learnings-search --type technical | grep -q 'canvas_export'"

check "fallback: bare search respects --limit when python3 is absent" \
  "[ \$(PATH=\"$TEST_DIR/nopy\" $IDSTACK_DIR/bin/idstack-learnings-search --limit 2 | wc -l | tr -d ' ') -eq 2 ]"

# A keyword starting with '-' is why the fallback greps use `--`. Without it
# grep reads the keyword as an option bundle and errors instead of matching.
check "fallback: leading-dash keyword is not read as a grep option" \
  "! PATH=\"$TEST_DIR/nopy\" $IDSTACK_DIR/bin/idstack-learnings-search --keyword -canvas 2>&1 | grep -qiE 'illegal option|invalid option|unrecognized option'"

check "no file returns empty" \
  "rm -f .idstack/learnings.jsonl && [ -z \"\$($IDSTACK_DIR/bin/idstack-learnings-search --limit 3)\" ]"

echo ""

# --- idstack-status ---
echo "## idstack-status"

check "no timeline shows empty state message" \
  "rm -f .idstack/timeline.jsonl && $IDSTACK_DIR/bin/idstack-status | grep -q 'No course data yet'"

# Rebuild timeline for status tests
$IDSTACK_DIR/bin/idstack-timeline-log '{"skill":"needs-analysis","event":"completed","training_justified":true}'
$IDSTACK_DIR/bin/idstack-timeline-log '{"skill":"course-quality-review","event":"completed","score":65,"dimensions":{"teaching_presence":7,"social_presence":3,"cognitive_presence":5}}'

check "shows skills completed checkboxes (namespaced)" \
  "$IDSTACK_DIR/bin/idstack-status | grep -q '\[x\] /idstack:needs-analysis'"

check "shows quality trend" \
  "$IDSTACK_DIR/bin/idstack-status | grep -q 'Quality trend: 65'"

check "suggests next skill" \
  "$IDSTACK_DIR/bin/idstack-status | grep -q 'Suggested next'"

# Quote-injection regression: a project name with an apostrophe must render,
# not blank the dashboard with a Python SyntaxError.
cat > .idstack/project.json <<'EOF'
{"version": "1.4", "project_name": "Bob's Advanced Course"}
EOF

check "apostrophe in project name renders" \
  "'$IDSTACK_DIR/bin/idstack-status' | grep -qF \"Project: Bob's Advanced Course\""

check "apostrophe in project name: no 'Error reading timeline'" \
  "! '$IDSTACK_DIR/bin/idstack-status' | grep -q 'Error reading timeline'"

# course-import is an alternative pipeline entry: with only course-import
# completed, the suggestion must be learning-objectives, not nothing.
mkdir -p importcase && ( cd importcase && \
  "$IDSTACK_DIR/bin/idstack-timeline-log" '{"skill":"course-import","event":"completed"}' )
check "course-import alone suggests learning-objectives" \
  "( cd importcase && '$IDSTACK_DIR/bin/idstack-status' | grep -q 'Suggested next: /idstack:learning-objectives' )"

# Everything idstack-status prints is text a user may type back. It must carry
# the /idstack: prefix for the same reason skill templates do — a bare /skill
# is not a valid command in either CLI.
check "idstack-status never prints a bare /skill command" \
  "! '$IDSTACK_DIR/bin/idstack-status' | grep -Eq '(^|[^:])/(needs-analysis|learning-objectives|assessment-design|course-builder|course-quality-review|accessibility-review|red-team|course-export|course-import|pipeline)\b'"

rm -f .idstack/project.json

echo ""

# --- idstack-gen-skills ---
# The staleness test mutates a generated SKILL.md, so it runs against a
# disposable copy of the repo under $TEST_DIR — never against the real tree
# (an interrupted run used to leave the working tree dirty).
echo "## idstack-gen-skills"

check "dry-run passes when fresh" \
  "'$IDSTACK_DIR/bin/idstack-gen-skills' --dry-run"

SANDBOX="$TEST_DIR/repo"
mkdir -p "$SANDBOX"
cp -R "$IDSTACK_DIR/bin" "$IDSTACK_DIR/skills" "$IDSTACK_DIR/templates" "$SANDBOX/"

check "dry-run detects stale SKILL.md (sandbox)" \
  "echo 'stale content' >> '$SANDBOX/skills/needs-analysis/SKILL.md' && ! '$SANDBOX/bin/idstack-gen-skills' --dry-run"

check "regenerate fixes staleness (sandbox)" \
  "'$SANDBOX/bin/idstack-gen-skills' && '$SANDBOX/bin/idstack-gen-skills' --dry-run"

# A template missing {{PREAMBLE}} must be an error, not a silent SKIP that
# lets --dry-run pass green over an absent or stale output.
check "missing {{PREAMBLE}} placeholder fails dry-run and generation (sandbox)" \
  "sed -i.bak 's/{{PREAMBLE}}/PREAMBLE_GONE/' '$SANDBOX/skills/learn/SKILL.md.tmpl' && ! '$SANDBOX/bin/idstack-gen-skills' --dry-run && ! '$SANDBOX/bin/idstack-gen-skills'"

check "real tree untouched by this suite" \
  "[ \"\$(git -C '$IDSTACK_DIR' status --porcelain 2>/dev/null || true)\" = \"\$TREE_BEFORE\" ]"

echo ""

# --- idstack-learnings-delete ---
echo "## idstack-learnings-delete"

check "returns error if no arguments provided" \
  "! $IDSTACK_DIR/bin/idstack-learnings-delete"

check "returns error if no file exists" \
  "rm -f .idstack/learnings.jsonl && ! $IDSTACK_DIR/bin/idstack-learnings-delete somekey"

# Setup data for delete tests
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key1","insight":"one"}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key2","insight":"two"}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key1","insight":"three"}'
$IDSTACK_DIR/bin/idstack-learnings-log '{"skill":"test","type":"fact","key":"key3_mode","insight":"four"}'
chmod 600 .idstack/learnings.jsonl

check "preserves file mode on delete (mode 600)" \
  "$IDSTACK_DIR/bin/idstack-learnings-delete key3_mode && python3 -c \"import os, stat; m = stat.S_IMODE(os.stat('.idstack/learnings.jsonl').st_mode); assert oct(m) == oct(0o600), f'Expected 0o600, got {oct(m)}'\""

check "returns error if key not found" \
  "! $IDSTACK_DIR/bin/idstack-learnings-delete missingkey"

check "deletes the most recent entry with the key when there are duplicates" \
  "$IDSTACK_DIR/bin/idstack-learnings-delete key1 && python3 -c \"import json,sys; lines=[json.loads(l) for l in open('.idstack/learnings.jsonl')]; assert len(lines)==2 and lines[0]['key']=='key1' and lines[0]['insight']=='one' and lines[1]['key']=='key2'\""

check "deletes a specific learning" \
  "$IDSTACK_DIR/bin/idstack-learnings-delete key2 && python3 -c \"import json,sys; lines=[json.loads(l) for l in open('.idstack/learnings.jsonl')]; assert len(lines)==1 and lines[0]['key']=='key1'\""

echo ""
# --- idstack-learnings-promote ---
echo "## idstack-learnings-promote"

FAKE_HOME="$TEST_DIR/fake_home"
mkdir -p "$FAKE_HOME"

check "fails if no key provided" \
  "! $IDSTACK_DIR/bin/idstack-learnings-promote"

check "fails if no local learnings found" \
  "rm -f .idstack/learnings.jsonl && ! $IDSTACK_DIR/bin/idstack-learnings-promote my-key"

mkdir -p .idstack
echo '{"skill":"test-skill","key":"my-key","type":"pattern","insight":"hello"}' > .idstack/learnings.jsonl

check "fails if key not found" \
  "! $IDSTACK_DIR/bin/idstack-learnings-promote wrong-key"

check "promotes learning with unknown project" \
  "HOME=\"$FAKE_HOME\" $IDSTACK_DIR/bin/idstack-learnings-promote my-key && [ -f \"$FAKE_HOME/.idstack/global/learnings.jsonl\" ] && python3 -c \"import json; d=json.loads(open('$FAKE_HOME/.idstack/global/learnings.jsonl').readlines()[-1]); assert d['_source_project'] == 'unknown'\""

echo '{"project_name":"my-test-proj"}' > .idstack/project.json
echo '{"skill":"test-skill","key":"key2","type":"pattern","insight":"hello2"}' >> .idstack/learnings.jsonl

check "promotes learning with known project" \
  "HOME=\"$FAKE_HOME\" $IDSTACK_DIR/bin/idstack-learnings-promote key2 && python3 -c \"import json; d=json.loads(open('$FAKE_HOME/.idstack/global/learnings.jsonl').readlines()[-1]); assert d['_source_project'] == 'my-test-proj'\""

# Carried over from PR #30, which was closed in favour of #37. #37 pins
# _source_project but not the _promoted marker, and downstream readers use that
# marker to tell a promoted record from a natively-global one.
check "promoted record carries the _promoted marker" \
  "python3 -c \"import json; d=json.loads(open('$FAKE_HOME/.idstack/global/learnings.jsonl').readlines()[-1]); assert d['_promoted'] is True\""

echo ""

echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
