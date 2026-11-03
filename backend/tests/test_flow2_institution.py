"""FLOW 2 - institution platform (Principal / Staff / Student). Items 7-12."""
from datetime import datetime, timedelta, timezone

import pytest

from conftest import PASSWORD
from markers import bug, missing


def _complete(client, headers, chapter_id, completed=True):
    return client.put(f"/student/chapters/{chapter_id}/completion", json={"completed": completed}, headers=headers)


def _set_completed_at(db, user_id, when):
    from app.models.student import StudentChapterCompletion
    db.query(StudentChapterCompletion).filter(StudentChapterCompletion.user_id == user_id).update({"completed_at": when})
    db.commit()


@pytest.fixture()
def register_student(client, school):
    def _reg(email="stu@example.com", sid="S1", reg="R1", name="Stu Dent", password=PASSWORD, code=None):
        r = client.post("/student/register", json={
            "school_code": code or school.code, "name": name, "email": email, "department": "Science", "student_id": sid,
            "registration_number": reg, "password": password, "confirm_password": password})
        assert r.status_code == 201, r.text
        return {"id": r.json()["data"]["id"], "headers": {"Authorization": f"Bearer {r.json()['access_token']}"}}
    return _reg


# ── 7. Principal login ──────────────────────────────────────────────────

class TestPrincipalLogin:
    def test_principal_logs_in(self, client, principal):
        r = client.post("/login", json={"email": principal.email, "password": PASSWORD})
        assert r.status_code == 200 and r.json()["data"]["role"] == "principal"

    def test_wrong_password_rejected(self, client, principal):
        assert client.post("/login", json={"email": principal.email, "password": "nope"}).status_code == 401

    def test_inactive_principal_cannot_log_in(self, client, make_user):
        p = make_user("principal", is_active=False)
        assert client.post("/login", json={"email": p.email, "password": PASSWORD}).status_code == 400


# ── 8. Add / invite teacher ─────────────────────────────────────────────

class TestAddTeacher:
    BODY = {"name": "Tara Teacher", "email": "tara@example.com", "department": "Maths"}

    def test_principal_creates_staff_who_can_log_in(self, client, principal, auth, outbox):
        r = client.post("/institution/staff", json=self.BODY, headers=auth(principal))
        assert r.status_code == 201
        temp = r.json()["temporary_password"]
        assert len(temp) >= 8
        assert r.json()["staff"]["role"] == "staff" and r.json()["staff"]["total_chapters"] == 0
        login = client.post("/login", json={"email": "tara@example.com", "password": temp})
        assert login.status_code == 200 and login.json()["data"]["role"] == "staff"

    def test_password_is_stored_hashed_only(self, client, principal, auth, db):
        r = client.post("/institution/staff", json=self.BODY, headers=auth(principal))
        from app.models.user import User
        stored = db.query(User).filter(User.email == "tara@example.com").one().password_hash
        assert r.json()["temporary_password"] not in stored and stored.startswith("$2")

    def test_duplicate_email_handled(self, client, principal, auth):
        h = auth(principal)
        assert client.post("/institution/staff", json=self.BODY, headers=h).status_code == 201
        assert client.post("/institution/staff", json=self.BODY, headers=h).status_code == 400
        upper = dict(self.BODY, email="TARA@example.com")
        assert client.post("/institution/staff", json=upper, headers=h).status_code == 400

    def test_email_of_existing_citizen_is_a_duplicate(self, client, principal, auth, make_user):
        make_user("citizen", email="taken@example.com")
        r = client.post("/institution/staff", json=dict(self.BODY, email="taken@example.com"), headers=auth(principal))
        assert r.status_code == 400

    @pytest.mark.parametrize("body", [
        {"name": "x", "email": "not-an-email"},
        {"name": "x"},
        {"email": "a@example.com"},
    ])
    def test_invalid_payload_rejected(self, client, principal, auth, body):
        assert client.post("/institution/staff", json=body, headers=auth(principal)).status_code == 422

    def test_blank_name_rejected(self, client, principal, auth):
        assert client.post("/institution/staff", json=dict(self.BODY, name=""), headers=auth(principal)).status_code == 400

    @pytest.mark.parametrize("role", ["staff", "student", "citizen", "official", "admin"])
    def test_only_principal_can_add_staff(self, client, make_user, auth, role):
        r = client.post("/institution/staff", json=self.BODY, headers=auth(make_user(role)))
        assert r.status_code == 403

    def test_unauthenticated_cannot_add_staff(self, client):
        assert client.post("/institution/staff", json=self.BODY).status_code == 401

    @bug("BUG-16", "staff e-mail is lower-cased on write but /login compares exactly, so a teacher who types "
                   "'Tara@example.com' (phone keyboards capitalise) is told the password is wrong")
    def test_staff_can_log_in_with_capitalised_email(self, client, principal, auth):
        temp = client.post("/institution/staff", json=dict(self.BODY, email="tara@example.com"),
                           headers=auth(principal)).json()["temporary_password"]
        assert client.post("/login", json={"email": "Tara@example.com", "password": temp}).status_code == 200

    def test_whitespace_name_rejected(self, client, principal, auth):
        r = client.post("/institution/staff", json=dict(self.BODY, name="   "), headers=auth(principal))
        assert r.status_code == 400

    @missing("no e-mail invite flow: POST /institution/staff creates the account immediately and returns a "
             "temporary password in the HTTP response; nothing is e-mailed, there is no invite token/link, "
             "no expiry, no single-use check and no 'subjects' field. Spec: invite e-mailed, link works once, "
             "expired/reused link fails.")
    def test_invite_email_is_sent_and_link_is_single_use(self, client, principal, auth, outbox):
        r = client.post("/institution/staff/invite",
                        json={"name": "T", "subjects": ["Maths"], "email": "inv@example.com"}, headers=auth(principal))
        assert r.status_code in (200, 201)
        assert len(outbox) == 1 and outbox[0]["to"] == "inv@example.com"


# ── 9. Bulk CSV ─────────────────────────────────────────────────────────

class TestBulkCsv:
    @missing("no CSV template download (teacher name, subjects, email)")
    def test_template_download(self, client, principal, auth):
        r = client.get("/institution/staff/template", headers=auth(principal))
        assert r.status_code == 200 and "text/csv" in r.headers["content-type"]

    @missing("no bulk CSV import endpoint, so valid / empty / missing-column / invalid-email / duplicate / "
             "large-file cases and the partial-failure report cannot be exercised")
    def test_bulk_import_partial_failure_report(self, client, principal, auth):
        csv = "teacher name,subjects,email\nA,Maths,a@example.com\nB,Sci,not-an-email\nC,Eng,a@example.com\n"
        r = client.post("/institution/staff/bulk", files={"file": ("t.csv", csv, "text/csv")}, headers=auth(principal))
        assert r.status_code == 200
        body = r.json()
        assert body["created"] == 1 and len(body["errors"]) == 2


# ── 10. Principal dashboard ─────────────────────────────────────────────

class TestPrincipalDashboard:
    def test_empty_state_no_course_no_members(self, client, principal, auth):
        d = client.get("/institution/dashboard", headers=auth(principal)).json()
        assert d == {"total_staff": 0, "total_students": 0, "certification_ready": 0, "active_students": 0,
                     "inactive_students": 0, "enrollment_pending": 0, "total_chapters": 0, "recent_activity": []}

    def test_empty_state_with_course_but_no_progress(self, client, principal, auth, course, make_user):
        make_user("staff"); make_user("student")
        d = client.get("/institution/dashboard", headers=auth(principal)).json()
        assert (d["total_staff"], d["total_students"], d["total_chapters"]) == (1, 1, 4)
        assert d["certification_ready"] == 0 and d["active_students"] == 0 and d["inactive_students"] == 1
        assert d["recent_activity"] == []
        staff = client.get("/institution/staff", headers=auth(principal)).json()[0]
        assert staff["progress_pct"] == 0.0 and staff["status"] == "not_started" and staff["last_active"] is None

    def test_populated_numbers_match_database(self, client, principal, auth, course, make_user, db):
        hp = auth(principal)
        t1, t2 = make_user("staff", full_name="Alpha"), make_user("staff", full_name="Beta")
        s1, s2, s3 = (make_user("student", full_name=n) for n in ("S One", "S Two", "S Three"))
        make_user("student", is_active=False)              # deactivated: must not be counted
        ids = [c.id for c in course]
        for c in ids:                                       # t1 finishes the whole course
            _complete(client, auth(t1), c)
        for c in ids[:2]:                                   # s1: 2/4
            _complete(client, auth(s1), c)
        _complete(client, auth(s2), ids[0])                 # s2: 1/4 but long ago -> inactive
        _set_completed_at(db, s2.id, datetime.now(timezone.utc) - timedelta(days=40))

        d = client.get("/institution/dashboard", headers=hp).json()
        assert d["total_staff"] == 2 and d["total_students"] == 3 and d["total_chapters"] == 4
        assert d["certification_ready"] == 1                # only t1 completed everything
        assert d["active_students"] == 1 and d["inactive_students"] == 2
        assert len(d["recent_activity"]) == 7               # 4 + 2 + 1 completions
        assert all(a["action"].startswith("Completed chapter: ") for a in d["recent_activity"])

        by_name = {m["name"]: m for m in client.get("/institution/staff", headers=hp).json()}
        assert by_name["Alpha"]["completed_chapters"] == 4 and by_name["Alpha"]["status"] == "completed"
        assert by_name["Alpha"]["progress_pct"] == 1.0
        assert by_name["Beta"]["completed_chapters"] == 0 and by_name["Beta"]["status"] == "not_started"
        studs = {m["name"]: m for m in client.get("/institution/students", headers=hp).json()}
        assert studs["S One"]["progress_pct"] == 0.5 and studs["S One"]["status"] == "in_progress"
        assert studs["S Two"]["completed_chapters"] == 1 and studs["S Three"]["completed_chapters"] == 0
        assert "S One" in studs and len(studs) == 3

    def test_recent_activity_is_capped_and_newest_first(self, client, principal, auth, course, make_user):
        users = [make_user("student", full_name=f"S{i}") for i in range(4)]
        for u in users:
            for c in course:
                _complete(client, auth(u), c.id)
        act = client.get("/institution/dashboard", headers=auth(principal)).json()["recent_activity"]
        assert len(act) == 10
        times = [a["completed_at"] for a in act]
        assert times == sorted(times, reverse=True)

    @missing("dashboard has no per-class performance metric (no class concept in the data model); only per-member "
             "chapter progress. Spec item 10 asks for class performance.")
    def test_class_performance_metric(self, client, principal, auth):
        assert client.get("/institution/classes", headers=auth(principal)).status_code == 200


# ── 11. Teacher visibility ──────────────────────────────────────────────

class TestTeacherScope:
    def test_teacher_sees_students_progress_and_not_other_staff(self, client, make_user, auth, course):
        teacher, other_staff, student = make_user("staff"), make_user("staff"), make_user("student")
        principal = make_user("principal")
        h = auth(teacher)
        _complete(client, auth(student), course[0].id)
        r = client.get(f"/institution/members/{student.id}/progress", headers=h)
        assert r.status_code == 200
        assert r.json()["member"]["completed_chapters"] == 1
        assert r.json()["course"]["completed_chapters"] == 1
        assert client.get(f"/institution/members/{other_staff.id}/progress", headers=h).status_code == 403
        assert client.get(f"/institution/members/{principal.id}/progress", headers=h).status_code == 404
        assert client.get("/institution/members/99999/progress", headers=h).status_code == 404

    def test_teacher_can_see_their_own_course_progress(self, client, make_user, auth, course):
        teacher = make_user("staff")
        h = auth(teacher)
        _complete(client, h, course[0].id)
        r = client.get(f"/student/courses/{course[0].course_id}/chapters", headers=h).json()
        assert r["completed_chapters"] == 1 and r["total_chapters"] == 4
        assert client.get("/student/dashboard", headers=h).json()["overall_completion_pct"] == 25

    def test_teacher_cannot_use_principal_only_endpoints(self, client, make_user, auth):
        h = auth(make_user("staff"))
        assert client.get("/institution/staff", headers=h).status_code == 403
        assert client.post("/institution/staff", json={"name": "x", "email": "x@example.com"}, headers=h).status_code == 403

    @pytest.mark.parametrize("role", ["student", "citizen", "official", "admin"])
    def test_other_roles_cannot_read_institution_data(self, client, make_user, auth, role):
        h = auth(make_user(role))
        for path in ("/institution/dashboard", "/institution/students", "/institution/members/1/progress"):
            assert client.get(path, headers=h).status_code == 403

    @missing("no class / teacher<->student assignment in the data model. A teacher therefore sees EVERY student "
             "(GET /institution/students) and can fetch any student's progress by swapping the id in "
             "/institution/members/{id}/progress. Spec: teacher sees only own classes/students; ID swap must fail.")
    def test_teacher_cannot_see_another_teachers_students_by_id_swap(self, client, make_user, auth, course):
        t_a, t_b = make_user("staff"), make_user("staff")
        stu_of_a = make_user("student")
        # (assignment of stu_of_a to t_a would happen here; no API exists)
        assert client.post(f"/institution/classes", json={"teacher_id": t_a.id, "student_ids": [stu_of_a.id]},
                           headers=auth(make_user("principal"))).status_code in (200, 201)
        assert client.get(f"/institution/members/{stu_of_a.id}/progress", headers=auth(t_b)).status_code == 403

    @bug("BUG-17 (MEDIUM)", "GET /institution/dashboard for a teacher returns school-wide data: every staff member's "
                            "count and every colleague's chapter activity (names), not just the teacher's own")
    def test_teacher_dashboard_is_scoped_to_the_teacher(self, client, make_user, auth, course):
        t_a, t_b = make_user("staff", full_name="Teacher A"), make_user("staff", full_name="Teacher B")
        _complete(client, auth(t_b), course[0].id)
        d = client.get("/institution/dashboard", headers=auth(t_a)).json()
        assert d["total_staff"] <= 1
        assert "Teacher B" not in [a["name"] for a in d["recent_activity"]]


# ── 12. Student takes the course ────────────────────────────────────────

class TestStudentCourse:
    def test_registration_validations(self, client, register_student):
        register_student("a@example.com", "S1", "R1")
        base = {"school_code": "TESTSCH", "name": "N", "department": "D", "student_id": "S9", "registration_number": "R9",
                "password": PASSWORD, "confirm_password": PASSWORD, "email": "n@example.com"}
        assert client.post("/student/register", json=dict(base, confirm_password="different")).status_code == 400
        assert client.post("/student/register", json=dict(base, password="abc", confirm_password="abc")).status_code == 400
        assert client.post("/student/register", json=dict(base, email="A@example.com")).status_code == 400   # dup email
        assert client.post("/student/register", json=dict(base, student_id="S1")).status_code == 400          # dup id
        assert client.post("/student/register", json=dict(base, registration_number="R1")).status_code == 400

    def test_registration_enrols_in_course_and_welcomes(self, client, register_student, course):
        s = register_student()
        courses = client.get("/student/courses", headers=s["headers"]).json()
        assert courses[0]["enrollment_status"] == "enrolled" and courses[0]["total_chapters"] == 4
        notes = client.get("/student/notifications", headers=s["headers"]).json()
        assert notes["unread_count"] == 1

    def test_chapter_completion_is_saved_and_reflected_for_teacher_and_principal(
            self, client, register_student, make_user, auth, course):
        s = register_student()
        teacher, principal = make_user("staff"), make_user("principal")
        r = _complete(client, s["headers"], course[0].id)
        assert r.status_code == 200 and r.json()["completed_chapters"] == 1
        # persisted: a fresh read shows it
        again = client.get(f"/student/courses/{course[0].course_id}/chapters", headers=s["headers"]).json()
        done = [c["key"] for m in again["modules"] for c in m["chapters"] if c["completed"]]
        assert done == ["1.1"]
        # teacher + principal views
        tv = client.get(f"/institution/members/{s['id']}/progress", headers=auth(teacher)).json()
        assert tv["member"]["completed_chapters"] == 1 and tv["member"]["progress_pct"] == 0.25
        pv = [m for m in client.get("/institution/students", headers=auth(principal)).json() if m["id"] == s["id"]][0]
        assert pv["completed_chapters"] == 1 and pv["status"] == "in_progress"
        dash = client.get("/institution/dashboard", headers=auth(principal)).json()
        assert dash["recent_activity"][0]["action"] == "Completed chapter: C1"

    def test_completion_is_idempotent_and_reversible(self, client, register_student, course):
        s = register_student()
        for _ in range(3):
            assert _complete(client, s["headers"], course[0].id).json()["completed_chapters"] == 1
        assert _complete(client, s["headers"], course[0].id, completed=False).json()["completed_chapters"] == 0
        assert _complete(client, s["headers"], course[0].id, completed=False).json()["completed_chapters"] == 0

    def test_unknown_chapter_is_404(self, client, register_student, course):
        assert _complete(client, register_student()["headers"], 99999).status_code == 404

    def test_progress_is_isolated_per_student(self, client, register_student, course):
        a = register_student("a@example.com", "A1", "RA")
        b = register_student("b@example.com", "B1", "RB")
        _complete(client, a["headers"], course[0].id)
        _complete(client, a["headers"], course[1].id)
        assert client.get("/student/progress", headers=a["headers"]).json()[0]["progress_pct"] == 0.5
        assert client.get("/student/progress", headers=b["headers"]).json()[0]["progress_pct"] == 0.0

    def test_finishing_the_course_completes_enrollment_and_notifies_once(self, client, register_student, course):
        s = register_student()
        for c in course:
            _complete(client, s["headers"], c.id)
        courses = client.get("/student/courses", headers=s["headers"]).json()
        assert courses[0]["enrollment_status"] == "completed" and courses[0]["progress_pct"] == 1.0
        _complete(client, s["headers"], course[0].id)       # re-submit: must not re-issue
        titles = [n["title"] for n in client.get("/student/notifications", headers=s["headers"]).json()["last_7_days"]]
        assert titles.count("Certificate ready") == 1
