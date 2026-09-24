"""
Comprehensive Backend Tests for Comment Deletion & Ownership Enforcement in MEDAL.
Tests:
1. User registration & authentication for Citizen Alice and Citizen Bob.
2. Alice creates Complaint A and Complaint B.
3. Alice posts comment A1 on Complaint A.
4. Bob posts comment B1 on Complaint A.
5. Bob replies to A1 with reply B2 on Complaint A (A1 now has a child reply).
6. Security Check: Alice attempts to delete Bob's comment B1 -> 403 Forbidden.
7. Security Check: Bob attempts to delete Alice's comment A1 -> 403 Forbidden.
8. Security Check: Unauthenticated deletion -> 401 Unauthorized.
9. Validation Check: Delete non-existent comment -> 404 Not Found.
10. Validation Check: Delete comment belonging to different complaint -> 404 Not Found.
11. Leaf Comment Deletion: Bob deletes his leaf comment B1 -> 200 OK, permanently hard-deleted.
12. Threaded Parent Deletion: Alice deletes A1 (has reply B2) -> 200 OK, soft-deleted as "This comment was deleted", reply B2 preserved.
13. Feed comments_count accurately decrements to count only active non-deleted comments.
"""

import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_comment_deletion():
    print("=" * 65)
    print("STARTING COMMENT DELETION & OWNERSHIP ENFORCEMENT TESTS")
    print("=" * 65)

    # 1. Setup two citizens
    print("\n[STEP 1] Registering Citizen Alice and Citizen Bob...")
    uid_a = uuid.uuid4().hex[:8]
    email_a = f"alice_del_{uid_a}@medal.app"
    pwd = "TestPassword123!"

    r_reg_a = client.post("/register", json={
        "email": email_a,
        "password": pwd,
        "full_name": "Alice Green",
        "phone": "9842000001",
    })
    assert r_reg_a.status_code == 201
    token_a = client.post("/login", json={"email": email_a, "password": pwd}).json()["access_token"]
    headers_a = {"Authorization": f"Bearer {token_a}"}

    uid_b = uuid.uuid4().hex[:8]
    email_b = f"bob_del_{uid_b}@medal.app"
    r_reg_b = client.post("/register", json={
        "email": email_b,
        "password": pwd,
        "full_name": "Bob White",
        "phone": "9842000002",
    })
    assert r_reg_b.status_code == 201
    token_b = client.post("/login", json={"email": email_b, "password": pwd}).json()["access_token"]
    headers_b = {"Authorization": f"Bearer {token_b}"}
    print("  -> PASS: Citizens registered and authenticated")

    # 2. Setup complaints
    print("\n[STEP 2] Creating test complaints...")
    r_comp_a = client.post("/complaints", headers=headers_a, json={
        "title": "Broken traffic signal at junction",
        "description": "Lights stuck on red continuously.",
        "category": "infrastructure",
        "location": "Junction 7",
    })
    assert r_comp_a.status_code == 201
    comp_a_id = r_comp_a.json()["id"]

    r_comp_b = client.post("/complaints", headers=headers_a, json={
        "title": "Garbage dump near school",
        "description": "Uncollected trash heaps.",
        "category": "garbage",
        "location": "School Lane",
    })
    assert r_comp_b.status_code == 201
    comp_b_id = r_comp_b.json()["id"]
    print(f"  -> PASS: Complaint A #{comp_a_id} and Complaint B #{comp_b_id} created")

    # 3. Create comments
    print("\n[STEP 3] Posting comments on Complaint A...")
    # Alice posts A1 (will be a parent)
    r_a1 = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_a,
        json={"content": "Please prioritize this before school starts!"},
    )
    assert r_a1.status_code == 201
    a1_id = r_a1.json()["id"]

    # Bob posts B1 (will be a leaf comment)
    r_b1 = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_b,
        json={"content": "I noticed the same issue yesterday."},
    )
    assert r_b1.status_code == 201
    b1_id = r_b1.json()["id"]

    # Bob replies to A1 (making A1 a parent with replies)
    r_b2 = client.post(
        f"/complaints/{comp_a_id}/comments",
        headers=headers_b,
        json={
            "content": "@Alice Green Agreed, traffic is already backed up!",
            "parent_comment_id": a1_id,
        },
    )
    assert r_b2.status_code == 201
    b2_id = r_b2.json()["id"]
    print(f"  -> PASS: Created comment A1 (#{a1_id}), leaf B1 (#{b1_id}), and reply B2 (#{b2_id})")

    # Verify initial comments count = 3
    r_initial = client.get(f"/complaints/{comp_a_id}/comments")
    assert len(r_initial.json()) == 3

    # 4. Security Check: Non-author attempts deletion (Alice tries to delete Bob's comment)
    print("\n[STEP 4] Testing non-author deletion rejected with 403 Forbidden...")
    r_forbidden = client.delete(
        f"/complaints/{comp_a_id}/comments/{b1_id}",
        headers=headers_a,  # Alice trying to delete Bob's comment
    )
    assert r_forbidden.status_code == 403
    assert "only delete your own comments" in r_forbidden.json()["detail"]
    print("  -> PASS: 403 Forbidden returned when user attempts to delete another user's comment")

    # 5. Security Check: Bob tries to delete Alice's comment
    r_forbidden_2 = client.delete(
        f"/complaints/{comp_a_id}/comments/{a1_id}",
        headers=headers_b,  # Bob trying to delete Alice's comment
    )
    assert r_forbidden_2.status_code == 403
    print("  -> PASS: 403 Forbidden confirmed for reverse non-author deletion attempt")

    # 6. Security Check: Unauthenticated deletion
    print("\n[STEP 5] Testing unauthenticated deletion rejected with 401 Unauthorized...")
    r_unauth = client.delete(f"/complaints/{comp_a_id}/comments/{b1_id}")
    assert r_unauth.status_code == 401
    print("  -> PASS: 401 Unauthorized returned for unauthenticated request")

    # 7. Validation Check: Non-existent comment
    print("\n[STEP 6] Testing non-existent comment deletion rejected with 404 Not Found...")
    r_404 = client.delete(f"/complaints/{comp_a_id}/comments/999999", headers=headers_a)
    assert r_404.status_code == 404
    print("  -> PASS: 404 Not Found returned for non-existent comment")

    # 8. Validation Check: Cross-complaint comment deletion
    print("\n[STEP 7] Testing cross-complaint comment deletion rejected with 404...")
    r_cross = client.delete(
        f"/complaints/{comp_b_id}/comments/{a1_id}",  # a1_id belongs to comp_a, not comp_b
        headers=headers_a,
    )
    assert r_cross.status_code == 404
    print("  -> PASS: 404 returned when comment does not belong to specified complaint")

    # 9. Leaf Comment Deletion: Bob deletes his own leaf comment B1
    print("\n[STEP 8] Bob deletes his leaf comment B1...")
    r_del_leaf = client.delete(
        f"/complaints/{comp_a_id}/comments/{b1_id}",
        headers=headers_b,
    )
    assert r_del_leaf.status_code == 200
    res_leaf = r_del_leaf.json()
    assert res_leaf["is_deleted"] is True
    assert res_leaf["has_replies"] is False
    print("  -> PASS: Leaf comment permanently deleted (200 OK)")

    # Verify B1 is completely removed from GET comments
    r_after_leaf = client.get(f"/complaints/{comp_a_id}/comments")
    remaining_ids = [c["id"] for c in r_after_leaf.json()]
    assert b1_id not in remaining_ids
    assert len(remaining_ids) == 2
    print("  -> PASS: Comment B1 completely removed from comments list")

    # 10. Threaded Parent Deletion: Alice deletes comment A1 (has reply B2)
    print("\n[STEP 9] Alice deletes comment A1 which has child reply B2...")
    r_del_parent = client.delete(
        f"/complaints/{comp_a_id}/comments/{a1_id}",
        headers=headers_a,
    )
    assert r_del_parent.status_code == 200
    res_parent = r_del_parent.json()
    assert res_parent["is_deleted"] is True
    assert res_parent["has_replies"] is True
    print("  -> PASS: Parent comment soft-deleted (200 OK)")

    # Verify GET comments preserves the thread structure:
    # A1 is marked as deleted, B2 is preserved under it
    r_after_parent = client.get(f"/complaints/{comp_a_id}/comments")
    comms = r_after_parent.json()
    assert len(comms) == 2

    a1_found = [c for c in comms if c["id"] == a1_id][0]
    assert a1_found["is_deleted"] is True
    assert a1_found["comment"] == "This comment was deleted"
    assert a1_found["content"] == "This comment was deleted"
    assert a1_found["user_name"] == "[deleted]"

    b2_found = [c for c in comms if c["id"] == b2_id][0]
    assert b2_found["is_deleted"] is False
    assert b2_found["parent_comment_id"] == a1_id
    assert "@Alice Green" in b2_found["comment"]
    print("  -> PASS: Thread structure preserved: A1 is '[This comment was deleted]', reply B2 preserved")

    # 11. Verify Feed comments_count counts only active non-deleted comments
    print("\n[STEP 10] Verifying Community Feed comments_count...")
    r_feed = client.get("/complaints/feed")
    matched = [item for item in r_feed.json() if item["id"] == comp_a_id]
    assert len(matched) == 1
    # Only B2 is active (B1 was hard deleted, A1 is soft-deleted) -> active count = 1
    assert matched[0]["comments_count"] == 1
    print(f"  -> PASS: Feed reflects active comments_count = {matched[0]['comments_count']} (excluding deleted comments)")

    print("\n" + "=" * 65)
    print("ALL COMMENT DELETION & OWNERSHIP TESTS PASSED 100%!")
    print("=" * 65)


if __name__ == "__main__":
    test_comment_deletion()
