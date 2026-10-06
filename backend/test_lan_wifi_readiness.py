"""
Verification of MEDAL over PC LAN IP (Wi-Fi readiness for physical Android phone).
Tests:
1. FastAPI GET / and GET /docs via http://172.16.125.17:8000
2. MinIO S3 API via http://172.16.125.17:9000
3. Citizen register & login via LAN IP
4. Upload evidence image to MinIO via LAN IP
5. Verify returned image_url contains http://172.16.125.17:9000
6. Direct HTTP GET to fetch the image from MinIO via LAN IP
"""

import io
import uuid
import httpx

LAN_IP = "172.16.125.17"
API_BASE = f"http://{LAN_IP}:8000"
MINIO_BASE = f"http://{LAN_IP}:9000"


def test_lan_connectivity():
    print("=" * 65)
    print("TESTING LAN WI-FI CONFIGURATION & REACHABILITY")
    print(f"FastAPI LAN Base: {API_BASE}")
    print(f"MinIO LAN Base:   {MINIO_BASE}")
    print("=" * 65)

    # 1. FastAPI Root & Docs via LAN IP
    print("\n[TEST 1] Testing FastAPI reachability via LAN IP...")
    r_root = httpx.get(f"{API_BASE}/", timeout=5.0)
    assert r_root.status_code == 200, f"FastAPI root failed: {r_root.status_code}"
    r_docs = httpx.get(f"{API_BASE}/docs", timeout=5.0)
    assert r_docs.status_code == 200, f"FastAPI docs failed: {r_docs.status_code}"
    print(f"  -> PASS: FastAPI online at {API_BASE} (200 OK)")

    # 2. MinIO reachability via LAN IP
    print("\n[TEST 2] Testing MinIO reachability via LAN IP...")
    r_minio = httpx.get(f"{MINIO_BASE}/minio/health/live", timeout=5.0)
    assert r_minio.status_code == 200, f"MinIO health failed: {r_minio.status_code}"
    print(f"  -> PASS: MinIO online at {MINIO_BASE} (200 OK)")

    # 3. Auth via LAN IP
    print("\n[TEST 3] Testing user registration & login via LAN IP...")
    uid = uuid.uuid4().hex[:8]
    email = f"phone_tester_{uid}@medal.app"
    pwd = "PhonePassword123!"

    r_reg = httpx.post(f"{API_BASE}/register", json={
        "email": email,
        "password": pwd,
        "full_name": "Mobile Tester",
        "phone": "9841000001"
    }, timeout=5.0)
    assert r_reg.status_code == 201, f"Registration failed: {r_reg.text}"

    r_login = httpx.post(f"{API_BASE}/login", json={"email": email, "password": pwd}, timeout=5.0)
    assert r_login.status_code == 200, f"Login failed: {r_login.text}"
    token = r_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print(f"  -> PASS: Citizen registered and logged in over LAN IP")

    # 4. Upload photo evidence via LAN IP
    print("\n[TEST 4] Uploading photo evidence to MinIO via LAN IP...")
    test_photo = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00PHONE_PHOTO_EVIDENCE"
    r_up = httpx.post(
        f"{API_BASE}/complaints/upload-evidence",
        headers=headers,
        files={"file": ("phone_test.jpg", io.BytesIO(test_photo), "image/jpeg")},
        timeout=5.0
    )
    assert r_up.status_code == 200, f"Evidence upload failed: {r_up.text}"
    image_url = r_up.json()["image_url"]
    print(f"  -> PASS: Image uploaded. Generated MinIO URL: {image_url}")
    assert f"http://{LAN_IP}:9000/medal-evidence/reports/" in image_url, f"Expected LAN IP in URL, got: {image_url}"

    # 5. Direct download of MinIO image via LAN IP
    print("\n[TEST 5] Verifying physical phone can download the image via LAN IP...")
    r_img = httpx.get(image_url, timeout=5.0)
    assert r_img.status_code == 200, f"Image fetch failed: {r_img.status_code}"
    assert r_img.content == test_photo
    print(f"  -> PASS: Image downloaded directly from MinIO via LAN IP ({len(r_img.content)} bytes, 200 OK)")

    print("\n" + "=" * 65)
    print("ALL LAN WI-FI READINESS TESTS PASSED 100%!")
    print("=" * 65)


if __name__ == "__main__":
    test_lan_connectivity()
