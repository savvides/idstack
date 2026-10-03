#!/usr/bin/env python3
"""Unit tests for bin/idstack-ste-check.

The clean fixtures in test/fixtures/ste/ hold the hard cases of real idstack output:
chained citations, "et al.", WCAG numbers, version strings, file names, placeholders,
HTML entities, quoted faculty text and code. A false positive on these makes each
skill loop three times and then report problems that do not exist.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CHECKER = os.path.join(REPO_ROOT, 'bin', 'idstack-ste-check')
FIXTURES = os.path.join(REPO_ROOT, 'test', 'fixtures', 'ste')
PREAMBLE = os.path.join(REPO_ROOT, 'templates', 'preamble.md')


def run_checker(args, stdin=None):
    return subprocess.run([sys.executable, CHECKER] + args, input=stdin,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True, cwd=REPO_ROOT)


class SteCheckTest(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='idstack-test-ste-')

    def tearDown(self):
        shutil.rmtree(self.work)

    def write(self, name, text):
        path = os.path.join(self.work, name)
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)
        return path

    def check_file(self, name, text):
        return run_checker([self.write(name, text)])

    def assert_problem(self, proc, rule):
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertIn(': %s: ' % rule, proc.stdout)

    def assert_clean(self, proc):
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    # --- clean input -----------------------------------------------------

    def test_clean_fixtures_pass(self):
        for name in sorted(os.listdir(FIXTURES)):
            with self.subTest(fixture=name):
                self.assert_clean(run_checker([os.path.join(FIXTURES, name)]))

    def test_writing_standard_section_passes(self):
        with open(PREAMBLE, encoding='utf-8') as handle:
            text = handle.read()
        start = text.index('## Preamble: Writing Standard (ASD-STE100)')
        end = text.index('## Preamble:', start + 10)
        self.assert_clean(run_checker(['--format', 'markdown', '-'], stdin=text[start:end]))

    def test_directory_checks_html_and_markdown_only(self):
        self.write('a.md', 'Do not utilize this.\n')
        self.write('b.html', '<p>Do not utilize this.</p>\n')
        self.write('c.css', '.x { a: b; }\n')
        proc = run_checker([self.work])
        self.assertEqual(proc.returncode, 1)
        self.assertIn('a.md:1: word:', proc.stdout)
        self.assertIn('b.html:1: word:', proc.stdout)
        self.assertNotIn('c.css', proc.stdout)

    # --- sentence and paragraph length -------------------------------------

    def test_description_of_25_words_passes_and_26_fails(self):
        words25 = ' '.join(['word'] * 24) + ' end.'
        self.assert_clean(self.check_file('a.html', '<p>%s</p>' % words25))
        self.assert_problem(self.check_file('b.html', '<p>more %s</p>' % words25), 'sentence-length')

    def test_numbered_step_of_20_words_passes_and_21_fails(self):
        words20 = ' '.join(['word'] * 19) + ' end.'
        self.assert_clean(self.check_file('a.html', '<ol><li>%s</li></ol>' % words20))
        self.assert_problem(self.check_file('b.html', '<ol><li>more %s</li></ol>' % words20),
                            'sentence-length')
        self.assert_problem(self.check_file('c.md', '1. more %s\n' % words20), 'sentence-length')
        self.assert_problem(self.check_file('d.html', '<ol><li><p>Open it.</p><p>more %s</p></li></ol>' % words20),
                            'sentence-length')

    def test_bullet_item_uses_the_description_limit(self):
        words25 = ' '.join(['word'] * 24) + ' end.'
        self.assert_clean(self.check_file('a.md', '- %s\n' % words25))

    def test_citations_and_codes_count_as_one_word(self):
        sentence = ' '.join(['word'] * 22) + ' [CogLoad-4] [CogLoad-19] [T1].'
        self.assert_clean(self.check_file('a.html', '<p>%s</p>' % sentence))

    def test_text_in_parentheses_is_a_separate_sentence(self):
        inner = ' '.join(['word'] * 26)
        self.assert_problem(self.check_file('a.md', 'Short host sentence (%s).\n' % inner),
                            'sentence-length')
        self.assert_clean(self.check_file('b.md', 'Short host sentence (with a short note).\n'))
        two = ' '.join(['word'] * 14) + '. ' + ' '.join(['word'] * 13) + '.'
        self.assert_clean(self.check_file('c.md', 'Short host sentence (%s).\n' % two))

    def test_paragraph_of_6_sentences_passes_and_7_fails(self):
        six = ' '.join(['This is a sentence.'] * 6)
        self.assert_clean(self.check_file('a.html', '<p>%s</p>' % six))
        self.assert_problem(self.check_file('b.html', '<p>%s It has seven.</p>' % six),
                            'paragraph-length')

    def test_sentence_that_starts_in_lowercase_is_a_new_sentence(self):
        first = ' '.join(['word'] * 14) + ' end.'
        second = "idstack recommends that you add a rubric to each module 'now.' Then stop."
        self.assert_clean(self.check_file('a.html', '<p>%s %s</p>' % (first, second)))
        seven = ' '.join(['idstack found a problem.'] * 7)
        self.assert_problem(self.check_file('b.html', '<p>%s</p>' % seven), 'paragraph-length')

    def test_problems_in_parentheses_are_found(self):
        self.assert_problem(self.check_file('a.md', 'Add a rubric (you should do it now).\n'), 'word')
        self.assert_problem(self.check_file('b.md', 'Add a rubric (first this; then that).\n'), 'semicolon')
        self.assert_problem(self.check_file('c.md', "Add a rubric (it's late).\n"), 'contraction')
        # A year does not make a parenthesis a citation.
        self.assert_problem(self.check_file('d.md', 'Submit it (by October 15, 2026; late work loses points).\n'),
                            'semicolon')
        self.assert_clean(self.check_file('e.md', 'It works (e.g., Paas & van Gog, 2006, p. 3; Mayer, 2021).\n'))

    def test_punctuation_after_a_url_or_identifier_ends_the_sentence(self):
        second = ('Three of the eight learning objectives in this course have no matching '
                  'assessment in any of the modules.')
        self.assert_clean(self.check_file(
            'a.html', '<p>The quality score of the course is 62/100. %s</p>' % second))
        seven = ' '.join(['The score is 62/100.'] * 7)
        self.assert_problem(self.check_file('b.html', '<p>%s</p>' % seven), 'paragraph-length')
        for text in ['The score is 62/100; the target is 70/100.',
                     'Open data/x.csv; then save it.',
                     'See https://example.edu/syllabus; it has the dates.']:
            with self.subTest(text=text):
                self.assert_problem(run_checker(['-'], stdin=text + '\n'), 'semicolon')

    def test_line_breaks_end_a_sentence(self):
        lines = ['Course: Data Ethics 101', 'Instructor: [NAME]', 'Term: Fall 2026',
                 'Prerequisite: STAT 200 or the permission of the instructor',
                 'Format: Online, with two live sessions on Zoom']
        self.assert_clean(self.check_file('a.html', '<p>' + '<br>'.join(lines) + '</p>'))
        self.assert_clean(self.check_file('b.html', '<p>' + '<br/>'.join(lines) + '</p>'))
        self.assert_clean(self.check_file('c.md', '  \n'.join(lines) + '\n'))
        self.assert_clean(self.check_file('d.md', '\\\n'.join(lines) + '\n'))
        step = ' '.join(['word'] * 20) + '  \n   ' + ' '.join(['word'] * 21) + '\n'
        self.assert_problem(self.check_file('e.md', '1. ' + step), 'sentence-length')

    def test_abbreviations_and_versions_do_not_split_or_merge_sentences(self):
        text = '<p>Mayer et al. (2019) and Sweller et al. found this in v3.6.0.0 and WCAG 1.4.3.</p>'
        self.assert_clean(self.check_file('a.html', text))

    # --- punctuation, contractions, verb forms ----------------------------

    def test_semicolon_in_text_fails(self):
        self.assert_problem(self.check_file('a.md', 'Write the rubric; then test it.\n'), 'semicolon')

    def test_semicolon_in_code_entity_or_citation_passes(self):
        self.assert_clean(self.check_file('a.html', '<p>Run <code>a; b</code> now.</p>'))
        self.assert_clean(self.check_file('b.html', '<p>Text &amp; more text.</p>'))
        self.assert_clean(self.check_file('c.md', 'Text &amp; more text.\n'))
        self.assert_clean(self.check_file('d.md', 'It works (Pashler et al., 2008; Mayer, 2021).\n'))

    def test_contractions_fail_and_possessives_pass(self):
        self.assert_problem(self.check_file('a.md', "Learners don't read it.\n"), 'contraction')
        self.assert_problem(self.check_file('b.md', "It's late.\n"), 'contraction')
        self.assert_clean(self.check_file('c.md', "Bloom's taxonomy has six levels.\n"))
        self.assert_clean(self.check_file('d.md', "Campus IT's help desk supports the LMS.\n"))

    def test_perfect_tense_with_been_fails(self):
        self.assert_problem(self.check_file('a.md', 'The rubric has been changed.\n'), 'verb-form')
        self.assert_problem(self.check_file('b.md', 'The rubric has not been changed.\n'), 'verb-form')
        self.assert_problem(self.check_file('c.md', 'The rubrics have already been changed.\n'), 'verb-form')

    # --- word list --------------------------------------------------------

    def test_word_list_words_and_forms_fail(self):
        for text in ['Utilize the rubric.', 'The rubric is ensured.', 'It is ensuring that.',
                     'Do this prior to the quiz.', 'Use a rubric, e.g. this one.',
                     'You should add a rubric.', 'It verifies the score.',
                     'Start at the beginning.', 'The module began in week 2.',
                     'The instructor chose a quiz.']:
            with self.subTest(text=text):
                self.assert_problem(self.check_file('a.md', text + '\n'), 'word')

    def test_may_is_lowercase_only(self):
        self.assert_problem(self.check_file('a.md', 'You may add a rubric.\n'), 'word')
        self.assert_clean(self.check_file('b.md', 'The session is on May 15.\n'))

    def test_markdown_emphasis_does_not_hide_words(self):
        for text in ['You *should* add a rubric.', 'You **should** add a rubric.',
                     'You _should_ add a rubric.']:
            with self.subTest(text=text):
                self.assert_problem(self.check_file('a.md', text + '\n'), 'word')
        self.assert_clean(self.check_file('b.md', 'Set report_path and $_IDSTACK now.\n'))
        self.assert_clean(self.check_file('c.md', 'Use $_IDSTACK or should_ now.\n'))

    def test_technical_terms_are_not_in_the_word_list(self):
        text = ('Learners analyze, evaluate and create artifacts. The review found a critical '
                'finding about the evidence and the assessment.\n')
        self.assert_clean(self.check_file('a.md', text))

    # --- quoted text ------------------------------------------------------

    def test_quoted_text_is_not_examined(self):
        self.assert_clean(self.check_file('a.md', 'The syllabus says "you should utilize it; do not wait".\n'))
        self.assert_clean(self.check_file('b.html', '<p>It says <q>you should utilize it; do not wait</q>.</p>'))
        self.assert_clean(self.check_file('c.html', '<blockquote>You should utilize it; do not wait.</blockquote>'))
        self.assert_clean(self.check_file('d.html', '<ul><li data-ste="quoted">You should utilize it; wait.</li></ul>'))
        self.assert_clean(self.check_file('e.md', '> You should utilize it; do not wait.\n'))

    def test_text_after_an_open_element_is_examined(self):
        bad = '<p>You should utilize it.</p>'
        self.assert_problem(self.check_file('a.html', '<p>It says <q>wait.</p>' + bad), 'word')
        self.assert_problem(self.check_file('b.html', '<p>Run <code>./setup.</p>' + bad), 'word')
        self.assert_problem(self.check_file('c.html', '<p><img data-ste="quoted" src="x.png"> Text.</p>' + bad),
                            'word')
        self.assert_problem(self.check_file('d.html', '<blockquote>Quoted text.' + bad), 'html')

    def test_long_fence_ends_only_at_a_long_fence(self):
        text = '````markdown\n```bash\nrm a; rm b\n```\nYou should not see this.\n````\n\nText.\n'
        self.assert_clean(self.check_file('a.md', text))
        self.assert_problem(self.check_file('b.md', text + 'You should see this.\n'), 'word')

    def test_markdown_inline_code_and_quotation_are_not_examined(self):
        self.assert_clean(self.check_file('a.md', 'Run <code>a; b</code> in the terminal.\n'))
        self.assert_clean(self.check_file('b.md', 'The syllabus says <q>you should utilize it; do not wait</q>.\n'))

    def test_markdown_table_without_leading_pipe_is_cells(self):
        text = ('Week | Module | Topics\n--- | --- | ---\n'
                '1 | Module 1: Introduction to data | Variables and data types\n'
                '2 | Module 2: Methods | Loops and functions\n'
                '3 | Module 3: Analysis | Data frames and plots\n')
        self.assert_clean(self.check_file('a.md', text))
        long = ' '.join(['word'] * 13) + ' A | B ' + ' '.join(['word'] * 13) + '.\n'
        self.assert_problem(self.check_file('b.md', '| W | M |\n|---|---|\n| 1 | a |\n\n' + long), 'sentence-length')
        self.assert_problem(self.check_file('c.md', long + '---\n'), 'sentence-length')

    def test_bracket_notes_with_words_are_examined(self):
        self.assert_problem(self.check_file('a.md', 'Text. [Note: this is a neuromyth; use dual coding.]\n'),
                            'semicolon')

    # --- input modes and errors -------------------------------------------

    def test_stdin_uses_text_mode(self):
        proc = run_checker(['-'], stdin="  PROBLEM: it doesn't work.\n")
        self.assert_problem(proc, 'contraction')
        self.assertIn('stdin:1:', proc.stdout)

    def test_missing_markers_give_exit_2(self):
        bad = self.write('preamble.md', '# no markers here\n')
        proc = run_checker(['--word-list', bad, '-'], stdin='text\n')
        self.assertEqual(proc.returncode, 2)
        self.assertIn('markers are missing', proc.stderr)

    def test_empty_word_list_gives_exit_2(self):
        bad = self.write('preamble.md', '<!-- ste-core:begin -->\nNo table.\n<!-- ste-core:end -->\n')
        proc = run_checker(['--word-list', bad, '-'], stdin='text\n')
        self.assertEqual(proc.returncode, 2)
        self.assertIn('has no rows', proc.stderr)

    def test_missing_file_gives_exit_2(self):
        proc = run_checker([os.path.join(self.work, 'nothing.md')])
        self.assertEqual(proc.returncode, 2)
        self.assertNotIn('no problems', proc.stdout)

    def test_unreadable_file_does_not_stop_the_other_files(self):
        with open(os.path.join(self.work, 'a.md'), 'wb') as handle:
            handle.write(b'Caf\xe9 text.\n')
        self.write('b.md', 'You should do this.\n')
        proc = run_checker([self.work])
        self.assert_problem(proc, 'word')
        self.assertIn('b.md:1: word:', proc.stdout)
        self.assertIn('did not read 1 file(s)', proc.stdout)

    def test_byte_order_mark_before_front_matter_passes(self):
        path = os.path.join(self.work, 'bom.md')
        with open(path, 'wb') as handle:
            handle.write(b'\xef\xbb\xbf---\ntitle: You should utilize this; ok\n---\n\nThe text is good.\n')
        self.assert_clean(run_checker([path]))

    def test_help_exits_0(self):
        self.assertEqual(run_checker(['--help']).returncode, 0)


if __name__ == '__main__':
    unittest.main()
