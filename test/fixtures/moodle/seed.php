<?php
// Make the fake test course that test/fixtures/moodle/*.json were recorded from.
// See README.md in this folder. All names and text are made up.
define('CLI_SCRIPT', true);
require(__DIR__ . '/config.php');
require_once($CFG->dirroot . '/lib/phpunit/classes/util.php');
require_once($CFG->dirroot . '/webservice/lib.php');

\core\session\manager::set_user(get_admin());
$gen = phpunit_util::get_data_generator();

// Web services: REST on, mobile service on.
set_config('enablewebservices', 1);
set_config('webserviceprotocols', 'rest');
set_config('enablemobilewebservice', 1);
$DB->set_field('external_services', 'enabled', 1, ['shortname' => MOODLE_OFFICIAL_MOBILE_SERVICE]);
// An admin lets authenticated users call REST (needed for a custom service).
$userrole = $DB->get_field('role', 'id', ['shortname' => 'user']);
assign_capability('webservice/rest:use', CAP_ALLOW, $userrole, context_system::instance()->id, true);

$teacher = $gen->create_user(['username' => 'teacher1', 'firstname' => 'Test', 'lastname' => 'Teacher',
    'email' => 'teacher1@example.com']);

$course = $gen->create_course([
    'fullname' => 'Introduction to Data Ethics',
    'shortname' => 'DATA101',
    'summary' => '<p>An online course about ethical choices in data work.</p>',
    'format' => 'topics',
    'numsections' => 3,
    'startdate' => 1767225600, // 2026-01-01
    'enddate' => 1777593600,   // 2026-05-01
    'enablecompletion' => 1,
]);
$gen->enrol_user($teacher->id, $course->id, 'editingteacher');

$sections = [
    1 => ['Week 1: Data and privacy', '<p>By the end of this week, learners will be able to explain the main principles of data privacy.</p>'],
    2 => ['Week 2: Algorithmic bias', '<p>Learners will be able to evaluate a model for bias against a protected group.</p>'],
    3 => ['Week 3: Final project', '<p>Learners will design an ethics review plan for a data project.</p>'],
];
foreach ($sections as $num => [$name, $summary]) {
    $s = $DB->get_record('course_sections', ['course' => $course->id, 'section' => $num]);
    $DB->update_record('course_sections', (object)['id' => $s->id, 'name' => $name,
        'summary' => $summary, 'summaryformat' => FORMAT_HTML]);
}
rebuild_course_cache($course->id, true);

$gen->create_module('page', ['course' => $course->id, 'section' => 0, 'name' => 'Course syllabus',
    'intro' => '<p>Read the syllabus first.</p>', 'content' => '<p>Office hours: Tuesday. Tech support: helpdesk.</p>']);
$gen->create_module('forum', ['course' => $course->id, 'section' => 0, 'name' => 'Introduce yourself',
    'intro' => '<p>Tell the class about your work with data.</p>']);
$gen->create_module('page', ['course' => $course->id, 'section' => 1, 'name' => 'Reading: privacy principles',
    'intro' => '<p>Short reading.</p>']);
$gen->create_module('url', ['course' => $course->id, 'section' => 1, 'name' => 'GDPR overview',
    'externalurl' => 'https://example.com/gdpr']);
$quiz = $gen->create_module('quiz', ['course' => $course->id, 'section' => 1, 'name' => 'Privacy check quiz',
    'intro' => '<p>Ten questions on privacy terms.</p>', 'grade' => 10, 'timelimit' => 900, 'attempts' => 2]);
// A quiz password, so the tests prove that the import does not copy it.
$DB->set_field('quiz', 'password', 'quizpass-123', ['id' => $quiz->id]);

$rubricassign = $gen->create_module('assign', ['course' => $course->id, 'section' => 2, 'name' => 'Bias audit report',
    'intro' => '<p>Audit a public model for bias and write a two-page report.</p>', 'grade' => 100,
    'duedate' => 1771200000, 'assignsubmission_onlinetext_enabled' => 1]);
$gen->create_module('forum', ['course' => $course->id, 'section' => 2, 'name' => 'Bias case discussion',
    'intro' => '<p>Discuss one case of algorithmic bias.</p>', 'type' => 'general']);
$guideassign = $gen->create_module('assign', ['course' => $course->id, 'section' => 3, 'name' => 'Ethics review plan',
    'intro' => '<p>Write an ethics review plan for a project of your choice.</p>', 'grade' => 50,
    'assignsubmission_file_enabled' => 1]);
$gen->create_module('assign', ['course' => $course->id, 'section' => 3, 'name' => 'Reflection journal',
    'intro' => '<p>Write a short reflection.</p>', 'grade' => 10]);

$rgen = $gen->get_plugin_generator('gradingform_rubric');
$rgen->create_instance(context_module::instance($rubricassign->cmid), 'mod_assign', 'submissions',
    'Bias audit rubric', 'Rubric for the bias audit report.', [
        'Identifies the bias' => ['Bias not identified' => 0, 'Bias partly identified' => 10, 'Bias clearly identified' => 20],
        'Uses evidence' => ['No evidence' => 0, 'Some evidence' => 15, 'Strong evidence' => 30],
    ]);
$ggen = $gen->get_plugin_generator('gradingform_guide');
$ggen->create_instance(context_module::instance($guideassign->cmid), 'mod_assign', 'submissions',
    'Ethics plan guide', 'Marking guide for the plan.', [
        'Risks' => ['description' => 'Names the main ethical risks.', 'descriptionmarkers' => 'Look for at least three risks.', 'maxscore' => 25],
        'Mitigation' => ['description' => 'Gives a mitigation for each risk.', 'descriptionmarkers' => 'Each mitigation is practical.', 'maxscore' => 25],
    ]);

$cgen = $gen->get_plugin_generator('core_competency');
$fw = $cgen->create_framework(['shortname' => 'Data ethics skills', 'idnumber' => 'DES']);
foreach ([['DE1', 'Explain data privacy principles'], ['DE2', 'Evaluate algorithmic bias']] as [$id, $name]) {
    $c = $cgen->create_competency(['competencyframeworkid' => $fw->get('id'), 'idnumber' => $id,
        'shortname' => $name, 'description' => "<p>$name in a real data project.</p>"]);
    $cgen->create_course_competency(['courseid' => $course->id, 'competencyid' => $c->get('id')]);
}

// Custom service with the grading function, as an admin would set it up.
$wsman = new webservice();
$sid = $wsman->add_external_service((object)['name' => 'idstack import', 'shortname' => 'idstack_import',
    'enabled' => 1, 'restrictedusers' => 0, 'downloadfiles' => 0, 'uploadfiles' => 0]);
foreach (['core_webservice_get_site_info', 'core_course_get_courses_by_field', 'core_course_get_contents',
          'mod_assign_get_assignments', 'core_grading_get_definitions', 'mod_quiz_get_quizzes_by_courses',
          'mod_forum_get_forums_by_courses', 'mod_page_get_pages_by_courses',
          'core_competency_list_course_competencies'] as $f) {
    $wsman->add_external_function_to_service($f, $sid);
}
$syscontext = context_system::instance();
$mobile = $DB->get_record('external_services', ['shortname' => MOODLE_OFFICIAL_MOBILE_SERVICE]);
$custom = $DB->get_record('external_services', ['id' => $sid]);
$tmobile = \core_external\util::generate_token(EXTERNAL_TOKEN_PERMANENT, $mobile, $teacher->id, $syscontext);
$tcustom = \core_external\util::generate_token(EXTERNAL_TOKEN_PERMANENT, $custom, $teacher->id, $syscontext);
echo "COURSE_ID=$course->id\nTOKEN_MOBILE=$tmobile\nTOKEN_CUSTOM=$tcustom\n";
