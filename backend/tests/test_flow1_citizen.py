"""FLOW 1 - citizen platform (Admin / Authority / Citizen). Items 1-6."""
import io

import pytest
from PIL import Image

from conftest import ADMIN_EMAIL, ADMIN_PASSWORD, PASSWORD, authority_payload, complaint_payload
from markers import bug, missing

# Assumed radius for "nearby authorities" (brief: 1.5 or 2 km). Only used by the
# not-implemented spec test below; the app has no such constant yet.
NEARBY_RADIUS_KM = 2.0


def _png() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (4, 4), "white").save(buf, "PNG")
    return buf.getvalue()


# ── 1. Admin login ──────────────────────────────────────────────────────

class TestAdminLogin:
    def test_seeded_admin_can_log_in(self, client, admin):
        r = client.post("/login", json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD})
        assert r.status_code == 200
        assert r.json()["data"]["role"] == "admin"
        h = {"Authorization": f"Bearer {r.json()['access_token']}"}
        assert client.get("/admin-test", headers=h).status_code == 200

    @pytest.mark.parametrize("email,password", [
        (ADMIN_EMAIL, "wrong-password"),
        ("nobody@example.com", ADMIN_PASSWORD),
        (ADMIN_EMAIL, ""),
    ])
    def test_wrong_credentials_rejected(self, client, admin, email, password):
        r = client.post("/login", json={"email": email, "password": password})
        assert r.status_code == 401
        assert "access_token" not in r.json()

    def test_error_does_not_reveal_which_field_was_wrong(self, client, admin):
        a = client.post("/login", json={"email": ADMIN_EMAIL, "password": "x"}).json()
        b = client.post("/login", json={"email": "nobody@example.com", "password": "x"}).json()
        assert a == b


# ── 2. Authority sign-up ────────────────────────────────────────────────

class TestAuthoritySignup:
    @pytest.mark.parametrize("missing_field", ["aadhaar_document_url", "employment_document_url"])
    def test_blocked_without_mandatory_document(self, client, missing_field):
        body = authority_payload()
        body.pop(missing_field)
        assert client.post("/authority/register", json=body).status_code == 422

    def test_blocked_with_empty_document_url(self, client):
        assert client.post("/authority/register",
                           json=authority_payload(aadhaar_document_url="")).status_code == 422

    def test_submission_is_pending_and_cannot_access_app(self, client, register_authority, login):
        body = authority_payload()
        r = client.post("/authority/register", json=body)
        assert r.status_code == 201
        assert r.json()["status"] == "pending"
        r = login(body["official_email"], body["password"])
        assert r.status_code == 403
        assert "access_token" not in r.json()

    def test_status_endpoint_reports_pending(self, client):
        body = authority_payload()
        client.post("/authority/register", json=body)
        r = client.get("/authority/application-status", params={"email": body["official_email"]})
        assert r.json()["status"] == "pending"

    def test_duplicate_email_rejected(self, client):
        body = authority_payload()
        assert client.post("/authority/register", json=body).status_code == 201
        assert client.post("/authority/register", json=body).status_code == 400

    @bug("BUG-01", "whitespace-only document URL passes validation (min_length counts spaces, value is "
                   "stripped to '' afterwards) so an application is stored with NO document")
    def test_whitespace_document_url_is_rejected(self, client):
        r = client.post("/authority/register", json=authority_payload(aadhaar_document_url="      "))
        assert r.status_code == 422

    @bug("BUG-02", "document URL is not checked against an uploaded file; any 5+ char string is accepted")
    def test_document_url_must_come_from_upload(self, client):
        r = client.post("/authority/register", json=authority_payload(
            aadhaar_document_url="not-an-upload", employment_document_url="also-not-an-upload"))
        assert r.status_code == 422

    @bug("BUG-03", "POST /authority/upload-document requires no authentication (anyone can push files to storage)")
    def test_upload_document_requires_auth(self, client):
        r = client.post("/authority/upload-document", files={"file": ("a.png", _png(), "image/png")})
        assert r.status_code in (401, 403)

    def test_upload_document_rejects_non_documents(self, client):
        r = client.post("/authority/upload-document", files={"file": ("a.exe", b"MZ\x90\x00junk", "application/octet-stream")})
        assert r.status_code == 400

    @bug("BUG-04", "GET /authority/application-status is public: anyone can read any applicant's name, "
                   "designation and rejection reason by email")
    def test_application_status_requires_auth(self, client):
        body = authority_payload()
        client.post("/authority/register", json=body)
        r = client.get("/authority/application-status", params={"email": body["official_email"]})
        assert r.status_code in (401, 403)


# ── 3. Admin review ─────────────────────────────────────────────────────

class TestAdminReview:
    def _apply(self, client, **over):
        body = authority_payload(**over)
        r = client.post("/authority/register", json=body)
        assert r.status_code == 201
        return body, r.json()["data"]["id"]

    def test_admin_sees_pending_and_views_documents(self, client, admin, auth):
        _, app_id = self._apply(client)
        h = auth(admin, ADMIN_PASSWORD)
        listing = client.get("/admin/authority-applications", params={"status": "pending"}, headers=h)
        assert listing.status_code == 200
        assert [a["id"] for a in listing.json()] == [app_id]
        detail = client.get(f"/admin/authority-applications/{app_id}", headers=h).json()
        assert detail["aadhaar_document_url"].startswith("https://signed.test/")  # short-lived signed URL
        assert detail["employment_document_url"].startswith("https://signed.test/")

    def test_status_filter(self, client, admin, auth):
        _, app_id = self._apply(client)
        h = auth(admin, ADMIN_PASSWORD)
        client.post(f"/admin/authority-applications/{app_id}/approve", headers=h)
        assert client.get("/admin/authority-applications?status=pending", headers=h).json() == []
        assert len(client.get("/admin/authority-applications?status=approved", headers=h).json()) == 1
        assert len(client.get("/admin/authority-applications?status=all", headers=h).json()) == 1

    def test_approved_authority_can_log_in_and_see_profile(self, client, admin, auth, login):
        body, app_id = self._apply(client)
        r = client.post(f"/admin/authority-applications/{app_id}/approve", headers=auth(admin, ADMIN_PASSWORD))
        assert r.status_code == 200
        r = login(body["official_email"], body["password"])
        assert r.status_code == 200
        me = client.get("/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"}).json()
        assert me["role"] == "official" and me["approval_status"] == "approved"
        assert me["department"] == body["department"]

    def test_rejected_authority_cannot_log_in_and_sees_reason(self, client, admin, auth, login):
        body, app_id = self._apply(client)
        r = client.post(f"/admin/authority-applications/{app_id}/reject",
                        json={"reason": "Documents unreadable"}, headers=auth(admin, ADMIN_PASSWORD))
        assert r.status_code == 200
        r = login(body["official_email"], body["password"])
        assert r.status_code == 403
        assert "Documents unreadable" in r.json()["detail"]

    def test_reject_requires_reason(self, client, admin, auth):
        _, app_id = self._apply(client)
        r = client.post(f"/admin/authority-applications/{app_id}/reject", json={}, headers=auth(admin, ADMIN_PASSWORD))
        assert r.status_code == 422

    def test_unknown_application_is_404(self, client, admin, auth):
        h = auth(admin, ADMIN_PASSWORD)
        assert client.get("/admin/authority-applications/9999", headers=h).status_code == 404
        assert client.post("/admin/authority-applications/9999/approve", headers=h).status_code == 404

    def test_existing_token_stops_working_when_authority_is_rejected(self, client, admin, auth, login):
        body, app_id = self._apply(client)
        h_admin = auth(admin, ADMIN_PASSWORD)
        client.post(f"/admin/authority-applications/{app_id}/approve", headers=h_admin)
        tok = login(body["official_email"], body["password"]).json()["access_token"]
        h = {"Authorization": f"Bearer {tok}"}
        assert client.get("/me", headers=h).status_code == 200
        client.post(f"/admin/authority-applications/{app_id}/reject", json={"reason": "Revoked"}, headers=h_admin)
        assert client.get("/me", headers=h).status_code == 401   # session revoked (token_version bumped)

    @pytest.mark.parametrize("role", ["citizen", "official", "student", "staff", "principal"])
    def test_non_admin_cannot_use_admin_endpoints(self, client, make_user, auth, role):
        _, app_id = self._apply(client)
        user = make_user(role)
        h = auth(user)
        assert client.get("/admin/authority-applications", headers=h).status_code == 403
        assert client.get(f"/admin/authority-applications/{app_id}", headers=h).status_code == 403
        assert client.post(f"/admin/authority-applications/{app_id}/approve", headers=h).status_code == 403
        assert client.post(f"/admin/authority-applications/{app_id}/reject", json={"reason": "no"}, headers=h).status_code == 403

    @bug("BUG-05", "reject reason of only spaces passes min_length=3 and is stored as an empty string")
    def test_blank_rejection_reason_is_refused(self, client, admin, auth):
        _, app_id = self._apply(client)
        r = client.post(f"/admin/authority-applications/{app_id}/reject",
                        json={"reason": "     "}, headers=auth(admin, ADMIN_PASSWORD))
        assert r.status_code == 422

    @bug("BUG-06", "a rejected authority can never re-apply: /authority/register refuses the e-mail as "
                   "'already registered' and there is no re-submission path")
    def test_rejected_authority_can_reapply(self, client, admin, auth):
        body, app_id = self._apply(client)
        client.post(f"/admin/authority-applications/{app_id}/reject", json={"reason": "Blurry scan"},
                    headers=auth(admin, ADMIN_PASSWORD))
        assert client.post("/authority/register", json=body).status_code == 201


# ── 4. Citizen sign-up / login / report ─────────────────────────────────

class TestCitizenReporting:
    def _citizen(self, client, email="citizen1@example.com", password=PASSWORD):
        r = client.post("/register", json={"email": email, "password": password, "full_name": "Cit One"})
        assert r.status_code == 201, r.text
        tok = client.post("/login", json={"email": email, "password": password}).json()["access_token"]
        return {"Authorization": f"Bearer {tok}"}

    def test_signup_login_and_report_with_location(self, client):
        h = self._citizen(client)
        r = client.post("/complaints", json=complaint_payload(), headers=h)
        assert r.status_code == 201
        c = r.json()
        assert c["status"] == "submitted"
        assert (c["latitude"], c["longitude"]) == (12.9716, 77.5946)
        assert client.get(f"/complaints/{c['id']}", headers=h).json()["title"] == "Garbage pile"

    def test_signup_ignores_client_supplied_role(self, client):
        r = client.post("/register", json={"email": "evil@example.com", "password": PASSWORD,
                                           "full_name": "Evil", "role": "admin", "approval_status": "approved"})
        assert r.status_code == 201
        assert r.json()["data"]["role"] == "citizen"

    def test_duplicate_signup_rejected(self, client):
        self._citizen(client, "dupe@example.com")
        r = client.post("/register", json={"email": "dupe@example.com", "password": PASSWORD, "full_name": "x"})
        assert r.status_code == 400

    def test_report_requires_a_location(self, client):
        h = self._citizen(client)
        body = complaint_payload()
        for k in ("location", "latitude", "longitude"):
            body.pop(k)
        assert client.post("/complaints", json=body, headers=h).status_code == 422

    @pytest.mark.parametrize("lat,lng", [(91, 0), (-91, 0), (0, 181), (0, -181)])
    def test_report_rejects_out_of_range_coordinates(self, client, lat, lng):
        h = self._citizen(client)
        r = client.post("/complaints", json=complaint_payload(latitude=lat, longitude=lng), headers=h)
        assert r.status_code == 422

    def test_citizens_only_see_their_own_reports(self, client):
        h1 = self._citizen(client, "a@example.com")
        h2 = self._citizen(client, "b@example.com")
        cid = client.post("/complaints", json=complaint_payload(), headers=h1).json()["id"]
        assert client.get("/complaints", headers=h2).json() == []
        assert client.get(f"/complaints/{cid}", headers=h2).status_code == 403

    def test_report_requires_login(self, client):
        assert client.post("/complaints", json=complaint_payload()).status_code == 401

    @bug("BUG-07", "category is not validated (VALID_CATEGORIES exists but is never used)")
    def test_unknown_category_rejected(self, client):
        h = self._citizen(client)
        assert client.post("/complaints", json=complaint_payload(category="banana"), headers=h).status_code == 422

    @bug("BUG-08", "citizen password has no minimum length (1 char accepted; authority needs 6, reset needs 6)")
    def test_weak_password_rejected_at_signup(self, client):
        r = client.post("/register", json={"email": "weak@example.com", "password": "a", "full_name": "Weak"})
        assert r.status_code in (400, 422)

    @bug("BUG-09", "e-mail is stored case-sensitively and /login compares exactly, so 'Name@x' cannot log in as 'name@x'")
    def test_login_is_case_insensitive_on_email(self, client):
        client.post("/register", json={"email": "Mixed.Case@example.com", "password": PASSWORD, "full_name": "M"})
        r = client.post("/login", json={"email": "mixed.case@example.com", "password": PASSWORD})
        assert r.status_code == 200

    @bug("BUG-10", "citizen /register does not normalise e-mail case, so 'A@x' and 'a@x' register as two accounts")
    def test_case_variant_email_is_a_duplicate(self, client):
        assert client.post("/register", json={"email": "case@example.com", "password": PASSWORD, "full_name": "A"}).status_code == 201
        r = client.post("/register", json={"email": "CASE@example.com", "password": PASSWORD, "full_name": "B"})
        assert r.status_code == 400


# ── 5. Nearby authorities / tagging ─────────────────────────────────────

class TestTaggingAndNearby:
    def _citizen_h(self, make_user, auth):
        return auth(make_user("citizen"))

    def test_officials_directory_lists_only_approved_active_officials(self, client, make_user, auth):
        ok = make_user("official", full_name="Approved Officer")
        make_user("official", full_name="Pending Officer", approval_status="pending")
        make_user("official", full_name="Rejected Officer", approval_status="rejected")
        make_user("official", full_name="Inactive Officer", is_active=False)
        make_user("citizen", full_name="Citizen Person")
        make_user("student", full_name="Student Person")
        r = client.get("/officials", headers=self._citizen_h(make_user, auth))
        assert r.status_code == 200
        assert [o["id"] for o in r.json()] == [ok.id]

    def test_only_approved_officials_are_tagged_on_a_report(self, client, make_user, auth):
        good = make_user("official", full_name="Good Officer")
        pending = make_user("official", full_name="Pending Officer", approval_status="pending")
        not_official = make_user("citizen", full_name="Not Official")
        h = self._citizen_h(make_user, auth)
        r = client.post("/complaints", headers=h, json=complaint_payload(
            mentions=[good.id, pending.id, not_official.id, 99999]))
        assert [m["id"] for m in r.json()["mentions"]] == [good.id]

    @bug("BUG-11", "create_complaint does not check is_active, so a deactivated official can still be tagged by id "
                   "(the directory search does filter them out)")
    def test_inactive_official_cannot_be_tagged(self, client, make_user, auth):
        gone = make_user("official", is_active=False)
        r = client.post("/complaints", headers=self._citizen_h(make_user, auth),
                        json=complaint_payload(mentions=[gone.id]))
        assert r.json()["mentions"] == []

    def test_more_than_ten_mentions_rejected(self, client, make_user, auth):
        r = client.post("/complaints", headers=self._citizen_h(make_user, auth),
                        json=complaint_payload(mentions=list(range(1, 12))))
        assert r.status_code == 422

    @missing("no 'nearby authorities' feature: officials have no coordinates, there is no radius constant and "
             "no distance filter; GET /officials only does text search. Spec: within NEARBY_RADIUS_KM (2 km) "
             "listed, just outside (2.0+eps) not listed, zero nearby -> empty list")
    def test_nearby_authorities_radius_boundaries(self, client, make_user, auth):
        h = self._citizen_h(make_user, auth)
        r = client.get("/officials/nearby", params={"latitude": 12.9716, "longitude": 77.5946,
                                                    "radius_km": NEARBY_RADIUS_KM}, headers=h)
        assert r.status_code == 200
        assert r.json() == []   # zero authorities nearby


# ── 6. Notification + status workflow ───────────────────────────────────

class TestStatusWorkflow:
    @pytest.fixture()
    def setup(self, client, make_user, auth):
        citizen = make_user("citizen")
        tagged = make_user("official", full_name="Tagged Officer")
        other = make_user("official", full_name="Other Officer")
        hc = auth(citizen)
        cid = client.post("/complaints", headers=hc, json=complaint_payload(mentions=[tagged.id])).json()["id"]
        return {"cid": cid, "citizen": citizen, "hc": hc, "tagged": tagged, "ht": auth(tagged),
                "other": other, "ho": auth(other)}

    def test_tagged_authority_updates_status_and_citizen_sees_it(self, client, setup):
        s = setup
        for st in ("under_review", "in_progress", "resolved"):
            r = client.patch(f"/complaints/{s['cid']}/status", json={"status": st}, headers=s["ht"])
            assert r.status_code == 200 and r.json()["status"] == st
            assert client.get(f"/complaints/{s['cid']}", headers=s["hc"]).json()["status"] == st
        assert client.get("/complaints", headers=s["hc"]).json()[0]["status"] == "resolved"

    def test_citizen_cannot_change_status(self, client, setup):
        r = client.patch(f"/complaints/{setup['cid']}/status", json={"status": "resolved"}, headers=setup["hc"])
        assert r.status_code == 403

    def test_unauthenticated_cannot_change_status(self, client, setup):
        assert client.patch(f"/complaints/{setup['cid']}/status", json={"status": "resolved"}).status_code == 401

    def test_invalid_status_and_revert_rejected(self, client, setup):
        h = setup["ht"]
        assert client.patch(f"/complaints/{setup['cid']}/status", json={"status": "bogus"}, headers=h).status_code == 400
        assert client.patch(f"/complaints/{setup['cid']}/status", json={"status": "submitted"}, headers=h).status_code == 400

    def test_reject_needs_reason(self, client, setup):
        h = setup["ht"]
        assert client.patch(f"/complaints/{setup['cid']}/status", json={"status": "rejected"}, headers=h).status_code == 400
        r = client.patch(f"/complaints/{setup['cid']}/status",
                         json={"status": "rejected", "rejection_reason": "Duplicate report"}, headers=h)
        assert r.status_code == 200 and r.json()["rejection_reason"] == "Duplicate report"

    def test_unknown_complaint_is_404(self, client, setup):
        assert client.patch("/complaints/9999/status", json={"status": "resolved"}, headers=setup["ht"]).status_code == 404

    def test_untagged_authority_cannot_change_status(self, client, setup):
        r = client.patch(f"/complaints/{setup['cid']}/status", json={"status": "resolved"}, headers=setup["ho"])
        assert r.status_code == 403

    @bug("BUG-13", "GET /complaints returns every complaint to every official, not just those they are tagged on / in range of")
    def test_untagged_authority_does_not_see_the_complaint(self, client, setup):
        ids = [c["id"] for c in client.get("/complaints", headers=setup["ho"]).json()]
        assert setup["cid"] not in ids

    @bug("BUG-14", "PATCH /complaints/{id} lets the citizen write officer_notes (an official-only field)")
    def test_citizen_cannot_forge_officer_notes(self, client, setup):
        client.patch(f"/complaints/{setup['cid']}", json={"officer_notes": "Officially approved"}, headers=setup["hc"])
        assert client.get(f"/complaints/{setup['cid']}", headers=setup["hc"]).json()["officer_notes"] in (None, "")

    @bug("BUG-15", "moving a complaint out of 'rejected' keeps the old rejection_reason")
    def test_rejection_reason_cleared_when_reopened(self, client, setup):
        h, cid = setup["ht"], setup["cid"]
        client.patch(f"/complaints/{cid}/status", json={"status": "rejected", "rejection_reason": "Dup"}, headers=h)
        r = client.patch(f"/complaints/{cid}/status", json={"status": "in_progress"}, headers=h)
        assert r.json()["rejection_reason"] in (None, "")

    @missing("authority notification: the backend has no notification model/endpoint for officials or citizens "
             "(only student_notifications). The Flutter authority bell reads MockAuthorityRepository.notifications "
             "(hard-coded mock data). Tagging an official / a status change should create a notification.")
    def test_tagged_authority_gets_notification_and_citizen_notified_of_status(self, client, setup):
        r = client.get("/notifications", headers=setup["ht"])
        assert r.status_code == 200
        assert any(setup["cid"] == n.get("complaint_id") for n in r.json())
