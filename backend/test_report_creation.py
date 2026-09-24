"""
Comprehensive end-to-end tests for Citizen Report Creation Flow:
1. Authenticate Citizen
2. Upload Photo Evidence via Pluggable Storage (POST /complaints/upload-evidence)
3. Create Complaint with all Report fields (POST /complaints):
   - title
   - description
   - category
   - location
   - image_url
   - sdg_alignment
   - impact_level
   - equity_classification
4. Verify Record in PostgreSQL
5. Verify Live Retrieval via GET /complaints (Citizen Tracker Feed)
6. Verify Validation Error Handling
"""

import os
import uuid
import io
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from main import app
from app.database.database import SessionLocal
from app.models.complaint import Complaint
from app.models.user import User

client = TestClient(app)

def run_tests():
    print("=" * 60)
    print("STARTING CITIZEN REPORT CREATION COMPREHENSIVE TESTS")
    print("=" * 60)

    # 1. Register & Login a test citizen
    uid = uuid.uuid4().hex[:8]
    email = f"reporter_{uid}@example.com"
    password = "SecurePassword123!"
    full_name = f"Reporter Citizen {uid}"

    print(f"\n[STEP 1] Registering and authenticating citizen ({email})...")
    reg_res = client.post("/register", json={
        "email": email,
        "password": password,
        "full_name": full_name,
        "phone": "9988776655"
    })
    assert reg_res.status_code == 201, f"Registration failed: {reg_res.text}"

    login_res = client.post("/login", json={
        "email": email,
        "password": password
    })
    assert login_res.status_code == 200, f"Login failed: {login_res.text}"
    token = login_res.json()["access_token"]
    citizen_id = login_res.json()["data"]["id"]
    headers = {"Authorization": f"Bearer {token}"}
    print(f"  -> PASS: Citizen authenticated, ID = {citizen_id}")

    # 2. Upload Photo Evidence via Pluggable Storage Service
    print("\n[STEP 2] Testing photo evidence upload (/complaints/upload-evidence)...")
    fake_image_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00"
    upload_res = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("pothole_evidence.jpg", io.BytesIO(fake_image_bytes), "image/jpeg")}
    )
    assert upload_res.status_code == 200, f"Upload failed: {upload_res.text}"
    image_url = upload_res.json().get("image_url")
    assert image_url and ("/reports/" in image_url or image_url.startswith("/uploads/reports/")), f"Unexpected image_url: {image_url}"
    print(f"  -> PASS: Photo uploaded cleanly via storage layer: {image_url}")

    # 3. Create full Civic Report with all required and enriched fields
    print("\n[STEP 3] Submitting complete citizen civic report (POST /complaints)...")
    report_payload = {
        "title": "Severe Water Main Leakage opposite Hospital Gate",
        "description": "Massive clean water wastage flowing down the street, creating hazardous road conditions and flooding nearby pedestrian paths.",
        "category": "water",
        "location": "Opposite General Hospital Gate 3, Sector 4",
        "image_url": image_url,
        "sdg_alignment": "SDG 6: Clean Water and Sanitation",
        "impact_level": "High",
        "equity_classification": "School / Hospital Vicinity"
    }

    create_res = client.post("/complaints", headers=headers, json=report_payload)
    assert create_res.status_code == 201, f"Report creation failed: {create_res.status_code}: {create_res.text}"
    created_data = create_res.json()
    complaint_id = created_data["id"]

    assert created_data["title"] == report_payload["title"]
    assert created_data["description"] == report_payload["description"]
    assert created_data["category"] == "water"
    assert created_data["location"] == report_payload["location"]
    assert created_data["image_url"] == image_url
    assert created_data["sdg_alignment"] == report_payload["sdg_alignment"]
    assert created_data["impact_level"] == "High"
    assert created_data["equity_classification"] == "School / Hospital Vicinity"
    assert created_data["status"] == "submitted"
    assert created_data["citizen_id"] == citizen_id
    print(f"  -> PASS: Report created with ID #{complaint_id}")

    # 4. Verify Record in PostgreSQL database directly
    print("\n[STEP 4] Direct PostgreSQL verification using SQLAlchemy Session...")
    db: Session = SessionLocal()
    try:
        db_complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
        assert db_complaint is not None, "Complaint record not found in PostgreSQL!"
        assert db_complaint.title == report_payload["title"]
        assert db_complaint.image_url == image_url
        assert db_complaint.sdg_alignment == "SDG 6: Clean Water and Sanitation"
        assert db_complaint.impact_level == "High"
        assert db_complaint.equity_classification == "School / Hospital Vicinity"
        assert db_complaint.citizen_id == citizen_id
        print("  -> PASS: Verified all columns in PostgreSQL table 'complaints'")
    finally:
        db.close()

    # 5. Verify Live Retrieval via GET /complaints (Citizen Tracker Feed)
    print("\n[STEP 5] Verifying report appears immediately in Citizen Tracker (GET /complaints)...")
    list_res = client.get("/complaints", headers=headers)
    assert list_res.status_code == 200, f"List complaints failed: {list_res.text}"
    items = list_res.json()
    assert any(item["id"] == complaint_id for item in items), "Created report must appear in citizen complaints feed!"
    print(f"  -> PASS: Report #{complaint_id} immediately retrieved in tracker feed")

    # 6. Verify Validation Error Handling
    print("\n[STEP 6] Testing validation and error handling...")
    # Missing required field 'location'
    bad_res = client.post("/complaints", headers=headers, json={
        "title": "Incomplete report",
        "description": "No location provided",
        "category": "road"
    })
    assert bad_res.status_code == 422, f"Expected 422 validation error, got {bad_res.status_code}"
    print("  -> PASS: 422 Unprocessable Entity returned for missing required fields")

    # Non-image upload rejection
    bad_upload = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("malicious.exe", io.BytesIO(b"binary"), "application/x-msdownload")}
    )
    assert bad_upload.status_code == 400, f"Expected 400 for non-image, got {bad_upload.status_code}"
    print("  -> PASS: 400 Bad Request returned for invalid evidence file type")

    print("\n" + "=" * 60)
    print("ALL CITIZEN REPORT CREATION TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
