"""Staff 'Add Students': invite one student by e-mail, or many from a CSV; students sit under the teacher."""
import importlib.util
import io
from pathlib import Path

import pytest
import sqlalchemy as sa

from conftest import PASSWORD, FakeEmail
from main import app
from app.services.email import EmailDeliveryError, get_email_service

BACKEND = Path(__file__).resolve().parent.parent


def _csv(rows, header="name,email,department"):
    return "\n".join([header] + rows) + "\n"


def _upload(client, headers, text, name="students.csv"):
    data = text.encode("utf-8") if isinstance(text, str) else text
    return client.post("/institution/students/bulk", files={"file": (name, io.BytesIO(data), "text/csv")}, headers=headers)


@pytest.fixture()
def teacher(make_user):
    return make_user("staff", full_name="Tara Teacher", department="Science")


@pytest.fixture()
def ht(teacher, auth):
    return auth(teacher)


# ── single invite ───────────────────────────────────────────────────────

class TestInviteOne:
    def test_invite_creates_student_under_the_teacher_and_sends_the_email(self, client, teacher, ht, outbox, db, course, school):
        r = client.post("/institution/students/invite", json={"name": "Asha Kumar", "email": "Asha.Kumar@Example.com"}, headers=ht)
        assert r.status_code == 201
        body = r.json()
        assert body["email_sent"] is True and body["temporary_password"] is None
        assert body["student"]["email"] == "asha.kumar@example.com" and body["student"]["role"] == "student"
        assert body["student"]["teacher_id"] == teacher.id

        from app.models.student import StudentEnrollment, StudentNotification
        from app.models.user import User
        stu = db.query(User).filter(User.email == "asha.kumar@example.com").one()
        assert (stu.teacher_id, stu.school_id, stu.role) == (teacher.id, teacher.school_id, "student")
        assert stu.department == "Science"                                   # defaults to the teacher's
        assert db.query(StudentEnrollment).filter_by(user_id=stu.id).count() == 1
        assert db.query(StudentNotification).filter_by(user_id=stu.id).count() == 1

        assert len(outbox) == 1
        mail = outbox[0]
        assert (mail["kind"], mail["to"], mail["teacher"], mail["school"]) == \
            ("student_invite", "asha.kumar@example.com", "Tara Teacher", school.name)

        login = client.post("/login", json={"email": "asha.kumar@example.com", "password": mail["password"]})
        assert login.status_code == 200 and login.json()["data"]["role"] == "student"

    def test_student_is_listed_for_the_teacher_but_not_for_other_teachers(self, client, teacher, ht, auth, make_user):
        client.post("/institution/students/invite", json={"name": "Asha", "email": "asha@example.com"}, headers=ht)
        other = make_user("staff", full_name="Other Teacher")
        mine = [m["email"] for m in client.get("/institution/students", headers=ht).json()]
        theirs = client.get("/institution/students", headers=auth(other)).json()
        assert mine == ["asha@example.com"] and theirs == []
        principal = make_user("principal")
        assert [m["email"] for m in client.get("/institution/students", headers=auth(principal)).json()] == ["asha@example.com"]

    def test_teacher_sees_progress_only_of_own_students(self, client, ht, auth, make_user, course):
        sid = client.post("/institution/students/invite", json={"name": "Asha", "email": "asha@example.com"}, headers=ht).json()["student"]["id"]
        assert client.get(f"/institution/members/{sid}/progress", headers=ht).status_code == 200
        assert client.get(f"/institution/members/{sid}/progress", headers=auth(make_user("staff"))).status_code == 404
        assert client.get(f"/institution/members/{sid}/progress", headers=auth(make_user("principal"))).status_code == 200

    def test_self_registered_students_are_not_in_a_teachers_list(self, client, ht, make_user):
        make_user("student", full_name="Self Registered")            # no teacher
        assert client.get("/institution/students", headers=ht).json() == []

    def test_duplicates_and_bad_input(self, client, ht, make_user, outbox):
        make_user("citizen", email="taken@example.com")
        ok = {"name": "Asha", "email": "asha@example.com"}
        assert client.post("/institution/students/invite", json=ok, headers=ht).status_code == 201
        assert client.post("/institution/students/invite", json=ok, headers=ht).status_code == 400
        assert client.post("/institution/students/invite", json={**ok, "email": "ASHA@example.com"}, headers=ht).status_code == 400
        assert client.post("/institution/students/invite", json={**ok, "email": "taken@example.com"}, headers=ht).status_code == 400
        assert client.post("/institution/students/invite", json={"name": "x", "email": "not-an-email"}, headers=ht).status_code == 422
        assert client.post("/institution/students/invite", json={"name": "   ", "email": "b@example.com"}, headers=ht).status_code == 400
        assert len(outbox) == 1                                     # only the first one was invited

    def test_failed_email_keeps_the_account_and_hands_back_the_password(self, client, ht):
        FakeEmail.fail_with = EmailDeliveryError("provider down")
        r = client.post("/institution/students/invite", json={"name": "Asha", "email": "asha@example.com"}, headers=ht)
        assert r.status_code == 201
        body = r.json()
        assert body["email_sent"] is False and body["temporary_password"] and "provider down" in body["error"]
        assert client.post("/login", json={"email": "asha@example.com", "password": body["temporary_password"]}).status_code == 200

    def test_no_email_provider_in_dev_returns_the_password(self, client, ht):
        class Unconfigured(FakeEmail):
            def is_configured(self): return False
            def send_student_invite(self, *a, **k): return False
        app.dependency_overrides[get_email_service] = lambda: Unconfigured()
        r = client.post("/institution/students/invite", json={"name": "Asha", "email": "asha@example.com"}, headers=ht)
        assert r.status_code == 201 and r.json()["email_sent"] is False and r.json()["temporary_password"]

    def test_production_without_email_provider_refuses_to_create(self, client, ht, db):
        class ProdNoMail(FakeEmail):
            def is_configured(self): return False
            def is_production(self): return True
        app.dependency_overrides[get_email_service] = lambda: ProdNoMail()
        r = client.post("/institution/students/invite", json={"name": "Asha", "email": "asha@example.com"}, headers=ht)
        assert r.status_code == 503
        from app.models.user import User
        assert db.query(User).filter(User.email == "asha@example.com").count() == 0

    @pytest.mark.parametrize("role", ["principal", "student", "citizen", "official", "admin"])
    def test_only_staff_can_invite_students(self, client, make_user, auth, role):
        r = client.post("/institution/students/invite", json={"name": "A", "email": "a@example.com"}, headers=auth(make_user(role)))
        assert r.status_code == 403

    def test_unauthenticated_cannot_invite(self, client):
        assert client.post("/institution/students/invite", json={"name": "A", "email": "a@example.com"}).status_code == 401

    def test_teacher_without_a_school_cannot_invite(self, client, make_user, auth):
        orphan = make_user("staff", school_id=None)
        assert client.post("/institution/students/invite", json={"name": "A", "email": "a@example.com"}, headers=auth(orphan)).status_code == 403

    def test_student_joins_the_teachers_school_not_another(self, client, make_user, make_school, auth, db):
        b = make_school("SCHOOLB")
        teacher_b = make_user("staff", school_id=b.id)
        client.post("/institution/students/invite", json={"name": "A", "email": "a@example.com"}, headers=auth(teacher_b))
        from app.models.user import User
        assert db.query(User).filter(User.email == "a@example.com").one().school_id == b.id


# ── CSV ─────────────────────────────────────────────────────────────────

class TestCsv:
    def test_template_download(self, client, ht):
        r = client.get("/institution/students/template", headers=ht)
        assert r.status_code == 200 and r.headers["content-type"].startswith("text/csv")
        assert r.text.splitlines()[0] == "name,email,department"
        assert "attachment" in r.headers["content-disposition"]

    def test_valid_file_creates_students_under_the_teacher_and_sends_invites(self, client, teacher, ht, outbox, db):
        rows = [f"Student {i},stu{i}@example.com,Science" for i in range(25)]
        r = _upload(client, ht, _csv(rows))
        assert r.status_code == 200
        body = r.json()
        assert (body["total_rows"], body["created"], body["failed"], body["invites_queued"]) == (25, 25, 0, 25)
        assert body["errors"] == [] and body["credentials"] == []
        assert {m["teacher_id"] for m in body["students"]} == {teacher.id}
        assert sorted(m["to"] for m in outbox) == sorted(f"stu{i}@example.com" for i in range(25))
        assert all(m["kind"] == "student_invite" and m["teacher"] == "Tara Teacher" for m in outbox)
        first = outbox[0]
        assert client.post("/login", json={"email": first["to"], "password": first["password"]}).status_code == 200
        assert len(client.get("/institution/students", headers=ht).json()) == 25

    def test_partial_failure_report_names_each_bad_row(self, client, ht, make_user, outbox):
        make_user("citizen", email="exists@example.com")
        text = _csv([
            "Good One,good1@example.com,Maths",
            "Bad Email,not-an-email,Maths",
            ",noname@example.com,Maths",
            "Dup A,dup@example.com,",
            "Dup B,DUP@example.com,",
            "Already Here,exists@example.com,",
            "Good Two,good2@example.com,",
        ])
        body = _upload(client, ht, text).json()
        # data rows start at line 2; the first "dup@" is valid, its twin on line 6 is the duplicate
        assert (body["total_rows"], body["created"], body["failed"]) == (7, 3, 4)
        assert {e["row"]: e["error"] for e in body["errors"]} == {
            3: "Invalid email address",
            4: "Name is required",
            6: "Duplicate email in this file",
            7: "Email is already registered",
        }
        assert sorted(m["to"] for m in outbox) == ["dup@example.com", "good1@example.com", "good2@example.com"]
        assert sorted(m["email"] for m in body["students"]) == ["dup@example.com", "good1@example.com", "good2@example.com"]

    def test_header_aliases_bom_and_blank_lines(self, client, ht):
        text = "﻿Student Name,Email ID\n\nAsha,asha@example.com\n   ,   \nBala,bala@example.com\n"
        body = _upload(client, ht, text).json()
        assert (body["created"], body["failed"], body["total_rows"]) == (2, 0, 2)

    def test_empty_file_and_header_only(self, client, ht):
        assert _upload(client, ht, "").status_code == 400
        assert _upload(client, ht, "   \n").status_code == 400
        r = _upload(client, ht, "name,email,department\n")
        assert r.status_code == 400 and "no student rows" in r.json()["detail"]

    def test_missing_columns_are_named(self, client, ht):
        r = _upload(client, ht, "name,department\nAsha,Science\n")
        assert r.status_code == 400 and "email" in r.json()["detail"]
        r = _upload(client, ht, "email\nasha@example.com\n")
        assert r.status_code == 400 and "name" in r.json()["detail"]

    def test_not_utf8_is_rejected(self, client, ht):
        assert _upload(client, ht, b"name,email\n\xff\xfe\xfa,a@example.com\n").status_code == 400

    def test_too_many_rows_and_too_large_files(self, client, ht, db):
        rows = [f"S{i},s{i}@example.com" for i in range(201)]
        r = _upload(client, ht, _csv(rows, header="name,email"))
        assert r.status_code == 400 and "Too many rows" in r.json()["detail"]
        assert _upload(client, ht, "name,email\n" + "x" * 1_100_000).status_code == 413
        from app.models.user import User
        assert db.query(User).filter(User.role == "student").count() == 0          # nothing was created

    def test_production_without_email_provider_creates_nothing(self, client, ht, db):
        class ProdNoMail(FakeEmail):
            def is_configured(self): return False
            def is_production(self): return True
        app.dependency_overrides[get_email_service] = lambda: ProdNoMail()
        assert _upload(client, ht, _csv(["A,a@example.com,"])).status_code == 503
        from app.models.user import User
        assert db.query(User).filter(User.role == "student").count() == 0

    def test_dev_without_email_provider_returns_credentials(self, client, ht):
        class Unconfigured(FakeEmail):
            def is_configured(self): return False
        app.dependency_overrides[get_email_service] = lambda: Unconfigured()
        body = _upload(client, ht, _csv(["A,a@example.com,"])).json()
        assert body["created"] == 1 and body["invites_queued"] == 0
        cred = body["credentials"][0]
        assert client.post("/login", json={"email": cred["email"], "password": cred["temporary_password"]}).status_code == 200

    def test_one_failing_invite_does_not_stop_the_rest(self, client, ht, outbox):
        calls = []
        class Flaky(FakeEmail):
            def send_student_invite(self, to_email, **k):
                calls.append(to_email)
                if to_email.startswith("bad"):
                    raise EmailDeliveryError("rejected")
                return super().send_student_invite(to_email, **k)
        app.dependency_overrides[get_email_service] = lambda: Flaky()
        body = _upload(client, ht, _csv(["A,good@example.com,", "B,bad@example.com,", "C,good2@example.com,"])).json()
        assert body["created"] == 3
        assert calls == ["good@example.com", "bad@example.com", "good2@example.com"]
        assert sorted(m["to"] for m in outbox) == ["good2@example.com", "good@example.com"]

    @pytest.mark.parametrize("role", ["principal", "student", "citizen", "official", "admin"])
    def test_only_staff_can_use_csv_upload_and_template(self, client, make_user, auth, role):
        h = auth(make_user(role))
        assert _upload(client, h, _csv(["A,a@example.com,"])).status_code == 403
        assert client.get("/institution/students/template", headers=h).status_code == 403

    def test_unauthenticated(self, client):
        assert client.post("/institution/students/bulk", files={"file": ("s.csv", b"name,email\n", "text/csv")}).status_code == 401
        assert client.get("/institution/students/template").status_code == 401


# ── migration ───────────────────────────────────────────────────────────

def test_teacher_id_migration_up_and_down(tmp_path):
    path = next((BACKEND / "alembic" / "versions").glob("c9d0e1f2a3b4_*.py"))
    spec = importlib.util.spec_from_file_location("mig_teacher", path)
    mig = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mig)
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    eng = sa.create_engine(f"sqlite:///{tmp_path / 'm.db'}")
    with eng.begin() as conn:
        conn.execute(sa.text("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT, role TEXT)"))
        conn.execute(sa.text("INSERT INTO users (id, email, role) VALUES (1,'t','staff'),(2,'s','student')"))
        with Operations.context(MigrationContext.configure(conn)):
            mig.upgrade()
        assert [r[0] for r in conn.execute(sa.text("SELECT teacher_id FROM users ORDER BY id")).all()] == [None, None]
        assert "teacher_id" in [c["name"] for c in sa.inspect(conn).get_columns("users")]
        with Operations.context(MigrationContext.configure(conn)):
            mig.downgrade()
        assert "teacher_id" not in [c["name"] for c in sa.inspect(conn).get_columns("users")]
