"""COURSES (both platforms). Items 13-14."""
import importlib.util
import json
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.exc import IntegrityError

import app.services.seek_chapters as seek
from app.models.student import StudentChapterCompletion, StudentCertificate, StudentCourse, StudentCourseChapter
from app.services.seek_chapters import init_chapters, load_chapters
from conftest import PASSWORD, SEED
from markers import bug, missing


def _count(db, model):
    db.expire_all()
    return db.query(model).count()


def _complete(client, headers, chapter_id, completed=True):
    return client.put(f"/student/chapters/{chapter_id}/completion", json={"completed": completed}, headers=headers)


def _point_startup_at(monkeypatch, path):
    """init_chapters() calls load_chapters(db) whose default path is bound at import time."""
    real = seek.load_chapters
    monkeypatch.setattr(seek, "load_chapters", lambda db: real(db, path))


# ── 13. Course / chapter loading ────────────────────────────────────────

class TestChapterLoading:
    @missing("there is no course scraper: content is read from backend/data/seek_course_chapters.json at startup "
             "(load_chapters). 'Unreachable source' and 'malformed scraped content' therefore map to missing / "
             "invalid JSON, tested below. No daily-content job exists either.")
    def test_scraper_module_exists(self):
        assert importlib.util.find_spec("app.services.scraper") is not None

    def test_valid_file_loads_course_and_chapters(self, db, seed_file):
        assert load_chapters(db, seed_file()) == 4
        course = db.query(StudentCourse).one()
        assert (course.title, course.total_modules, course.duration) == ("SEEK Course", 2, "1h 40m")
        assert [c.chapter_key for c in db.query(StudentCourseChapter).order_by(StudentCourseChapter.position)] == \
            ["1.1", "1.2", "2.1", "2.2"]

    def test_rerun_creates_no_duplicates(self, db, seed_file):
        path = seed_file()
        load_chapters(db, path)
        ids = sorted(c.id for c in db.query(StudentCourseChapter))
        for _ in range(3):
            assert load_chapters(db, path) == 4
        assert _count(db, StudentCourseChapter) == 4 and _count(db, StudentCourse) == 1
        assert sorted(c.id for c in db.query(StudentCourseChapter)) == ids        # ids are stable

    def test_rerun_updates_in_place_and_keeps_user_progress(self, client, db, seed_file, make_user, auth):
        load_chapters(db, seed_file())
        user = make_user("student")
        first = db.query(StudentCourseChapter).order_by(StudentCourseChapter.position).first()
        _complete(client, auth(user), first.id)
        changed = json.loads(json.dumps(SEED))
        changed["chapters"][0]["title"] = "Renamed chapter"
        load_chapters(db, seed_file(changed))
        db.expire_all()
        assert db.get(StudentCourseChapter, first.id).title == "Renamed chapter"
        assert _count(db, StudentChapterCompletion) == 1

    def test_missing_source_loads_nothing(self, db, tmp_path):
        assert load_chapters(db, str(tmp_path / "does-not-exist.json")) == 0
        assert _count(db, StudentCourseChapter) == 0

    def test_malformed_json_raises_and_startup_hook_swallows_it(self, db, seed_file, monkeypatch):
        bad = seed_file(raw='{"course": {"title": "x"}, "chapters": [')
        with pytest.raises(json.JSONDecodeError):
            load_chapters(db, bad)
        _point_startup_at(monkeypatch, bad)
        init_chapters()                                   # must not raise (documented "Never raises")
        assert _count(db, StudentCourseChapter) == 0

    def test_chapter_missing_required_field_is_not_partially_saved(self, db, seed_file):
        broken = json.loads(json.dumps(SEED))
        del broken["chapters"][2]["title"]
        with pytest.raises(KeyError):
            load_chapters(db, seed_file(broken))
        db.rollback()
        assert _count(db, StudentCourseChapter) == 0

    def test_startup_hook_loads_seed_via_real_entrypoint(self, db, seed_file, monkeypatch):
        _point_startup_at(monkeypatch, seed_file())
        init_chapters()
        assert _count(db, StudentCourseChapter) == 4

    @bug("BUG-19", "two chapters with the same key in one file crash the whole load with IntegrityError "
                   "(SessionLocal has autoflush=False so the loader's existence check cannot see the pending row)")
    def test_duplicate_keys_inside_the_file_are_tolerated(self, db, seed_file):
        dup = json.loads(json.dumps(SEED))
        dup["chapters"].append(dict(dup["chapters"][0]))
        try:
            load_chapters(db, seed_file(dup))
        except IntegrityError:
            db.rollback()
            pytest.fail("IntegrityError: duplicate (course_id, chapter_key)")
        assert _count(db, StudentCourseChapter) == 4

    @bug("BUG-20", "chapters deleted from the data file stay in the database forever (upsert-only), so they "
                   "keep counting toward total_chapters and users can never reach 100%")
    def test_removed_chapter_leaves_the_course(self, db, seed_file):
        load_chapters(db, seed_file())
        smaller = json.loads(json.dumps(SEED))
        smaller["chapters"] = smaller["chapters"][:3]
        load_chapters(db, seed_file(smaller))
        assert _count(db, StudentCourseChapter) == 3


# ── 14. Progress tracking + certificates ────────────────────────────────

class TestProgressAndCertificates:
    @pytest.fixture()
    def student(self, make_user, auth):
        u = make_user("student")
        return u, auth(u)

    def test_progress_numbers_across_endpoints(self, client, student, course):
        _, h = student
        _complete(client, h, course[0].id)
        _complete(client, h, course[1].id)
        dash = client.get("/student/dashboard", headers=h).json()
        assert dash["overall_completion_pct"] == 50 and dash["chapters"] == {"completed": 2, "total": 4}
        assert dash["study_minutes"] == 30 and dash["streak_days"] == 1
        prog = client.get("/student/progress", headers=h).json()[0]
        assert prog["progress_pct"] == 0.5 and prog["remaining_modules"] == 2 and prog["status"] == "In Progress"
        assert dash["stats"]["certifications_ready"] == 0

    def test_no_certificate_until_complete(self, client, student, course, db):
        _, h = student
        assert client.get("/student/certificates", headers=h).json() == []
        for c in course[:3]:
            _complete(client, h, c.id)
        assert client.get("/student/certificates", headers=h).json() == []
        assert _count(db, StudentCertificate) == 0

    def test_certificate_after_completion_is_issued_once_and_per_user(self, client, student, course, db, make_user, auth):
        user, h = student
        for c in course:
            _complete(client, h, c.id)
        first = client.get("/student/certificates", headers=h).json()
        second = client.get("/student/certificates", headers=h).json()
        assert len(first) == 1 and first == second
        assert first[0]["certificate_no"] == f"MED-C{course[0].course_id}-U{user.id}"
        assert _count(db, StudentCertificate) == 1
        assert client.get("/student/certificates", headers=auth(make_user("student"))).json() == []

    def test_certificate_withdrawn_view_when_a_chapter_is_unticked(self, client, student, course):
        _, h = student
        for c in course:
            _complete(client, h, c.id)
        _complete(client, h, course[0].id, completed=False)
        assert client.get("/student/certificates", headers=h).json() == []

    @bug("BUG-19b (MEDIUM)", "certificate download_url ('/certificates/download/<no>.pdf') is not served by any route; it 404s")
    def test_certificate_download_link_works(self, client, student, course):
        _, h = student
        for c in course:
            _complete(client, h, c.id)
        url = client.get("/student/certificates", headers=h).json()[0]["download_url"]
        assert client.get(url, headers=h).status_code == 200

    @bug("BUG-20b (LOW)", "certificate 'COMPLETED <MON YYYY>' is stamped when the certificate is first viewed, "
                          "not when the course was finished")
    def test_certificate_date_is_completion_date(self, client, student, course, db):
        user, h = student
        for c in course:
            _complete(client, h, c.id)
        long_ago = datetime.now(timezone.utc) - timedelta(days=100)
        db.query(StudentChapterCompletion).filter(StudentChapterCompletion.user_id == user.id).update({"completed_at": long_ago})
        db.commit()
        cert = client.get("/student/certificates", headers=h).json()[0]
        assert cert["completed_date_str"] == f"COMPLETED {long_ago.strftime('%b %Y').upper()}"

    @bug("BUG-21 (LOW)", "PATCH /student/profile returns a hard-coded study_hours=7 regardless of real activity")
    def test_profile_study_hours_is_real(self, client, student, course):
        _, h = student
        r = client.patch("/student/profile", json={"phone": "123"}, headers=h).json()
        assert r["data"]["study_hours"] == 0
