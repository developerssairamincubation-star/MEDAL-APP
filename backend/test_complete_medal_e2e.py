"""
=============================================================================
MEdAL COMPLETE END-TO-END MASTER WORKFLOW VERIFICATION TEST
=============================================================================
Flow:
1. Citizen Registration (POST /register)
2. Citizen Login (POST /login) -> JWT Access Token
3. Profile Inspection & Update (GET /me, PATCH /me)
4. Evidence Photo Upload to MinIO (POST /complaints/upload-evidence)
5. Direct HTTP GET verification of MinIO Object
6. Civic Report Creation (POST /complaints) -> PostgreSQL Persistence
7. Citizen Tracker (GET /complaints)
8. Public Community Feed (GET /complaints/feed) with category filter
9. Civic Engagement / Upvote by peer citizen (POST /complaints/{id}/upvote)
10. Official Processing & Status Lifecycle (PATCH /complaints/{id}/status)
11. Citizen verified status resolution (GET /complaints/{id})
=============================================================================
"""

import io
import uuid
import httpx
from fastapi.testclient import TestClient

from main import app
from app.database.database import SessionLocal
from app.models.user import User

client = TestClient(app)


def run_complete_medal_e2e():
    print("=" * 70)
    print("STARTING COMPLETE MEdAL MASTER END-TO-END WORKFLOW TEST")
    print("=" * 70)

    uid = uuid.uuid4().hex[:8]
    citizen_email = f"e2e_citizen_{uid}@example.com"
    peer_email = f"e2e_peer_{uid}@example.com"
    official_email = f"e2e_official_{uid}@example.com"
    password = "MasterPassword123!"

    # -------------------------------------------------------------------------
    # STAGE 1: Citizen Registration
    # -------------------------------------------------------------------------
    print("\n[STAGE 1] Registering citizen account...")
    reg_res = client.post("/register", json={
        "email": citizen_email,
        "password": password,
        "full_name": "Arun Kumar",
        "phone": "9840123456"
    })
    assert reg_res.status_code == 201, f"Registration failed: {reg_res.text}"
    citizen_id = reg_res.json()["data"]["id"]
    print(f"  -> PASS: Citizen registered successfully (ID: {citizen_id}, Email: {citizen_email})")

    # -------------------------------------------------------------------------
    # STAGE 2: Citizen Login
    # -------------------------------------------------------------------------
    print("\n[STAGE 2] Authenticating citizen & obtaining JWT token...")
    login_res = client.post("/login", json={"email": citizen_email, "password": password})
    assert login_res.status_code == 200, f"Login failed: {login_res.text}"
    token_citizen = login_res.json()["access_token"]
    headers_citizen = {"Authorization": f"Bearer {token_citizen}"}
    print("  -> PASS: JWT Access Token issued")

    # -------------------------------------------------------------------------
    # STAGE 3: Citizen Profile Inspection & Update
    # -------------------------------------------------------------------------
    print("\n[STAGE 3] Inspecting profile (GET /me) & Updating profile (PATCH /me)...")
    me_res = client.get("/me", headers=headers_citizen)
    assert me_res.status_code == 200
    assert me_res.json()["full_name"] == "Arun Kumar"

    patch_res = client.patch("/me", headers=headers_citizen, json={
        "full_name": "Arun Kumar Sundaram",
        "phone": "9840999999"
    })
    assert patch_res.status_code == 200
    assert patch_res.json()["full_name"] == "Arun Kumar Sundaram"
    assert patch_res.json()["phone"] == "9840999999"
    print("  -> PASS: Profile successfully updated in PostgreSQL via PATCH /me")

    # -------------------------------------------------------------------------
    # STAGE 4: Photo Evidence Upload to MinIO Object Storage
    # -------------------------------------------------------------------------
    print("\n[STAGE 4] Uploading photo evidence to MinIO (POST /complaints/upload-evidence)...")
    raw_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00E2E_PHOTO"
    upload_res = client.post(
        "/complaints/upload-evidence",
        headers=headers_citizen,
        files={"file": ("e2e_crater.jpg", io.BytesIO(raw_jpeg), "image/jpeg")}
    )
    assert upload_res.status_code == 200, f"Evidence upload failed: {upload_res.text}"
    evidence_url = upload_res.json()["image_url"]
    assert "medal-evidence/reports/" in evidence_url, f"Expected MinIO URL, got: {evidence_url}"
    print(f"  -> PASS: Evidence uploaded to MinIO: {evidence_url}")

    # -------------------------------------------------------------------------
    # STAGE 5: Direct HTTP Verification of MinIO Evidence
    # -------------------------------------------------------------------------
    print("\n[STAGE 5] Verifying public HTTP GET download of MinIO image...")
    try:
        minio_resp = httpx.get(evidence_url, timeout=3.0)
    except Exception:
        from urllib.parse import urlparse
        local_url = evidence_url.replace(urlparse(evidence_url).netloc, "127.0.0.1:9000")
        minio_resp = httpx.get(local_url, timeout=3.0)
    assert minio_resp.status_code == 200
    assert minio_resp.content == raw_jpeg
    print(f"  -> PASS: MinIO image retrievable via HTTP (200 OK, Size: {len(minio_resp.content)} bytes)")

    # -------------------------------------------------------------------------
    # STAGE 6: Submit Complete Civic Report to PostgreSQL
    # -------------------------------------------------------------------------
    print("\n[STAGE 6] Submitting complete Civic Report (POST /complaints)...")
    report_payload = {
        "title": f"Dangerous Open Manhole near Primary School {uid}",
        "description": "Uncovered drain manhole with high risk of fall injury for schoolchildren during evening hours.",
        "category": "drainage",
        "location": "Opposite St. Jude Primary School, Ward 15",
        "image_url": evidence_url,
        "sdg_alignment": "SDG 11: Sustainable Cities and Communities",
        "impact_level": "Critical",
        "equity_classification": "School / Hospital Vicinity"
    }
    create_res = client.post("/complaints", headers=headers_citizen, json=report_payload)
    assert create_res.status_code == 201, f"Report creation failed: {create_res.text}"
    report_data = create_res.json()
    complaint_id = report_data["id"]
    assert report_data["status"] == "submitted"
    assert report_data["image_url"] == evidence_url
    print(f"  -> PASS: Civic Report #{complaint_id} saved in PostgreSQL")

    # -------------------------------------------------------------------------
    # STAGE 7: Citizen Tracker Verification
    # -------------------------------------------------------------------------
    print("\n[STAGE 7] Verifying report in Citizen Tracker (GET /complaints)...")
    tracker_res = client.get("/complaints", headers=headers_citizen)
    assert tracker_res.status_code == 200
    my_reports = tracker_res.json()
    assert any(r["id"] == complaint_id for r in my_reports)
    print(f"  -> PASS: Report #{complaint_id} present in citizen's tracker list")

    # -------------------------------------------------------------------------
    # STAGE 8: Public Community Feed Verification
    # -------------------------------------------------------------------------
    print("\n[STAGE 8] Verifying report appears in Public Community Feed...")
    feed_res = client.get("/complaints/feed")
    assert feed_res.status_code == 200
    feed_items = feed_res.json()
    feed_item = next((i for i in feed_items if i["id"] == complaint_id), None)
    assert feed_item is not None
    assert feed_item["citizen_name"] == "Arun Kumar Sundaram"
    assert feed_item["citizen_initials"] == "AK"
    assert "email" not in feed_item and "phone" not in feed_item
    print(f"  -> PASS: Public Community Feed displays report #{complaint_id} with full privacy preservation")

    # -------------------------------------------------------------------------
    # STAGE 9: Civic Engagement (Peer Upvote)
    # -------------------------------------------------------------------------
    print("\n[STAGE 9] Peer citizen registers and endorses/upvotes the report...")
    client.post("/register", json={"email": peer_email, "password": password, "full_name": "Pooja Raman", "phone": "9840888888"})
    login_peer = client.post("/login", json={"email": peer_email, "password": password}).json()
    headers_peer = {"Authorization": f"Bearer {login_peer['access_token']}"}

    upvote_res = client.post(f"/complaints/{complaint_id}/upvote", headers=headers_peer)
    assert upvote_res.status_code == 200
    assert upvote_res.json()["total_upvotes"] == 1
    assert upvote_res.json()["has_upvoted"] is True
    print("  -> PASS: Peer upvote registered, total_upvotes = 1")

    # -------------------------------------------------------------------------
    # STAGE 10: Municipal Official Processing & Resolution
    # -------------------------------------------------------------------------
    print("\n[STAGE 10] Official reviews all complaints, inspects stats, and resolves issue...")
    client.post("/register", json={"email": official_email, "password": password, "full_name": "Engineer Divya", "phone": "9840777777"})
    db = SessionLocal()
    off_user = db.query(User).filter(User.email == official_email).first()
    off_user.role = "official"
    db.commit()
    db.close()

    login_off = client.post("/login", json={"email": official_email, "password": password}).json()
    headers_official = {"Authorization": f"Bearer {login_off['access_token']}"}

    # Official checks stats
    stats_res = client.get("/complaints/stats", headers=headers_official)
    assert stats_res.status_code == 200
    print(f"  -> PASS: Official checked analytics dashboard ({stats_res.json()['total_reports']} total reports)")

    # Official advances status: submitted -> in_progress -> resolved
    p_in_prog = client.patch(f"/complaints/{complaint_id}/status", headers=headers_official, json={"status": "in_progress"})
    assert p_in_prog.status_code == 200

    p_resolved = client.patch(f"/complaints/{complaint_id}/status", headers=headers_official, json={"status": "resolved"})
    assert p_resolved.status_code == 200
    assert p_resolved.json()["status"] == "resolved"
    print("  -> PASS: Official marked complaint as 'resolved'")

    # -------------------------------------------------------------------------
    # STAGE 11: Citizen Sees Final Resolved Status
    # -------------------------------------------------------------------------
    print("\n[STAGE 11] Citizen fetches updated report and verifies 'resolved' status...")
    final_res = client.get(f"/complaints/{complaint_id}", headers=headers_citizen)
    assert final_res.status_code == 200
    assert final_res.json()["status"] == "resolved"
    print(f"  -> PASS: Citizen verified report #{complaint_id} status is 'resolved'!")

    print("\n" + "=" * 70)
    print("ALL 11 STAGES OF THE MEdAL MASTER END-TO-END WORKFLOW PASSED 100%!")
    print("=" * 70)


if __name__ == "__main__":
    run_complete_medal_e2e()
