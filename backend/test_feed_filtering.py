from fastapi.testclient import TestClient
from main import app
from app.database.database import SessionLocal
from app.models.complaint import Complaint
from sqlalchemy import func

client = TestClient(app)

def test_feed_category_filtering_and_union():
    db = SessionLocal()
    # Total active non-rejected complaints in DB
    total_active_count = db.query(Complaint).filter(Complaint.status != "rejected").count()
    db.close()

    # 1. Fetch All Reports across pages using pagination
    limit = 20
    offset = 0
    all_reports = []
    while True:
        resp = client.get(f"/complaints/feed?limit={limit}&offset={offset}")
        assert resp.status_code == 200
        items = resp.json()
        if not items:
            break
        all_reports.extend(items)
        if len(items) < limit:
            break
        offset += len(items)

    all_ids = [c["id"] for c in all_reports]
    unique_all_ids = set(all_ids)

    # Case 1: All Reports contains every report that exists
    assert len(unique_all_ids) == total_active_count, (
        f"Expected {total_active_count} active reports in All Reports, got {len(unique_all_ids)}"
    )

    # Case 7: No duplicate reports appear across pagination
    assert len(all_ids) == len(unique_all_ids), "Duplicate report IDs found in paginated All Reports!"

    # 2. Fetch Environmental across pages
    offset = 0
    env_reports = []
    while True:
        resp = client.get(f"/complaints/feed?category=Environmental&limit={limit}&offset={offset}")
        assert resp.status_code == 200
        items = resp.json()
        if not items:
            break
        env_reports.extend(items)
        if len(items) < limit:
            break
        offset += len(items)

    env_ids = set(c["id"] for c in env_reports)

    # Case 2: Every report visible in Environmental also exists in All Reports
    assert env_ids.issubset(unique_all_ids), "Found Environmental report that is NOT in All Reports!"

    # 3. Fetch Infrastructure across pages
    offset = 0
    infra_reports = []
    while True:
        resp = client.get(f"/complaints/feed?category=Infrastructure&limit={limit}&offset={offset}")
        assert resp.status_code == 200
        items = resp.json()
        if not items:
            break
        infra_reports.extend(items)
        if len(items) < limit:
            break
        offset += len(items)

    infra_ids = set(c["id"] for c in infra_reports)

    # Case 3: Every report visible in Infrastructure also exists in All Reports
    assert infra_ids.issubset(unique_all_ids), "Found Infrastructure report that is NOT in All Reports!"

    # Case 4: No Environmental report appears in Infrastructure
    assert len(env_ids.intersection(infra_ids)) == 0, (
        f"Overlap found between Environmental and Infrastructure: {env_ids.intersection(infra_ids)}"
    )

    # Case 5: No Infrastructure report appears in Environmental
    assert len(infra_ids.intersection(env_ids)) == 0, (
        f"Overlap found between Infrastructure and Environmental: {infra_ids.intersection(env_ids)}"
    )

    # Case 8: Pagination/load-more continues to respect selected category
    for c in env_reports:
        cat = c["category"].lower()
        assert cat in [
            "environment", "environmental", "environment_&_greenery",
            "garbage", "garbage_&_solid_waste", "waste", "sanitation", "health_&_sanitation"
        ], f"Non-environmental category '{cat}' found in Environmental feed: {c['id']}"

    for c in infra_reports:
        cat = c["category"].lower()
        assert cat in [
            "infrastructure", "road", "road_&_potholes",
            "streetlight", "streetlight_&_lighting",
            "drainage", "drainage_&_sewage", "educational_infrastructure"
        ], f"Non-infrastructure category '{cat}' found in Infrastructure feed: {c['id']}"

    print(f"\n[TEST PASSED] Total in DB: {total_active_count}")
    print(f"[TEST PASSED] Total in All Reports (Union): {len(unique_all_ids)}")
    print(f"[TEST PASSED] Total in Environmental: {len(env_ids)}")
    print(f"[TEST PASSED] Total in Infrastructure: {len(infra_ids)}")
    print(f"[TEST PASSED] Total Other Categories: {len(unique_all_ids - env_ids - infra_ids)}")
    print(f"[TEST PASSED] Intersection(Environmental, Infrastructure) = {env_ids.intersection(infra_ids)}")

if __name__ == "__main__":
    test_feed_category_filtering_and_union()
