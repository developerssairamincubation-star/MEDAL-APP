"""
Comprehensive diagnostic script to safely test Gmail SMTP connectivity and authentication.
- Establishes connection to SMTP host & port.
- Negotiates TLS / SSL and performs post-TLS EHLO according to RFC 3207.
- Performs direct single-mechanism authentication (avoiding multi-auth loops that mask 535 errors).
- Distinguishes authentication rejection, TLS failures, network timeouts, and port blocks.
- Zero emails are sent (sendmail is never invoked).
- Passwords and raw secrets are NEVER printed or logged.
"""

import os
import socket
import smtplib
import ssl
from dotenv import load_dotenv

# Ensure environment variables are loaded from backend/.env
env_path = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(env_path, override=True)

from app.services.email import EmailService, mask_email


def verify_smtp() -> bool:
    print("=" * 70)
    print("MEDAL GMAIL SMTP DIAGNOSTIC SUITE (ZERO EMAILS SENT)")
    print("=" * 70)

    service = EmailService()

    # 1. Configuration check
    is_placeholder = (
        not service.smtp_user
        or "your_email" in service.smtp_user
        or not service.smtp_password
        or "your_16_char" in service.smtp_password
    )

    if is_placeholder:
        print("\n[STATUS: PENDING CONFIGURATION]")
        print("Your backend/.env still contains default placeholder values.")
        print(f"Current SMTP_USER: {service.smtp_user or '<EMPTY>'}")
        print("Please edit backend/.env with your real Gmail address and 16-character App Password.")
        print("=" * 70)
        return False

    masked_user = mask_email(service.smtp_user)
    print(f"\nConfiguration:")
    print(f"  - Host: {service.smtp_host}:{service.smtp_port}")
    print(f"  - Mode: {'SSL / SMTPS (Direct)' if (service.use_ssl or service.smtp_port == 465) else 'STARTTLS (Opportunistic TLS)'}")
    print(f"  - User: {masked_user}")
    print(f"  - Password configured: Yes ({len(service.smtp_password)} characters, whitespace trimmed)")

    # 2. Step 1: TCP Network Connectivity
    print("\n[STEP 1/4] Establishing TCP connection...")
    try:
        remote_ip = socket.gethostbyname(service.smtp_host)
        print(f"  -> DNS resolved {service.smtp_host} to {remote_ip}")
    except socket.gaierror as e:
        print(f"  -> [DNS RESOLUTION ERROR] Could not resolve {service.smtp_host}: {e}")
        return False

    server = None
    try:
        if service.use_ssl or service.smtp_port == 465:
            context = ssl.create_default_context()
            print(f"  -> Connecting directly over SSL to {service.smtp_host}:{service.smtp_port} (timeout={service.timeout}s)...")
            server = smtplib.SMTP_SSL(service.smtp_host, service.smtp_port, context=context, timeout=service.timeout)
            print("  -> SSL TCP socket established successfully.")

            print("\n[STEP 2/4] Performing post-connection ESMTP EHLO handshake...")
            ehlo_code, ehlo_msg = server.ehlo()
            print(f"  -> Post-connection EHLO accepted (Code {ehlo_code}).")
        else:
            print(f"  -> Connecting TCP stream to {service.smtp_host}:{service.smtp_port} (timeout={service.timeout}s)...")
            server = smtplib.SMTP(service.smtp_host, service.smtp_port, timeout=service.timeout)
            print("  -> Plain TCP connection established.")

            print("\n[STEP 2/4] Performing initial ESMTP EHLO handshake...")
            ehlo_code, ehlo_msg = server.ehlo()
            print(f"  -> Initial EHLO accepted (Code {ehlo_code}).")

            if service.use_tls:
                print("\n[STEP 3/4] Initiating STARTTLS handshake...")
                context = ssl.create_default_context()
                tls_code, tls_msg = server.starttls(context=context)
                print(f"  -> STARTTLS encryption active (Code {tls_code}: {tls_msg.decode('utf-8', errors='ignore').strip()}).")

                # RFC 3207: Must re-issue EHLO after TLS
                print("  -> Re-negotiating ESMTP capabilities over encrypted TLS channel (RFC 3207)...")
                post_tls_code, post_tls_msg = server.ehlo()
                print(f"  -> Post-TLS EHLO accepted (Code {post_tls_code}).")

        # 3. Inspect advertised Auth capabilities
        auth_mechanisms = server.esmtp_features.get("auth", "").strip()
        print(f"  -> Server advertised auth mechanisms: {auth_mechanisms or 'None advertised'}")

        # 4. Step 4: Authentication (Single-mechanism to prevent multi-loop masking)
        print(f"\n[STEP 4/4] Authenticating with Google as {masked_user}...")
        server.user = service.smtp_user
        server.password = service.smtp_password

        auth_upper = auth_mechanisms.upper()
        if "PLAIN" in auth_upper:
            code, resp = server.auth("PLAIN", server.auth_plain)
        elif "LOGIN" in auth_upper:
            code, resp = server.auth("LOGIN", server.auth_login)
        else:
            code, resp = server.login(service.smtp_user, service.smtp_password)

        clean_resp = resp.decode("utf-8", errors="ignore").strip() if isinstance(resp, bytes) else str(resp).strip()
        print(f"  -> Google response: Code {code} - {clean_resp}")

        print("\n" + "=" * 70)
        print(">>> SUCCESS: Gmail SMTP credentials verified and accepted by Google! <<<")
        print(">>> Zero emails were sent. Your local backend is ready for real OTP delivery! <<<")
        print("=" * 70)
        return True

    except smtplib.SMTPAuthenticationError as e:
        err_msg = e.smtp_error.decode("utf-8", errors="ignore").strip() if isinstance(e.smtp_error, bytes) else str(e)
        print("\n" + "!" * 70)
        print(f"[AUTHENTICATION REJECTED BY GOOGLE (Code {e.smtp_code})]")
        print(f"Google Response: {err_msg}")
        print("\nDiagnostic Checklist:")
        print("1. Google Account Match:")
        print(f"   Confirm the App Password was generated while signed in to {masked_user}.")
        print("   If you have multiple Google accounts, Chrome often defaults to your primary account.")
        print("2. 2-Step Verification:")
        print("   Google App Passwords only work when 2-Step Verification is actively turned ON.")
        print("3. App Password Validity:")
        print("   Generate a fresh 16-character code at: https://myaccount.google.com/apppasswords")
        print("   Name it 'MEDAL-App' and update SMTP_PASSWORD in backend/.env.")
        print("!" * 70)
        return False

    except ssl.SSLError as e:
        print("\n" + "!" * 70)
        print(f"[TLS / SSL HANDSHAKE ERROR] {e}")
        print("Check if local antivirus SSL-inspection / proxy is tampering with TLS certificates.")
        print("!" * 70)
        return False

    except smtplib.SMTPServerDisconnected as e:
        print("\n" + "!" * 70)
        print(f"[SERVER DISCONNECTED] {e}")
        print("The remote server abruptly dropped the connection.")
        print("!" * 70)
        return False

    except (socket.timeout, TimeoutError) as e:
        print("\n" + "!" * 70)
        print(f"[CONNECTION TIMED OUT] {e}")
        print("Port 587 or 465 timed out. Verify network connectivity.")
        print("!" * 70)
        return False

    except (smtplib.SMTPConnectError, OSError) as e:
        print("\n" + "!" * 70)
        print(f"[NETWORK CONNECTION ERROR] Could not reach {service.smtp_host}:{service.smtp_port}: {e}")
        print("Ensure port 587 is not blocked by a local firewall.")
        print("!" * 70)
        return False

    except Exception as e:
        print(f"\n[UNEXPECTED DIAGNOSTIC ERROR] {type(e).__name__}: {e}")
        return False

    finally:
        if server:
            try:
                server.quit()
            except Exception:
                pass


if __name__ == "__main__":
    verify_smtp()
