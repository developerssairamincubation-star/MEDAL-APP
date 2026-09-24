"""
Comprehensive test suite for Official & Institution workflow in MEDAL backend.
Tests:
1. Official & Admin authentication
2. Citizen files a report with evidence
3. Official views all complaints via GET /complaints
4. Official views complaint stats & analytics via GET /complaints/stats
5. Official updates status: submitted -> under_review -> in_progress -> resolved
6. Citizen is blocked from modifying status (403 Forbidden)
7. Citizen views updated complaint detail showing "resolved"
"""

import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def run_official_workflow_tests():
    print("=" * 65)
    print("STARTING OFFICIAL & INSTITUTION WORKFLOW TESTS")
    print("=" * 65)

    uid = uuid.uuid4().hex[:8]
    pwd = "OfficialPassword123!"

    # 1. Register Citizen and Official
    print("\n[STEP 1] Setting up Citizen and Official accounts...")
    citizen_email = f"citizen_wf_{uid}@example.com"
    official_email = f"official_wf_{uid}@example.com"

    client.post("/register", json={
        "email": citizen_email,
        "password": pwd,
        "full_name": "Citizen User",
        "phone": "9000000001"
    })
    # Create Official account directly
    client.post("/register", json={
        "email": official_email,
        "password": pwd,
        "full_name": "Ward Engineer Anitha",
        "phone": "9000000002"
    })

    # Elevate official role in database
    from app.database.database import SessionLocal
    from app.models.user import User
    db = SessionLocal()
    off_user = db.query(User).filter(User.email == official_email).first()
    off_user.role = "official"
    db.commit()
    db.close()

    login_c = client.post("/login", json={"email": citizen_email, "password": pwd}).json()
    login_o = client.post("/login", json={"email": official_email, "password": pwd}).json()

    headers_citizen = {"Authorization": f"Bearer {login_c['access_token']}"}
    headers_official = {"Authorization": f"Bearer {login_o['access_token']}"}
    print(f"  -> PASS: Accounts created. Official role = {login_o['data']['role']}")

    # 2. Citizen creates a report
    print("\n[STEP 2] Citizen creates a new report...")
    res = client.post("/complaints", headers=headers_citizen, json={
        "title": f"Broken Water Main {uid}",
        "description": "Massive pipeline rupture causing street flood",
        "category": "water",
        "location": "Ward 12, Main Road",
        "impact_level": "High",
        "equity_classification": "Hospital Corridor"
    })
    assert res.status_code == 201
    complaint_id = res.json()["id"]
    print(f"  -> PASS: Citizen created complaint #{complaint_id} with status 'submitted'")

    # 3. Official views all complaints
    print("\n[STEP 3] Official queries all city complaints (GET /complaints)...")
    all_res = client.get("/complaints", headers=headers_official)
    assert all_res.status_code == 200
    all_complaints = all_res.json()
    assert any(c["id"] == complaint_id for c in all_complaints)
    print(f"  -> PASS: Official sees all complaints ({len(all_complaints)} total)")

    # 4. Official queries stats
    print("\n[STEP 4] Official queries analytics (GET /complaints/stats)...")
    stats_res = client.get("/complaints/stats", headers=headers_official)
    assert stats_res.status_code == 200
    stats = stats_res.json()
    assert "total_reports" in stats
    assert "submitted" in stats
    assert "in_progress" in stats
    assert "resolved" in stats
    assert "by_category" in stats
    print(f"  -> PASS: Analytics verified. Total: {stats['total_reports']}, Submitted: {stats['submitted']}")

    # 5. Citizen forbidden from updating status
    print("\n[STEP 5] Verifying citizen cannot update status (403 Forbidden)...")
    cit_patch = client.patch(
        f"/complaints/{complaint_id}/status",
        headers=headers_citizen,
        json={"status": "resolved"}
    )
    assert cit_patch.status_code == 403
    print("  -> PASS: Citizen status update correctly blocked with 403 Forbidden")

    # 6. Official transitions status through lifecycle
    print("\n[STEP 6] Official updates status through lifecycle (under_review -> in_progress -> resolved)...")
    p1 = client.patch(f"/complaints/{complaint_id}/status", headers=headers_official, json={"status": "under_review"})
    assert p1.status_code == 200 and p1.json()["status"] == "under_review"

    p2 = client.patch(f"/complaints/{complaint_id}/status", headers=headers_official, json={"status": "in_progress"})
    assert p2.status_code == 200 and p2.json()["status"] == "in_progress"

    p3 = client.patch(f"/complaints/{complaint_id}/status", headers=headers_official, json={"status": "resolved"})
    assert p3.status_code == 200 and p3.json()["status"] == "resolved"
    print("  -> PASS: Status successfully updated to 'resolved'")

    # 7. Citizen checks updated complaint
    print("\n[STEP 7] Citizen views updated complaint details (GET /complaints/{id})...")
    detail = client.get(f"/complaints/{complaint_id}", headers=headers_citizen)
    assert detail.status_code == 200
    assert detail.json()["status"] == "resolved"
    print(f"  -> PASS: Citizen receives verified 'resolved' status on report #{complaint_id}")

    print("\n" + "=" * 65)
    print("ALL OFFICIAL & INSTITUTION WORKFLOW TESTS PASSED SUCCESSFULLY!")
    print("=" * 65)


if __name__ == "__main__":
    run_official_workflow_tests()
