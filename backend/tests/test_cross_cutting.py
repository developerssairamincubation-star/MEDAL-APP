"""CROSS-CUTTING. Items 15-16 (role-based access, logout) + token hygiene."""
import os
import re
import subprocess
import sys
from datetime import timedelta

import pytest

from conftest import PASSWORD, complaint_payload
from main import app
from markers import bug, missing

ROLES = ["citizen", "official", "admin", "principal", "staff", "student"]

# Intentionally public (login/sign-up flows, probes, API docs, public community feed).
INTENDED_PUBLIC = {
    "/", "/health", "/register", "/login", "/forgot-password", "/verify-otp", "/resend-otp",
    "/reset-password", "/authority/register", "/student/register",
}
# Public but should not be (see BUG-03/04/22/23).
UNINTENDED_PUBLIC = {
    "/authority/upload-document", "/authority/application-status", "/complaints/analyze-sdg", "/health/storage",
}

# (method, path, roles allowed). Anything else must answer 403.
ROLE_MATRIX = [
    ("GET", "/admin-test", {"admin"}),
    ("GET", "/official-test", {"official", "admin"}),
    ("GET", "/users", {"admin"}),
    ("GET", "/admin/authority-applications", {"admin"}),
    ("GET", "/admin/authority-applications/1", {"admin"}),
    ("POST", "/admin/authority-applications/1/approve", {"admin"}),
    ("POST", "/admin/authority-applications/1/reject", {"admin"}),
    ("GET", "/complaints/stats", {"official", "admin"}),
    ("PATCH", "/complaints/1/status", {"official"}),
    ("GET", "/institution/dashboard", {"principal", "staff"}),
    ("GET", "/institution/staff", {"principal"}),
    ("POST", "/institution/staff", {"principal"}),
    ("GET", "/institution/students", {"principal", "staff"}),
    ("GET", "/institution/members/1/progress", {"principal", "staff"}),
]


def _operations():
    for path, ops in app.openapi()["paths"].items():
        for method in ops:
            if method.upper() in ("GET", "POST", "PUT", "PATCH", "DELETE"):
                yield method.upper(), path


def _open_paths(client):
    open_paths = set()
    for method, path in _operations():
        if client.request(method, re.sub(r"\{[^}]+\}", "1", path)).status_code != 401:
            open_paths.add(path)
    return open_paths


# ── 15. Role-based access ───────────────────────────────────────────────

class TestAccessControl:
    def test_every_route_rejects_unauthenticated_except_the_public_ones(self, client):
        unexpected = _open_paths(client) - INTENDED_PUBLIC - UNINTENDED_PUBLIC - {"/docs", "/redoc", "/openapi.json",
                                                                                 "/docs/oauth2-redirect"}
        assert unexpected == set(), f"new unauthenticated routes: {sorted(unexpected)}"

    @bug("BUG-22 (MEDIUM)", "POST /authority/upload-document, GET /authority/application-status, "
                            "POST /complaints/analyze-sdg (runs the AI/OpenAI pipeline) and GET /health/storage "
                            "(?deep=true calls Cloudinary) answer without any token")
    def test_no_sensitive_route_is_anonymous(self, client):
        assert _open_paths(client) & UNINTENDED_PUBLIC == set()

    def test_role_matrix(self, client, make_user, auth):
        users = {role: make_user(role) for role in ROLES}
        headers = {role: auth(u) for role, u in users.items()}
        wrong = []
        for method, path, allowed in ROLE_MATRIX:
            for role in ROLES:
                status = client.request(method, path, headers=headers[role]).status_code
                if role in allowed and status in (401, 403):
                    wrong.append(f"{role} should reach {method} {path} but got {status}")
                if role not in allowed and status != 403:
                    wrong.append(f"{role} should get 403 on {method} {path} but got {status}")
        assert wrong == []

    @pytest.mark.parametrize("role", ["citizen", "official", "admin"])
    def test_student_api_is_for_institution_roles_only(self, client, make_user, auth, role):
        assert client.get("/student/dashboard", headers=auth(make_user(role))).status_code == 403

    @pytest.mark.parametrize("role", ["student", "staff", "principal"])
    def test_institution_roles_cannot_touch_citizen_complaints(self, client, make_user, auth, role):
        owner = make_user("citizen")
        cid = client.post("/complaints", json=complaint_payload(), headers=auth(owner)).json()["id"]
        h = auth(make_user(role))
        assert client.get(f"/complaints/{cid}", headers=h).status_code == 403
        assert client.get("/complaints", headers=h).status_code == 403
        assert client.patch(f"/complaints/{cid}", json={"title": "defaced"}, headers=h).status_code == 403

    def test_citizen_cannot_edit_or_delete_someone_elses_complaint(self, client, make_user, auth):
        owner, other = make_user("citizen"), make_user("citizen")
        cid = client.post("/complaints", json=complaint_payload(), headers=auth(owner)).json()["id"]
        assert client.patch(f"/complaints/{cid}", json={"title": "x"}, headers=auth(other)).status_code == 403
        assert client.delete(f"/complaints/{cid}", headers=auth(other)).status_code == 403

    def test_profile_update_cannot_change_role(self, client, make_user, auth, db):
        u = make_user("citizen")
        client.patch("/me", json={"full_name": "Renamed", "role": "admin", "approval_status": "approved"}, headers=auth(u))
        db.refresh(u)
        assert u.role == "citizen" and u.full_name == "Renamed"


# ── token hygiene ───────────────────────────────────────────────────────

class TestTokens:
    def _token(self, user, **kw):
        from app.utils.security import create_access_token, create_user_token
        if kw:
            return create_access_token({"sub": str(user.id), "role": user.role, "plat": "citizen", "tv": 0}, **kw)
        return create_user_token(user)

    def test_valid_token_works(self, client, make_user):
        u = make_user("citizen")
        assert client.get("/me", headers={"Authorization": f"Bearer {self._token(u)}"}).status_code == 200

    def test_expired_token_rejected(self, client, make_user):
        u = make_user("citizen")
        tok = self._token(u, expires_delta=timedelta(minutes=-1))
        assert client.get("/me", headers={"Authorization": f"Bearer {tok}"}).status_code == 401

    @pytest.mark.parametrize("tok", ["garbage", "a.b.c", ""])
    def test_malformed_token_rejected(self, client, tok):
        assert client.get("/me", headers={"Authorization": f"Bearer {tok}"}).status_code == 401

    def test_tampered_and_foreign_signature_rejected(self, client, make_user):
        from jose import jwt
        u = make_user("citizen")
        forged = jwt.encode({"sub": str(u.id), "role": "admin"}, "another-secret", algorithm="HS256")
        assert client.get("/me", headers={"Authorization": f"Bearer {forged}"}).status_code == 401
        good = self._token(u)
        assert client.get("/me", headers={"Authorization": f"Bearer {good[:-3]}xyz"}).status_code == 401

    def test_token_of_deleted_user_rejected(self, client, make_user, db):
        u = make_user("citizen")
        tok = self._token(u)
        db.delete(u)
        db.commit()
        assert client.get("/me", headers={"Authorization": f"Bearer {tok}"}).status_code == 401

    def test_role_claim_in_token_is_not_trusted(self, client, make_user):
        from app.utils.security import create_access_token
        u = make_user("citizen")
        tok = create_access_token({"sub": str(u.id), "role": "admin", "plat": "citizen", "tv": 0})
        assert client.get("/admin-test", headers={"Authorization": f"Bearer {tok}"}).status_code == 403

    @bug("BUG-25 (LOW)", "a deactivated user's valid token gets HTTP 400 'Inactive user' instead of 401/403")
    def test_inactive_user_token_status_code(self, client, make_user):
        u = make_user("citizen", is_active=False)
        assert client.get("/me", headers={"Authorization": f"Bearer {self._token(u)}"}).status_code in (401, 403)

    def test_app_refuses_to_start_without_a_secret_key(self, tmp_path):
        env = {k: v for k, v in os.environ.items() if k not in ("JWT_SECRET", "SECRET_KEY")}
        env["DATABASE_URL"] = f"sqlite:///{tmp_path / 'x.db'}"
        env["PYTHONPATH"] = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        out = subprocess.run([sys.executable, "-c", "import app.utils.security as s; print(s.JWT_SECRET)"],
                             cwd=tmp_path, env=env, capture_output=True, text=True)
        assert out.returncode != 0, "imported fine without a signing key"


# ── 16. Logout / session end ────────────────────────────────────────────

class TestLogout:
    def test_logout_ends_the_session(self, client, make_user, auth):
        u = make_user("citizen")
        h = auth(u)
        assert client.post("/logout", headers=h).status_code == 200
        assert client.get("/me", headers=h).status_code == 401

    def test_old_token_dies_after_password_change(self, client, make_user, auth):
        u = make_user("student")
        h = auth(u)
        r = client.post("/student/manage-password", json={"current_password": PASSWORD, "new_password": "Another-Pass-1"}, headers=h)
        assert r.status_code == 200
        assert client.get("/me", headers=h).status_code == 401

    def test_new_login_after_password_change_works_with_new_password_only(self, client, make_user, auth):
        u = make_user("student")
        client.post("/student/manage-password", json={"current_password": PASSWORD, "new_password": "Another-Pass-1"}, headers=auth(u))
        assert client.post("/login", json={"email": u.email, "password": PASSWORD}).status_code == 401
        assert client.post("/login", json={"email": u.email, "password": "Another-Pass-1"}).status_code == 200

    def test_change_password_requires_correct_current_password(self, client, make_user, auth):
        u = make_user("student")
        r = client.post("/student/manage-password", json={"current_password": "wrong", "new_password": "Another-Pass-1"}, headers=auth(u))
        assert r.status_code == 400


# ── password reset (mail is captured by the fake sender) ────────────────

class TestForgotPassword:
    def test_known_user_gets_an_otp_mail_and_unknown_user_gets_the_same_answer(self, client, make_user, outbox):
        u = make_user("citizen")
        known = client.post("/forgot-password", json={"email": u.email})
        unknown = client.post("/forgot-password", json={"email": "nobody@example.com"})
        assert known.status_code == unknown.status_code == 200
        assert known.json()["message"] == unknown.json()["message"]
        assert [m["to"] for m in outbox] == [u.email]
        assert len(outbox[0]["otp"]) == 6

    def test_inactive_user_gets_no_mail(self, client, make_user, outbox):
        u = make_user("citizen", is_active=False)
        client.post("/forgot-password", json={"email": u.email})
        assert outbox == []

    def test_reset_with_bogus_token_rejected(self, client):
        assert client.post("/reset-password", json={"token": "bogus", "new_password": "Whatever-1"}).status_code == 400
