"""Regression tests for the security fixes:
1 tagged-only status change, 2 platform + school isolation, 3 JWT secret / algorithm, 4 token invalidation.
"""
import base64
import importlib.util
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest
import sqlalchemy as sa
from jose import jwt

from conftest import PASSWORD, complaint_payload
from main import app

BACKEND = Path(__file__).resolve().parent.parent
OLD_FALLBACK_SECRET = "medal-secret-key-change-in-production"   # compromised: must never be accepted


def bearer(token):
    return {"Authorization": f"Bearer {token}"}


def _json_b64(obj):
    return base64.urlsafe_b64encode(json.dumps(obj).encode()).rstrip(b"=").decode()


# ── 1. Only a tagged authority may change a complaint's status ──────────

class TestTaggedOnlyStatus:
    @pytest.fixture()
    def case(self, client, make_user, auth, db):
        citizen = make_user("citizen")
        tagged = make_user("official", full_name="Tagged")
        untagged = make_user("official", full_name="Untagged")
        admin = make_user("admin")
        h = auth(citizen)
        cid = client.post("/complaints", json=complaint_payload(mentions=[tagged.id]), headers=h).json()["id"]
        return dict(cid=cid, citizen=citizen, hc=h, tagged=tagged, ht=auth(tagged), untagged=untagged,
                    hu=auth(untagged), admin=admin, ha=auth(admin))

    def _set(self, client, headers, cid, status="in_progress"):
        return client.patch(f"/complaints/{cid}/status", json={"status": status}, headers=headers)

    def test_tagged_authority_can_change_status(self, client, case):
        assert self._set(client, case["ht"], case["cid"]).status_code == 200

    def test_untagged_authority_gets_403_and_status_is_unchanged(self, client, case):
        assert self._set(client, case["hu"], case["cid"]).status_code == 403
        assert client.get(f"/complaints/{case['cid']}", headers=case["hc"]).json()["status"] == "submitted"

    def test_owner_citizen_and_admin_cannot_change_status(self, client, case):
        assert self._set(client, case["hc"], case["cid"]).status_code == 403
        assert self._set(client, case["ha"], case["cid"]).status_code == 403

    def test_removing_the_tag_removes_the_permission(self, client, case, db):
        from app.models.complaint import Complaint
        assert self._set(client, case["ht"], case["cid"], "under_review").status_code == 200
        db.query(Complaint).filter(Complaint.id == case["cid"]).update({"mentioned_officials": None})
        db.commit()
        assert self._set(client, case["ht"], case["cid"], "resolved").status_code == 403
        assert client.get(f"/complaints/{case['cid']}", headers=case["hc"]).json()["status"] == "under_review"

    def test_tag_of_another_official_does_not_grant_permission(self, client, case, db):
        from app.models.complaint import Complaint
        import json as _json
        db.query(Complaint).filter(Complaint.id == case["cid"]).update(
            {"mentioned_officials": _json.dumps([{"id": case["untagged"].id, "name": "Untagged"}])})
        db.commit()
        assert self._set(client, case["ht"], case["cid"]).status_code == 403
        assert self._set(client, case["hu"], case["cid"]).status_code == 200

    def test_unknown_complaint_still_404_for_an_authority(self, client, case):
        assert self._set(client, case["ht"], 99999).status_code == 404

    def test_untagged_authority_cannot_edit_via_patch_complaint(self, client, case):
        r = client.patch(f"/complaints/{case['cid']}", json={"officer_notes": "x"}, headers=case["hu"])
        assert r.status_code == 403
        r = client.patch(f"/complaints/{case['cid']}", json={"officer_notes": "x"}, headers=case["ht"])
        assert r.status_code == 200

    def test_can_update_status_flag_for_the_ui(self, client, case):
        cid = case["cid"]
        flag = lambda h: client.get(f"/complaints/{cid}", headers=h).json()["can_update_status"]
        assert flag(case["ht"]) is True
        assert flag(case["hu"]) is False and flag(case["hc"]) is False and flag(case["ha"]) is False
        listing = {c["id"]: c["can_update_status"] for c in client.get("/complaints", headers=case["ht"]).json()}
        assert listing[cid] is True
        assert {c["id"]: c["can_update_status"] for c in client.get("/complaints", headers=case["hu"]).json()}[cid] is False
        feed = {c["id"]: c["can_update_status"] for c in client.get("/complaints/feed", headers=case["ht"]).json()}
        assert feed[cid] is True
        feed_u = {c["id"]: c["can_update_status"] for c in client.get("/complaints/feed", headers=case["hu"]).json()}
        assert feed_u[cid] is False

    def test_flag_is_false_on_creation_response_for_the_citizen(self, client, case):
        r = client.post("/complaints", json=complaint_payload(), headers=case["hc"])
        assert r.json()["can_update_status"] is False


# ── 2. Platform isolation ───────────────────────────────────────────────

class TestPlatformIsolation:
    INSTITUTION = ["student", "staff", "principal"]
    CITIZEN_SIDE = ["citizen", "official", "admin"]

    @pytest.mark.parametrize("role", INSTITUTION)
    def test_institution_roles_have_no_access_to_citizen_routes(self, client, make_user, auth, role):
        owner = make_user("citizen")
        cid = client.post("/complaints", json=complaint_payload(), headers=auth(owner)).json()["id"]
        h = auth(make_user(role))
        calls = [
            ("GET", "/complaints"), ("GET", f"/complaints/{cid}"), ("GET", "/complaints/feed"),
            ("GET", f"/complaints/{cid}/comments"), ("GET", f"/complaints/{cid}/upvote-status"),
            ("POST", f"/complaints/{cid}/upvote"), ("POST", f"/complaints/{cid}/repost"),
            ("GET", f"/complaints/{cid}/repost-status"), ("GET", "/officials"), ("GET", "/complaints/stats"),
            ("PATCH", f"/complaints/{cid}"), ("PATCH", f"/complaints/{cid}/status"), ("DELETE", f"/complaints/{cid}"),
            ("POST", "/complaints"), ("POST", f"/complaints/{cid}/comments"), ("POST", "/complaints/upload-evidence"),
            ("GET", "/admin/authority-applications"), ("GET", "/users"),
        ]
        bad = []
        for method, path in calls:
            code = client.request(method, path, headers=h, json={} if method in ("POST", "PATCH") else None).status_code
            if code != 403:
                bad.append(f"{role} {method} {path} -> {code}")
        assert bad == []

    @pytest.mark.parametrize("role", CITIZEN_SIDE)
    def test_citizen_side_roles_have_no_access_to_institution_routes(self, client, make_user, auth, role):
        h = auth(make_user(role))
        calls = [
            ("GET", "/institution/dashboard"), ("GET", "/institution/staff"), ("GET", "/institution/students"),
            ("POST", "/institution/staff"), ("GET", "/institution/members/1/progress"),
            ("GET", "/student/dashboard"), ("GET", "/student/courses"), ("GET", "/student/courses/1"),
            ("GET", "/student/courses/1/chapters"), ("PUT", "/student/chapters/1/completion"),
            ("POST", "/student/courses/1/enroll"), ("GET", "/student/pending-courses"), ("GET", "/student/progress"),
            ("GET", "/student/certificates"), ("POST", "/student/certificates/upload"),
            ("GET", "/student/notifications"), ("PATCH", "/student/profile"), ("POST", "/student/manage-password"),
        ]
        bad = []
        for method, path in calls:
            code = client.request(method, path, headers=h, json={} if method in ("POST", "PATCH", "PUT") else None).status_code
            if code != 403:
                bad.append(f"{role} {method} {path} -> {code}")
        assert bad == []

    def test_admin_user_list_hides_institution_accounts(self, client, make_user, auth):
        admin = make_user("admin")
        hidden = [make_user(r) for r in ("principal", "staff", "student")]
        shown = [make_user("citizen"), make_user("official")]
        ids = {u["id"] for u in client.get("/users", headers=auth(admin)).json()}
        assert {u.id for u in shown} <= ids and ids.isdisjoint({u.id for u in hidden})

    def test_token_carries_platform_claim(self, client, make_user, token_for):
        from app.utils.security import decode_access_token
        assert decode_access_token(token_for(make_user("citizen")))["plat"] == "citizen"
        assert decode_access_token(token_for(make_user("official")))["plat"] == "citizen"
        assert decode_access_token(token_for(make_user("admin")))["plat"] == "citizen"
        for role in ("principal", "staff", "student"):
            assert decode_access_token(token_for(make_user(role)))["plat"] == "institution"

    def test_token_without_or_with_wrong_platform_claim_is_rejected(self, client, make_user):
        from app.utils.security import create_access_token
        student = make_user("student")
        base = {"sub": str(student.id), "role": "student", "tv": 0}
        assert client.get("/me", headers=bearer(create_access_token(base))).status_code == 401                 # no plat
        assert client.get("/me", headers=bearer(create_access_token({**base, "plat": "citizen"}))).status_code == 401
        assert client.get("/me", headers=bearer(create_access_token({**base, "plat": "institution"}))).status_code == 200

    def test_shared_profile_routes_work_on_both_platforms(self, client, make_user, auth):
        for role in ("citizen", "student"):
            assert client.get("/me", headers=auth(make_user(role))).status_code == 200


# ── 2b. Multi-school isolation (ID swap across two schools) ─────────────

class TestSchoolIsolation:
    @pytest.fixture()
    def two_schools(self, client, make_user, make_school, auth, course):
        a, b = make_school("SCHOOLA"), make_school("SCHOOLB")
        d = {}
        for tag, sch in (("a", a), ("b", b)):
            d[f"principal_{tag}"] = make_user("principal", school_id=sch.id, full_name=f"Principal {tag}")
            d[f"staff_{tag}"] = make_user("staff", school_id=sch.id, full_name=f"Teacher {tag}")
            d[f"student_{tag}"] = make_user("student", school_id=sch.id, full_name=f"Student {tag}",
                                            teacher_id=d[f"staff_{tag}"].id)
        for key in ("staff_a", "staff_b", "student_a", "student_b"):
            client.put(f"/student/chapters/{course[0].id}/completion", json={"completed": True}, headers=auth(d[key]))
        d["h"] = {k: auth(v) for k, v in d.items() if not k.startswith("h")}
        return d

    def test_lists_only_show_own_school(self, client, two_schools):
        t = two_schools
        for who in ("principal_a", "staff_a"):
            names = [m["name"] for m in client.get("/institution/students", headers=t["h"][who]).json()]
            assert names == ["Student a"]
        assert [m["name"] for m in client.get("/institution/staff", headers=t["h"]["principal_a"]).json()] == ["Teacher a"]
        assert [m["name"] for m in client.get("/institution/staff", headers=t["h"]["principal_b"]).json()] == ["Teacher b"]

    def test_dashboard_counts_and_activity_are_per_school(self, client, two_schools):
        t = two_schools
        for who, other in (("principal_a", "b"), ("staff_a", "b"), ("principal_b", "a")):
            d = client.get("/institution/dashboard", headers=t["h"][who]).json()
            assert (d["total_staff"], d["total_students"]) == (1, 1)
            assert len(d["recent_activity"]) == 2
            assert all(f" {other}" not in a["name"] for a in d["recent_activity"])

    def test_id_swap_to_another_schools_member_is_404(self, client, two_schools):
        t = two_schools
        for who in ("principal_a", "staff_a"):
            assert client.get(f"/institution/members/{t['student_b'].id}/progress", headers=t["h"][who]).status_code == 404
        assert client.get(f"/institution/members/{t['staff_b'].id}/progress", headers=t["h"]["principal_a"]).status_code == 404
        assert client.get(f"/institution/members/{t['student_a'].id}/progress", headers=t["h"]["staff_a"]).status_code == 200
        assert client.get(f"/institution/members/{t['student_a'].id}/progress", headers=t["h"]["principal_b"]).status_code == 404

    def test_new_teacher_belongs_to_the_principals_school(self, client, two_schools, db):
        t = two_schools
        r = client.post("/institution/staff", json={"name": "New T", "email": "newt@example.com"}, headers=t["h"]["principal_a"])
        assert r.status_code == 201
        from app.models.user import User
        assert db.query(User).filter(User.email == "newt@example.com").one().school_id == t["principal_a"].school_id
        names = [m["name"] for m in client.get("/institution/staff", headers=t["h"]["principal_b"]).json()]
        assert "New T" not in names

    def test_user_without_a_school_gets_no_institution_data(self, client, make_user, auth, db):
        orphan = make_user("principal", school_id=None)
        h = auth(orphan)
        for path in ("/institution/dashboard", "/institution/staff", "/institution/students"):
            assert client.get(path, headers=h).status_code == 403

    def test_student_signup_joins_the_school_of_the_code(self, client, make_school, db):
        a, b = make_school("SCHOOLA"), make_school("SCHOOLB")
        body = {"name": "N", "email": "n@example.com", "department": "D", "student_id": "S1",
                "registration_number": "R1", "password": PASSWORD, "confirm_password": PASSWORD}
        assert client.post("/student/register", json={**body, "school_code": "nope"}).status_code == 400
        assert client.post("/student/register", json=body).status_code == 422                       # code is required
        assert client.post("/student/register", json={**body, "school_code": "schoola"}).status_code == 201
        # same student / registration number in another school is fine; in the same school it is a duplicate
        body2 = {**body, "email": "m@example.com"}
        assert client.post("/student/register", json={**body2, "school_code": "SCHOOLB"}).status_code == 201
        assert client.post("/student/register", json={**body2, "email": "k@example.com", "school_code": "SCHOOLA"}).status_code == 400
        from app.models.user import User
        assert db.query(User).filter(User.email == "n@example.com").one().school_id == a.id
        assert db.query(User).filter(User.email == "m@example.com").one().school_id == b.id

    def test_migration_backfills_existing_institution_users(self, tmp_path):
        path = next((BACKEND / "alembic" / "versions").glob("b8c9d0e1f2a3_*.py"))
        spec = importlib.util.spec_from_file_location("mig_schools", path)
        mig = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mig)
        from alembic.migration import MigrationContext
        from alembic.operations import Operations

        def run(roles):
            eng = sa.create_engine(f"sqlite:///{tmp_path / (str(len(roles)) + '.db')}")
            with eng.begin() as conn:
                conn.execute(sa.text("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT, role TEXT)"))
                for i, r in enumerate(roles):
                    conn.execute(sa.text("INSERT INTO users (id, email, role) VALUES (:i, :e, :r)"), {"i": i + 1, "e": f"{r}{i}", "r": r})
                with Operations.context(MigrationContext.configure(conn)):
                    mig.upgrade()
                rows = conn.execute(sa.text("SELECT role, school_id, token_version FROM users ORDER BY id")).all()
                schools = conn.execute(sa.text("SELECT code FROM schools")).all()
                with Operations.context(MigrationContext.configure(conn)):
                    mig.downgrade()
                cols = [c["name"] for c in sa.inspect(conn).get_columns("users")]
            return rows, schools, cols

        rows, schools, cols = run(["citizen", "official", "admin", "principal", "staff", "student"])
        assert schools == [("DEFAULT",)]
        for role, school_id, tv in rows:
            assert tv == 0
            assert (school_id is not None) == (role in ("principal", "staff", "student"))
        assert "school_id" not in cols and "token_version" not in cols            # downgrade is clean
        rows, schools, _ = run(["citizen"])                                       # nothing to attach -> no school invented
        assert schools == [] and rows == [("citizen", None, 0)]


# ── 3. JWT secret and algorithm ─────────────────────────────────────────

def _import_security(tmp_path, **env_over):
    env = {k: v for k, v in os.environ.items() if k not in ("JWT_SECRET", "SECRET_KEY", "ALGORITHM")}
    env.update({"DATABASE_URL": f"sqlite:///{tmp_path / 'x.db'}", "PYTHONPATH": str(BACKEND)})
    env.update(env_over)
    return subprocess.run([sys.executable, "-c", "import app.utils.security as s; print(s.ALGORITHM)"],
                          cwd=tmp_path, env=env, capture_output=True, text=True)


class TestJwtSecretAndAlgorithm:
    def test_refuses_to_start_without_secret(self, tmp_path):
        assert _import_security(tmp_path).returncode != 0

    def test_refuses_empty_and_short_secret(self, tmp_path):
        assert _import_security(tmp_path, JWT_SECRET="").returncode != 0
        short = "x" * 31
        out = _import_security(tmp_path, JWT_SECRET=short)
        assert out.returncode != 0 and short not in out.stdout + out.stderr         # secret is never echoed

    def test_old_secret_key_variable_and_fallback_are_not_honoured(self, tmp_path):
        assert _import_security(tmp_path, SECRET_KEY="k" * 64).returncode != 0
        assert _import_security(tmp_path, JWT_SECRET=OLD_FALLBACK_SECRET[:31]).returncode != 0

    def test_starts_with_32_bytes_and_algorithm_is_pinned(self, tmp_path):
        out = _import_security(tmp_path, JWT_SECRET="s" * 32, ALGORITHM="none")
        assert out.returncode == 0 and out.stdout.strip() == "HS256"               # env cannot change it

    def test_token_signed_with_the_old_fallback_secret_is_rejected(self, client, make_user):
        u = make_user("admin")
        forged = jwt.encode({"sub": str(u.id), "role": "admin", "plat": "citizen", "tv": 0,
                             "exp": int(time.time()) + 600}, OLD_FALLBACK_SECRET, algorithm="HS256")
        assert client.get("/admin-test", headers=bearer(forged)).status_code == 401

    def test_alg_none_token_is_rejected(self, client, make_user):
        u = make_user("admin")
        payload = {"sub": str(u.id), "role": "admin", "plat": "citizen", "tv": 0, "exp": int(time.time()) + 600}
        for alg in ("none", "None", "NONE"):
            tok = f"{_json_b64({'alg': alg, 'typ': 'JWT'})}.{_json_b64(payload)}."
            assert client.get("/admin-test", headers=bearer(tok)).status_code == 401

    def test_other_hmac_algorithms_with_the_right_secret_are_rejected(self, client, make_user):
        from app.utils.security import JWT_SECRET
        u = make_user("admin")
        payload = {"sub": str(u.id), "role": "admin", "plat": "citizen", "tv": 0, "exp": int(time.time()) + 600}
        assert client.get("/admin-test", headers=bearer(jwt.encode(payload, JWT_SECRET, algorithm="HS512"))).status_code == 401
        assert client.get("/admin-test", headers=bearer(jwt.encode(payload, JWT_SECRET, algorithm="HS256"))).status_code == 200

    def test_env_example_documents_the_variable_without_a_value(self):
        text = (BACKEND / ".env.example").read_text()
        line = next(l for l in text.splitlines() if l.startswith("JWT_SECRET"))
        assert line.strip() == "JWT_SECRET="
        assert "SECRET_KEY=" not in text.replace("JWT_SECRET=", "")


# ── 4. Token invalidation ───────────────────────────────────────────────

class TestTokenInvalidation:
    def test_access_token_is_short_lived_by_default(self, client, make_user, token_for):
        from app.utils.security import ACCESS_TOKEN_EXPIRE_MINUTES, decode_access_token
        assert ACCESS_TOKEN_EXPIRE_MINUTES == 15
        exp = decode_access_token(token_for(make_user("citizen")))["exp"]
        assert 14 * 60 <= exp - time.time() <= 15 * 60 + 5

    def test_token_carries_version_and_stale_version_is_rejected(self, client, make_user, token_for, db):
        from app.utils.security import decode_access_token
        u = make_user("citizen")
        tok = token_for(u)
        assert decode_access_token(tok)["tv"] == 0
        u.token_version = 5
        db.commit()
        assert client.get("/me", headers=bearer(tok)).status_code == 401

    def test_token_without_version_is_rejected(self, client, make_user):
        from app.utils.security import create_access_token
        u = make_user("citizen")
        assert client.get("/me", headers=bearer(create_access_token({"sub": str(u.id), "role": "citizen", "plat": "citizen"}))).status_code == 401

    @pytest.mark.parametrize("role", ["citizen", "student", "staff", "principal", "official", "admin"])
    def test_old_token_is_401_after_logout(self, client, make_user, token_for, login, role):
        u = make_user(role)
        old = token_for(u)
        assert client.get("/me", headers=bearer(old)).status_code == 200
        assert client.post("/logout", headers=bearer(old)).status_code == 200
        assert client.get("/me", headers=bearer(old)).status_code == 401
        new = login(u.email).json()["access_token"]                     # logging in again works
        assert client.get("/me", headers=bearer(new)).status_code == 200

    def test_logout_ends_all_sessions_of_the_user(self, client, make_user, token_for):
        u = make_user("citizen")
        phone, laptop = token_for(u), token_for(u)
        client.post("/logout", headers=bearer(phone))
        assert client.get("/me", headers=bearer(laptop)).status_code == 401

    def test_logout_requires_a_valid_token(self, client):
        assert client.post("/logout").status_code == 401

    def test_old_token_is_401_after_password_change(self, client, make_user, token_for, login):
        u = make_user("student")
        old = token_for(u)
        r = client.post("/student/manage-password", json={"current_password": PASSWORD, "new_password": "Another-Pass-1"}, headers=bearer(old))
        assert r.status_code == 200
        assert client.get("/me", headers=bearer(old)).status_code == 401
        new = login(u.email, "Another-Pass-1").json()["access_token"]
        assert client.get("/me", headers=bearer(new)).status_code == 200

    def test_old_token_is_401_after_password_reset(self, client, make_user, token_for):
        from app.utils.security import create_verified_reset_token
        u = make_user("citizen")
        old = token_for(u)
        reset = create_verified_reset_token(u.email, otp_id=1)
        assert client.post("/reset-password", json={"token": reset, "new_password": "Reset-Pass-123"}).status_code == 200
        assert client.get("/me", headers=bearer(old)).status_code == 401

    def test_old_token_is_401_after_role_change(self, client, make_user, token_for, db):
        u = make_user("citizen")
        old = token_for(u)
        u.role = "admin"
        db.commit()
        assert client.get("/me", headers=bearer(old)).status_code == 401

    def test_deactivation_bumps_version_and_reactivation_does_not_revive_old_tokens(self, client, make_user, token_for, db):
        u = make_user("citizen")
        old = token_for(u)
        u.is_active = False
        db.commit()
        db.refresh(u)
        assert u.token_version == 1
        assert client.get("/me", headers=bearer(old)).status_code != 200
        u.is_active = True
        db.commit()
        assert client.get("/me", headers=bearer(old)).status_code == 401

    def test_rejecting_an_authority_revokes_its_sessions(self, client, make_user, token_for, db, auth):
        admin = make_user("admin")
        off = make_user("official", approval_status="approved")
        old = token_for(off)
        from app.models.authority_application import AuthorityApplication
        app_row = AuthorityApplication(user_id=off.id, full_name="x", official_email=off.email, designation="d",
                                       department="d", jurisdiction="j", aadhaar_document_url="https://f/a",
                                       employment_document_url="https://f/e", status="approved")
        db.add(app_row)
        db.commit()
        r = client.post(f"/admin/authority-applications/{app_row.id}/reject", json={"reason": "Revoked"}, headers=auth(admin))
        assert r.status_code == 200
        db.refresh(off)
        assert off.token_version == 1
        assert client.get("/me", headers=bearer(old)).status_code == 401

    def test_approval_without_role_change_does_not_log_the_user_out(self, client, make_user, db):
        u = make_user("official", approval_status="pending")
        u.approval_status = "approved"
        u.role = "official"
        db.commit()
        db.refresh(u)
        assert u.token_version == 0

    def test_ordinary_profile_edit_does_not_invalidate_tokens(self, client, make_user, token_for):
        u = make_user("citizen")
        tok = token_for(u)
        assert client.patch("/me", json={"full_name": "New Name"}, headers=bearer(tok)).status_code == 200
        assert client.get("/me", headers=bearer(tok)).status_code == 200
