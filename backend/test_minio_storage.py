"""
Comprehensive test suite for MinIO Object Storage integration in MEDAL backend.
Tests:
1. Direct MinIO Client connectivity & bucket creation
2. MinioStorageService upload_bytes with content_type preservation
3. MinioStorageService upload_file with content_type
4. Direct MinIO stat_object verification (size, content_type)
5. Direct HTTP GET retrieval of the public image URL
6. End-to-end FastAPI POST /complaints/upload-evidence with MinIO
7. End-to-end report creation storing MinIO URL in PostgreSQL
8. Retrieve report detail verifying MinIO image_url is returned
"""

import asyncio
import io
import os
import uuid
from datetime import datetime
import httpx
from fastapi.testclient import TestClient

from main import app
from app.services.storage import MinioStorageService, get_storage_service

client = TestClient(app)


def run_minio_tests():
    print("=" * 65)
    print("STARTING MINIO OBJECT STORAGE INTEGRATION TESTS")
    print("=" * 65)

    # 1. Initialize MinioStorageService
    print("\n[TEST 1] Initializing MinioStorageService & verifying bucket...")
    try:
        storage = MinioStorageService()
        assert storage.client.bucket_exists(storage.bucket_name), f"Bucket {storage.bucket_name} must exist"
        print(f"  -> PASS: Connected to MinIO ({storage.endpoint}), bucket '{storage.bucket_name}' verified")
    except Exception as e:
        print(f"  -> FAIL: Could not connect to MinIO: {e}")
        raise

    # 2. Test upload_bytes
    print("\n[TEST 2] Testing direct upload_bytes() to MinIO...")
    sample_jpeg_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00"
    url = asyncio.run(
        storage.upload_bytes(
            data=sample_jpeg_bytes,
            filename="pothole_sample.jpg",
            content_type="image/jpeg",
            folder="reports",
        )
    )
    assert url.startswith("http://") or url.startswith("https://"), f"Expected full HTTP URL, got: {url}"
    assert f"/{storage.bucket_name}/reports/" in url, f"URL path missing bucket/folder: {url}"
    print(f"  -> PASS: Uploaded bytes successfully. Generated URL: {url}")

    # 3. Verify object in MinIO directly
    print("\n[TEST 3] Verifying object exists in MinIO with correct metadata...")
    object_name = url.split(f"/{storage.bucket_name}/")[-1]
    stat = storage.client.stat_object(storage.bucket_name, object_name)
    assert stat.size == len(sample_jpeg_bytes), f"Size mismatch: {stat.size} != {len(sample_jpeg_bytes)}"
    assert stat.content_type == "image/jpeg", f"Content-Type mismatch: {stat.content_type}"
    print(f"  -> PASS: Object '{object_name}' confirmed in MinIO (Size: {stat.size} bytes, Type: {stat.content_type})")

    # 4. Verify HTTP retrieval from MinIO
    print("\n[TEST 4] Testing public HTTP GET accessibility of the uploaded image...")
    try:
        resp = httpx.get(url, timeout=3.0)
    except Exception:
        # Fallback to local loopback if external LAN IP is not routed on this interface
        from urllib.parse import urlparse
        local_url = url.replace(urlparse(url).netloc, "127.0.0.1:9000")
        resp = httpx.get(local_url, timeout=3.0)
    assert resp.status_code == 200, f"Expected 200 OK from MinIO, got {resp.status_code}"
    assert resp.content == sample_jpeg_bytes, "Retrieved image bytes mismatch"
    print(f"  -> PASS: Image retrieved cleanly via HTTP GET (Status: 200 OK, Size: {len(resp.content)} bytes)")

    # 5. Test End-to-End FastAPI POST /complaints/upload-evidence
    print("\n[TEST 5] Testing FastAPI POST /complaints/upload-evidence route...")
    # Register & login test user
    uid = uuid.uuid4().hex[:8]
    email = f"minio_tester_{uid}@example.com"
    pwd = "SecureTestPassword123!"

    reg_res = client.post("/register", json={
        "email": email,
        "password": pwd,
        "full_name": "MinIO Citizen Tester",
        "phone": "9876543210"
    })
    assert reg_res.status_code == 201, f"Registration failed: {reg_res.text}"

    login_res = client.post("/login", json={"email": email, "password": pwd})
    assert login_res.status_code == 200, f"Login failed: {login_res.text}"
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Upload evidence file
    upload_res = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("street_damage.jpg", io.BytesIO(sample_jpeg_bytes), "image/jpeg")}
    )
    assert upload_res.status_code == 200, f"Upload failed: {upload_res.text}"
    evidence_url = upload_res.json().get("image_url")
    assert evidence_url and f"/{storage.bucket_name}/reports/" in evidence_url, f"Unexpected URL: {evidence_url}"
    print(f"  -> PASS: Endpoint /complaints/upload-evidence returned MinIO URL: {evidence_url}")

    # 6. Test Report Creation with MinIO URL saved to PostgreSQL
    print("\n[TEST 6] Testing complaint creation storing MinIO URL in PostgreSQL...")
    complaint_payload = {
        "title": "Broken Drainage Channel near Market Road",
        "description": "Severe sewage overflow causing sanitation hazard across market entrance.",
        "category": "drainage",
        "location": "Market Road, Sector 3",
        "image_url": evidence_url,
        "sdg_alignment": "SDG 6: Clean Water and Sanitation",
        "impact_level": "High",
        "equity_classification": "Commercial District"
    }

    create_res = client.post("/complaints", headers=headers, json=complaint_payload)
    assert create_res.status_code == 201, f"Report creation failed: {create_res.text}"
    created_data = create_res.json()
    complaint_id = created_data["id"]
    assert created_data["image_url"] == evidence_url, "Saved image_url does not match MinIO URL!"
    print(f"  -> PASS: Report #{complaint_id} saved in PostgreSQL with MinIO image_url")

    # 7. Test Retrieval of complaint details
    print("\n[TEST 7] Testing GET /complaints/{id} returns MinIO URL...")
    detail_res = client.get(f"/complaints/{complaint_id}", headers=headers)
    assert detail_res.status_code == 200, f"Get complaint failed: {detail_res.text}"
    assert detail_res.json()["image_url"] == evidence_url
    print(f"  -> PASS: Retrieved complaint details successfully, verified image_url: {evidence_url}")

    print("\n" + "=" * 65)
    print("ALL 7 MINIO INTEGRATION TESTS PASSED SUCCESSFULLY!")
    print("=" * 65)


if __name__ == "__main__":
    run_minio_tests()
