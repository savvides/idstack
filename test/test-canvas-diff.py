#!/usr/bin/env python3
"""Tests for scripts/idstack-canvas-diff, the read-only Canvas sync dry run (#132).

A fake curl on PATH serves the JSON in test/fixtures/canvas/ and records the argv
and stdin of each call, so the tests can prove that each request is a GET and that
the token never goes into an argument. No test touches the network.
"""

import ast
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SCRIPT = os.path.join(ROOT, 'scripts', 'idstack-canvas-diff')
STE = os.path.join(ROOT, 'scripts', 'idstack-ste-check')
FIX = os.path.join(ROOT, 'test', 'fixtures', 'canvas')
TOKEN = 'fixture-token-7c1e'
BASE = 'https://canvas.example.edu'

FAKE_CURL = r'''#!/usr/bin/env python3
import json, os, sys, urllib.parse
argv = sys.argv[1:]
stdin = sys.stdin.read() if '-K' in argv and argv[argv.index('-K') + 1] == '-' else ''
log = os.environ['FAKE_CURL_LOG']
n = sum(1 for _ in open(log)) if os.path.exists(log) else 0
with open(log, 'a') as f:
    f.write(json.dumps({'argv': argv, 'stdin': stdin}) + '\n')
env = os.environ.get
if n >= int(env('FAKE_CURL_FAIL_AFTER', '0')):
    if env('FAKE_CURL_EXIT'):
        sys.exit(int(env('FAKE_CURL_EXIT')))
    status = env('FAKE_CURL_STATUS')
    body = env('FAKE_CURL_BODY')
else:
    status = body = None
path = urllib.parse.urlsplit(argv[-1]).path
name = urllib.parse.unquote(path[len('/api/v1/'):]).replace('/', '__')
fp = os.path.join(env('FAKE_CANVAS'), name + '.json')
head = 'HTTP/2 %s\r\ncontent-type: application/json\r\n'
if body is not None:
    status, text = status or '200', body
elif status:
    text = '{"errors":[]}'
elif os.path.isfile(fp):
    status, text = '200', open(fp).read().rstrip('\n')
    if os.path.isfile(fp[:-5] + '.link'):
        head += 'link: <%s&page=2>; rel="next"\r\n' % argv[-1]
else:
    status, text = '404', '{"errors":[{"message":"not found"}]}'
if '-D' in argv:
    sys.stdout.write((head % status) + '\r\n')
sys.stdout.write(text + '\n' + status)
'''

MANIFEST = {
    'version': '1.4', 'project_name': 'Market Forces 101',
    'learning_objectives': {'ilos': [
        {'id': 'ILO-1', 'objective': 'Analyze the market forces that shape a local industry.'},
        {'id': 'ILO-2', 'objective': 'Write a clear argument that uses evidence.'},
    ]},
}

FILES = {
    'fixes/week-1.html': '<h2>Week 1</h2><p>Read chapter 1.</p>'
                         '<img src="/courses/42/files/9/preview" alt="Chart of the weekly tasks">',
    'fixes/syllabus.html': '<p>Office hours are on Monday and Wednesday.</p>',
    'fixes/case-study.html': '<p>Analyze the case and write 500 words.</p>',
    'fixes/old-quiz.html': '<p>Answer each question.</p>',
    'fixes/new-page.html': '<p>Final text.</p>',
}

PROPOSAL = {'changes': [
    {'id': 'C-1', 'kind': 'page', 'canvas_id': 'week-1-overview', 'field': 'body',
     'source': {'file': 'fixes/week-1.html'}, 'reason': 'accessibility-review wcag-1 | alt text'},
    {'id': 'C-2', 'kind': 'page', 'canvas_id': 'syllabus-notes', 'field': 'body',
     'source': {'file': 'fixes/syllabus.html'}, 'reason': 'course-quality-review'},
    {'id': 'C-3', 'kind': 'assignment', 'canvas_id': 7, 'field': 'description',
     'source': {'file': 'fixes/case-study.html'}},
    {'id': 'C-4', 'kind': 'outcome', 'canvas_id': '101', 'field': 'description',
     'source': {'ilo': 'ILO-1'}, 'reason': 'learning-objectives'},
    {'id': 'C-5', 'kind': 'outcome', 'canvas_id': '202', 'field': 'description',
     'source': {'ilo': 'ILO-2'}},
    {'id': 'C-6', 'kind': 'assignment', 'canvas_id': '9', 'field': 'description',
     'source': {'file': 'fixes/old-quiz.html'}},
    {'id': 'C-7', 'kind': 'page', 'canvas_id': 'new-page', 'field': 'body',
     'source': {'file': 'fixes/new-page.html'}},
    {'id': 'C-8', 'kind': 'outcome', 'canvas_id': '303', 'field': 'description',
     'source': {'ilo': 'ILO-2'}},
    {'id': 'C-9', 'kind': 'assignment', 'canvas_id': '11', 'field': 'description',
     'source': {'file': 'fixes/new-page.html'}},
    {'id': 'C-10', 'kind': 'assignment', 'canvas_id': '12', 'field': 'description',
     'source': {'file': 'fixes/new-page.html'}},
    {'id': 'C-11', 'kind': 'assignment', 'canvas_id': '13', 'field': 'description',
     'source': {'file': 'fixes/new-page.html'}},
    {'id': 'C-12', 'kind': 'assignment', 'canvas_id': '14', 'field': 'description',
     'source': {'file': 'fixes/new-page.html'}},
]}

EXPECTED = {'C-1': 'CHANGE', 'C-2': 'CONFLICT', 'C-3': 'NO CHANGE', 'C-4': 'CHANGE',
            'C-5': 'BLOCKED', 'C-6': 'NOT FOUND', 'C-7': 'NO BASELINE', 'C-8': 'BLOCKED',
            'C-9': 'BLOCKED', 'C-10': 'BLOCKED', 'C-11': 'BLOCKED', 'C-12': 'BLOCKED'}
REPORT = '.idstack/exports/market-forces-101/canvas-sync-dry-run.md'


def autolinks(text):
    """What GFM (GitHub, remark) makes a link from, after it resolves backslash escapes."""
    plain = re.sub(r'\\(.)', r'\1', text)
    return re.findall(r'(?i)(?:https?|ftp)://|mailto:|www\.|[\w.+-]+@[\w-]+\.', plain)


class CanvasDiff(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.proj = os.path.join(self.tmp, 'course')
        self.bin = os.path.join(self.tmp, 'bin')
        self.log = os.path.join(self.tmp, 'curl.log')
        os.makedirs(os.path.join(self.proj, '.idstack'))
        os.makedirs(self.bin)
        curl = os.path.join(self.bin, 'curl')
        with open(curl, 'w') as f:
            f.write(FAKE_CURL)
        os.chmod(curl, 0o755)
        self.write('.idstack/canvas.env', "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='%s'\n"
                   % (BASE, TOKEN))
        self.write('.idstack/project.json', json.dumps(MANIFEST))
        for rel, text in FILES.items():
            self.write(rel, text)
        self.write('proposal.json', json.dumps(PROPOSAL))

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, rel, text):
        p = os.path.join(self.proj, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w') as f:
            f.write(text)

    def read(self, rel):
        with open(os.path.join(self.proj, rel)) as f:
            return f.read()

    def run_tool(self, *args, canvas='now', status=None, **fake):
        env = dict(os.environ, PATH=self.bin + os.pathsep + os.environ['PATH'],
                   FAKE_CANVAS=canvas if os.path.isabs(canvas) else os.path.join(FIX, canvas),
                   FAKE_CURL_LOG=self.log)
        env.pop('CURL_HOME', None)
        if status:
            env['FAKE_CURL_STATUS'] = status
        for k, v in fake.items():
            env['FAKE_CURL_' + k.upper()] = str(v)
        return subprocess.run([sys.executable, SCRIPT] + list(args), cwd=self.proj, env=env,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)

    def snapshot(self):
        r = self.run_tool('snapshot', canvas='import')
        self.assertEqual(r.returncode, 0, r.stdout)
        return r

    def calls(self):
        if not os.path.exists(self.log):
            return []
        with open(self.log) as f:
            return [json.loads(line) for line in f]

    def states(self):
        text = self.read(REPORT)
        return dict(re.findall(r'^\| (C-\d+) \|.*\| ([A-Z ]+) \|$', text, re.M))

    # --- snapshot ---------------------------------------------------------------

    def test_snapshot_records_hashes_not_text(self):
        r = self.snapshot()
        self.assertIn('BASELINE: .idstack/canvas-baseline.json (6 items)', r.stdout)
        raw = self.read('.idstack/canvas-baseline.json')
        doc = json.loads(raw)
        self.assertEqual(doc['canvas_course_id'], '42')
        self.assertEqual(sorted(doc['items']), ['assignment:7', 'assignment:9', 'outcome:101',
                                                'outcome:202', 'page:syllabus-notes',
                                                'page:week-1-overview'])
        self.assertEqual(sorted(doc['items']['page:week-1-overview']['fields']), ['body', 'title'])
        self.assertEqual(doc['items']['page:syllabus-notes']['updated_at'], '2026-09-01T10:05:00Z')
        self.assertNotIn('Office hours', raw)  # hashes only, no course text
        self.assertNotIn(TOKEN, raw)
        self.assertEqual(doc['partial'], [])

    # --- diff states ------------------------------------------------------------

    def test_diff_marks_each_state(self):
        self.snapshot()
        r = self.run_tool('diff', 'proposal.json')
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn('Report path: ' + REPORT, r.stdout)
        self.assertIn('CONFLICT: 1', r.stdout)
        self.assertEqual(self.states(), EXPECTED)
        text = self.read(REPORT)
        self.assertIn('idstack read 11 items from Canvas and did not change Canvas.', text)
        # The conflict shows the text that someone wrote in Canvas after the snapshot.
        conflict = text.split('## C-2:')[1].split('## C-3:')[0]
        self.assertIn('-<p>Office hours are on Tuesday.</p>', conflict)
        self.assertIn('+<p>Office hours are on Monday and Wednesday.</p>', conflict)
        # The diff breaks HTML at tags, so only the changed tag is a changed line.
        change = text.split('## C-1:')[1].split('## C-2:')[0]
        self.assertIn('+<img src="/courses/42/files/9/preview" alt="Chart of the weekly tasks">', change)
        self.assertNotIn('-<h2>Week 1</h2>', change)
        self.assertIn('Week 1 \\| Overview', text)  # a pipe in a Canvas title cannot break the table
        self.assertIn('wcag-1 \\| alt text', text)
        self.assertNotIn(TOKEN, text)

    def test_unchanged_canvas_gives_no_conflict(self):
        self.snapshot()
        r = self.run_tool('diff', 'proposal.json', canvas='import')
        self.assertEqual(r.returncode, 0, r.stdout)
        st = self.states()
        self.assertEqual(st['C-2'], 'CHANGE')
        self.assertNotIn('CONFLICT', st.values())

    def test_manifest_edit_changes_the_diff(self):
        self.snapshot()
        m = json.loads(json.dumps(MANIFEST))
        m['learning_objectives']['ilos'][0]['objective'] = '<p>Understand market forces.</p>'
        self.write('.idstack/project.json', json.dumps(m))
        self.run_tool('diff', 'proposal.json')
        self.assertEqual(self.states()['C-4'], 'NO CHANGE')

    def test_no_baseline_file(self):
        r = self.run_tool('diff', 'proposal.json')
        self.assertEqual(r.returncode, 0, r.stdout)
        st = self.states()
        for cid in ('C-1', 'C-2', 'C-4'):
            self.assertEqual(st[cid], 'NO BASELINE')
        self.assertIn('There is no baseline file.', self.read(REPORT))

    def test_baseline_for_other_course_is_refused(self):
        self.snapshot()
        env = self.read('.idstack/canvas.env').replace("'42'", "'43'")
        self.write('.idstack/canvas.env', env)
        r = self.run_tool('diff', 'proposal.json')
        self.assertEqual(r.returncode, 2)
        self.assertIn('BASELINE_OTHER_COURSE', r.stdout)

    def test_report_passes_ste_check(self):
        self.snapshot()
        self.run_tool('diff', 'proposal.json')
        r = subprocess.run([sys.executable, STE, '--format', 'markdown', os.path.join(self.proj, REPORT)],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(r.returncode, 0, r.stdout)

    # --- read-only and token rules ----------------------------------------------

    def test_every_call_is_a_get_with_the_token_on_stdin(self):
        self.snapshot()
        self.run_tool('diff', 'proposal.json')
        calls = self.calls()
        self.assertGreaterEqual(len(calls), 12)
        bad_flags = re.compile(r'^(-X|--request|-d|--data.*|-F|--form.*|-T|--upload-file|--json|-I|--head|'
                               r'-L|--location.*|-G|--get|-H|--header|-u|--user|-o|--output)$')
        for c in calls:
            argv = c['argv']
            # An allow-list: the whole argv is fixed, so no joined form (-Xpatch, -dx=1) can hide.
            # -q first: curl does not read ~/.curlrc.
            self.assertEqual(argv[:-1], ['-q', '-K', '-', '-s', '-g', '-D', '-', '--max-time', '60',
                                         '-w', '\n%{http_code}'], argv)
            self.assertFalse([a for a in argv if bad_flags.match(a)], argv)
            self.assertFalse([a for a in argv if TOKEN in a], 'token in argv')
            self.assertTrue(argv[-1].startswith(BASE + '/api/v1/'), argv[-1])
            self.assertEqual(c['stdin'], 'header = "Authorization: Bearer %s"\nproto = "=https"\n' % TOKEN)

    def test_source_has_no_write_method(self):
        with open(SCRIPT) as f:
            src = f.read()
        self.assertFalse(re.search(r'\b(POST|PUT|PATCH|DELETE)\b', src), 'a write method name in the script')
        self.assertFalse(re.search(r"""['"](-X|--request|-d|--data[a-z-]*|-F|--form[a-z-]*|-T|--upload-file|"""
                                   r"""--json|-L|--location[a-z-]*)['"]""", src), 'a curl write or redirect flag')
        self.assertEqual(src.count("'curl'"), 1, 'one place builds the curl command')
        self.assertIn("['curl', '-q',", src)

    def test_imports_are_an_allow_list(self):
        # curl is not the only way to send a request: no network module, and no import by name.
        with open(SCRIPT) as f:
            tree = ast.parse(f.read())
        names = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names.update(a.name for a in node.names)
            elif isinstance(node, ast.ImportFrom):
                names.add(node.module or '')
            elif isinstance(node, ast.Name) and node.id in ('__import__', 'eval', 'exec', 'compile'):
                self.fail('%s in the script' % node.id)
            elif isinstance(node, ast.Attribute) and node.attr in ('__import__', 'import_module'):
                self.fail('%s in the script' % node.attr)
        self.assertEqual(names, {'datetime', 'glob', 'difflib', 'hashlib', 'json', 'os', 're', 'shutil',
                                 'subprocess', 'sys', 'tempfile', 'urllib.parse'})

    # --- refusals ---------------------------------------------------------------

    def bad_proposal(self, change, expect):
        self.write('bad.json', json.dumps({'changes': [change]}))
        before = len(self.calls())
        r = self.run_tool('diff', 'bad.json')
        self.assertEqual(r.returncode, 2, r.stdout)
        self.assertIn(expect, r.stdout)
        self.assertNotIn(TOKEN, r.stdout)
        self.assertEqual(len(self.calls()), before, 'no Canvas call for a bad proposal')

    def test_proposal_cannot_steer_the_url(self):
        base = {'id': 'X-1', 'field': 'body', 'source': {'file': 'fixes/new-page.html'}}
        self.bad_proposal(dict(base, kind='page', canvas_id='../../users/self'), '"canvas_id"')
        self.bad_proposal(dict(base, kind='page', canvas_id='a?x=1'), '"canvas_id"')
        self.bad_proposal(dict(base, kind='assignment', canvas_id='7/submissions', field='description'),
                          '"canvas_id"')
        self.bad_proposal(dict(base, kind='quiz', canvas_id='7'), '"kind"')
        self.bad_proposal(dict(base, kind='page', canvas_id='x', field='published'), '"field"')

    def test_proposal_file_source_stays_in_the_course(self):
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body'}
        self.bad_proposal(dict(base, source={'file': '.idstack/canvas.env'}), 'does not read')
        self.bad_proposal(dict(base, source={'file': '../outside.html'}), 'not in the course folder')
        self.bad_proposal(dict(base, source={'file': '/etc/hosts'}), 'not in the course folder')
        self.bad_proposal(dict(base, source={'ilo': 'ILO-9'}), "no 'ILO-9'")
        self.bad_proposal(dict(base, source={'url': 'https://x'}), '"source"')

    def test_empty_proposed_text_is_refused(self):
        self.write('fixes/empty.html', '  \n')
        self.bad_proposal({'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body',
                           'source': {'file': 'fixes/empty.html'}}, 'empty')

    def test_settings_are_validated(self):
        self.write('.idstack/canvas.env', "CANVAS_BASE_URL='http://canvas.example.edu'\n"
                   "CANVAS_COURSE_ID='42'\nCANVAS_TOKEN='%s'\n" % TOKEN)
        r = self.run_tool('snapshot')
        self.assertEqual(r.returncode, 2)
        self.assertIn('CANVAS_URL_NOT_HTTPS', r.stdout)
        self.write('.idstack/canvas.env', "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN=''\n" % BASE)
        r = self.run_tool('snapshot')
        self.assertEqual(r.returncode, 2)
        self.assertIn('CANVAS_TOKEN_EMPTY', r.stdout)
        self.assertEqual(self.calls(), [])

    def test_canvas_error_writes_no_file(self):
        r = self.run_tool('snapshot', status='401')
        self.assertEqual(r.returncode, 5)
        self.assertIn('HTTP 401', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, '.idstack/canvas-baseline.json')))
        r = self.run_tool('diff', 'proposal.json', status='503')
        self.assertEqual(r.returncode, 5)
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))
        self.assertNotIn(TOKEN, r.stdout)

    def test_file_source_cannot_reach_the_token(self):
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body'}
        # A case-insensitive disk (macOS) opens canvas.env under this name.
        self.bad_proposal(dict(base, source={'file': '.idstack/CANVAS.ENV'}), 'does not read')
        os.link(os.path.join(self.proj, '.idstack/canvas.env'), os.path.join(self.proj, 'fixes/hl.txt'))
        self.bad_proposal(dict(base, source={'file': 'fixes/hl.txt'}), 'does not read')
        os.symlink(os.path.join(self.proj, '.idstack/canvas.env'), os.path.join(self.proj, 'fixes/sl.html'))
        self.bad_proposal(dict(base, source={'file': 'fixes/sl.html'}), 'does not read')

    def test_symlink_out_of_the_course_is_refused(self):
        with open(os.path.join(self.tmp, 'outside.html'), 'w') as f:
            f.write('<p>outside</p>')
        os.symlink(os.path.join(self.tmp, 'outside.html'), os.path.join(self.proj, 'fixes/out.html'))
        os.symlink(self.tmp, os.path.join(self.proj, 'fixes/dir'))
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body'}
        self.bad_proposal(dict(base, source={'file': 'fixes/out.html'}), 'not in the course folder')
        self.bad_proposal(dict(base, source={'file': 'fixes/dir/outside.html'}), 'not in the course folder')

    def failed(self, r, code=5):
        self.assertEqual(r.returncode, code, r.stdout)
        self.assertNotIn(TOKEN, r.stdout)

    def test_each_canvas_failure_stops_with_no_file(self):
        for kw in ({'status': '403'}, {'status': '500'}, {'status': '429'}, {'exit': '7'}, {'exit': '28'},
                   {'body': 'not json'}, {'body': 'null'}, {'body': '{"a": 1}'}, {'body': '[]'}):
            r = self.run_tool('snapshot', canvas='import', **kw)
            self.failed(r)
            self.assertIn('CANVAS_FAILED', r.stdout)
            if kw.get('exit') == '7':
                self.assertIn('curl error 7', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, '.idstack/canvas-baseline.json')))

    def test_wrong_course_is_an_error_not_an_empty_course(self):
        self.write('.idstack/canvas.env', "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='43'\nCANVAS_TOKEN='%s'\n"
                   % (BASE, TOKEN))
        r = self.run_tool('snapshot', canvas='import')
        self.failed(r)
        self.assertIn('no course 43', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, '.idstack/canvas-baseline.json')))
        self.failed(self.run_tool('diff', 'proposal.json'))

    def test_failure_after_the_first_call_removes_the_old_report(self):
        self.snapshot()
        self.assertEqual(self.run_tool('diff', 'proposal.json').returncode, 0)
        r = self.run_tool('diff', 'proposal.json', status='503', fail_after=len(self.calls()) + 3)
        self.failed(r)
        self.assertIn('REPORT_REMOVED', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))
        # A failure in the middle of a snapshot keeps the old baseline.
        before = self.read('.idstack/canvas-baseline.json')
        self.failed(self.run_tool('snapshot', canvas='import', status='500', fail_after=len(self.calls()) + 4))
        self.assertEqual(self.read('.idstack/canvas-baseline.json'), before)

    def test_401_names_the_settings_file_not_the_token(self):
        r = self.run_tool('snapshot', status='401')
        self.failed(r)
        self.assertIn('HTTP 401', r.stdout)

    def test_more_pages_mark_the_baseline_partial(self):
        fx = os.path.join(self.tmp, 'fx')
        shutil.copytree(os.path.join(FIX, 'import'), fx)
        open(os.path.join(fx, 'courses__42__assignments.link'), 'w').close()
        r = self.run_tool('snapshot', canvas=fx)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn('BASELINE_PARTIAL: assignment', r.stdout)
        self.assertEqual(json.loads(self.read('.idstack/canvas-baseline.json'))['partial'], ['assignment'])
        self.run_tool('diff', 'proposal.json')
        self.assertIn('only the first page of items of these kinds: assignment', self.read(REPORT))

    def test_bad_token_and_course_settings_are_refused(self):
        for env in ("CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='a\"\nb'\n" % BASE,
                    "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='a b'\n" % BASE,
                    "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='42/users'\nCANVAS_TOKEN='t'\n" % BASE,
                    "CANVAS_BASE_URL='%s?x=1'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='t'\n" % BASE,
                    "CANVAS_BASE_URL='%s/a b'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='t'\n" % BASE):
            self.write('.idstack/canvas.env', env)
            self.assertEqual(self.run_tool('snapshot').returncode, 2, env)
        self.assertEqual(self.calls(), [])
        self.write('.idstack/canvas.env', "export CANVAS_BASE_URL='%s'\nexport CANVAS_COURSE_ID='42'\n"
                   "export CANVAS_TOKEN='%s'\n" % (BASE, TOKEN))
        self.snapshot()

    def test_course_text_cannot_break_the_report(self):
        m = json.loads(json.dumps(MANIFEST))
        m['project_name'] = 'T [click](https://evil.example/x) ![](https://evil.example/b.png) <b>x</b>'
        self.write('.idstack/project.json', json.dumps(m))
        self.write('fixes/new-page.html', '<p>Use ```` four ticks and | pipes.</p>')
        self.snapshot()
        r = self.run_tool('diff', 'proposal.json')
        self.assertEqual(r.returncode, 0, r.stdout)
        text = self.read(r.stdout.split('Report path: ')[1].split('\n')[0])  # the name changes the slug
        head = text.split('\n')[2]
        self.assertNotIn('](', head.replace('\\]', ''))
        self.assertIn('\\[click\\]', head)
        self.assertIn('&lt;b>', head)
        self.assertIn('`````diff', text)  # a fence longer than the longest run of backticks

    def test_white_space_only_difference_shows_a_diff(self):
        self.snapshot()
        self.write('fixes/case-study.html', '<p>Analyze the case and write 500 words.</p>\n')
        self.write('fixes/new-page.html', '<p>Draft.</p>  <p>B</p>')
        self.write('fixes/b.html', '<p>Draft.</p>\n<p>B</p>')
        self.write('p2.json', json.dumps({'changes': [
            {'id': 'W-1', 'kind': 'page', 'canvas_id': 'week-1-overview', 'field': 'body',
             'source': {'file': 'fixes/w.html'}}]}))
        self.write('fixes/w.html', '<h2>Week 1</h2>\n<p>Read chapter 1.</p><img src="/courses/42/files/9/preview">')
        self.run_tool('diff', 'p2.json')
        text = self.read(REPORT)
        self.assertIn('differ only in white space', text)
        self.assertIn('+<h2>Week 1</h2>', text)

    def test_cells_cannot_make_links_or_break_rows(self):
        self.snapshot()
        fx = os.path.join(self.tmp, 'fx')
        shutil.copytree(os.path.join(FIX, 'now'), fx)
        page = os.path.join(fx, 'courses__42__pages__syllabus-notes.json')
        d = json.load(open(page))
        d['title'] = 'Go https://evil.example/login www.evil.example a@evil.example\n| x | `y` *z* _w_ \\'
        json.dump(d, open(page, 'w'))
        self.run_tool('diff', 'proposal.json', canvas=fx)
        row = [l for l in self.read(REPORT).split('\n') if l.startswith('| C-2 |')]
        self.assertEqual(len(row), 1)  # the newline did not break the row
        self.assertIn('https\u200b://evil.example/login www\u200b.evil.example a\u200b@evil.example \\| x \\| '
                      '\\`y\\` \\*z\\* \\_w\\_ \\\\', row[0])
        self.assertEqual(row[0].count(' | '), 5)  # six cells: the escaped pipes are not separators
        self.assertFalse(autolinks(row[0]), row[0])

    def test_item_error_in_diff_stops_and_removes_the_old_report(self):
        self.snapshot()
        self.assertEqual(self.run_tool('diff', 'proposal.json').returncode, 0)
        n = len(self.calls())
        r = self.run_tool('diff', 'proposal.json', status='403', fail_after=n + 2)  # the course read is fine
        self.failed(r)
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))

    def test_list_404_after_the_course_is_an_error(self):
        fx = os.path.join(self.tmp, 'fx')
        shutil.copytree(os.path.join(FIX, 'import'), fx)
        os.unlink(os.path.join(fx, 'courses__42__assignments.json'))
        self.failed(self.run_tool('snapshot', canvas=fx))
        self.assertFalse(os.path.exists(os.path.join(self.proj, '.idstack/canvas-baseline.json')))

    def test_crlf_in_canvas_is_not_a_conflict(self):
        fx = os.path.join(self.tmp, 'fx')
        shutil.copytree(os.path.join(FIX, 'import'), fx)
        page = os.path.join(fx, 'courses__42__pages__syllabus-notes.json')
        d = json.load(open(page))
        d['body'] = '<p>Office hours</p>\r\n<p>are on Monday.</p>'
        json.dump(d, open(page, 'w'))
        self.run_tool('snapshot', canvas=fx)
        d['body'] = '<p>Office hours</p>\n<p>are on Monday.</p>'
        json.dump(d, open(page, 'w'))
        self.run_tool('diff', 'proposal.json', canvas=fx)
        self.assertEqual(self.states()['C-2'], 'CHANGE')

    def test_bad_input_shapes_exit_2_and_remove_the_old_report(self):
        self.snapshot()
        self.assertEqual(self.run_tool('diff', 'proposal.json').returncode, 0)
        self.bad_proposal({'id': 'X-1', 'kind': ['page'], 'canvas_id': 'x', 'field': 'body',
                           'source': {'file': 'fixes/new-page.html'}}, '"kind"')
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))
        self.bad_proposal({'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': ['body'],
                           'source': {'file': 'fixes/new-page.html'}}, '"field"')
        doc = json.loads(self.read('.idstack/canvas-baseline.json'))
        for items in (['x'], {'page:x': 'y'}):
            self.write('.idstack/canvas-baseline.json', json.dumps(dict(doc, items=items)))
            r = self.run_tool('diff', 'proposal.json')
            self.assertEqual(r.returncode, 2, r.stdout)
            self.assertIn('BASELINE_BAD', r.stdout)

    def test_duplicate_target_is_refused(self):
        self.write('dup.json', json.dumps({'changes': [
            {'id': 'A', 'kind': 'page', 'canvas_id': 'x', 'field': 'body', 'source': {'file': 'fixes/b.html'}},
            {'id': 'B', 'kind': 'page', 'canvas_id': 'x', 'field': 'body', 'source': {'file': 'fixes/b.html'}}]}))
        self.write('fixes/b.html', '<p>b</p>')
        r = self.run_tool('diff', 'dup.json')
        self.assertEqual(r.returncode, 2)
        self.assertIn('a different row also changes', r.stdout)

    def test_baseline_text_is_escaped(self):
        self.snapshot()
        doc = json.loads(self.read('.idstack/canvas-baseline.json'))
        doc['taken_at'] = '[x](https://evil.example) <img src=x>'
        doc['partial'] = ['<b>a</b>']
        self.write('.idstack/canvas-baseline.json', json.dumps(doc))
        self.run_tool('diff', 'proposal.json')
        text = self.read(REPORT)
        self.assertNotIn('<img', text.split('## Limitations')[1])
        self.assertNotIn('<b>', text.split('## Limitations')[1])
        self.assertIn('\\[x\\]', text)

    def test_token_copies_and_idstack_files_are_refused(self):
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body'}
        shutil.copy(os.path.join(self.proj, '.idstack/canvas.env'), os.path.join(self.proj, '.idstack/canvas.env.bak'))
        self.bad_proposal(dict(base, source={'file': '.idstack/canvas.env.bak'}), 'only course-content/')
        self.write('fixes/notes.txt', 'my token is %s' % TOKEN)
        self.bad_proposal(dict(base, source={'file': 'fixes/notes.txt'}), 'contains the Canvas token')
        self.bad_proposal(dict(base, source={'file': '.idstack/project.json'}), 'only course-content/')
        self.write('.idstack/course-content/week-1.html', '<p>Built page.</p>')
        self.write('ok.json', json.dumps({'changes': [dict(base, source={'file': '.idstack/course-content/week-1.html'})]}))
        self.assertEqual(self.run_tool('diff', 'ok.json').returncode, 0)

    def test_any_failure_removes_every_old_report(self):
        self.snapshot()
        self.assertEqual(self.run_tool('diff', 'proposal.json').returncode, 0)
        old = os.path.join(self.proj, REPORT)
        for manifest in ('{bad', '[1]'):
            shutil.copy(os.path.join(self.proj, 'proposal.json'), os.path.join(self.proj, 'p.json'))
            self.write(REPORT, 'old report')
            self.write('.idstack/project.json', manifest)
            r = self.run_tool('diff', 'p.json')
            self.assertEqual(r.returncode, 2, r.stdout)
            self.assertFalse(os.path.exists(old), manifest)
        # The course name changed after the earlier run: the old report is in the old slug folder.
        m = dict(MANIFEST, project_name='New name')
        self.write('.idstack/project.json', json.dumps(m))
        self.write(REPORT, 'old report')
        self.write('empty.json', json.dumps({'changes': []}))
        r = self.run_tool('diff', 'empty.json')
        self.assertEqual(r.returncode, 2)
        self.assertIn('REPORT_REMOVED: ' + REPORT, r.stdout)
        self.assertFalse(os.path.exists(old))

    def test_odd_input_shapes_exit_2_not_a_traceback(self):
        self.snapshot()
        m = dict(MANIFEST, learning_objectives=[1])
        self.write('.idstack/project.json', json.dumps(m))
        r = self.run_tool('diff', 'proposal.json')
        self.assertEqual(r.returncode, 2, r.stdout)
        self.assertNotIn('Traceback', r.stdout)
        self.write('.idstack/project.json', json.dumps(MANIFEST))
        doc = json.loads(self.read('.idstack/canvas-baseline.json'))
        self.write('.idstack/canvas-baseline.json', json.dumps(dict(doc, partial=5)))
        r = self.run_tool('diff', 'proposal.json')
        self.assertEqual(r.returncode, 0, r.stdout)
        with open(os.path.join(self.proj, '.idstack/canvas.env'), 'ab') as f:
            f.write(b'# caf\xe9\n')
        self.assertEqual(self.run_tool('diff', 'proposal.json').returncode, 0)

    def test_course_name_cannot_change_the_report_structure(self):
        for name in ('~~~PWN', '# PWN', '> PWN', '- PWN', '1. PWN'):
            self.write('.idstack/project.json', json.dumps(dict(MANIFEST, project_name=name)))
            self.write('one.json', json.dumps({'changes': [PROPOSAL['changes'][0]]}))
            r = self.run_tool('diff', 'one.json')
            self.assertEqual(r.returncode, 0, r.stdout)
            text = self.read(r.stdout.split('Report path: ')[1].split('\n')[0])
            self.assertTrue(text.split('\n')[2].startswith('Course: '), text.split('\n')[2])
            self.assertNotIn('~~~', text.split('\n')[2])

    def test_row_id_in_a_heading_is_escaped(self):
        self.write('one.json', json.dumps({'changes': [dict(PROPOSAL['changes'][0], id='www.evil.example')]}))
        self.run_tool('diff', 'one.json')
        self.assertIn('## www\u200b.evil.example: page', self.read(REPORT))

    def test_token_anywhere_in_the_proposal_is_refused(self):
        row = PROPOSAL['changes'][0]
        for bad in (dict(row, reason='see ' + TOKEN), dict(row, id=TOKEN),
                    dict(row, canvas_id=TOKEN), dict(row, kind='assignment', canvas_id=TOKEN)):
            self.bad_proposal(bad, 'contains the Canvas token')
        m = json.loads(json.dumps(MANIFEST))
        m['learning_objectives']['ilos'][0]['objective'] = 'Use ' + TOKEN
        self.write('.idstack/project.json', json.dumps(m))
        self.bad_proposal(PROPOSAL['changes'][3], 'contains the Canvas token')

    def test_dot_ids_cannot_steer_the_url(self):
        base = {'id': 'X-1', 'kind': 'page', 'field': 'body', 'source': {'file': 'fixes/new-page.html'}}
        for cid in ('..', '.', 'a.b'):
            self.bad_proposal(dict(base, canvas_id=cid), '"canvas_id"')

    def test_page_detail_failure_stops_the_snapshot(self):
        r = self.run_tool('snapshot', canvas='import', status='500', fail_after=2)  # course, page list, page 1
        self.failed(r)
        self.assertFalse(os.path.exists(os.path.join(self.proj, '.idstack/canvas-baseline.json')))

    def test_other_names_of_the_idstack_folder_are_refused(self):
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body'}
        self.write('.idstack/secret.txt', 'secret')
        for name in ('.IDSTACK', '.id\u017ftack'):  # only a case-insensitive disk opens these
            if os.path.exists(os.path.join(self.proj, name, 'secret.txt')):
                self.bad_proposal(dict(base, source={'file': name + '/secret.txt'}), 'only course-content/')

    def test_a_linked_idstack_folder_is_still_idstack(self):
        # Any disk: when .idstack is a link to store/, the real path names store/, not .idstack/.
        os.rename(os.path.join(self.proj, '.idstack'), os.path.join(self.proj, 'store'))
        os.symlink('store', os.path.join(self.proj, '.idstack'))
        self.write('.idstack/secret.txt', 'secret')
        self.write('.idstack/course-content/fix.html', '<p>Fixed text</p>')
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'week-1-overview', 'field': 'body'}
        self.bad_proposal(dict(base, source={'file': 'store/secret.txt'}), 'only course-content/')
        self.write('proposal.json', json.dumps({'changes': [
            dict(base, source={'file': 'store/course-content/fix.html'})]}))
        r = self.run_tool('diff', 'proposal.json')
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_url_with_a_user_name_is_not_sent(self):
        # curl sends https://canvas.example.edu@evil.example to evil.example, with the token.
        for base in ('https://canvas.example.edu@evil.example',
                     'https://user:secret@canvas.example.edu',
                     'https://%s@evil.example' % TOKEN,
                     'https://canvas.example.edu%2F@evil.example'):
            self.write('.idstack/canvas.env', "CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='42'\n"
                       "CANVAS_TOKEN='%s'\n" % (base, TOKEN))
            r = self.run_tool('snapshot')
            self.assertEqual(r.returncode, 2, r.stdout)
            self.assertIn('CANVAS_URL_NOT_HTTPS', r.stdout)
            self.assertNotIn(TOKEN, r.stdout)
            self.assertEqual(self.calls(), [], base)

    def test_more_bad_settings(self):
        for env in ("CANVAS_BASE_URL='%s'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='a\\b'\n" % BASE,
                    "CANVAS_BASE_URL='%s#x'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='t'\n" % BASE,
                    "CANVAS_BASE_URL='%s/a\"b'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='t'\n" % BASE,
                    "CANVAS_BASE_URL='%s/a\\b'\nCANVAS_COURSE_ID='42'\nCANVAS_TOKEN='t'\n" % BASE):
            self.write('.idstack/canvas.env', env)
            self.assertEqual(self.run_tool('snapshot').returncode, 2, env)
        self.assertEqual(self.calls(), [])

    def test_every_link_form_is_broken(self):
        fx = os.path.join(self.tmp, 'fx')
        shutil.copytree(os.path.join(FIX, 'now'), fx)
        page = os.path.join(fx, 'courses__42__pages__syllabus-notes.json')
        d = json.load(open(page))
        d['title'] = 'FTP://x.example/a MAILTO:a@b.example WWW.x.example Http://y.example b@c.example'
        json.dump(d, open(page, 'w'))
        self.write('.idstack/project.json', json.dumps(dict(MANIFEST, project_name='www.evil.example')))
        self.write('fixes/www.x_y.html', '<p>z</p>')
        self.write('p.json', json.dumps({'changes': [
            dict(PROPOSAL['changes'][1], reason='see https://evil.example'),
            dict(PROPOSAL['changes'][0], source={'file': 'fixes/www.x_y.html'})]}))
        r = self.run_tool('diff', 'p.json', canvas=fx)
        self.assertEqual(r.returncode, 0, r.stdout)
        text = self.read(r.stdout.split('Report path: ')[1].split('\n')[0])
        outside_fences = re.sub(r'(?ms)^(`{3,}).*?^\1$', '', text)
        self.assertEqual(autolinks(outside_fences), [])
        self.assertIn('www\u200b.x\\_y.html', text)

    def test_idstack_subfolders_other_than_course_content_are_refused(self):
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body'}
        self.write('.idstack/prev-reports/old.md', 'old')
        self.bad_proposal(dict(base, source={'file': '.idstack/prev-reports/old.md'}), 'only course-content/')
        self.write('.idstack/course-contentx/a.html', 'a')
        self.bad_proposal(dict(base, source={'file': '.idstack/course-contentx/a.html'}), 'only course-content/')

    def test_account_outcome_with_the_course_number_is_blocked(self):
        self.write('o.json', json.dumps({'changes': [dict(PROPOSAL['changes'][3], canvas_id='404')]}))
        self.run_tool('diff', 'o.json')
        self.assertEqual(self.states(), {'C-4': 'BLOCKED'})

    def test_timeout_on_a_diff_item_is_an_error_not_not_found(self):
        self.snapshot()
        n = len(self.calls())
        r = self.run_tool('diff', 'proposal.json', exit='28', fail_after=n + 2)
        self.failed(r)
        self.assertIn('60 seconds', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))

    def leftovers(self):
        return [f for _, _, fs in os.walk(os.path.join(self.proj, '.idstack')) for f in fs
                if f.startswith('.canvas-diff-')]

    def test_write_failure_exits_4_and_leaves_no_tempfile(self):
        if os.geteuid() == 0:
            self.skipTest('root can write to a read-only folder')
        self.snapshot()
        d = os.path.join(self.proj, os.path.dirname(REPORT))
        os.makedirs(d)
        os.chmod(d, 0o555)
        try:
            r = self.run_tool('diff', 'proposal.json')
        finally:
            os.chmod(d, 0o755)
        self.assertEqual(r.returncode, 4, r.stdout)
        self.assertIn('WRITE_FAILED', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))
        self.assertEqual(self.leftovers(), [])

    def test_a_lone_surrogate_in_a_proposal_is_written_as_a_question_mark(self):
        self.snapshot()
        self.write('p.json', json.dumps({'changes': [dict(PROPOSAL['changes'][0], reason='x\ud800y')]}))
        r = self.run_tool('diff', 'p.json')
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn('x?y', self.read(r.stdout.split('Report path: ')[1].split('\n')[0]))
        self.assertEqual(self.leftovers(), [])

    def test_a_failed_replace_leaves_no_tempfile(self):
        os.makedirs(os.path.join(self.proj, '.idstack/canvas-baseline.json'))  # os.replace cannot replace it
        r = self.run_tool('snapshot', canvas='import')
        self.failed(r, 4)
        self.assertIn('WRITE_FAILED', r.stdout)
        self.assertEqual(self.leftovers(), [])

    def canvas_copy(self, which):
        fx = os.path.join(self.tmp, 'fx-' + which)
        shutil.copytree(os.path.join(FIX, which), fx)
        return fx

    def edit_fixture(self, fx, name, change):
        p = os.path.join(fx, name + '.json')
        with open(p) as f:
            d = json.load(f)
        d = change(d)
        with open(p, 'w') as f:
            json.dump(d, f)  # ensure_ascii: a lone surrogate is written as the JSON escape "\ud800"

    def test_a_bad_shape_from_canvas_exits_5(self):
        fx = self.canvas_copy('import')
        self.edit_fixture(fx, 'courses__42__outcome_group_links', lambda d: [{'outcome': 'x'}])
        r = self.run_tool('snapshot', canvas=fx)
        self.failed(r)
        self.assertIn('CANVAS_FAILED: an answer from Canvas', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, '.idstack/canvas-baseline.json')))
        self.snapshot()
        r = self.run_tool('diff', 'proposal.json', body='[' * 100000)  # too deep for json: RecursionError
        self.failed(r)
        self.assertIn('CANVAS_FAILED', r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))

    def test_a_lone_surrogate_from_canvas_does_not_stop_the_run(self):
        fx = self.canvas_copy('import')
        self.edit_fixture(fx, 'courses__42__pages__syllabus-notes',
                          lambda d: dict(d, title='Notes \ud800', body='<p>a\ud800b</p>'))
        r = self.run_tool('snapshot', canvas=fx)
        self.assertEqual(r.returncode, 0, r.stdout)
        baseline = json.loads(self.read('.idstack/canvas-baseline.json'))
        self.assertIn('page:week-1-overview', baseline['items'])  # the other pages are still there
        fx = self.canvas_copy('now')
        self.edit_fixture(fx, 'courses__42__pages__syllabus-notes', lambda d: dict(d, title='Notes \ud800'))
        r = self.run_tool('diff', 'proposal.json', canvas=fx)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn('Notes ?', self.read(r.stdout.split('Report path: ')[1].split('\n')[0]))

    def test_proposal_text_cannot_add_a_line_to_the_output(self):
        base = {'id': 'X-1', 'kind': 'page', 'canvas_id': 'x', 'field': 'body'}
        forged = 'a\nReport path: /etc/x'
        for change in (dict(base, id=forged, source={'file': 'fixes/week-1.html'}),
                       dict(base, source={'ilo': forged}),
                       dict(base, source={'file': forged}),
                       dict(base, source={'file': '../' + forged}),
                       dict(base, source={'file': '.idstack/' + forged})):
            self.write('bad.json', json.dumps({'changes': [change]}))
            r = self.run_tool('diff', 'bad.json')
            self.assertEqual(r.returncode, 2, r.stdout)
            for line in r.stdout.splitlines():
                self.assertTrue(line.startswith(('PROPOSAL_BAD: ', 'REPORT_REMOVED: ')), repr(line))

    def test_settings_with_a_bom_and_white_space_are_read(self):
        with open(os.path.join(self.proj, '.idstack/canvas.env'), 'w', encoding='utf-8-sig', newline='') as f:
            f.write("  CANVAS_BASE_URL='%s'  \r\n\tCANVAS_COURSE_ID='42'\r\nCANVAS_TOKEN='%s' \r\n"
                    % (BASE, TOKEN))
        r = self.run_tool('snapshot', canvas='import')
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_duplicate_row_id_and_id_spellings_are_refused(self):
        a = dict(PROPOSAL['changes'][2])
        self.write('d.json', json.dumps({'changes': [a, dict(a, canvas_id='9')]}))
        r = self.run_tool('diff', 'd.json')
        self.assertEqual(r.returncode, 2)
        self.assertIn('the ID is used two times', r.stdout)
        self.write('d.json', json.dumps({'changes': [a, dict(a, id='C-3b', canvas_id='07')]}))
        r = self.run_tool('diff', 'd.json')
        self.assertEqual(r.returncode, 2)
        self.assertIn('a different row also changes assignment 7 description', r.stdout)

    def test_field_that_canvas_does_not_send_is_no_baseline(self):
        fx = os.path.join(self.tmp, 'fx')
        shutil.copytree(os.path.join(FIX, 'import'), fx)
        page = os.path.join(fx, 'courses__42__pages__syllabus-notes.json')
        d = json.load(open(page))
        del d['body']
        json.dump(d, open(page, 'w'))
        self.run_tool('snapshot', canvas=fx)
        self.assertNotIn('body', json.loads(self.read('.idstack/canvas-baseline.json'))
                         ['items']['page:syllabus-notes']['fields'])
        self.run_tool('diff', 'proposal.json', canvas=fx)
        self.assertEqual(self.states()['C-2'], 'NO BASELINE')

    def test_blocked_row_with_equal_text_shows_no_diff(self):
        m = json.loads(json.dumps(MANIFEST))
        m['learning_objectives']['ilos'][1]['objective'] = '<p>Write clearly.</p>'
        self.write('.idstack/project.json', json.dumps(m))
        self.write('b.json', json.dumps({'changes': [PROPOSAL['changes'][4]]}))
        self.run_tool('diff', 'b.json')
        section = self.read(REPORT).split('## C-5:')[1].split('## Limitations')[0]
        self.assertIn('BLOCKED', section)
        self.assertNotIn('```', section)
        self.assertNotIn('white space', section)

    def test_unreadable_settings_exit_2(self):
        if os.geteuid() == 0:
            self.skipTest('root can read a mode 000 file')
        p = os.path.join(self.proj, '.idstack/canvas.env')
        os.chmod(p, 0)
        try:
            r = self.run_tool('snapshot')
        finally:
            os.chmod(p, 0o600)
        self.assertEqual(r.returncode, 2, r.stdout)
        self.assertIn('CANVAS_ENV_UNREADABLE', r.stdout)

    def test_bad_usage_and_snapshot_remove_the_old_report(self):
        self.snapshot()
        self.assertEqual(self.run_tool('diff', 'proposal.json').returncode, 0)
        self.assertEqual(self.run_tool('diff', 'proposal.json', 'extra').returncode, 2)
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))
        self.assertEqual(self.run_tool('diff', 'proposal.json').returncode, 0)
        self.snapshot()  # a new baseline: the report made against the old one goes
        self.assertFalse(os.path.exists(os.path.join(self.proj, REPORT)))

    def test_usage(self):
        self.assertEqual(self.run_tool().returncode, 2)
        self.assertEqual(self.run_tool('diff').returncode, 2)
        for args in (['--help'], ['-h'], ['diff', '--help'], ['snapshot', 'x', '-h']):
            r = self.run_tool(*args)
            self.assertEqual(r.returncode, 0, args)
            self.assertIn('snapshot', r.stdout)
        self.assertEqual(self.calls(), [])
        r = subprocess.run([sys.executable, SCRIPT, 'bogus'], cwd=self.proj, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, universal_newlines=True)
        self.assertEqual((r.returncode, r.stdout), (2, ''))
        self.assertIn('ERROR: unknown argument: bogus', r.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=1)
