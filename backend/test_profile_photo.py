"""
Automated tests for Profile Photo Update feature:
1. Citizen Registration and Login via LAN IP
2. Unauthenticated Profile Photo Upload (must return 401)
3. Invalid non-image file upload (must return 400)
4. Authenticated Valid Profile Photo Upload (must return 200 with MinIO URL under profiles/{user_id}/)
5. GET /me verification (must include profile_image_url)
6. MinIO HTTP GET verification (must download uploaded bytes directly from MinIO)
"""

import io
import uuid
import httpx

LAN_IP = "172.16.125.17"
API_BASE = f"http://{LAN_IP}:8000"
MINIO_BASE = f"http://{LAN_IP}:9000"


def test_profile_photo_flow():
    print("=" * 65)
    print("STARTING PROFILE PHOTO UPDATE AUTOMATED TESTS")
    print(f"FastAPI: {API_BASE}")
    print(f"MinIO:   {MINIO_BASE}")
    print("=" * 65)

    client = httpx.Client(timeout=10.0)

    # 1. Register a test user
    uid = uuid.uuid4().hex[:8]
    email = f"photo_tester_{uid}@medal.app"
    password = "PhotoPassword123!"

    print("\n[STEP 1] Registering test citizen...")
    r_reg = client.post(
        f"{API_BASE}/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Photo Test Citizen",
            "phone": "9841009999",
        },
    )
    assert r_reg.status_code == 201, f"Registration failed: {r_reg.text}"
    user_id = r_reg.json()["data"]["id"]
    print(f"  -> PASS: User registered with ID {user_id}")

    # 2. Login to get token
    print("\n[STEP 2] Logging in to retrieve JWT...")
    r_login = client.post(
        f"{API_BASE}/login",
        json={"email": email, "password": password},
    )
    assert r_login.status_code == 200, f"Login failed: {r_login.text}"
    token = r_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("  -> PASS: JWT token acquired")

    # 3. Test unauthenticated request
    print("\n[STEP 3] Testing unauthenticated upload (expect 401)...")
    sample_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9"
    r_unauth = client.put(
        f"{API_BASE}/users/me/profile-photo",
        files={"file": ("profile.jpg", io.BytesIO(sample_jpeg), "image/jpeg")},
    )
    assert r_unauth.status_code == 401, f"Expected 401, got {r_unauth.status_code}"
    print("  -> PASS: Unauthenticated request rejected with 401 Unauthorized")

    # 4. Test invalid non-image file
    print("\n[STEP 4] Testing invalid non-image file (expect 400)...")
    invalid_file = b"This is a plain text file, not an image."
    r_invalid = client.put(
        f"{API_BASE}/users/me/profile-photo",
        headers=headers,
        files={"file": ("document.txt", io.BytesIO(invalid_file), "text/plain")},
    )
    assert r_invalid.status_code == 400, f"Expected 400, got {r_invalid.status_code}: {r_invalid.text}"
    print(f"  -> PASS: Non-image rejected with 400 ({r_invalid.json()['detail']})")

    # 5. Test valid authenticated upload
    print("\n[STEP 5] Testing valid profile photo upload...")
    r_upload = client.put(
        f"{API_BASE}/users/me/profile-photo",
        headers=headers,
        files={"file": ("avatar.jpg", io.BytesIO(sample_jpeg), "image/jpeg")},
    )
    assert r_upload.status_code == 200, f"Upload failed: {r_upload.text}"
    upload_data = r_upload.json()
    assert "profile_image_url" in upload_data, "Missing profile_image_url in response"
    photo_url = upload_data["profile_image_url"]
    print(f"  -> PASS: Upload returned 200 OK. URL: {photo_url}")
    assert f"profiles/{user_id}/" in photo_url, f"Expected path profiles/{user_id}/ in {photo_url}"
    print(f"  -> PASS: Correct isolated path 'profiles/{user_id}/' verified")

    # 6. Verify GET /me returns the new profile_image_url
    print("\n[STEP 6] Testing GET /me to confirm profile_image_url is returned...")
    r_me = client.get(f"{API_BASE}/me", headers=headers)
    assert r_me.status_code == 200, f"GET /me failed: {r_me.text}"
    me_data = r_me.json()
    assert me_data["profile_image_url"] == photo_url, f"GET /me mismatch: {me_data.get('profile_image_url')} != {photo_url}"
    print(f"  -> PASS: GET /me returns persisted profile_image_url")

    # 7. Test direct MinIO HTTP retrieval
    print("\n[STEP 7] Verifying MinIO HTTP retrieval of profile photo...")
    r_minio = client.get(photo_url)
    assert r_minio.status_code == 200, f"MinIO fetch failed: {r_minio.status_code}"
    assert r_minio.content == sample_jpeg, "Downloaded bytes do not match uploaded JPEG!"
    print(f"  -> PASS: Successfully fetched {len(r_minio.content)} bytes directly from MinIO")

    # 8. Test alias endpoint PUT /me/profile-photo
    print("\n[STEP 8] Testing alias endpoint PUT /me/profile-photo...")
    r_alias = client.put(
        f"{API_BASE}/me/profile-photo",
        headers=headers,
        files={"file": ("new_avatar.jpg", io.BytesIO(sample_jpeg), "image/jpeg")},
    )
    assert r_alias.status_code == 200, f"Alias endpoint failed: {r_alias.text}"
    print("  -> PASS: Alias PUT /me/profile-photo returned 200 OK")

    print("\n" + "=" * 65)
    print("ALL BACKEND PROFILE PHOTO TESTS PASSED 100%!")
    print("=" * 65)


if __name__ == "__main__":
    test_profile_photo_flow()
