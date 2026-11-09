#!/usr/bin/env python3
"""Unit tests for bin/idstack-report-section.

Each test runs the shipped script in a temporary course folder against the real
evidence/references.md. [Alignment-14] is T1 and [Needs-8] is T3 there.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
HELPER = os.path.join(REPO_ROOT, 'bin', 'idstack-report-section')
REPORT = '.idstack/exports/bio-101/needs-analysis.md'
DRAFT = '.idstack/.report-section.md'

TASKS = """## Task analysis

| ID | Task | Priority | Justification | Evidence |
|----|------|----------|---------------|----------|
| T-1 | Write a lab report | High | Learners do this task each week. | [Needs-8] [T3] |
"""

FINDINGS = """## Findings

| ID | Severity | What we saw | Recommendation | Justification | Evidence |
|----|----------|-------------|----------------|---------------|----------|
| needs-1 | critical | No module teaches the lab report. | idstack recommends that you add a module. | Practice improves transfer. | [Alignment-14] [T1] |
| needs-2 | info | The course has a glossary. | You can link the glossary. | Learners find terms faster. | [Needs-8] [T3] |
"""

CLOSING = """## Summary

idstack found one critical problem.

## Limitations

idstack did not read the videos.
"""


class ReportSectionTest(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix='idstack-test-section-')
        os.makedirs(os.path.join(self.root, '.idstack'))
        with open(os.path.join(self.root, '.idstack', 'project.json'), 'w', encoding='utf-8') as f:
            f.write('{"project_name": "Bio 101"}')

    def tearDown(self):
        shutil.rmtree(self.root)

    def run_helper(self, *args):
        return subprocess.run([sys.executable, HELPER] + list(args), cwd=self.root,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    def path(self, rel):
        return os.path.join(self.root, rel)

    def write(self, rel, text):
        with open(self.path(rel), 'w', encoding='utf-8') as f:
            f.write(text)

    def read(self, rel):
        with open(self.path(rel), encoding='utf-8') as f:
            return f.read()

    def init(self, *extra):
        result = self.run_helper('init', REPORT, '--skill', 'needs-analysis',
                                 '--title', 'Needs Analysis Report', *extra)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def append(self, text):
        self.write(DRAFT, text)
        return self.run_helper('append', REPORT, DRAFT)

    def check(self, text):
        self.write(DRAFT, text)
        return self.run_helper('check', DRAFT)

    # init -----------------------------------------------------------------

    def test_init_writes_header_status_placeholders_and_footer(self):
        result = self.init('--reserve', 'Score breakdown', '--mode', 'audit')
        self.assertIn('REPORT_STARTED: ' + REPORT, result.stdout)
        text = self.read(REPORT)
        self.assertTrue(text.startswith('# Needs Analysis Report\n'))
        self.assertIn('`/idstack:needs-analysis` · Bio 101', text)
        self.assertIn('mode: audit', text)
        self.assertIn('**Status:** in progress', text)
        self.assertLess(text.index('## Summary'), text.index('## Score breakdown'))
        self.assertIn('\n---\n', text)
        self.assertIn('[Course dashboard](index.md)', text)

    def test_init_refuses_an_unreplaced_placeholder(self):
        result = self.run_helper('init', REPORT, '--skill', 'needs-analysis',
                                 '--title', 'Needs Analysis Report', '--mode', '<mode>')
        self.assertEqual(result.returncode, 2)
        self.assertIn('replace <mode> in --mode', result.stderr)
        self.assertFalse(os.path.exists(self.path(REPORT)))

    def test_init_replaces_an_earlier_report(self):
        self.init()
        self.append(TASKS)
        self.init()
        self.assertNotIn('Task analysis', self.read(REPORT))

    # check ----------------------------------------------------------------

    def test_check_accepts_a_valid_draft(self):
        result = self.check(TASKS + '\n' + FINDINGS)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('CHECK_OK', result.stdout)

    def assert_refused(self, text, message):
        result = self.check(text)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn(message, result.stdout)

    def test_check_refuses_a_tier_that_disagrees_with_references(self):
        self.assert_refused(TASKS.replace('[Needs-8] [T3]', '[Needs-8] [T1]'),
                            '[Needs-8] is T3 in evidence/references.md, not T1.')

    def test_check_refuses_an_unknown_code(self):
        self.assert_refused(TASKS.replace('[Needs-8]', '[Needs-999]'),
                            '[Needs-999] is not in evidence/references.md.')

    def test_check_refuses_a_cell_that_is_not_a_citation(self):
        self.assert_refused(TASKS.replace('[Needs-8] [T3]', 'Ferreira 2013'),
                            'the Evidence cell must have only citations')

    def test_check_refuses_two_tiers_for_one_group(self):
        self.assert_refused(TASKS.replace('[Needs-8] [T3]', '[Needs-8] [Alignment-14] [T3] [T1]'),
                            'gives more than one tier')

    def test_check_accepts_mixed_tiers_written_after_each_code(self):
        result = self.check(TASKS.replace('[Needs-8] [T3]', '[Needs-8] [T3] [Alignment-14] [T1]'))
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_check_refuses_an_empty_justification(self):
        self.assert_refused(TASKS.replace('Learners do this task each week.', ''),
                            'has no justification')

    def test_check_refuses_a_table_without_id_first(self):
        self.assert_refused(TASKS.replace('| ID | Task |', '| Task | ID |'),
                            'the first column of the table in "Task analysis" must be ID')

    def test_check_refuses_a_table_without_justification_and_evidence(self):
        self.assert_refused('## Task analysis\n\n| ID | Task |\n|----|------|\n| T-1 | Lab |\n',
                            'must be Justification and Evidence')

    def test_check_refuses_a_duplicate_id(self):
        row = TASKS.splitlines()[-1]
        self.assert_refused(TASKS + row + '\n', 'is in the table two times')

    def test_check_refuses_a_bad_severity_and_wrong_order(self):
        self.assert_refused(FINDINGS.replace('| info |', '| low |'), 'must be critical, warning or info')
        swapped = FINDINGS.replace('| critical |', '| TMP |').replace('| info |', '| critical |') \
            .replace('| TMP |', '| info |')
        self.assert_refused(swapped, 'put the critical rows first')

    def test_check_refuses_finding_blocks_and_a_title(self):
        self.assert_refused(TASKS + '\n### Finding needs-1\n\ntext\n', 'do not write "### Finding" blocks')
        self.assert_refused('# Title\n\n' + TASKS, 'a draft has no "# " title')

    def test_check_refuses_a_section_without_a_table(self):
        self.assert_refused('## Task analysis\n\nLearners write lab reports.\n', 'has no table')

    def test_check_accepts_prose_and_fact_sections(self):
        fact = '## Project context\n\n| ID | Item | Value |\n|----|------|-------|\n| P-1 | Class size | 30 |\n'
        result = self.check(CLOSING + '\n' + fact)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_check_runs_the_writing_standard(self):
        self.assert_refused(TASKS.replace('Learners do this task each week.',
                                          'You should consider this task.'),
                            'writing standard: word: "should"')

    def test_check_refuses_a_heading_that_repeats(self):
        # append once added the first section and replaced it with the second,
        # so the rows of the first were lost.
        self.assert_refused(TASKS + '\n' + TASKS.replace('T-1', 'T-2'),
                            'the draft has the section "Task analysis" two times')

    def test_check_refuses_a_row_with_the_wrong_cell_count(self):
        self.assert_refused(TASKS + '| T-2 | Short row |\n', 'the row has 2 cells')

    # append ---------------------------------------------------------------

    def test_append_adds_sections_before_the_footer_and_keeps_the_draft(self):
        self.init()
        result = self.append(TASKS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('SECTION_ADDED: Task analysis', result.stdout)
        self.assertIn('Report path: ' + REPORT, result.stdout)
        text = self.read(REPORT)
        self.assertLess(text.index('## Task analysis'), text.index('\n---\n'))
        self.assertTrue(text.rstrip().endswith('[Course dashboard](index.md)'))
        # The draft stays, so that "Change a row" can edit it.
        self.assertTrue(os.path.exists(self.path(DRAFT)))

    def test_approve_with_draft_deletes_the_draft_file(self):
        self.init()
        self.append(TASKS)
        result = self.run_helper('approve', REPORT, '--draft', DRAFT)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse(os.path.exists(self.path(DRAFT)))

    def test_append_replaces_a_section_in_place_and_keeps_the_footer(self):
        self.init()
        self.append(TASKS)
        self.append(FINDINGS)
        result = self.append(TASKS.replace('Write a lab report', 'Write a field report'))
        self.assertIn('SECTION_REPLACED: Task analysis', result.stdout)
        text = self.read(REPORT)
        self.assertEqual(text.count('## Task analysis'), 1)
        self.assertIn('Write a field report', text)
        self.assertNotIn('Write a lab report', text)
        self.assertLess(text.index('## Task analysis'), text.index('## Findings'))
        self.assertIn('Generated by `/idstack:needs-analysis`', text)

    def test_append_writes_one_finding_block_per_approved_row(self):
        self.init()
        self.append(FINDINGS)
        text = self.read(REPORT)
        self.assertEqual(text.count('### Finding '), 2)
        self.assertIn('### Finding needs-1\n\n**Severity:** critical · **Evidence tier:** T1', text)
        self.assertIn('**Why it matters:** Practice improves transfer. [Alignment-14] [T1]', text)
        self.assertIn('**Recommendation:** You can link the glossary.', text)

    def test_append_replacing_findings_does_not_double_the_blocks(self):
        self.init()
        self.append(FINDINGS)
        self.append(FINDINGS.splitlines()[0] + '\n' + '\n'.join(FINDINGS.splitlines()[1:5]) + '\n')
        text = self.read(REPORT)
        self.assertEqual(text.count('### Finding '), 1)
        self.assertNotIn('needs-2', text)

    def test_append_refused_leaves_report_and_draft_unchanged(self):
        self.init()
        before = self.read(REPORT)
        result = self.append(TASKS.replace('[T3]', '[T1]'))
        self.assertEqual(result.returncode, 1)
        self.assertIn('The report did not change.', result.stdout)
        self.assertEqual(self.read(REPORT), before)
        self.assertTrue(os.path.exists(self.path(DRAFT)))

    def test_append_without_a_report_exits_3(self):
        result = self.append(TASKS)
        self.assertEqual(result.returncode, 3)

    def test_init_and_append_keep_a_readable_file_mode(self):
        # mkstemp makes a 0600 file, and the rename once kept that mode.
        old_umask = os.umask(0o022)
        try:
            self.init()
        finally:
            os.umask(old_umask)
        self.assertEqual(os.stat(self.path(REPORT)).st_mode & 0o777, 0o644)
        os.chmod(self.path(REPORT), 0o640)
        self.append(TASKS)
        self.assertEqual(os.stat(self.path(REPORT)).st_mode & 0o777, 0o640)

    def test_append_leaves_no_temporary_file(self):
        self.init()
        self.append(TASKS)
        folder = os.path.dirname(self.path(REPORT))
        self.assertEqual(sorted(os.listdir(folder)), ['needs-analysis.md'])

    # draft and approve ----------------------------------------------------

    def test_append_marks_the_new_section_as_a_draft(self):
        self.init()
        self.append(TASKS)
        text = self.read(REPORT)
        self.assertIn('## Task analysis\n\n**Draft:** this section waits for your approval.\n\n| ID |', text)

    def test_replacing_a_section_keeps_one_draft_mark(self):
        self.init()
        self.append(TASKS)
        self.append(TASKS.replace('Write a lab report', 'Write a field report'))
        self.assertEqual(self.read(REPORT).count('**Draft:**'), 1)

    def test_approve_removes_each_draft_mark(self):
        self.init()
        self.append(TASKS + '\n' + FINDINGS)
        result = self.run_helper('approve', REPORT)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('SECTION_APPROVED: Task analysis', result.stdout)
        self.assertIn('SECTION_APPROVED: Findings', result.stdout)
        text = self.read(REPORT)
        self.assertNotIn('**Draft:**', text)
        self.assertIn('## Task analysis\n\n| ID |', text)

    def test_approve_with_no_draft_exits_1(self):
        self.init()
        self.append(TASKS)
        self.run_helper('approve', REPORT)
        result = self.run_helper('approve', REPORT)
        self.assertEqual(result.returncode, 1)
        self.assertIn('no section waits for approval', result.stdout)

    def test_check_refuses_a_draft_mark_in_the_draft(self):
        self.assert_refused('## Task analysis\n\n**Draft:** this section waits for your approval.\n\n'
                            + '\n'.join(TASKS.splitlines()[2:]) + '\n', 'text that only the script writes')

    # finish ---------------------------------------------------------------

    def test_finish_refuses_a_placeholder(self):
        self.init('--reserve', 'Score breakdown')
        self.append(CLOSING)
        self.run_helper('approve', REPORT)
        result = self.run_helper('finish', REPORT)
        self.assertEqual(result.returncode, 1)
        self.assertIn('"Score breakdown" has no text', result.stdout)
        self.assertIn('**Status:** in progress', self.read(REPORT))

    def test_finish_stopped_fills_a_reserved_section(self):
        # A skill that stops early has no score for its reserved section.
        self.init('--reserve', 'Score breakdown')
        self.append(CLOSING)
        self.run_helper('approve', REPORT)
        result = self.run_helper('finish', REPORT, '--stopped')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('REPORT_COMPLETE', result.stdout)
        text = self.read(REPORT)
        self.assertIn('idstack did not write this section because the skill stopped.', text)
        self.assertNotIn('_idstack writes this section', text)

    def test_finish_stopped_still_needs_the_summary(self):
        self.init('--reserve', 'Score breakdown')
        result = self.run_helper('finish', REPORT, '--stopped')
        self.assertEqual(result.returncode, 1)
        self.assertIn('"Summary" has no text', result.stdout)
        self.assertNotIn('"Score breakdown" has no text', result.stdout)

    def test_finish_refuses_a_draft_section(self):
        # Only the draft is wrong here: the Summary has text and is approved.
        self.init()
        self.append(CLOSING)
        self.run_helper('approve', REPORT)
        self.append(TASKS)
        result = self.run_helper('finish', REPORT)
        self.assertEqual(result.returncode, 1)
        self.assertIn('"Task analysis" is a draft. Ask the user to approve it.', result.stdout)
        self.assertIn('**Status:** in progress', self.read(REPORT))

    def test_finish_removes_the_status_line(self):
        self.init()
        self.append(TASKS)
        self.run_helper('approve', REPORT)
        result = self.append(CLOSING)
        self.assertIn('SECTION_REPLACED: Summary', result.stdout)
        self.run_helper('approve', REPORT)
        result = self.run_helper('finish', REPORT)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('REPORT_COMPLETE', result.stdout)
        text = self.read(REPORT)
        self.assertNotIn('**Status:**', text)
        self.assertNotIn('_idstack writes this section', text)


if __name__ == '__main__':
    unittest.main()
