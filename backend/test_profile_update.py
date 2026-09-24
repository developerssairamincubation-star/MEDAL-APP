"""
Comprehensive test suite for Citizen Profile Update (PATCH /me) in MEDAL backend.
Tests:
1. Authenticated user updates full_name and phone successfully
2. Verify changes persisted in PostgreSQL
3. Validation: reject empty/short full_name (< 2 chars) with 422
4. Security: attempt to tamper role, email, password via PATCH /me fails to modify protected fields
5. Unauthenticated PATCH /me rejected with 401 Unauthorized
"""

import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def run_profile_update_tests():
    print("=" * 65)
    print("STARTING PROFILE UPDATE (PATCH /me) TESTS")
    print("=" * 65)

    uid = uuid.uuid4().hex[:8]
    email = f"profile_user_{uid}@example.com"
    pwd = "ProfilePassword123!"

    # 1. Register & Login
    print("\n[STEP 1] Registering and authenticating citizen...")
    reg_res = client.post("/register", json={
        "email": email,
        "password": pwd,
        "full_name": "Original Name",
        "phone": "9000000001"
    })
    assert reg_res.status_code == 201

    login_res = client.post("/login", json={"email": email, "password": pwd})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("  -> PASS: Citizen registered and logged in")

    # 2. Update profile with valid full_name & phone
    print("\n[STEP 2] Updating full_name and phone via PATCH /me...")
    patch_res = client.patch("/me", headers=headers, json={
        "full_name": "Updated Citizen Name",
        "phone": "9998887776"
    })
    assert patch_res.status_code == 200, f"Expected 200, got: {patch_res.text}"
    data = patch_res.json()
    assert data["full_name"] == "Updated Citizen Name"
    assert data["phone"] == "9998887776"
    assert data["email"] == email
    assert data["role"] == "citizen"
    print("  -> PASS: Profile updated successfully via PATCH /me")

    # 3. Verify via GET /me
    print("\n[STEP 3] Verifying persistence via GET /me...")
    me_res = client.get("/me", headers=headers)
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert me_data["full_name"] == "Updated Citizen Name"
    assert me_data["phone"] == "9998887776"
    print("  -> PASS: Persisted data verified via GET /me")

    # 4. Validation: short full_name rejected
    print("\n[STEP 4] Testing validation (< 2 characters rejected with 422)...")
    invalid_res = client.patch("/me", headers=headers, json={"full_name": "A"})
    assert invalid_res.status_code == 422
    print("  -> PASS: Invalid short full_name rejected with 422")

    # 5. Security: attempt to tamper role/email/password
    print("\n[STEP 5] Testing security against privilege escalation / field tampering...")
    tamper_res = client.patch("/me", headers=headers, json={
        "full_name": "Honest Citizen",
        "role": "admin",
        "is_admin": True,
        "email": "hacked@example.com"
    })
    assert tamper_res.status_code == 200
    tamper_data = tamper_res.json()
    assert tamper_data["role"] == "citizen", "Role must NOT be escalated to admin!"
    assert tamper_data["email"] == email, "Email must NOT be altered!"
    print("  -> PASS: Protected fields (role, email) completely unaffected")

    # 6. Unauthenticated PATCH /me rejected
    print("\n[STEP 6] Testing unauthenticated PATCH /me...")
    unauth_res = client.patch("/me", json={"full_name": "No Auth"})
    assert unauth_res.status_code == 401
    print("  -> PASS: Unauthenticated request rejected with 401 Unauthorized")

    print("\n" + "=" * 65)
    print("ALL PROFILE UPDATE (PATCH /me) TESTS PASSED SUCCESSFULLY!")
    print("=" * 65)


if __name__ == "__main__":
    run_profile_update_tests()
