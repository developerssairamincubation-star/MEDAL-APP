"""
Verification of Complaint Comments API & Database Persistence.
Tests:
1. Citizen A registers & creates a complaint.
2. Citizen B registers & logs in.
3. Citizen B posts a comment on the complaint.
4. Verify comment returned matches Citizen B's name, initials, and text.
5. Verify comment is persisted in PostgreSQL.
6. Citizen A posts a second comment.
7. Verify GET /complaints/{id}/comments returns both comments in order.
8. Verify GET /complaints/feed reflects comments_count == 2.
9. Verify posting an empty comment returns 400 Bad Request.
10. Verify posting comment to non-existent complaint returns 404.
11. Verify unauthenticated comment returns 401 Unauthorized.
"""

import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_complaint_comments():
    print("=" * 65)
    print("STARTING COMPLAINT COMMENTS & PERSISTENCE TESTS")
    print("=" * 65)

    # 1. Setup two citizens
    print("\n[STEP 1] Setting up two citizen accounts...")
    uid_a = uuid.uuid4().hex[:8]
    email_a = f"alice_{uid_a}@medal.app"
    pwd = "TestPassword123!"

    r_reg_a = client.post("/register", json={
        "email": email_a,
        "password": pwd,
        "full_name": "Alice Green",
        "phone": "9841000001",
    })
    assert r_reg_a.status_code == 201
    token_a = client.post("/login", json={"email": email_a, "password": pwd}).json()["access_token"]
    headers_a = {"Authorization": f"Bearer {token_a}"}

    uid_b = uuid.uuid4().hex[:8]
    email_b = f"bob_{uid_b}@medal.app"
    r_reg_b = client.post("/register", json={
        "email": email_b,
        "password": pwd,
        "full_name": "Bob Kumar",
        "phone": "9841000002",
    })
    assert r_reg_b.status_code == 201
    token_b = client.post("/login", json={"email": email_b, "password": pwd}).json()["access_token"]
    headers_b = {"Authorization": f"Bearer {token_b}"}
    print("  -> PASS: Citizen Alice and Citizen Bob registered and authenticated")

    # 2. Alice creates a complaint
    print("\n[STEP 2] Alice creates a civic complaint...")
    r_comp = client.post("/complaints", headers=headers_a, json={
        "title": "Broken storm drain flooding road",
        "description": "Severe overflow during rain at junction 4.",
        "category": "drainage",
        "location": "North Canal Road",
    })
    assert r_comp.status_code == 201
    complaint_id = r_comp.json()["id"]
    print(f"  -> PASS: Complaint #{complaint_id} created")

    # 3. Initial comments check
    print("\n[STEP 3] Checking initial comments list is empty...")
    r_initial_comms = client.get(f"/complaints/{complaint_id}/comments")
    assert r_initial_comms.status_code == 200
    assert r_initial_comms.json() == []
    print("  -> PASS: Initial comments list is empty (0 comments)")

    # 4. Bob posts a comment
    print("\n[STEP 4] Bob posts a comment on Alice's complaint...")
    r_post_1 = client.post(
        f"/complaints/{complaint_id}/comments",
        headers=headers_b,
        json={"comment": "I pass here every day, water levels are indeed very high!"},
    )
    assert r_post_1.status_code == 201
    c1 = r_post_1.json()
    assert c1["complaint_id"] == complaint_id
    assert c1["user_name"] == "Bob Kumar"
    assert c1["user_initials"] == "BK"
    assert "I pass here every day" in c1["comment"]
    print(f"  -> PASS: Bob posted comment #{c1['id']} successfully")

    # 5. Alice replies with a comment
    print("\n[STEP 5] Alice replies with a second comment...")
    r_post_2 = client.post(
        f"/complaints/{complaint_id}/comments",
        headers=headers_a,
        json={"comment": "Thanks Bob, I have informed the local ward office as well."},
    )
    assert r_post_2.status_code == 201
    c2 = r_post_2.json()
    assert c2["user_name"] == "Alice Green"
    assert c2["user_initials"] == "AG"
    print(f"  -> PASS: Alice posted reply #{c2['id']} successfully")

    # 6. Retrieve all comments
    print("\n[STEP 6] Retrieving comments for the complaint...")
    r_list = client.get(f"/complaints/{complaint_id}/comments")
    assert r_list.status_code == 200
    all_comments = r_list.json()
    assert len(all_comments) == 2
    assert all_comments[0]["id"] == c1["id"]
    assert all_comments[1]["id"] == c2["id"]
    print("  -> PASS: Both comments retrieved in chronological order")

    # 7. Check Community Feed comments_count
    print("\n[STEP 7] Verifying Community Feed displays correct comments_count...")
    r_feed = client.get("/complaints/feed")
    assert r_feed.status_code == 200
    feed_items = r_feed.json()
    matched = [item for item in feed_items if item["id"] == complaint_id]
    assert len(matched) == 1
    assert matched[0]["comments_count"] == 2
    print(f"  -> PASS: Community Feed reflects exact comments_count = {matched[0]['comments_count']}")

    # 8. Validation tests
    print("\n[STEP 8] Testing validation: empty comment rejected with 400...")
    r_empty = client.post(
        f"/complaints/{complaint_id}/comments",
        headers=headers_b,
        json={"comment": "   "},
    )
    assert r_empty.status_code == 400
    print("  -> PASS: Empty comment rejected with 400 Bad Request")

    print("\n[STEP 9] Testing non-existent complaint rejected with 404...")
    r_404 = client.post(
        "/complaints/999999/comments",
        headers=headers_b,
        json={"comment": "Hello"},
    )
    assert r_404.status_code == 404
    print("  -> PASS: Non-existent complaint rejected with 404 Not Found")

    print("\n[STEP 10] Testing unauthenticated comment rejected with 401...")
    r_unauth = client.post(
        f"/complaints/{complaint_id}/comments",
        json={"comment": "Anonymous comment"},
    )
    assert r_unauth.status_code == 401
    print("  -> PASS: Unauthenticated comment rejected with 401 Unauthorized")

    print("\n" + "=" * 65)
    print("ALL COMPLAINT COMMENTS & PERSISTENCE TESTS PASSED 100%!")
    print("=" * 65)


if __name__ == "__main__":
    test_complaint_comments()
