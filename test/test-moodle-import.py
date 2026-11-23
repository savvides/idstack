#!/usr/bin/env python3
"""Tests for scripts/idstack-moodle-import.

The script runs against a fake Moodle on 127.0.0.1. The fake sends the responses
in test/fixtures/moodle/, which were recorded from a real Moodle 4.5 site (see
test/fixtures/moodle/README.md). Each test runs the shipped script.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SCRIPT = os.path.join(REPO_ROOT, 'scripts', 'idstack-moodle-import')
STE_CHECK = os.path.join(REPO_ROOT, 'scripts', 'idstack-ste-check')
FIXTURES = os.path.join(REPO_ROOT, 'test', 'fixtures', 'moodle')
TOKEN = 'faketokenfaketokenfaketoken'  # letters only: the script accepts it, a secret scanner does not flag it


def fixture(name):
    with open(os.path.join(FIXTURES, name), 'rb') as f:
        return f.read()


class FakeMoodle(BaseHTTPRequestHandler):
    """Sends a fixture for each wsfunction. The test sets `routes` and reads `seen`."""
    routes = {}
    seen = []

    def log_message(self, *args):
        pass

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get('Content-Length') or 0)).decode('ascii')
        form = dict(urllib.parse.parse_qsl(body))
        FakeMoodle.seen.append({'path': self.path, 'form': form, 'raw': body})
        route = FakeMoodle.routes.get(form.get('wsfunction'), form.get('wsfunction') + '.json')
        if callable(route):
            route = route(form)
        if isinstance(route, tuple):  # (status, headers, body)
            status, headers, payload = route
        else:
            status, headers, payload = 200, {}, fixture(route)
        self.send_response(status)
        for k, v in headers.items():
            self.send_header(k, v)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


class MoodleImportTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(('127.0.0.1', 0), FakeMoodle)
        cls.base = 'http://127.0.0.1:%d' % cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix='idstack-test-moodle-')
        os.makedirs(os.path.join(self.root, '.idstack'))
        FakeMoodle.routes = {}
        FakeMoodle.seen = []

    def tearDown(self):
        shutil.rmtree(self.root)

    def settings(self, base=None, course='2', token=TOKEN, quote="'"):
        with open(os.path.join(self.root, '.idstack', 'moodle.env'), 'w', encoding='utf-8') as f:
            f.write("MOODLE_BASE_URL=%s%s%s\nMOODLE_COURSE_ID=%s%s%s\nMOODLE_TOKEN=%s%s%s\n" % (
                quote, self.base if base is None else base, quote, quote, course, quote, quote, token, quote))

    def run_import(self, *args, env=None):
        clean_env = {k: v for k, v in os.environ.items() if 'proxy' not in k.lower()}
        clean_env.update(env or {})
        return subprocess.run([sys.executable, SCRIPT] + list(args), cwd=self.root, env=clean_env,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    def import_ok(self):
        r = self.run_import()
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout), r

    def functions_called(self):
        return [s['form'].get('wsfunction') for s in FakeMoodle.seen]

    def site_info_without(self, *names):
        info = json.loads(fixture('core_webservice_get_site_info.json'))
        info['functions'] = [f for f in info['functions'] if f['name'] not in names]
        return (200, {}, json.dumps(info).encode())

    # --- the import -------------------------------------------------------

    def test_full_import_from_recorded_moodle(self):
        self.settings()
        out, _ = self.import_ok()
        self.assertEqual(out['source'], 'moodle-api')
        self.assertTrue(out['moodle']['release'].startswith('4.5'))
        self.assertEqual(out['course']['fullname'], 'Introduction to Data Ethics')
        self.assertEqual(out['course']['start_date'], '2026-01-01')
        self.assertEqual(out['counts'], {'sections': 4, 'activities': 9, 'assignments': 3, 'rubrics': 1,
                                         'marking_guides': 1, 'quizzes': 1, 'forums': 2, 'pages': 2,
                                         'competencies': 2})
        self.assertEqual(out['not_available'], [])
        self.assertEqual(out['errors'], [])
        week1 = out['sections'][1]
        self.assertEqual(week1['name'], 'Week 1: Data and privacy')
        self.assertIn('learners will be able to explain', week1['summary'])
        self.assertNotIn('<p>', week1['summary'])
        self.assertEqual([a['type'] for a in week1['activities']], ['page', 'url', 'quiz'])

    def test_non_ascii_course_name_on_a_cp1252_pipe(self):
        # A native Windows python3 writes a pipe in cp1252, which has no "ā" (#136).
        course = json.loads(fixture('core_course_get_courses_by_field.json'))
        course['courses'][0]['fullname'] = 'Māori data ethics'
        FakeMoodle.routes['core_course_get_courses_by_field'] = (200, {}, json.dumps(course).encode())
        self.settings()
        env = {k: v for k, v in os.environ.items() if 'proxy' not in k.lower()}
        env['PYTHONIOENCODING'] = 'cp1252'
        r = subprocess.run([sys.executable, SCRIPT], cwd=self.root, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout.decode('utf-8'))['course']['fullname'], 'Māori data ethics')

    def test_rubric_marking_guide_and_simple_grading(self):
        self.settings()
        out, _ = self.import_ok()
        by_name = {a['name']: a for a in out['assignments']}
        bias = by_name['Bias audit report']
        self.assertEqual(bias['grading_method'], 'rubric')
        self.assertEqual(bias['max_grade'], 100)
        self.assertEqual(bias['submission_types'], ['onlinetext'])
        self.assertEqual([c['description'] for c in bias['rubric']['criteria']],
                         ['Identifies the bias', 'Uses evidence'])
        self.assertEqual([lv['score'] for lv in bias['rubric']['criteria'][1]['levels']], [0, 15, 30])
        plan = by_name['Ethics review plan']
        self.assertEqual(plan['grading_method'], 'guide')
        self.assertIsNone(plan['rubric'])
        self.assertEqual([(c['shortname'], c['max_score']) for c in plan['marking_guide']['criteria']],
                         [('Risks', 25), ('Mitigation', 25)])
        journal = by_name['Reflection journal']
        self.assertEqual(journal['grading_method'], 'simple')
        self.assertIsNone(journal['rubric'])
        self.assertIsNone(journal['marking_guide'])

    def test_grading_call_does_not_ask_for_active_only(self):
        # Real Moodle 4.5 answers activeonly=1 with invalid_method_name when one
        # assignment uses simple grading. Recorded in error-grading-activeonly.json.
        FakeMoodle.routes['core_grading_get_definitions'] = lambda form: (
            'error-grading-activeonly.json' if form.get('activeonly') == '1'
            else 'core_grading_get_definitions.json')
        self.settings()
        out, _ = self.import_ok()
        self.assertEqual(out['counts']['rubrics'], 1)
        self.assertEqual(out['errors'], [])

    def test_site_info_secrets_are_not_copied(self):
        self.assertIn(b'"userprivateaccesskey":"scrubbed"', fixture('core_webservice_get_site_info.json'))
        self.settings()
        out, r = self.import_ok()
        self.assertNotIn('scrubbed', r.stdout)
        self.assertNotIn('teacher1', r.stdout)

    def test_quiz_password_is_not_copied(self):
        self.assertIn(b'quizpass-123', fixture('mod_quiz_get_quizzes_by_courses.json'))
        self.settings()
        out, r = self.import_ok()
        self.assertNotIn('quizpass-123', r.stdout)
        quiz = out['quizzes'][0]
        self.assertEqual((quiz['name'], quiz['time_limit_minutes'], quiz['attempts']),
                         ('Privacy check quiz', 15, 2))
        self.assertEqual(quiz['behaviour'], 'deferredfeedback')

    def test_competencies_and_forums(self):
        self.settings()
        out, _ = self.import_ok()
        self.assertEqual([c['shortname'] for c in out['competencies']],
                         ['Explain data privacy principles', 'Evaluate algorithmic bias'])
        self.assertEqual([f['name'] for f in out['forums']], ['Introduce yourself', 'Bias case discussion'])
        self.assertFalse(any(f['graded'] for f in out['forums']))

    def test_mobile_app_token_without_grading_function(self):
        # The Moodle app service has no core_grading_get_definitions.
        FakeMoodle.routes['core_webservice_get_site_info'] = self.site_info_without('core_grading_get_definitions')
        self.settings()
        out, _ = self.import_ok()
        self.assertEqual(out['not_available'], ['core_grading_get_definitions'])
        self.assertNotIn('core_grading_get_definitions', self.functions_called())
        self.assertEqual({a['grading_method'] for a in out['assignments']}, {'unknown'})
        self.assertEqual(out['counts']['assignments'], 3)

    def test_moodle_error_in_a_200_response_is_recorded(self):
        FakeMoodle.routes['core_grading_get_definitions'] = 'error-function-not-allowed.json'
        self.settings()
        out, _ = self.import_ok()
        self.assertEqual(out['errors'][0]['function'], 'core_grading_get_definitions')
        self.assertEqual(out['errors'][0]['errorcode'], 'accessexception')
        self.assertEqual(out['counts']['rubrics'], 0)

    def test_warning_only_response_is_recorded(self):
        FakeMoodle.routes['mod_assign_get_assignments'] = lambda form: (200, {}, json.dumps(
            {'courses': [], 'warnings': [{'item': 'course', 'itemid': 2, 'warningcode': '2',
                                           'message': 'No access rights in module context'}]}).encode())
        self.settings()
        out, _ = self.import_ok()
        self.assertEqual(out['counts']['assignments'], 0)
        self.assertEqual(out['errors'][0]['function'], 'mod_assign_get_assignments')
        self.assertIn('No access rights', out['errors'][0]['message'])

    def test_html_to_text(self):
        contents = json.loads(fixture('core_course_get_contents.json'))
        contents[1]['summary'] = '<p>One</p><p>two &amp; three</p><script>alert(1)</script>'
        FakeMoodle.routes['core_course_get_contents'] = (200, {}, json.dumps(contents).encode())
        self.settings()
        out, _ = self.import_ok()
        self.assertEqual(out['sections'][1]['summary'], 'One two & three')

    def test_unexpected_response_shapes_give_a_code_not_a_traceback(self):
        courses = json.loads(fixture('core_course_get_courses_by_field.json'))
        courses['courses'][0]['startdate'] = 'soon'
        for function, payload in [('core_webservice_get_site_info', b'null'),
                                  ('core_webservice_get_site_info', b'[]'),
                                  ('core_course_get_courses_by_field', json.dumps(courses).encode()),
                                  ('core_course_get_contents', b'[null]'),
                                  ('mod_forum_get_forums_by_courses', b'{"a": 1}')]:
            with self.subTest(function=function, payload=payload[:20]):
                FakeMoodle.routes = {function: (200, {}, payload)}
                self.settings()
                r = self.run_import()
                self.assertEqual(r.returncode, 4, r.stderr)
                self.assertIn('MOODLE_BAD_RESPONSE', r.stderr)
                self.assertNotIn('Traceback', r.stderr)

    # --- the token --------------------------------------------------------

    def test_token_is_only_in_the_post_body(self):
        self.settings()
        _, r = self.import_ok()
        self.assertGreaterEqual(len(FakeMoodle.seen), 9)
        for s in FakeMoodle.seen:
            self.assertEqual(s['path'], '/webservice/rest/server.php')
            self.assertNotIn(TOKEN, s['path'])
            self.assertEqual(s['form'].get('wstoken'), TOKEN)
        self.assertNotIn(TOKEN, r.stdout + r.stderr)

    def test_no_proxy_for_plain_http_on_this_computer(self):
        # A proxy on a closed port: the import works only if it does not use the proxy.
        self.settings()
        r = self.run_import(env={'http_proxy': 'http://127.0.0.1:9', 'HTTP_PROXY': 'http://127.0.0.1:9'})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(FakeMoodle.seen)

    def test_uppercase_http_on_this_computer_does_not_use_a_proxy(self):
        # urlsplit accepts HTTP:// as http, then the request URL kept that case.
        # opener() only skipped the proxy when the URL started with lowercase http://.
        self.settings(base='HTTP://127.0.0.1:%d' % self.server.server_address[1])
        r = self.run_import(env={'http_proxy': 'http://127.0.0.1:9', 'HTTP_PROXY': 'http://127.0.0.1:9'})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(FakeMoodle.seen)
        self.assertNotIn(TOKEN, r.stdout + r.stderr)

    def test_moodle_message_never_carries_the_token(self):
        FakeMoodle.routes['core_grading_get_definitions'] = (200, {}, json.dumps(
            {'exception': 'x', 'errorcode': 'bad', 'message': 'token %s is bad' % TOKEN}).encode())
        self.settings()
        out, r = self.import_ok()
        self.assertNotIn(TOKEN, r.stdout + r.stderr)
        self.assertIn('[token]', out['errors'][0]['message'])

    def test_settings_file_with_export_and_a_byte_order_mark(self):
        with open(os.path.join(self.root, '.idstack', 'moodle.env'), 'w', encoding='utf-8-sig') as f:
            f.write("export MOODLE_BASE_URL='%s'\r\nMOODLE_COURSE_ID=2\r\nexport MOODLE_TOKEN=%s\r\n" % (self.base, TOKEN))
        self.import_ok()

    def test_token_with_double_quotes_in_the_settings_file(self):
        self.settings(quote='"')
        self.import_ok()
        self.assertEqual(FakeMoodle.seen[0]['form'].get('wstoken'), TOKEN)

    def test_site_address_keeps_its_path(self):
        self.settings(base=self.base + '/moodle/')
        self.import_ok()
        self.assertEqual({s['path'] for s in FakeMoodle.seen}, {'/moodle/webservice/rest/server.php'})

    def test_redirect_is_not_followed(self):
        FakeMoodle.routes['core_webservice_get_site_info'] = lambda form: (
            (302, {'Location': self.base + '/other/webservice/rest/server.php'}, b'')
            if len(FakeMoodle.seen) == 1 else 'core_webservice_get_site_info.json')
        self.settings()
        r = self.run_import()
        self.assertEqual(r.returncode, 4)
        self.assertIn('MOODLE_REDIRECT', r.stderr)
        self.assertEqual(len(FakeMoodle.seen), 1)

    def test_redirect_location_does_not_carry_the_token(self):
        FakeMoodle.routes['core_webservice_get_site_info'] = (
            302, {'Location': 'https://evil.example/login?wstoken=%s' % TOKEN}, b'')
        self.settings()
        r = self.run_import()
        self.assertEqual(r.returncode, 4, r.stderr)
        self.assertIn('MOODLE_REDIRECT', r.stderr)
        self.assertNotIn(TOKEN, r.stdout + r.stderr)
        self.assertIn('[token]', r.stderr)

    def test_plain_http_is_refused_except_on_this_computer(self):
        for base, code in [('http://moodle.example.invalid', 'MOODLE_URL_NOT_HTTPS'),
                           ('http://localhost.example.invalid', 'MOODLE_URL_NOT_HTTPS'),
                           ('http://127.0.0.1.example.invalid:8000', 'MOODLE_URL_NOT_HTTPS'),
                           ('http://localhost@moodle.example.invalid', 'MOODLE_URL_BAD'),
                           ('https://moodle.example.invalid/?id=2', 'MOODLE_URL_BAD'),
                           ('ftp://moodle.example.invalid', 'MOODLE_URL_BAD'),
                           ('moodle.example.invalid', 'MOODLE_URL_BAD'),
                           ('http://[::1', 'MOODLE_URL_BAD'),
                           ('https://moodle.example.invalid/p\u00e4', 'MOODLE_URL_BAD'),
                           ('', 'MOODLE_URL_BAD')]:
            with self.subTest(base=base):
                self.settings(base=base)
                r = self.run_import()
                self.assertEqual(r.returncode, 2, r.stderr)
                self.assertIn(code, r.stderr)
        self.assertEqual(FakeMoodle.seen, [])
        # [::1] is this computer: it passes the address check, then finds no server.
        self.settings(base='http://[::1]:9')
        r = self.run_import()
        self.assertEqual(r.returncode, 4, r.stderr)
        self.assertIn('MOODLE_NO_CONNECTION', r.stderr)

    # --- refusals and failures ---------------------------------------------

    def test_rejected_token(self):
        FakeMoodle.routes['core_webservice_get_site_info'] = 'error-invalid-token.json'
        self.settings()
        r = self.run_import()
        self.assertEqual(r.returncode, 3)
        self.assertIn('MOODLE_TOKEN_REJECTED', r.stderr)
        self.assertEqual(self.functions_called(), ['core_webservice_get_site_info'])

    def test_token_that_cannot_read_the_course_contents(self):
        FakeMoodle.routes['core_webservice_get_site_info'] = self.site_info_without('core_course_get_contents')
        self.settings()
        r = self.run_import()
        self.assertEqual(r.returncode, 3)
        self.assertIn('MOODLE_FUNCTION_MISSING', r.stderr)

    def test_course_not_found(self):
        FakeMoodle.routes['core_course_get_courses_by_field'] = 'error-course-not-found.json'
        self.settings(course='999')
        r = self.run_import()
        self.assertEqual(r.returncode, 5)
        self.assertIn('MOODLE_COURSE_NOT_FOUND', r.stderr)

    def test_course_contents_refused(self):
        FakeMoodle.routes['core_course_get_contents'] = 'error-function-not-allowed.json'
        self.settings()
        r = self.run_import()
        self.assertEqual(r.returncode, 5)
        self.assertIn('MOODLE_COURSE_NO_ACCESS', r.stderr)

    def test_http_error_and_a_response_that_is_not_json(self):
        for route, code in [((500, {}, b'oops'), 'MOODLE_HTTP_ERROR'),
                            ((200, {}, b'<html>login</html>'), 'MOODLE_BAD_RESPONSE')]:
            with self.subTest(code=code):
                FakeMoodle.routes['core_webservice_get_site_info'] = route
                self.settings()
                r = self.run_import()
                self.assertEqual(r.returncode, 4)
                self.assertIn(code, r.stderr)

    def test_settings_problems(self):
        r = self.run_import()
        self.assertEqual(r.returncode, 1)
        self.assertIn('MOODLE_ENV_MISSING', r.stderr)
        for kwargs, code in [({'token': ''}, 'MOODLE_TOKEN_EMPTY'),
                             ({'token': 'abc 123'}, 'MOODLE_TOKEN_BAD'),
                             ({'token': 'abc&wsfunction=x'}, 'MOODLE_TOKEN_BAD'),
                             ({'course': '12a'}, 'MOODLE_COURSE_ID_BAD'),
                             ({'course': ''}, 'MOODLE_COURSE_ID_BAD')]:
            with self.subTest(code=code, **kwargs):
                self.settings(**kwargs)
                r = self.run_import()
                self.assertEqual(r.returncode, 1)
                self.assertIn(code, r.stderr)
                self.assertNotIn('wsfunction=x', r.stderr)
        self.assertEqual(FakeMoodle.seen, [])

    def test_messages_follow_the_writing_standard(self):
        messages = []
        for base in ('http://moodle.example.invalid', 'moodle.example.invalid'):
            self.settings(base=base)
            messages.append(self.run_import().stderr)
        for route in ('error-invalid-token.json', (302, {'Location': 'https://x.example.edu'}, b''),
                      (500, {}, b''), (200, {}, b'<html>')):
            FakeMoodle.routes = {'core_webservice_get_site_info': route}
            self.settings()
            messages.append(self.run_import().stderr)
        FakeMoodle.routes = {'core_webservice_get_site_info': self.site_info_without('core_course_get_contents')}
        messages.append(self.run_import().stderr)
        FakeMoodle.routes = {'core_course_get_courses_by_field': 'error-course-not-found.json'}
        messages.append(self.run_import().stderr)
        text = '\n'.join(m.split(': ', 1)[1] for m in messages)
        r = subprocess.run([sys.executable, STE_CHECK, '--format', 'text', '-'], input=text,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=1)
