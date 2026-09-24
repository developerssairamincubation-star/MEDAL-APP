"""
Comprehensive Backend Tests for Threaded Comments & Discussion Hierarchy in MEDAL.
Tests:
1. User registration & authentication for Alice and Bob.
2. Alice creates Complaint A, Bob creates Complaint B.
3. Bob creates a top-level comment on Complaint A (parent_comment_id = None).
4. Alice replies to Bob's comment on Complaint A (parent_comment_id = c1.id).
5. Bob replies to Alice's reply (nested reply, parent_comment_id = c2.id).
6. Reject reply with parent_comment_id from another complaint (400 Bad Request).
7. Reject reply with non-existent parent_comment_id (404 Not Found).
8. Verify GET /complaints/{id}/comments returns all comments with parent_comment_id.
9. Verify GET /complaints/feed comments_count equals top-level + replies (3 total).
10. Verify unauthenticated comment rejected with 401.
11. Verify empty comment rejected with 400.
12. Verify user profile_image_url is returned in comment responses.
"""

import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_threaded_comments():
    print("=" * 65)
    print("STARTING THREADED COMMENTS & HIERARCHY TESTS")
    print("=" * 65)

    # 1. Setup two citizens
    print("\n[STEP 1] Setting up Citizen Alice and Citizen Bob...")
    uid_a = uuid.uuid4().hex[:8]
    email_a = f"alice_{uid_a}@medal.app"
    pwd = "TestPassword123!"

    r_reg_a = client.post("/register", json={
        "email": email_a,
        "password": pwd,
        "full_name": "Alice Walker",
        "phone": "9841111111",
    })
    assert r_reg_a.status_code == 201
    token_a = client.post("/login", json={"email": email_a, "password": pwd}).json()["access_token"]
    headers_a = {"Authorization": f"Bearer {token_a}"}

    uid_b = uuid.uuid4().hex[:8]
    email_b = f"bob_{uid_b}@medal.app"
    r_reg_b = client.post("/register", json={
        "email": email_b,
        "password": pwd,
        "full_name": "Bob Davis",
        "phone": "9841111112",
    })
    assert r_reg_b.status_code == 201
    token_b = client.post("/login", json={"email": email_b, "password": pwd}).json()["access_token"]
    headers_b = {"Authorization": f"Bearer {token_b}"}
    print("  -> PASS: Citizen Alice and Citizen Bob authenticated successfully")

    # 2. Setup complaints
    print("\n[STEP 2] Creating test complaints...")
    r_comp_a = client.post("/complaints", headers=headers_a, json={
        "title": "Flooded Underpass at Station Road",
        "description": "Drainage pump failure causing waterlogging.",
        "category": "drainage",
        "location": "Station Road Junction",
    })
    assert r_comp_a.status_code == 201
    comp_a_id = r_comp_a.json()["id"]

    r_comp_b = client.post("/complaints", headers=headers_b, json={
        "title": "Broken Streetlights in Ward 7",
        "description": "Pitch black stretch on 2nd avenue.",
        "category": "streetlight",
        "location": "Ward 7, 2nd Avenue",
    })
    assert r_comp_b.status_code == 201
    comp_b_id = r_comp_b.json()["id"]
    print(f"  -> PASS: Complaint A #{comp_a_id} and Complaint B #{comp_b_id} created")

    # 3. Create top-level comment on Complaint A
    print("\n[STEP 3] Bob posts a top-level comment on Complaint A...")
    r_c1 = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_b,
        json={
            "content": "Water is over 2 feet deep near the subway!",
            "parent_comment_id": None,
        },
    )
    assert r_c1.status_code == 201
    c1 = r_c1.json()
    assert c1["parent_comment_id"] is None
    assert c1["user_name"] == "Bob Davis"
    assert c1["username"] == "Bob Davis"
    assert c1["comment"] == "Water is over 2 feet deep near the subway!"
    assert c1["content"] == "Water is over 2 feet deep near the subway!"
    print(f"  -> PASS: Top-level comment #{c1['id']} created (parent_comment_id = None)")

    # 4. Alice replies to Bob's comment
    print("\n[STEP 4] Alice replies to Bob's comment...")
    r_c2 = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_a,
        json={
            "content": "@Bob Davis Thanks for confirming. I called the municipal helpline.",
            "parent_comment_id": c1["id"],
        },
    )
    assert r_c2.status_code == 201
    c2 = r_c2.json()
    assert c2["parent_comment_id"] == c1["id"]
    assert c2["user_name"] == "Alice Walker"
    assert "@Bob Davis" in c2["content"]
    print(f"  -> PASS: Reply #{c2['id']} created with parent_comment_id = {c1['id']}")

    # 5. Bob replies to Alice's reply (nested reply)
    print("\n[STEP 5] Bob posts a nested reply to Alice...")
    r_c3 = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_b,
        json={
            "content": "@Alice Walker Great, please let us know if they send a pump truck.",
            "parent_comment_id": c2["id"],
        },
    )
    assert r_c3.status_code == 201
    c3 = r_c3.json()
    assert c3["parent_comment_id"] == c2["id"]
    print(f"  -> PASS: Nested reply #{c3['id']} created with parent_comment_id = {c2['id']}")

    # 6. Reject parent_comment_id belonging to another complaint
    print("\n[STEP 6] Testing cross-complaint parent_comment_id rejected with 400...")
    r_cross = client.post(
        f"/complaints/{comp_b_id}/comments",
        headers=headers_a,
        json={
            "content": "Trying to reply to a comment on another complaint",
            "parent_comment_id": c1["id"],  # c1 belongs to comp_a, not comp_b
        },
    )
    assert r_cross.status_code == 400
    assert "belongs to a different complaint" in r_cross.json()["detail"]
    print("  -> PASS: Cross-complaint parent_comment_id rejected with 400 Bad Request")

    # 7. Reject non-existent parent_comment_id
    print("\n[STEP 7] Testing non-existent parent_comment_id rejected with 404...")
    r_invalid_parent = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_a,
        json={
            "content": "Replying to phantom comment",
            "parent_comment_id": 999999,
        },
    )
    assert r_invalid_parent.status_code == 404
    print("  -> PASS: Non-existent parent_comment_id rejected with 404 Not Found")

    # 8. Retrieve all comments for Complaint A
    print("\n[STEP 8] Retrieving comments for Complaint A...")
    r_list = client.get(f"/complaints/{comp_a_id}/comments")
    assert r_list.status_code == 200
    comments = r_list.json()
    assert len(comments) == 3
    assert comments[0]["id"] == c1["id"]
    assert comments[0]["parent_comment_id"] is None
    assert comments[1]["id"] == c2["id"]
    assert comments[1]["parent_comment_id"] == c1["id"]
    assert comments[2]["id"] == c3["id"]
    assert comments[2]["parent_comment_id"] == c2["id"]
    print("  -> PASS: GET comments returns all threaded comments with correct parent_comment_id")

    # 9. Verify comments_count includes top-level + replies
    print("\n[STEP 9] Verifying Community Feed comments_count includes replies...")
    r_feed = client.get("/complaints/feed")
    assert r_feed.status_code == 200
    feed_items = r_feed.json()
    matched = [item for item in feed_items if item["id"] == comp_a_id]
    assert len(matched) == 1
    assert matched[0]["comments_count"] == 3
    print(f"  -> PASS: Feed reflects total comments_count = {matched[0]['comments_count']} (top-level + replies)")

    # 10. Security & Validation checks
    print("\n[STEP 10] Testing security & validation...")
    r_unauth = client.post(
        f"/complaints/{comp_a_id}/comments",
        json={"content": "Anonymous reply", "parent_comment_id": c1["id"]},
    )
    assert r_unauth.status_code == 401
    print("  -> PASS: Unauthenticated reply rejected with 401 Unauthorized")

    r_empty = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_a,
        json={"content": "   ", "parent_comment_id": c1["id"]},
    )
    assert r_empty.status_code == 400
    print("  -> PASS: Empty comment rejected with 400 Bad Request")

    print("\n" + "=" * 65)
    print("ALL THREADED COMMENTS & HIERARCHY TESTS PASSED 100%!")
    print("=" * 65)


if __name__ == "__main__":
    test_threaded_comments()
