# Moodle web service fixtures

`test/test-moodle-import.py` sends these files from a fake Moodle, so the tests of
`scripts/idstack-moodle-import` run with no Moodle. Each `<function>.json` file is
the real response of that web service function, recorded from Moodle 4.5.16+
(Build: 20261117, `MOODLE_405_STABLE`) with PHP 8.3 and PostgreSQL 17 in Docker.

The course comes from `seed.php` in this folder. All names and text are made up.
The token user is a teacher in the course. Before the commit, the files were
examined for the token, and `userprivateaccesskey` in
`core_webservice_get_site_info.json` was changed to `scrubbed`. The quiz password
`quizpass-123` is in the fixture on purpose: the tests make sure that the import
does not copy it.

The `error-*.json` files are real Moodle errors. Moodle sends them with HTTP 200:

| File | Request |
|------|---------|
| `error-invalid-token.json` | Any function with a token that Moodle does not know |
| `error-function-not-allowed.json` | `core_grading_get_definitions` with a Moodle app service token |
| `error-course-not-found.json` | `core_course_get_courses_by_field` with a course ID that does not exist |
| `error-grading-activeonly.json` | `core_grading_get_definitions` with `activeonly=1`, when one assignment uses simple grading |

## Record the files again

1. Start Moodle: clone `moodle/moodle` (a `MOODLE_*_STABLE` branch) and
   `moodlehq/moodle-docker`. Copy `config.docker-template.php` to `config.php` in
   the Moodle folder. Run Postgres and `moodlehq/moodle-php-apache` on one Docker
   network (the Postgres network alias is `db`), with the `MOODLE_DOCKER_*`
   variables from `moodle-docker/base.yml` and `db.pgsql.yml`, and port
   `127.0.0.1:8000`. Install with `php admin/cli/install_database.php`.
2. Copy `seed.php` into the Moodle folder and run `php seed.php` as `www-data`.
   It prints the course ID and two tokens. The first token is for the Moodle app
   service. The second token is for a service that also has
   `core_grading_get_definitions`.
3. Call each function with the second token and save the response. Send the token
   in the POST body, for example
   `printf 'wstoken=%s&wsfunction=%s&moodlewsrestformat=json&%s' "$TOKEN" "$FUNCTION" "$ARGS" | curl -s --data-binary @- http://localhost:8000/webservice/rest/server.php`.
   The arguments are in `scripts/idstack-moodle-import`.
4. Change `userprivateaccesskey` to `scrubbed`. Search the files for the token.
   Then remove the Docker containers and the network.
