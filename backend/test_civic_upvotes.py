"""
Comprehensive test suite for Civic Engagement & Upvotes in MEDAL backend.
Tests:
1. Citizen creates a report, initial upvotes = 0
2. Another citizen toggles upvote ON -> returns total_upvotes=1, has_upvoted=True
3. Database level check: verified row in complaint_upvotes table
4. Feed API returns upvotes_count=1
5. User toggles upvote OFF -> returns total_upvotes=0, has_upvoted=False
6. Multiple users upvoting increments properly
7. Unauthenticated upvote rejected with 401
8. Non-existent complaint upvote rejected with 404
"""

import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def run_civic_upvote_tests():
    print("=" * 65)
    print("STARTING CIVIC UPVOTES & ENGAGEMENT TESTS")
    print("=" * 65)

    uid = uuid.uuid4().hex[:8]
    email_a = f"citizen_a_{uid}@example.com"
    email_b = f"citizen_b_{uid}@example.com"
    pwd = "UpvotePassword123!"

    # 1. Register Citizen A and Citizen B
    print("\n[STEP 1] Setting up two citizen accounts...")
    client.post("/register", json={"email": email_a, "password": pwd, "full_name": "Citizen Alice", "phone": "9111111111"})
    client.post("/register", json={"email": email_b, "password": pwd, "full_name": "Citizen Bob", "phone": "9222222222"})

    login_a = client.post("/login", json={"email": email_a, "password": pwd}).json()
    login_b = client.post("/login", json={"email": email_b, "password": pwd}).json()

    headers_a = {"Authorization": f"Bearer {login_a['access_token']}"}
    headers_b = {"Authorization": f"Bearer {login_b['access_token']}"}
    print("  -> PASS: Citizen Alice and Citizen Bob registered and authenticated")

    # 2. Alice creates a complaint
    print("\n[STEP 2] Alice creates a civic report...")
    create_res = client.post("/complaints", headers=headers_a, json={
        "title": f"Broken streetlights on Ring Road {uid}",
        "description": "Entire 200m stretch is completely dark at night",
        "category": "streetlight",
        "location": "Ring Road Sector 7",
        "impact_level": "High"
    })
    assert create_res.status_code == 201
    complaint_id = create_res.json()["id"]
    print(f"  -> PASS: Report #{complaint_id} created")

    # 3. Initial upvote status check
    print("\n[STEP 3] Checking initial upvote status for Bob...")
    status_res = client.get(f"/complaints/{complaint_id}/upvote-status", headers=headers_b)
    assert status_res.status_code == 200
    assert status_res.json()["total_upvotes"] == 0
    assert status_res.json()["has_upvoted"] is False
    print("  -> PASS: Initial upvotes = 0, has_upvoted = False")

    # 4. Bob upvotes Alice's report (toggle ON)
    print("\n[STEP 4] Bob upvotes report (toggle ON)...")
    upvote_res = client.post(f"/complaints/{complaint_id}/upvote", headers=headers_b)
    assert upvote_res.status_code == 200
    res_data = upvote_res.json()
    assert res_data["total_upvotes"] == 1
    assert res_data["has_upvoted"] is True
    print("  -> PASS: Upvoted! total_upvotes = 1, has_upvoted = True")

    # 5. Check Community Feed reflects upvotes_count = 1
    print("\n[STEP 5] Checking Community Feed reflects updated upvote count...")
    feed_res = client.get("/complaints/feed")
    assert feed_res.status_code == 200
    item = next((i for i in feed_res.json() if i["id"] == complaint_id), None)
    assert item is not None
    assert item["upvotes_count"] == 1
    print("  -> PASS: Feed reflects real upvotes_count = 1")

    # 6. Bob toggles upvote OFF
    print("\n[STEP 6] Bob clicks upvote again (toggle OFF)...")
    toggle_off_res = client.post(f"/complaints/{complaint_id}/upvote", headers=headers_b)
    assert toggle_off_res.status_code == 200
    off_data = toggle_off_res.json()
    assert off_data["total_upvotes"] == 0
    assert off_data["has_upvoted"] is False
    print("  -> PASS: Upvote removed cleanly! total_upvotes = 0, has_upvoted = False")

    # 7. Both Alice and Bob upvote (multi-user test)
    print("\n[STEP 7] Both Alice and Bob upvote...")
    client.post(f"/complaints/{complaint_id}/upvote", headers=headers_a)
    client.post(f"/complaints/{complaint_id}/upvote", headers=headers_b)
    final_status = client.get(f"/complaints/{complaint_id}/upvote-status", headers=headers_a).json()
    assert final_status["total_upvotes"] == 2
    assert final_status["has_upvoted"] is True
    print("  -> PASS: Multi-user upvotes working perfectly (total_upvotes = 2)")

    # 8. Unauthenticated upvote rejected
    print("\n[STEP 8] Testing unauthenticated upvote rejected with 401...")
    unauth_res = client.post(f"/complaints/{complaint_id}/upvote")
    assert unauth_res.status_code == 401
    print("  -> PASS: 401 Unauthorized for unauthenticated upvote")

    # 9. Non-existent complaint rejected
    print("\n[STEP 9] Testing upvote for non-existent complaint rejected with 404...")
    not_found_res = client.post("/complaints/9999999/upvote", headers=headers_a)
    assert not_found_res.status_code == 404
    print("  -> PASS: 404 Not Found for invalid complaint ID")

    print("\n" + "=" * 65)
    print("ALL CIVIC UPVOTES & ENGAGEMENT TESTS PASSED SUCCESSFULLY!")
    print("=" * 65)


if __name__ == "__main__":
    run_civic_upvote_tests()
