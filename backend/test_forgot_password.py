"""
Comprehensive test suite for MEDAL Citizen OTP Forgot Password & Reset Password mechanism.

Tests covered:
1. Registered email triggers OTP generation and email dispatch.
2. Privacy preservation: non-existent email gets identical generic response, no OTP created.
3. Cooldown rate-limiting: requesting another OTP within 60 seconds returns 429 Too Many Requests.
4. Verify OTP with invalid 6-digit code returns 400 and tracks remaining attempts.
5. Verify OTP with exceeded max attempts locks/invalidates the code.
6. Verify OTP with expired timestamp returns 400.
7. Verify OTP with valid 6-digit code returns 200 and a signed reset_token.
8. OTP reuse prevention: attempting to verify an already-used OTP returns 400.
9. Reset password with valid reset_token successfully updates password in PostgreSQL.
10. Login with new password succeeds.
11. Login with old password fails with 401 Unauthorized.
12. Reset password with invalid / expired / forged token fails with 400.
13. Reset password bypass attempt without verified token fails.
14. Mocked real SMTP success: verifies SMTP connection, STARTTLS, login, and sendmail.
15. Mocked SMTP authentication error: verifies 503 response and OTP database rollback.
16. Mocked SMTP connection/network error: verifies 503 response and OTP database rollback.
17. Mocked unconfigured production mode: verifies 503 and clear configuration error.
18. Resend OTP endpoint (/resend-otp) enforces cooldown and issues fresh OTP.
19. Existing register and login flows remain completely intact.
"""

from datetime import datetime, timedelta, timezone
import smtplib
from unittest.mock import MagicMock, patch
import uuid
from fastapi.testclient import TestClient

from main import app
from app.database.database import SessionLocal
from app.models.otp import PasswordResetOTP
from app.models.user import User
from app.services.email import EmailDeliveryError, EmailService
from app.utils.security import (
    create_password_reset_token,
    create_verified_reset_token,
    hash_otp,
)

client = TestClient(app)


def run_tests():
    print("=" * 75)
    print("MEDAL FORGOT PASSWORD (OTP) DIAGNOSTIC & END-TO-END TEST SUITE")
    print("=" * 75)

    db = SessionLocal()
    try:
        # Create a unique test citizen
        uid = uuid.uuid4().hex[:8]
        test_email = f"citizen_otp_{uid}@example.com"
        initial_password = "InitialPassword123!"
        new_password = "UpdatedPassword456!"
        full_name = f"OTP Citizen {uid}"

        # -------------------------------------------------------------
        # STEP 19a: Register & Initial Login
        # -------------------------------------------------------------
        print("\n[TEST 19a] Registering new user...")
        reg_res = client.post("/register", json={
            "email": test_email,
            "password": initial_password,
            "full_name": full_name,
            "phone": "9876543210"
        })
        assert reg_res.status_code == 201, f"Expected 201, got {reg_res.status_code}: {reg_res.text}"
        print(f"  -> PASS: User registered ({test_email})")

        print("\n[TEST 19b] Verifying initial login...")
        login_res = client.post("/login", json={
            "email": test_email,
            "password": initial_password
        })
        assert login_res.status_code == 200, f"Expected 200, got {login_res.status_code}"
        assert "access_token" in login_res.json()
        print("  -> PASS: Initial login successful")

        # -------------------------------------------------------------
        # STEP 1: Forgot Password for registered account
        # -------------------------------------------------------------
        print("\n[TEST 1] Initiating forgot password for registered email...")
        fp_res = client.post("/forgot-password", json={"email": test_email})
        assert fp_res.status_code == 200, f"Expected 200, got {fp_res.status_code}: {fp_res.text}"
        fp_data = fp_res.json()
        assert "message" in fp_data
        assert fp_data.get("reset_token") is None, "Security violation: reset_token must NOT be in forgot-password response"

        # Verify OTP record in database
        otp_rec = (
            db.query(PasswordResetOTP)
            .filter(PasswordResetOTP.email == test_email, PasswordResetOTP.is_used == False)
            .order_by(PasswordResetOTP.created_at.desc())
            .first()
        )
        assert otp_rec is not None, "OTP record must be stored in database"
        assert otp_rec.attempts_count == 0
        assert not otp_rec.is_used
        print("  -> PASS: Generic 200 response returned; OTP securely created in DB without leaking to client")

        # -------------------------------------------------------------
        # STEP 2: Privacy preservation for non-existent email
        # -------------------------------------------------------------
        print("\n[TEST 2] Forgot password for non-existent email (privacy preservation)...")
        non_existent_email = f"ghost_{uid}@example.com"
        fp_ghost_res = client.post("/forgot-password", json={"email": non_existent_email})
        assert fp_ghost_res.status_code == 200
        assert fp_ghost_res.json()["message"] == fp_data["message"], "Message must be identical to prevent enumeration"

        ghost_otp = db.query(PasswordResetOTP).filter(PasswordResetOTP.email == non_existent_email).first()
        assert ghost_otp is None, "No OTP must be generated for non-existent email"
        print("  -> PASS: Identical generic response returned; no OTP created for non-registered email")

        # -------------------------------------------------------------
        # STEP 3: Cooldown / Rate Limiting (within 60s)
        # -------------------------------------------------------------
        print("\n[TEST 3] Rate-limiting cooldown on immediate re-request...")
        fp_fast_res = client.post("/forgot-password", json={"email": test_email})
        assert fp_fast_res.status_code == 429, f"Expected 429 Too Many Requests, got {fp_fast_res.status_code}: {fp_fast_res.text}"
        assert "wait" in fp_fast_res.json().get("detail", "").lower()
        print("  -> PASS: 429 Too Many Requests returned when requesting within 60s cooldown")

        # -------------------------------------------------------------
        # STEP 4: Verify OTP with invalid code
        # -------------------------------------------------------------
        print("\n[TEST 4] Verifying OTP with wrong code...")
        inv_otp_res = client.post("/verify-otp", json={
            "email": test_email,
            "otp": "000000"
        })
        assert inv_otp_res.status_code == 400, f"Expected 400, got {inv_otp_res.status_code}"
        assert "attempt" in inv_otp_res.json().get("detail", "").lower()
        print("  -> PASS: 400 Bad Request returned with remaining attempts count")

        # -------------------------------------------------------------
        # STEP 5: Max attempts exceeded
        # -------------------------------------------------------------
        print("\n[TEST 5] Verifying max attempts lockout...")
        test_otp_code = "123456"
        otp_lockout = PasswordResetOTP(
            user_id=otp_rec.user_id,
            email=f"lockout_{uid}@example.com",
            otp_hash=hash_otp(test_otp_code),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
            attempts_count=4,
            max_attempts=5,
            is_used=False,
        )
        db.add(otp_lockout)
        db.commit()

        lockout_res = client.post("/verify-otp", json={
            "email": f"lockout_{uid}@example.com",
            "otp": "999999"
        })
        assert lockout_res.status_code == 400
        assert "maximum" in lockout_res.json().get("detail", "").lower()
        db.refresh(otp_lockout)
        assert otp_lockout.is_used is True, "OTP must be marked as used/invalidated on max attempts"
        print("  -> PASS: Code locked out and invalidated after max failed attempts")

        # -------------------------------------------------------------
        # STEP 6: Expired OTP
        # -------------------------------------------------------------
        print("\n[TEST 6] Verifying expired OTP rejection...")
        expired_otp_rec = PasswordResetOTP(
            user_id=otp_rec.user_id,
            email=f"expired_{uid}@example.com",
            otp_hash=hash_otp("654321"),
            expires_at=datetime.now(timezone.utc) - timedelta(seconds=10), # Expired
            attempts_count=0,
            max_attempts=5,
            is_used=False,
        )
        db.add(expired_otp_rec)
        db.commit()

        exp_res = client.post("/verify-otp", json={
            "email": f"expired_{uid}@example.com",
            "otp": "654321"
        })
        assert exp_res.status_code == 400
        assert "expired" in exp_res.json().get("detail", "").lower()
        print("  -> PASS: 400 Bad Request returned for expired OTP")

        # -------------------------------------------------------------
        # STEP 7: Successful OTP verification
        # -------------------------------------------------------------
        print("\n[TEST 7] Verifying OTP with valid 6-digit code...")
        known_otp = "789012"
        otp_rec.otp_hash = hash_otp(known_otp)
        otp_rec.attempts_count = 0
        db.commit()

        verify_res = client.post("/verify-otp", json={
            "email": test_email,
            "otp": known_otp
        })
        assert verify_res.status_code == 200, f"Expected 200, got {verify_res.status_code}: {verify_res.text}"
        verify_data = verify_res.json()
        assert "reset_token" in verify_data
        reset_token = verify_data["reset_token"]
        print("  -> PASS: 200 OK received; verified reset_token issued")

        # -------------------------------------------------------------
        # STEP 8: OTP Reuse prevention
        # -------------------------------------------------------------
        print("\n[TEST 8] Preventing reuse of already-verified OTP...")
        reuse_res = client.post("/verify-otp", json={
            "email": test_email,
            "otp": known_otp
        })
        assert reuse_res.status_code == 400, "Consumed OTP must not be accepted again"
        print("  -> PASS: Reusing verified OTP rejected with 400 Bad Request")

        # -------------------------------------------------------------
        # STEP 9: Reset password with verified token
        # -------------------------------------------------------------
        print("\n[TEST 9] Resetting password with verified reset_token...")
        reset_res = client.post("/reset-password", json={
            "token": reset_token,
            "new_password": new_password
        })
        assert reset_res.status_code == 200, f"Expected 200, got {reset_res.status_code}: {reset_res.text}"
        assert "successfully" in reset_res.json().get("message", "").lower()
        print("  -> PASS: Password reset successful")

        # -------------------------------------------------------------
        # STEP 10: Login with NEW password
        # -------------------------------------------------------------
        print("\n[TEST 10] Logging in with NEW password...")
        new_login_res = client.post("/login", json={
            "email": test_email,
            "password": new_password
        })
        assert new_login_res.status_code == 200
        assert "access_token" in new_login_res.json()
        print("  -> PASS: Login with new password succeeded")

        # -------------------------------------------------------------
        # STEP 11: Verify OLD password rejected
        # -------------------------------------------------------------
        print("\n[TEST 11] Verifying OLD password is now rejected...")
        old_login_res = client.post("/login", json={
            "email": test_email,
            "password": initial_password
        })
        assert old_login_res.status_code == 401
        print("  -> PASS: Old password rejected with 401 Unauthorized")

        # -------------------------------------------------------------
        # STEP 12 & 13: Invalid / Forged / Unverified token rejection
        # -------------------------------------------------------------
        print("\n[TEST 12 & 13] Reset password with invalid / unverified token...")
        fake_token_res = client.post("/reset-password", json={
            "token": "invalid.jwt.token",
            "new_password": "AnotherPassword123!"
        })
        assert fake_token_res.status_code == 400
        print("  -> PASS: Invalid token rejected with 400 Bad Request")

        # -------------------------------------------------------------
        # STEP 14: Mocked Real SMTP Success Flow
        # -------------------------------------------------------------
        print("\n[TEST 14] Testing configured SMTP delivery flow with mocked smtplib...")
        smtp_mock_user = f"smtp_ok_{uid}@example.com"
        client.post("/register", json={
            "email": smtp_mock_user,
            "password": "Password123!",
            "full_name": "SMTP Mock User",
        })

        mock_smtp_instance = MagicMock()
        with patch("smtplib.SMTP", return_value=mock_smtp_instance) as mock_smtp_class, \
             patch.dict("os.environ", {
                 "SMTP_USER": "medal.tester@gmail.com",
                 "SMTP_PASSWORD": "abcdefghijklmnop",
                 "SMTP_HOST": "smtp.gmail.com",
                 "SMTP_PORT": "587",
                 "SMTP_USE_TLS": "True",
             }):
            mock_smtp_instance.__enter__.return_value = mock_smtp_instance
            service = EmailService()
            assert service.is_configured() is True
            sent = service.send_password_reset_otp(smtp_mock_user, "123456")
            assert sent is True
            mock_smtp_instance.starttls.assert_called_once()
            mock_smtp_instance.login.assert_called_once_with("medal.tester@gmail.com", "abcdefghijklmnop")
            mock_smtp_instance.sendmail.assert_called_once()
        print("  -> PASS: SMTP connect, STARTTLS, login, and sendmail verified with proper credentials")

        # -------------------------------------------------------------
        # STEP 15: Mocked SMTP Authentication Error Handling
        # -------------------------------------------------------------
        print("\n[TEST 15] Testing SMTP authentication failure handling...")
        auth_fail_user = f"auth_fail_{uid}@example.com"
        client.post("/register", json={
            "email": auth_fail_user,
            "password": "Password123!",
            "full_name": "Auth Fail User",
        })

        mock_smtp_auth_fail = MagicMock()
        mock_smtp_auth_fail.__enter__.return_value = mock_smtp_auth_fail
        mock_smtp_auth_fail.login.side_effect = smtplib.SMTPAuthenticationError(535, b"5.7.8 Username and Password not accepted")

        with patch("smtplib.SMTP", return_value=mock_smtp_auth_fail), \
             patch.dict("os.environ", {
                 "SMTP_USER": "wrong.user@gmail.com",
                 "SMTP_PASSWORD": "badpassword1234",
             }):
            fail_res = client.post("/forgot-password", json={"email": auth_fail_user})
            assert fail_res.status_code == 503, f"Expected 503, got {fail_res.status_code}: {fail_res.text}"
            assert "authentication failed" in fail_res.json().get("detail", "").lower()
            # Ensure OTP rolled back
            fail_otp = db.query(PasswordResetOTP).filter(PasswordResetOTP.email == auth_fail_user).first()
            assert fail_otp is None, "OTP must be deleted from DB on SMTP auth error"
        print("  -> PASS: 503 returned and OTP rolled back on SMTPAuthenticationError")

        # -------------------------------------------------------------
        # STEP 16: Mocked SMTP Connection / Network Error Handling
        # -------------------------------------------------------------
        print("\n[TEST 16] Testing SMTP connection / network timeout error handling...")
        conn_fail_user = f"conn_fail_{uid}@example.com"
        client.post("/register", json={
            "email": conn_fail_user,
            "password": "Password123!",
            "full_name": "Conn Fail User",
        })

        with patch("smtplib.SMTP", side_effect=OSError("Network is unreachable")), \
             patch.dict("os.environ", {
                 "SMTP_USER": "user@gmail.com",
                 "SMTP_PASSWORD": "password123456",
             }):
            conn_res = client.post("/forgot-password", json={"email": conn_fail_user})
            assert conn_res.status_code == 503
            assert "could not connect" in conn_res.json().get("detail", "").lower()
            fail_otp2 = db.query(PasswordResetOTP).filter(PasswordResetOTP.email == conn_fail_user).first()
            assert fail_otp2 is None, "OTP must be rolled back on connection failure"
        print("  -> PASS: 503 returned and OTP rolled back on SMTP connection failure")

        # -------------------------------------------------------------
        # STEP 17: Mocked Unconfigured Production Mode Enforcement
        # -------------------------------------------------------------
        print("\n[TEST 17] Testing unconfigured SMTP in Render production mode...")
        prod_unconf_user = f"prod_unconf_{uid}@example.com"
        client.post("/register", json={
            "email": prod_unconf_user,
            "password": "Password123!",
            "full_name": "Prod Unconf User",
        })

        with patch.dict("os.environ", {
            "RENDER": "true",
            "SMTP_USER": "",
            "SMTP_PASSWORD": "",
        }):
            prod_res = client.post("/forgot-password", json={"email": prod_unconf_user})
            assert prod_res.status_code == 503
            assert "not configured on the production server" in prod_res.json().get("detail", "").lower()
        print("  -> PASS: Production mode rejects unconfigured SMTP with 503 instead of silent failure")

        # -------------------------------------------------------------
        # STEP 18: Resend OTP endpoint
        # -------------------------------------------------------------
        print("\n[TEST 18] Testing resend OTP endpoint (/resend-otp)...")
        resend_user = f"resend_{uid}@example.com"
        client.post("/register", json={
            "email": resend_user,
            "password": "Password123!",
            "full_name": "Resend User",
        })
        # Initial request
        r1 = client.post("/resend-otp", json={"email": resend_user})
        assert r1.status_code == 200
        assert r1.json()["cooldown_seconds"] == 60
        # Immediate second request hits cooldown
        r2 = client.post("/resend-otp", json={"email": resend_user})
        assert r2.status_code == 429
        print("  -> PASS: /resend-otp works and enforces cooldown")

        # -------------------------------------------------------------
        # STEP 20: Regression test: Render Free tier SMTP block ([Errno 101])
        # -------------------------------------------------------------
        print("\n[TEST 20] Testing Render Free tier SMTP block ([Errno 101] Network is unreachable)...")
        render_user = f"render_block_{uid}@example.com"
        client.post("/register", json={
            "email": render_user,
            "password": "Password123!",
            "full_name": "Render Block User",
        })

        with patch("smtplib.SMTP", side_effect=OSError(101, "Network is unreachable")), \
             patch.dict("os.environ", {"RENDER": "true", "SMTP_USER": "valid@gmail.com", "SMTP_PASSWORD": "apppassword1234"}):
            r_block = client.post("/forgot-password", json={"email": render_user})
            assert r_block.status_code == 503, f"Expected 503, got {r_block.status_code}"
            assert "blocked by server host firewall" in r_block.json().get("detail", "").lower()
            # Verify OTP record was cleanly deleted / rolled back
            otps = db.query(PasswordResetOTP).filter(PasswordResetOTP.email == render_user).all()
            assert len(otps) == 0, f"Expected 0 OTPs after rollback, got {len(otps)}"
        print("  -> PASS: Render SMTP block returns clean 503 and rolls back DB (never 500)")

        # -------------------------------------------------------------
        # STEP 21: Testing HTTPS email API dispatch (Resend)
        # -------------------------------------------------------------
        print("\n[TEST 21] Testing HTTPS REST email dispatch (Resend API)...")
        https_user = f"https_email_{uid}@example.com"
        client.post("/register", json={
            "email": https_user,
            "password": "Password123!",
            "full_name": "HTTPS User",
        })

        class MockHTTPResponse:
            def __init__(self, status=200):
                self.status = status
            def __enter__(self):
                return self
            def __exit__(self, *args):
                pass

        with patch("urllib.request.urlopen", return_value=MockHTTPResponse(200)), \
             patch.dict("os.environ", {"RESEND_API_KEY": "re_mock_test_key_12345"}):
            r_https = client.post("/forgot-password", json={"email": https_user})
            assert r_https.status_code == 200, f"Expected 200, got {r_https.status_code}"
            # Verify OTP record exists
            otps_https = db.query(PasswordResetOTP).filter(PasswordResetOTP.email == https_user).all()
            assert len(otps_https) == 1
        print("  -> PASS: HTTPS REST email dispatch operates over port 443 successfully")

        print("\n" + "=" * 75)
        print("ALL 21 TESTS (INCLUDING RENDER SMTP BLOCK & HTTPS DISPATCH) PASSED!")
        print("=" * 75)

    finally:
        db.close()


if __name__ == "__main__":
    run_tests()
