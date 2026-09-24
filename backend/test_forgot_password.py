"""
Comprehensive end-to-end test suite for Citizen Forgot Password and Reset Password functionality.
Tests:
1. Existing registered email (/forgot-password)
2. Non-existing email (/forgot-password)
3. Valid reset token (/reset-password)
4. Invalid token (/reset-password)
5. Expired token (/reset-password)
6. Successful password reset
7. Login using new password
8. Verify old password no longer works
9. Verify existing Register/Login still work
"""

import sys
import uuid
from datetime import timedelta
from fastapi.testclient import TestClient

from main import app
from app.utils.security import create_password_reset_token

client = TestClient(app)

def run_tests():
    print("=" * 60)
    print("STARTING FORGOT & RESET PASSWORD COMPREHENSIVE TESTS")
    print("=" * 60)

    # Setup unique test user
    uid = uuid.uuid4().hex[:8]
    test_email = f"citizen_{uid}@example.com"
    initial_password = "InitialPassword123!"
    new_password = "NewSecretPassword456!"
    full_name = f"Test Citizen {uid}"

    # -------------------------------------------------------------
    # 9. Verify initial Register works
    # -------------------------------------------------------------
    print("\n[TEST 9a] Register a new citizen account...")
    reg_res = client.post("/register", json={
        "email": test_email,
        "password": initial_password,
        "full_name": full_name,
        "phone": "9876543210"
    })
    assert reg_res.status_code == 201, f"Expected 201, got {reg_res.status_code}: {reg_res.text}"
    print(f"  -> PASS: User registered with email {test_email}")

    # Verify initial Login works
    print("\n[TEST 9b] Login with initial password...")
    login_res = client.post("/login", json={
        "email": test_email,
        "password": initial_password
    })
    assert login_res.status_code == 200, f"Expected 200, got {login_res.status_code}: {login_res.text}"
    assert "access_token" in login_res.json()
    print("  -> PASS: Initial login successful")

    # -------------------------------------------------------------
    # 1. Existing registered email forgot password
    # -------------------------------------------------------------
    print("\n[TEST 1] Forgot password request for EXISTING registered email...")
    fp_res = client.post("/forgot-password", json={"email": test_email})
    assert fp_res.status_code == 200, f"Expected 200, got {fp_res.status_code}: {fp_res.text}"
    fp_data = fp_res.json()
    assert "message" in fp_data
    assert fp_data["reset_token"] is not None, "Expected reset_token to be generated"
    valid_token = fp_data["reset_token"]
    print(f"  -> PASS: 200 OK received, reset token generated")

    # -------------------------------------------------------------
    # 2. Non-existing email forgot password (Privacy preservation)
    # -------------------------------------------------------------
    print("\n[TEST 2] Forgot password request for NON-EXISTING email...")
    non_existing_email = f"nonexistent_{uid}@example.com"
    fp_non_res = client.post("/forgot-password", json={"email": non_existing_email})
    assert fp_non_res.status_code == 200, f"Expected 200, got {fp_non_res.status_code}: {fp_non_res.text}"
    fp_non_data = fp_non_res.json()
    assert fp_non_data["message"] == fp_data["message"], "Message must be identical to protect privacy"
    assert fp_non_data.get("reset_token") is None, "Non-existing email must not generate a valid token"
    print("  -> PASS: 200 OK received with identical privacy-preserving message and no token leaked")

    # -------------------------------------------------------------
    # 4. Invalid reset token
    # -------------------------------------------------------------
    print("\n[TEST 4] Reset password with INVALID token...")
    inv_res = client.post("/reset-password", json={
        "token": "invalid.jwt.token.here",
        "new_password": new_password
    })
    assert inv_res.status_code == 400, f"Expected 400, got {inv_res.status_code}: {inv_res.text}"
    assert "Invalid or expired" in inv_res.json().get("detail", "")
    print("  -> PASS: 400 Bad Request returned for invalid token")

    # -------------------------------------------------------------
    # 5. Expired reset token
    # -------------------------------------------------------------
    print("\n[TEST 5] Reset password with EXPIRED token...")
    expired_token = create_password_reset_token(
        email=test_email,
        expires_delta=timedelta(seconds=-10) # Expired 10 seconds ago
    )
    exp_res = client.post("/reset-password", json={
        "token": expired_token,
        "new_password": new_password
    })
    assert exp_res.status_code == 400, f"Expected 400, got {exp_res.status_code}: {exp_res.text}"
    assert "Invalid or expired" in exp_res.json().get("detail", "")
    print("  -> PASS: 400 Bad Request returned for expired token")

    # -------------------------------------------------------------
    # 3 & 6. Valid reset token & Successful password reset
    # -------------------------------------------------------------
    print("\n[TEST 3 & 6] Reset password with VALID token...")
    reset_res = client.post("/reset-password", json={
        "token": valid_token,
        "new_password": new_password
    })
    assert reset_res.status_code == 200, f"Expected 200, got {reset_res.status_code}: {reset_res.text}"
    assert "successfully" in reset_res.json().get("message", "").lower()
    print("  -> PASS: Password reset successful")

    # -------------------------------------------------------------
    # 7. Login using new password
    # -------------------------------------------------------------
    print("\n[TEST 7] Login using NEW password...")
    new_login_res = client.post("/login", json={
        "email": test_email,
        "password": new_password
    })
    assert new_login_res.status_code == 200, f"Expected 200, got {new_login_res.status_code}: {new_login_res.text}"
    assert "access_token" in new_login_res.json()
    print("  -> PASS: Login with new password succeeded")

    # -------------------------------------------------------------
    # 8. Verify old password no longer works
    # -------------------------------------------------------------
    print("\n[TEST 8] Verify OLD password is rejected...")
    old_login_res = client.post("/login", json={
        "email": test_email,
        "password": initial_password
    })
    assert old_login_res.status_code == 401, f"Expected 401, got {old_login_res.status_code}: {old_login_res.text}"
    print("  -> PASS: Old password rejected with 401 Unauthorized")

    # -------------------------------------------------------------
    # 9c. Verify another new user register/login
    # -------------------------------------------------------------
    print("\n[TEST 9c] Verify standard registration and login for another user remains completely unaffected...")
    uid2 = uuid.uuid4().hex[:8]
    email2 = f"citizen2_{uid2}@example.com"
    pwd2 = "StandardPass123!"
    r2 = client.post("/register", json={
        "email": email2,
        "password": pwd2,
        "full_name": "Standard User",
        "phone": "1234567890"
    })
    assert r2.status_code == 201
    l2 = client.post("/login", json={"email": email2, "password": pwd2})
    assert l2.status_code == 200
    assert "access_token" in l2.json()
    print("  -> PASS: Existing register/login flows perfectly intact")

    print("\n" + "=" * 60)
    print("ALL 9 TEST SCENARIOS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
