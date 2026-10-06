"""
Unit and Integration Tests for AI-powered Image Analysis + Civic Issue Detection + SDG Alignment
Tests:
1. YOLO Service singleton loading and inference
2. Civic Issue Service classification & confidence calculation
3. SDG Mapping Engine UN SDG resolution
4. POST /api/v1/ml/analyze-image endpoint authentication, validation, and response
5. Report submission storing both AI prediction and citizen manual selection
6. Backward compatibility (reports without AI analysis succeed)
"""

import os
import uuid
from fastapi.testclient import TestClient

from main import app
from app.schemas.image_analysis import DetectedObject
from app.services.civic_issue_service import CivicIssueService
from app.services.sdg_mapping_service import SDGMappingService
from app.services.yolo_service import YOLOService

client = TestClient(app)


def run_tests():
    print("=" * 60)
    print("STARTING AI IMAGE ANALYSIS & SDG ALIGNMENT TESTS")
    print("=" * 60)

    # --- Test 1: Civic Issue Service Unit Tests ---
    print("\n[TEST 1] Testing CivicIssueService...")
    # 1.A: Waste detections
    waste_dets = [
        DetectedObject(class_name="bottle", confidence=0.88),
        DetectedObject(class_name="cup", confidence=0.75),
    ]
    waste_issue = CivicIssueService.classify_detections(waste_dets)
    assert waste_issue.category == "waste_dumping", f"Expected waste_dumping, got {waste_issue.category}"
    assert waste_issue.confidence >= 0.80, f"Expected high confidence, got {waste_issue.confidence}"
    print(f"  -> PASS: Waste objects mapped to '{waste_issue.label}' (conf: {waste_issue.confidence})")

    # 1.B: Empty/unknown detections
    unknown_issue = CivicIssueService.classify_detections([])
    assert unknown_issue.category == "unknown", f"Expected unknown, got {unknown_issue.category}"
    assert unknown_issue.confidence == 0.0
    print("  -> PASS: Empty detections return 'unknown' category without fabricating results")

    # 1.C: Future custom model class
    custom_dets = [DetectedObject(class_name="road_damage", confidence=0.94)]
    custom_issue = CivicIssueService.classify_detections(custom_dets)
    assert custom_issue.category == "road_damage"
    assert custom_issue.confidence == 0.94
    print("  -> PASS: Future custom MEDAL class directly matched")

    # --- Test 2: SDG Mapping Service Unit Tests ---
    print("\n[TEST 2] Testing SDGMappingService...")
    sdgs = SDGMappingService.map_issue_to_sdgs("waste_dumping", 0.94)
    assert len(sdgs) >= 2, f"Expected at least 2 SDGs for waste_dumping, got {len(sdgs)}"
    sdg_ids = [s.id for s in sdgs]
    assert 11 in sdg_ids and 12 in sdg_ids, f"Expected SDG 11 & 12, got {sdg_ids}"
    print(f"  -> PASS: waste_dumping mapped to SDGs: {[s.id for s in sdgs]} with confidences {[s.confidence for s in sdgs]}")

    road_sdgs = SDGMappingService.map_issue_to_sdgs("road_damage", 0.90)
    road_ids = [s.id for s in road_sdgs]
    assert 9 in road_ids and 11 in road_ids, f"Expected SDG 9 & 11, got {road_ids}"
    print(f"  -> PASS: road_damage mapped to SDGs: {road_ids}")

    empty_sdgs = SDGMappingService.map_issue_to_sdgs("unknown", 0.0)
    assert len(empty_sdgs) == 0, "Expected no SDGs for unknown category"
    print("  -> PASS: unknown category produces empty SDG suggestions")

    # --- Test 3: Authenticated API Endpoint Test ---
    print("\n[TEST 3] Testing POST /api/v1/ml/analyze-image endpoint...")
    # Register and authenticate citizen
    uid = uuid.uuid4().hex[:8]
    email = f"ai_user_{uid}@example.com"
    password = "SecurePassword123!"

    reg_res = client.post("/register", json={
        "email": email,
        "password": password,
        "full_name": f"AI Tester {uid}",
        "phone": "9876543210",
    })
    assert reg_res.status_code == 201

    login_res = client.post("/login", json={"email": email, "password": password})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 3.A: Test without image file (validation error)
    missing_file_res = client.post("/api/v1/ml/analyze-image")
    assert missing_file_res.status_code == 422, f"Expected 422, got {missing_file_res.status_code}"
    print("  -> PASS: Missing image file returns 422 validation error")

    # 3.B: Test unauthenticated with valid image file (succeeds gracefully without 401)
    test_img_path = os.path.join(os.path.dirname(__file__), "test_images", "garbage.jpg")
    with open(test_img_path, "rb") as f:
        unauth_img_res = client.post(
            "/api/v1/ml/analyze-image",
            files={"image": ("garbage.jpg", f, "image/jpeg")},
        )
    assert unauth_img_res.status_code == 200, f"Expected 200, got {unauth_img_res.status_code}"
    print("  -> PASS: Unauthenticated/guest citizen analysis succeeds without 401 error")

    # 3.B: Test with valid image file
    test_img_path = os.path.join(os.path.dirname(__file__), "test_images", "garbage.jpg")
    with open(test_img_path, "rb") as f:
        response = client.post(
            "/api/v1/ml/analyze-image",
            headers=headers,
            files={"image": ("garbage.jpg", f, "image/jpeg")},
        )
    assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
    data = response.json()
    assert data["success"] is True
    assert "analysis" in data
    assert "issue" in data["analysis"]
    assert "sdgs" in data["analysis"]
    print(f"  -> PASS: Image analysis returned successful response: {data['analysis']['issue']['label']}")

    # 3.C: Test with non-image file
    invalid_file_res = client.post(
        "/api/v1/ml/analyze-image",
        headers=headers,
        files={"image": ("test.txt", b"plain text content", "text/plain")},
    )
    assert invalid_file_res.status_code == 400
    print("  -> PASS: Invalid MIME type rejected with 400")

    # --- Test 4: Report Submission with AI Fields + Citizen Manual Choice ---
    print("\n[TEST 4] Testing Complaint Creation with AI analysis preservation...")
    complaint_payload = {
        "title": "Overflowing Garbage on 2nd Main Road",
        "description": "Large garbage heap accumulating on roadside attracting pests.",
        "category": "garbage",
        "location": "2nd Main Road, Sector 4",
        "image_url": "/uploads/reports/sample_garbage.jpg",
        "sdg_alignment": "SDG 11: Sustainable Cities and Communities",
        "impact_level": "High",
        "equity_classification": "Standard Urban Zone",
        # AI metadata
        "ai_detected_issue": "waste_dumping",
        "ai_issue_confidence": 0.94,
        "ai_suggested_sdgs": '[{"id": 11, "name": "Sustainable Cities and Communities", "confidence": 0.91}, {"id": 12, "name": "Responsible Consumption and Production", "confidence": 0.87}]',
        "ai_analysis_status": "success",
        "ai_model_version": "yolo26n.pt",
    }

    create_res = client.post("/complaints", headers=headers, json=complaint_payload)
    assert create_res.status_code == 201, f"Create complaint failed: {create_res.text}"
    created_data = create_res.json()
    assert created_data["ai_detected_issue"] == "waste_dumping"
    assert created_data["ai_issue_confidence"] == 0.94
    assert created_data["sdg_alignment"] == "SDG 11: Sustainable Cities and Communities"
    print(f"  -> PASS: Complaint created with both citizen choice and AI analysis preserved (ID: {created_data['id']})")

    # --- Test 5: Backward Compatibility (Report without AI metadata) ---
    print("\n[TEST 5] Testing Backward Compatibility (report without AI fields)...")
    legacy_payload = {
        "title": "Broken Streetlight",
        "description": "Streetlight near park entrance is non-functional.",
        "category": "streetlight",
        "location": "Park Avenue",
    }
    legacy_res = client.post("/complaints", headers=headers, json=legacy_payload)
    assert legacy_res.status_code == 201, f"Legacy complaint failed: {legacy_res.text}"
    legacy_data = legacy_res.json()
    assert legacy_data["ai_detected_issue"] is None
    print(f"  -> PASS: Legacy complaint created cleanly without AI fields (ID: {legacy_data['id']})")

    print("\n" + "=" * 60)
    print("ALL AI IMAGE ANALYSIS & SDG TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)


if __name__ == "__main__":
    run_tests()
