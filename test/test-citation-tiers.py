#!/usr/bin/env python3
"""Unit tests for test/check-citation-tiers.py.

Each test builds a small repo with an evidence/references.md and one skill
template, then runs the checker on it. The forms here are the ones a line-by-line
match missed: codes separated by commas, and a citation that a line break splits.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CHECKER = os.path.join(REPO_ROOT, 'test', 'check-citation-tiers.py')
REFS = ('- [Alpha-1] Author, A. (2020). A trial. T1\n'
        '- [Beta-2] Author, B. (2021). An opinion. T5\n')


def run_checker(root):
    return subprocess.run([sys.executable, CHECKER, root], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, universal_newlines=True)


class CitationTierTest(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix='idstack-test-tiers-')
        os.makedirs(os.path.join(self.root, 'evidence'))
        os.makedirs(os.path.join(self.root, 'skills', 'demo'))
        with open(os.path.join(self.root, 'evidence', 'references.md'), 'w', encoding='utf-8') as f:
            f.write(REFS)

    def tearDown(self):
        shutil.rmtree(self.root)

    def check(self, text):
        with open(os.path.join(self.root, 'skills', 'demo', 'SKILL.md.tmpl'), 'w', encoding='utf-8') as f:
            f.write(text)
        return run_checker(self.root)

    def test_correct_citations_pass(self):
        proc = self.check('One [Alpha-1] [T1]. Two [Beta-2] [T5].\n')
        self.assertEqual(proc.returncode, 0, proc.stdout)

    def test_wrong_tier_on_one_line_fails(self):
        proc = self.check('Text [Beta-2] [T1].\n')
        self.assertEqual(proc.returncode, 1)
        self.assertIn('SKILL.md.tmpl:1: [Beta-2] is T5 in evidence/references.md, not T1', proc.stdout)

    def test_each_code_in_a_comma_list_is_checked(self):
        # The code before the comma is the one that a match without commas left out.
        proc = self.check('Text [Beta-2], [Alpha-1] [T1].\n')
        self.assertEqual(proc.returncode, 1)
        self.assertIn('[Beta-2] is T5 in evidence/references.md, not T1', proc.stdout)

    def test_comma_list_at_the_correct_tier_passes(self):
        proc = self.check('Text [Beta-2], [Beta-2] [T5].\n')
        self.assertEqual(proc.returncode, 0, proc.stdout)

    def test_citation_split_by_a_line_break_is_checked(self):
        proc = self.check('First line.\nText that ends with [Beta-2]\n  [T1] and goes on.\n')
        self.assertEqual(proc.returncode, 1)
        self.assertIn('SKILL.md.tmpl:2: [Beta-2] is T5 in evidence/references.md, not T1', proc.stdout)

    def test_split_citation_at_the_correct_tier_passes(self):
        proc = self.check('Text that ends with [Beta-2]\n[T5] and goes on.\n')
        self.assertEqual(proc.returncode, 0, proc.stdout)

    def test_a_blank_line_ends_a_citation(self):
        # A code at the end of one paragraph and a tier at the start of the next are not one citation.
        proc = self.check('Text [Beta-2] [T5] ends with [Alpha-1]\n\n[T5] starts here.\n')
        self.assertEqual(proc.returncode, 0, proc.stdout)

    def test_the_repo_passes(self):
        proc = run_checker(REPO_ROOT)
        self.assertEqual(proc.returncode, 0, proc.stdout)


if __name__ == '__main__':
    unittest.main()
