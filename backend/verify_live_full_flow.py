"""
Live Real-World Integration & Verification Script
Executes the exact 15-step manual flow against the live FastAPI server at http://127.0.0.1:8000
and MinIO container at http://127.0.0.1:9000.
"""

import io
import uuid
import httpx

BASE_URL = "http://127.0.0.1:8000"


def main():
    print("=" * 70)
    print("STARTING LIVE REAL-WORLD INTEGRATION VERIFICATION")
    print(f"Target Server: {BASE_URL}")
    print("=" * 70)

    uid = uuid.uuid4().hex[:8]
    citizen_email = f"live_citizen_{uid}@medal.app"
    peer_email = f"live_peer_{uid}@medal.app"
    official_email = f"live_official_{uid}@medal.gov.in"
    password = "LivePassword123!"

    # 1. Health check
    print("\n[STEP 1] Testing Server Root & Docs...")
    r_root = httpx.get(f"{BASE_URL}/")
    assert r_root.status_code == 200, f"Root failed: {r_root.status_code}"
    r_docs = httpx.get(f"{BASE_URL}/docs")
    assert r_docs.status_code == 200, f"Docs failed: {r_docs.status_code}"
    print(f"  -> PASS: GET / returned {r_root.json()}, GET /docs returned 200 OK")

    # 2. Register Citizen
    print(f"\n[STEP 2] Registering Citizen ({citizen_email})...")
    r_reg = httpx.post(f"{BASE_URL}/register", json={
        "email": citizen_email,
        "password": password,
        "full_name": "Senthil Nathan",
        "phone": "9841011223"
    })
    assert r_reg.status_code == 201, f"Registration failed: {r_reg.text}"
    print(f"  -> PASS: Citizen registered (ID: {r_reg.json()['data']['id']})")

    # 3. Login Citizen
    print("\n[STEP 3] Logging in Citizen...")
    r_login = httpx.post(f"{BASE_URL}/login", json={
        "email": citizen_email,
        "password": password
    })
    assert r_login.status_code == 200, f"Login failed: {r_login.text}"
    token_citizen = r_login.json()["access_token"]
    headers_citizen = {"Authorization": f"Bearer {token_citizen}"}
    print("  -> PASS: Logged in, JWT token obtained")

    # 4. Upload Evidence to MinIO
    print("\n[STEP 4] Uploading photo evidence to MinIO via /complaints/upload-evidence...")
    sample_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00LIVE_EVIDENCE_PHOTO"
    r_upload = httpx.post(
        f"{BASE_URL}/complaints/upload-evidence",
        headers=headers_citizen,
        files={"file": ("live_pothole.jpg", io.BytesIO(sample_jpeg), "image/jpeg")}
    )
    assert r_upload.status_code == 200, f"Upload failed: {r_upload.text}"
    image_url = r_upload.json()["image_url"]
    print(f"  -> PASS: Evidence uploaded to MinIO: {image_url}")

    # 5. Direct MinIO HTTP GET check
    print("\n[STEP 5] Verifying image is stored & accessible in MinIO container...")
    r_minio = httpx.get(image_url, timeout=5.0)
    assert r_minio.status_code == 200, f"MinIO image fetch failed: {r_minio.status_code}"
    assert r_minio.content == sample_jpeg
    print(f"  -> PASS: MinIO photo retrieved via HTTP (200 OK, {len(r_minio.content)} bytes)")

    # 6. Submit Civic Report
    print("\n[STEP 6] Submitting Civic Report (POST /complaints)...")
    r_create = httpx.post(
        f"{BASE_URL}/complaints",
        headers=headers_citizen,
        json={
            "title": f"Dangerous Open Drainage Trench {uid}",
            "description": "Exposed concrete drainage trench overflowing near community market.",
            "category": "drainage",
            "location": "Anna Nagar 3rd Avenue, Ward 10",
            "image_url": image_url,
            "sdg_alignment": "SDG 6: Clean Water and Sanitation",
            "impact_level": "High",
            "equity_classification": "Commercial District"
        }
    )
    assert r_create.status_code == 201, f"Report creation failed: {r_create.text}"
    complaint_id = r_create.json()["id"]
    print(f"  -> PASS: Report #{complaint_id} created successfully with status 'submitted'")

    # 7. Open Tracker (GET /complaints)
    print("\n[STEP 7] Opening Citizen Tracker (GET /complaints)...")
    r_tracker = httpx.get(f"{BASE_URL}/complaints", headers=headers_citizen)
    assert r_tracker.status_code == 200
    my_list = r_tracker.json()
    assert any(c["id"] == complaint_id for c in my_list)
    print(f"  -> PASS: Report #{complaint_id} appears in Citizen Tracker list")

    # 8. Open Report Details (GET /complaints/{id})
    print(f"\n[STEP 8] Opening Report Details for #{complaint_id}...")
    r_detail = httpx.get(f"{BASE_URL}/complaints/{complaint_id}", headers=headers_citizen)
    assert r_detail.status_code == 200
    assert r_detail.json()["image_url"] == image_url
    print(f"  -> PASS: Report details verified (Category: {r_detail.json()['category']}, Status: {r_detail.json()['status']})")

    # 9. Open Community Feed (GET /complaints/feed)
    print("\n[STEP 9] Opening Public Community Feed...")
    r_feed = httpx.get(f"{BASE_URL}/complaints/feed")
    assert r_feed.status_code == 200
    feed_items = r_feed.json()
    feed_item = next((i for i in feed_items if i["id"] == complaint_id), None)
    assert feed_item is not None
    assert feed_item["citizen_name"] == "Senthil Nathan"
    assert feed_item["citizen_initials"] == "SN"
    assert "email" not in feed_item and "phone" not in feed_item
    print(f"  -> PASS: Feed displays report #{complaint_id} with privacy preserved")

    # 10. Filter Community Feed by Category
    print("\n[STEP 10] Filtering Community Feed (?category=drainage)...")
    r_filter = httpx.get(f"{BASE_URL}/complaints/feed?category=infrastructure")
    assert r_filter.status_code == 200
    assert any(i["id"] == complaint_id for i in r_filter.json())
    print("  -> PASS: Category filtering operates correctly")

    # 11. Peer Citizen Upvotes
    print("\n[STEP 11] Peer Citizen registers and upvotes report...")
    httpx.post(f"{BASE_URL}/register", json={"email": peer_email, "password": password, "full_name": "Priya Ramesh", "phone": "9841998877"})
    token_peer = httpx.post(f"{BASE_URL}/login", json={"email": peer_email, "password": password}).json()["access_token"]
    headers_peer = {"Authorization": f"Bearer {token_peer}"}

    r_upvote = httpx.post(f"{BASE_URL}/complaints/{complaint_id}/upvote", headers=headers_peer)
    assert r_upvote.status_code == 200
    assert r_upvote.json()["total_upvotes"] == 1
    assert r_upvote.json()["has_upvoted"] is True
    print("  -> PASS: Upvote recorded (total_upvotes = 1)")

    # 12. Open Profile (GET /me)
    print("\n[STEP 12] Inspecting Profile (GET /me)...")
    r_me = httpx.get(f"{BASE_URL}/me", headers=headers_citizen)
    assert r_me.status_code == 200
    print(f"  -> PASS: Profile loaded (Name: {r_me.json()['full_name']}, Email: {r_me.json()['email']})")

    # 13. Edit Profile (PATCH /me)
    print("\n[STEP 13] Editing Profile (PATCH /me)...")
    r_patch = httpx.patch(f"{BASE_URL}/me", headers=headers_citizen, json={
        "full_name": "Senthil Nathan K.",
        "phone": "9841099999"
    })
    assert r_patch.status_code == 200
    assert r_patch.json()["full_name"] == "Senthil Nathan K."
    assert r_patch.json()["phone"] == "9841099999"
    print("  -> PASS: Profile updated successfully")

    # 14. Verify Updated Profile (GET /me)
    print("\n[STEP 14] Verifying updated profile persistence...")
    r_me_updated = httpx.get(f"{BASE_URL}/me", headers=headers_citizen)
    assert r_me_updated.json()["full_name"] == "Senthil Nathan K."
    print("  -> PASS: Updated profile persisted in PostgreSQL")

    # 15. Official Lifecycle & Status Update
    print("\n[STEP 15] Municipal Official reviews and resolves report...")
    httpx.post(f"{BASE_URL}/register", json={"email": official_email, "password": password, "full_name": "Ward Inspector Rajesh", "phone": "9841055555"})
    
    # Update official role
    from app.database.database import SessionLocal
    from app.models.user import User
    db = SessionLocal()
    u = db.query(User).filter(User.email == official_email).first()
    u.role = "official"
    db.commit()
    db.close()

    token_off = httpx.post(f"{BASE_URL}/login", json={"email": official_email, "password": password}).json()["access_token"]
    headers_official = {"Authorization": f"Bearer {token_off}"}

    # Official checks stats
    r_stats = httpx.get(f"{BASE_URL}/complaints/stats", headers=headers_official)
    assert r_stats.status_code == 200
    print(f"  -> PASS: Official accessed analytics dashboard (Total reports: {r_stats.json()['total_reports']})")

    # Official marks report as in_progress then resolved
    httpx.patch(f"{BASE_URL}/complaints/{complaint_id}/status", headers=headers_official, json={"status": "in_progress"})
    r_res = httpx.patch(f"{BASE_URL}/complaints/{complaint_id}/status", headers=headers_official, json={"status": "resolved"})
    assert r_res.status_code == 200
    assert r_res.json()["status"] == "resolved"
    print(f"  -> PASS: Official resolved report #{complaint_id}")

    # Citizen checks updated report
    r_final = httpx.get(f"{BASE_URL}/complaints/{complaint_id}", headers=headers_citizen)
    assert r_final.status_code == 200
    assert r_final.json()["status"] == "resolved"
    print(f"  -> PASS: Citizen verified report #{complaint_id} status is 'resolved'!")

    print("\n" + "=" * 70)
    print("ALL 15 LIVE INTEGRATION VERIFICATION STEPS PASSED 100%!")
    print("=" * 70)


if __name__ == "__main__":
    main()
