"""
Safe, isolated unit and integration test suite for Authority Status Updates,
Officer Notes, and Rejection Reason persistence.

Uses an in-memory SQLite database via FastAPI dependency override (get_db).
Completely isolated from the live PostgreSQL development database.
"""

import sys
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from app.database.database import Base, get_db
from app.models.user import User
from app.models.complaint import Complaint
from app.utils.security import hash_password, create_access_token


# 1. Setup in-memory SQLite engine
SQLITE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLITE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


def setup_test_fixtures():
    """Create all tables in memory and seed test accounts and a complaint."""
    Base.metadata.create_all(bind=engine)
    db = TestingSession()

    # Seed Citizen user
    citizen = User(
        email="citizen_test@medal.gov",
        password_hash=hash_password("TestPass123!"),
        full_name="Test Citizen",
        role="citizen",
        is_verified=True,
        is_active=True,
    )
    # Seed Official user
    official = User(
        email="official_test@medal.gov",
        password_hash=hash_password("TestPass123!"),
        full_name="Ward Officer Kumar",
        role="official",
        is_verified=True,
        is_active=True,
    )
    # Seed Admin user
    admin = User(
        email="admin_test@medal.gov",
        password_hash=hash_password("TestPass123!"),
        full_name="Zonal Admin",
        role="admin",
        is_verified=True,
        is_active=True,
    )
    db.add_all([citizen, official, admin])
    db.commit()
    db.refresh(citizen)
    db.refresh(official)
    db.refresh(admin)

    # Seed Complaint
    complaint = Complaint(
        title="Overflowing Garbage at Central Junction",
        description="Waste bin overflowing on main avenue causing hazard.",
        category="waste",
        status="submitted",
        location="Central Junction, Ward 14",
        citizen_id=citizen.id,
    )
    db.add(complaint)
    db.commit()
    db.refresh(complaint)

    # Tokens
    citizen_token = create_access_token({"sub": str(citizen.id), "role": citizen.role})
    official_token = create_access_token({"sub": str(official.id), "role": official.role})
    admin_token = create_access_token({"sub": str(admin.id), "role": admin.role})

    fixtures = {
        "citizen": citizen,
        "official": official,
        "admin": admin,
        "complaint": complaint,
        "citizen_headers": {"Authorization": f"Bearer {citizen_token}"},
        "official_headers": {"Authorization": f"Bearer {official_token}"},
        "admin_headers": {"Authorization": f"Bearer {admin_token}"},
    }
    db.close()
    return fixtures


def run_all_tests():
    print("=" * 70)
    print("RUNNING ISOLATED AUTHORITY STATUS UPDATE TESTS (IN-MEMORY SQLITE)")
    print("=" * 70)

    f = setup_test_fixtures()
    cid = f["complaint"].id
    official_h = f["official_headers"]
    citizen_h = f["citizen_headers"]

    # Test 1: Unauthorized user (citizen) cannot update status -> 403
    print("\n[TEST 1] Citizen role cannot update complaint status (403 Forbidden)...")
    res = client.patch(f"/complaints/{cid}/status", headers=citizen_h, json={"status": "in_progress"})
    assert res.status_code == 403, f"Expected 403, got {res.status_code}: {res.text}"
    print("  -> PASS: Citizen forbidden from updating status (403).")

    # Test 2: Unauthenticated user cannot update status -> 401
    print("\n[TEST 2] Unauthenticated request cannot update complaint status (401 Unauthorized)...")
    res = client.patch(f"/complaints/{cid}/status", json={"status": "in_progress"})
    assert res.status_code == 401, f"Expected 401, got {res.status_code}: {res.text}"
    print("  -> PASS: Unauthenticated request rejected (401).")

    # Test 3: Missing complaint ID -> 404
    print("\n[TEST 3] Updating non-existent complaint ID returns 404 Not Found...")
    res = client.patch("/complaints/99999/status", headers=official_h, json={"status": "in_progress"})
    assert res.status_code == 404, f"Expected 404, got {res.status_code}: {res.text}"
    print("  -> PASS: Missing complaint returns 404.")

    # Test 4: Invalid status value -> 400
    print("\n[TEST 4] Invalid status string returns 400 Bad Request...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={"status": "not_a_valid_status"})
    assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
    assert "Invalid status" in res.json()["detail"]
    print("  -> PASS: Unsupported status rejected with 400.")

    # Test 5: Reverting to 'submitted' is rejected -> 400
    print("\n[TEST 5] Reverting status to 'submitted' is rejected (400 Bad Request)...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={"status": "submitted"})
    assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
    assert "Cannot revert complaint status" in res.json()["detail"]
    print("  -> PASS: Setting status to 'submitted' correctly rejected (400).")

    # Test 6: Valid update to 'under_review' with officer note
    print("\n[TEST 6] Official updates status to 'under_review' with officer note...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "under_review",
        "officer_notes": "Complaint assigned to inspection team Alpha."
    })
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    data = res.json()
    assert data["status"] == "under_review"
    assert data["officer_notes"] == "Complaint assigned to inspection team Alpha."
    assert data["rejection_reason"] is None
    print("  -> PASS: Status updated to 'under_review' and note saved.")

    # Test 7: 'assigned' status specifically
    print("\n[TEST 7] Official updates status to 'assigned' with note...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "assigned",
        "officer_notes": "Assigned to Ward 14 Sanitation Unit."
    })
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    data = res.json()
    assert data["status"] == "assigned"
    assert data["officer_notes"] == "Assigned to Ward 14 Sanitation Unit."
    print("  -> PASS: 'assigned' status successfully persisted.")

    # Test 8: 'in_progress' status
    print("\n[TEST 8] Official updates status to 'in_progress'...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "in_progress",
        "officer_notes": "Sanitation crew on site. Clearing waste."
    })
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    data = res.json()
    assert data["status"] == "in_progress"
    assert data["officer_notes"] == "Sanitation crew on site. Clearing waste."
    print("  -> PASS: 'in_progress' status successfully persisted.")

    # Test 9: Rejection reason provided when status is NOT rejected -> 400
    print("\n[TEST 9] Rejection reason provided when status is not rejected returns 400...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "in_progress",
        "rejection_reason": "Not within our jurisdiction"
    })
    assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
    assert "Rejection reason can only be provided when status is 'rejected'" in res.json()["detail"]
    print("  -> PASS: Rejection reason rejected when status is not rejected.")

    # Test 10: Rejecting with empty rejection reason -> 400
    print("\n[TEST 10] Rejecting a complaint without a rejection reason returns 400...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "rejected",
        "rejection_reason": "   "
    })
    assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.text}"
    assert "A rejection reason must be provided" in res.json()["detail"]
    print("  -> PASS: Rejecting without reason blocked (400).")

    # Test 11: Valid rejection with rejection reason and officer note
    print("\n[TEST 11] Official rejects complaint with valid rejection reason...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "rejected",
        "rejection_reason": "Private residential property; municipal authority cannot intervene.",
        "officer_notes": "Advised citizen to contact property owners association."
    })
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    data = res.json()
    assert data["status"] == "rejected"
    assert data["rejection_reason"] == "Private residential property; municipal authority cannot intervene."
    assert data["officer_notes"] == "Advised citizen to contact property owners association."
    print("  -> PASS: Complaint rejected with reason and notes persisted.")

    # Test 12: Overwrite protection: updating without rejection_reason preserves existing reason
    print("\n[TEST 12] Preserving existing rejection reason when not provided in subsequent call...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "rejected",
        "officer_notes": "Follow-up phone call completed."
    })
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    data = res.json()
    assert data["status"] == "rejected"
    assert data["rejection_reason"] == "Private residential property; municipal authority cannot intervene."
    assert data["officer_notes"] == "Follow-up phone call completed."
    print("  -> PASS: Existing rejection reason preserved.")

    # Test 13: Retrieving via GET /complaints/{id} returns saved officer notes & rejection reason
    print("\n[TEST 13] Verification via GET /complaints/{id}...")
    detail_res = client.get(f"/complaints/{cid}", headers=official_h)
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["status"] == "rejected"
    assert detail["rejection_reason"] == "Private residential property; municipal authority cannot intervene."
    assert detail["officer_notes"] == "Follow-up phone call completed."
    print("  -> PASS: GET endpoint accurately reflects persisted notes and rejection reason.")

    # Test 14: Valid status update to 'resolved'
    print("\n[TEST 14] Official updates status to 'resolved'...")
    res = client.patch(f"/complaints/{cid}/status", headers=official_h, json={
        "status": "resolved",
        "officer_notes": "Resolved following site re-inspection."
    })
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "resolved"
    assert data["officer_notes"] == "Resolved following site re-inspection."
    print("  -> PASS: 'resolved' status successfully set.")

    # Test 15: GET /complaints/stats reflects 'assigned' and updated counts
    print("\n[TEST 15] Checking GET /complaints/stats includes assigned count...")
    stats_res = client.get("/complaints/stats", headers=official_h)
    assert stats_res.status_code == 200
    stats = stats_res.json()
    assert "assigned" in stats
    assert "resolved" in stats
    assert stats["resolved"] >= 1
    print(f"  -> PASS: Stats endpoint verified with assigned={stats['assigned']}, resolved={stats['resolved']}.")

    print("\n" + "=" * 70)
    print("ALL 15 ISOLATED AUTHORITY STATUS UPDATE TESTS PASSED 100%!")
    print("=" * 70)


if __name__ == "__main__":
    run_all_tests()
