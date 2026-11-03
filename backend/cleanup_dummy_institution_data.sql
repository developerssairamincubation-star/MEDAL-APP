-- Removes the sample Institution (Student / Staff / Principal) data that the old
-- seed script and mock repository created. It touches ONLY:
--   * the sample accounts listed in `dummy_users` below (and their rows), and
--   * the sample courses 2-6 (course 1 is the real SEEK course and is kept;
--     its details are rewritten from data/seek_course_chapters.json at API start-up).
-- Citizen, Authority and Admin accounts, and any real student/staff/principal
-- that registered themselves, are NOT touched.
--
-- HOW TO USE (PostgreSQL):
--   1. Run as-is: it ends in ROLLBACK, so it only PREVIEWS the counts.
--   2. Check the output. If the rows are all sample data, change the last line
--      from ROLLBACK to COMMIT and run again.
--   3. Take a database backup first.

BEGIN;

CREATE TEMP TABLE dummy_users AS
SELECT id, email, role FROM users
WHERE lower(email) IN (
    'kajolmisra@medal.gov',
    'dilli.ganesh@medal.gov',
    'steverogers@medal.gov',
    'principal@medal.gov',
    'staff@medal.gov',
    'sarah.jenkins@medal.gov'
);

-- Preview: who would be removed
SELECT 'users to delete' AS what, id, email, role FROM dummy_users ORDER BY id;
SELECT 'completions'  AS what, count(*) FROM student_chapter_completions WHERE user_id IN (SELECT id FROM dummy_users);
SELECT 'enrollments'  AS what, count(*) FROM student_enrollments        WHERE user_id IN (SELECT id FROM dummy_users);
SELECT 'certificates' AS what, count(*) FROM student_certificates        WHERE user_id IN (SELECT id FROM dummy_users);
SELECT 'notifications' AS what, count(*) FROM student_notifications      WHERE user_id IN (SELECT id FROM dummy_users);
SELECT 'courses to delete (id > 1)' AS what, id, title FROM student_courses WHERE id > 1 ORDER BY id;

-- Delete (children first)
DELETE FROM student_chapter_completions WHERE user_id IN (SELECT id FROM dummy_users);
DELETE FROM student_certificates        WHERE user_id IN (SELECT id FROM dummy_users);
DELETE FROM student_notifications       WHERE user_id IN (SELECT id FROM dummy_users);
DELETE FROM student_enrollments         WHERE user_id IN (SELECT id FROM dummy_users);
DELETE FROM users                       WHERE id      IN (SELECT id FROM dummy_users);

-- Sample courses 2-6 and anything attached to them
DELETE FROM student_enrollments WHERE course_id > 1;
DELETE FROM student_course_chapters WHERE course_id > 1;
DELETE FROM student_courses WHERE id > 1;

-- Review, then change ROLLBACK to COMMIT.
ROLLBACK;
