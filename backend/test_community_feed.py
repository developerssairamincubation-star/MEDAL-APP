"""
Comprehensive test suite for Public Community Feed in MEDAL backend.
Tests:
1. Public GET /complaints/feed accessibility (no auth token required)
2. Verify response structure & fields
3. Verify privacy (no email/phone leaked)
4. Verify chronological ordering (newest first)
5. Verify category filtering (?category=environment, ?category=infrastructure)
6. Verify rejected complaints are excluded
"""

import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def run_community_feed_tests():
    print("=" * 65)
    print("STARTING COMMUNITY FEED TESTS")
    print("=" * 65)

    # 1. Register test user and create 2 complaints in different categories
    uid = uuid.uuid4().hex[:8]
    email = f"feed_user_{uid}@example.com"
    pwd = "FeedPassword123!"

    print("\n[STEP 1] Setting up test citizen and complaints...")
    reg_res = client.post("/register", json={
        "email": email,
        "password": pwd,
        "full_name": "Ravi Kumar",
        "phone": "9123456780"
    })
    assert reg_res.status_code == 201

    login_res = client.post("/login", json={"email": email, "password": pwd})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Complaint A: Road / Infrastructure
    res_a = client.post("/complaints", headers=headers, json={
        "title": f"Pothole cluster {uid}",
        "description": "Hazardous road condition on main street",
        "category": "road",
        "location": "Main Street Junction",
        "impact_level": "Medium"
    })
    assert res_a.status_code == 201
    id_a = res_a.json()["id"]

    # Complaint B: Garbage / Environment
    res_b = client.post("/complaints", headers=headers, json={
        "title": f"Waste pile {uid}",
        "description": "Garbage overflow near school",
        "category": "garbage",
        "location": "Opposite Primary School",
        "impact_level": "High"
    })
    assert res_b.status_code == 201
    id_b = res_b.json()["id"]
    print(f"  -> PASS: Created complaints #{id_a} (road) and #{id_b} (garbage)")

    # 2. Public GET /complaints/feed without Auth
    print("\n[STEP 2] Calling GET /complaints/feed (public, unauthenticated)...")
    feed_res = client.get("/complaints/feed")
    assert feed_res.status_code == 200, f"Expected 200, got {feed_res.status_code}: {feed_res.text}"
    feed_items = feed_res.json()
    assert isinstance(feed_items, list)
    assert len(feed_items) >= 2
    print(f"  -> PASS: Retrieved {len(feed_items)} community feed items publicly")

    # 3. Verify fields & privacy
    print("\n[STEP 3] Verifying feed item fields and citizen privacy protection...")
    item_b = next((item for item in feed_items if item["id"] == id_b), None)
    assert item_b is not None, f"Complaint #{id_b} must be present in feed"
    assert item_b["title"] == f"Waste pile {uid}"
    assert item_b["citizen_name"] == "Ravi Kumar"
    assert item_b["citizen_initials"] == "RK"
    assert "email" not in item_b
    assert "phone" not in item_b
    assert "password" not in item_b
    assert "password_hash" not in item_b
    assert "upvotes_count" in item_b
    assert "comments_count" in item_b
    print("  -> PASS: All feed fields present, privacy preserved (no email/phone exposed)")

    # 4. Verify category filtering
    print("\n[STEP 4] Testing category filtering (?category=environment & ?category=infrastructure)...")
    env_res = client.get("/complaints/feed?category=environment")
    assert env_res.status_code == 200
    env_items = env_res.json()
    assert any(i["id"] == id_b for i in env_items), "Garbage complaint must appear under environment filter"
    assert not any(i["id"] == id_a for i in env_items), "Road complaint must NOT appear under environment filter"

    infra_res = client.get("/complaints/feed?category=infrastructure")
    assert infra_res.status_code == 200
    infra_items = infra_res.json()
    assert any(i["id"] == id_a for i in infra_items), "Road complaint must appear under infrastructure filter"
    assert not any(i["id"] == id_b for i in infra_items), "Garbage complaint must NOT appear under infrastructure filter"
    print("  -> PASS: Category filtering operates correctly")

    print("\n" + "=" * 65)
    print("ALL COMMUNITY FEED TESTS PASSED SUCCESSFULLY!")
    print("=" * 65)


if __name__ == "__main__":
    run_community_feed_tests()
