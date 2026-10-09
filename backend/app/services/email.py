import json
import logging
import os
import smtplib
import ssl
import urllib.error
import urllib.request
from email.header import Header
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("medal.email")


class EmailDeliveryError(Exception):
    """Raised when email delivery fails."""
    pass


def mask_email(email: str) -> str:
    """Safely mask email address for privacy in logs (e.g., s***8@gmail.com)."""
    if not email or "@" not in email:
        return "***"
    parts = email.split("@", 1)
    user, domain = parts[0], parts[1]
    if len(user) <= 2:
        masked_user = user[0] + "*"
    else:
        masked_user = user[0] + "*" * (len(user) - 2) + user[-1]
    return f"{masked_user}@{domain}"


class EmailService:
    def __init__(
        self,
        smtp_host: Optional[str] = None,
        smtp_port: Optional[int] = None,
        smtp_user: Optional[str] = None,
        smtp_password: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
        use_tls: Optional[bool] = None,
        use_ssl: Optional[bool] = None,
        timeout: int = 15,
    ):
        # Refresh environment in case variables were loaded after module import
        load_dotenv()

        # Support primary names and common aliases
        self.smtp_host = (
            smtp_host
            or os.getenv("SMTP_HOST")
            or os.getenv("EMAIL_HOST")
            or os.getenv("MAIL_SERVER")
            or "smtp.gmail.com"
        ).strip()

        port_str = (
            str(smtp_port)
            if smtp_port is not None
            else (
                os.getenv("SMTP_PORT")
                or os.getenv("EMAIL_PORT")
                or os.getenv("MAIL_PORT")
                or "587"
            )
        ).strip()
        try:
            self.smtp_port = int(port_str)
        except ValueError:
            self.smtp_port = 587

        raw_user = (
            smtp_user
            or os.getenv("SMTP_USER")
            or os.getenv("EMAIL_USER")
            or os.getenv("MAIL_USERNAME")
            or os.getenv("GMAIL_USER")
            or ""
        ).strip()
        self.smtp_user = raw_user

        raw_password = (
            smtp_password
            or os.getenv("SMTP_PASSWORD")
            or os.getenv("EMAIL_PASSWORD")
            or os.getenv("MAIL_PASSWORD")
            or os.getenv("GMAIL_APP_PASSWORD")
            or ""
        ).strip()
        # Google App Passwords are 16 characters often formatted with spaces (e.g., 'abcd efgh ijkl mnop')
        # Stripping internal whitespace ensures smtplib passes the clean 16-character secret
        self.smtp_password = raw_password.replace(" ", "")

        self.from_email = (
            from_email
            or os.getenv("SMTP_FROM_EMAIL")
            or os.getenv("EMAIL_FROM")
            or os.getenv("MAIL_FROM")
            or self.smtp_user
        ).strip()

        self.from_name = (
            from_name
            or os.getenv("SMTP_FROM_NAME")
            or os.getenv("EMAIL_FROM_NAME")
            or "MEDAL Civic Support"
        ).strip()

        tls_setting = (
            use_tls
            if use_tls is not None
            else (
                os.getenv("SMTP_USE_TLS")
                or os.getenv("EMAIL_USE_TLS")
                or "True"
            )
        )
        self.use_tls = str(tls_setting).lower() in ("true", "1", "yes")

        ssl_setting = (
            use_ssl
            if use_ssl is not None
            else (
                os.getenv("SMTP_USE_SSL")
                or os.getenv("EMAIL_USE_SSL")
                or "False"
            )
        )
        self.use_ssl = str(ssl_setting).lower() in ("true", "1", "yes")

        self.resend_api_key = (
            os.getenv("RESEND_API_KEY")
            or os.getenv("EMAIL_API_KEY")
            or ""
        ).strip()

        self.timeout = timeout

    def is_configured(self) -> bool:
        """Returns True if real SMTP credentials or HTTPS email API key are provided."""
        return bool(self.resend_api_key or (self.smtp_user and self.smtp_password))

    def is_production(self) -> bool:
        """Detects whether running in Render or explicit production environment."""
        is_render = os.getenv("RENDER", "").lower() in ("true", "1")
        is_prod_env = os.getenv("ENVIRONMENT", "").lower() in ("production", "prod")
        return is_render or is_prod_env

    def send_password_reset_otp(
        self,
        to_email: str,
        otp: str,
        expires_in_minutes: int = 10,
    ) -> bool:
        """
        Send a 6-digit OTP code to the requested recipient.
        In simulation/dev mode (when credentials are unset in local dev), safely logs delivery without printing secrets.
        In production/configured mode, sends via Gmail SMTP (port 587 STARTTLS or 465 SSL).
        """
        masked_recipient = mask_email(to_email)
        subject = f"Your MEDAL Password Reset Code: {otp}"

        # Check configuration
        if not self.is_configured():
            if self.is_production():
                logger.error(
                    "[EMAIL CONFIG ERROR] Cannot deliver password reset email on Render: "
                    "SMTP_USER and/or SMTP_PASSWORD environment variables are missing or empty."
                )
                raise EmailDeliveryError(
                    "Email service is not configured on the production server. "
                    "Please set SMTP_USER and SMTP_PASSWORD in Render Environment settings."
                )
            else:
                logger.warning(
                    "[EMAIL SERVICE - DEV SIMULATION] SMTP credentials not configured in local environment. "
                    "Simulating email dispatch to %s (no real email will be sent).",
                    masked_recipient,
                )
                return True

        text_content = (
            f"Hello,\n\n"
            f"You requested to reset your password for your MEDAL account.\n\n"
            f"Your 6-digit verification code is: {otp}\n\n"
            f"This code will expire in {expires_in_minutes} minutes.\n"
            f"If you did not request a password reset, please ignore this email. Your password will remain unchanged.\n\n"
            f"Regards,\n"
            f"MEDAL Support Team"
        )

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MEDAL Password Reset</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #F8FAFC;
      margin: 0;
      padding: 24px 12px;
      color: #111C2D;
    }}
    .card {{
      max-width: 520px;
      margin: 0 auto;
      background-color: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      border: 1px solid #E2E8F0;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.05);
    }}
    .card-header {{
      background: linear-gradient(135deg, #0467B6 0%, #111C2D 100%);
      padding: 32px 24px;
      text-align: center;
      color: #FFFFFF;
    }}
    .card-header h1 {{
      margin: 0;
      font-size: 28px;
      font-weight: 800;
      letter-spacing: 1.5px;
    }}
    .card-header p {{
      margin: 6px 0 0 0;
      font-size: 13px;
      color: #E8F4FD;
      font-weight: 400;
    }}
    .card-body {{
      padding: 32px 28px;
    }}
    .greeting {{
      font-size: 18px;
      font-weight: 700;
      color: #111C2D;
      margin-top: 0;
      margin-bottom: 12px;
    }}
    .desc {{
      font-size: 14px;
      line-height: 1.6;
      color: #575E72;
      margin: 0 0 24px 0;
    }}
    .otp-wrapper {{
      background-color: #F0F7FD;
      border: 2px dashed #0467B6;
      border-radius: 14px;
      padding: 24px 16px;
      text-align: center;
      margin: 20px 0;
    }}
    .otp-label {{
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 1.2px;
      color: #5D6478;
      margin-bottom: 8px;
    }}
    .otp-code {{
      font-size: 36px;
      font-weight: 900;
      letter-spacing: 10px;
      color: #0467B6;
      font-family: 'Courier New', Courier, monospace;
    }}
    .expiry-note {{
      font-size: 13px;
      color: #5D6478;
      text-align: center;
      line-height: 1.5;
      margin: 16px 0 0 0;
    }}
    .expiry-note strong {{
      color: #0467B6;
    }}
    .security-notice {{
      margin-top: 28px;
      padding-top: 20px;
      border-top: 1px solid #EDF2F7;
      font-size: 12px;
      color: #6B7280;
      line-height: 1.5;
    }}
    .card-footer {{
      background-color: #F8FAFC;
      padding: 16px 24px;
      text-align: center;
      font-size: 12px;
      color: #6B7280;
      border-top: 1px solid #E2E8F0;
    }}
  </style>
</head>
<body>
  <div class="card">
    <div class="card-header">
      <h1>MEdAL</h1>
      <p>Municipal Grievance Redressal & Civic Engagement</p>
    </div>
    <div class="card-body">
      <div class="greeting">Password Reset Verification</div>
      <p class="desc">
        We received a request to reset the password for your account (<strong>{to_email}</strong>). Use the verification code below to proceed:
      </p>
      <div class="otp-wrapper">
        <div class="otp-label">Your Verification Code</div>
        <div class="otp-code">{otp}</div>
      </div>
      <p class="expiry-note">
        This code is valid for <strong>{expires_in_minutes} minutes</strong>.<br>
        For your security, never share this code with anyone.
      </p>
      <div class="security-notice">
        If you did not request a password reset, you can safely ignore this email. Your current password remains active and secure.
      </div>
    </div>
    <div class="card-footer">
      &copy; MEDAL Civic Engagement Platform &bull; Secure Authentication
    </div>
  </div>
</body>
</html>
"""

        # If an HTTPS transactional email API key is configured, use port 443 (never blocked on Render)
        if self.resend_api_key:
            return self._send_via_https_api(
                to_email=to_email,
                subject=subject,
                text_content=text_content,
                html_content=html_content,
            )

        logger.info(
            "Initiating SMTP email dispatch to %s (Host=%s:%s, TLS=%s, SSL=%s, Sender=%s)",
            masked_recipient,
            self.smtp_host,
            self.smtp_port,
            self.use_tls,
            self.use_ssl,
            mask_email(self.from_email),
        )

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = formataddr((str(Header(self.from_name, "utf-8")), self.from_email))
            msg["To"] = to_email

            part1 = MIMEText(text_content, "plain", "utf-8")
            part2 = MIMEText(html_content, "html", "utf-8")
            msg.attach(part1)
            msg.attach(part2)

            if self.use_ssl or self.smtp_port == 465:
                context = ssl.create_default_context()
                logger.info("Opening SSL connection to %s:%s ...", self.smtp_host, self.smtp_port)
                with smtplib.SMTP_SSL(
                    self.smtp_host, self.smtp_port, context=context, timeout=self.timeout
                ) as server:
                    logger.info("Authenticating with SMTP server as %s ...", mask_email(self.smtp_user))
                    server.login(self.smtp_user, self.smtp_password)
                    logger.info("SMTP authentication successful. Sending message...")
                    server.sendmail(self.from_email, [to_email], msg.as_string())
            else:
                logger.info("Opening TCP connection to %s:%s ...", self.smtp_host, self.smtp_port)
                with smtplib.SMTP(
                    self.smtp_host, self.smtp_port, timeout=self.timeout
                ) as server:
                    if self.use_tls:
                        logger.info("Initiating STARTTLS handshake...")
                        context = ssl.create_default_context()
                        server.starttls(context=context)
                    logger.info("Authenticating with SMTP server as %s ...", mask_email(self.smtp_user))
                    server.login(self.smtp_user, self.smtp_password)
                    logger.info("SMTP authentication successful. Sending message...")
                    server.sendmail(self.from_email, [to_email], msg.as_string())

            logger.info("Password reset OTP successfully sent and accepted by SMTP server for recipient %s", masked_recipient)
            return True
        except smtplib.SMTPAuthenticationError as e:
            logger.error(
                "SMTP Authentication Error for sender %s at %s:%s. "
                "Gmail rejected the credentials. Ensure 2FA is enabled and a valid 16-character App Password is used. Detail: %s",
                mask_email(self.smtp_user),
                self.smtp_host,
                self.smtp_port,
                e,
            )
            raise EmailDeliveryError(
                "Email authentication failed. Please check the Gmail App Password in server configuration."
            ) from e
        except (smtplib.SMTPConnectError, OSError) as e:
            err_str = str(e)
            is_unreachable = "101" in err_str or "unreachable" in err_str.lower() or "timed out" in err_str.lower()
            if self.is_production() and is_unreachable:
                logger.error(
                    "SMTP connection blocked by hosting environment connecting to %s:%s for recipient %s: %s. "
                    "Render free tier blocks outbound SMTP ports (25, 465, 587).",
                    self.smtp_host,
                    self.smtp_port,
                    masked_recipient,
                    e,
                )
                raise EmailDeliveryError(
                    f"Outbound SMTP is blocked by server host firewall ({err_str}). "
                    "Render Free tier blocks outbound SMTP ports (587/465); please set RESEND_API_KEY in Render Environment settings to send via HTTPS."
                ) from e

            logger.error(
                "SMTP Connection Error connecting to %s:%s for recipient %s: %s",
                self.smtp_host,
                self.smtp_port,
                masked_recipient,
                e,
            )
            raise EmailDeliveryError(
                f"Could not connect to SMTP server ({self.smtp_host}:{self.smtp_port}): {str(e)}"
            ) from e
        except smtplib.SMTPException as e:
            logger.error(
                "SMTP Delivery Error sending to %s: %s",
                masked_recipient,
                e,
            )
            raise EmailDeliveryError(
                f"SMTP delivery error: {str(e)}"
            ) from e

    def _send_via_https_api(
        self,
        to_email: str,
        subject: str,
        text_content: str,
        html_content: str,
    ) -> bool:
        """Send email via Resend HTTPS REST API (Port 443, unrestricted on Render)."""
        masked_recipient = mask_email(to_email)
        logger.info("Initiating HTTPS email dispatch via Resend API to %s", masked_recipient)

        # Resend free tier sends from 'onboarding@resend.dev' or custom verified domain
        sender_email = self.from_email
        if not sender_email or "@gmail.com" in sender_email.lower():
            sender_email = "onboarding@resend.dev"

        sender_header = f"{self.from_name} <{sender_email}>" if self.from_name else sender_email

        payload = {
            "from": sender_header,
            "to": [to_email],
            "subject": subject,
            "html": html_content,
            "text": text_content,
        }

        data_bytes = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            "https://api.resend.com/emails",
            data=data_bytes,
            headers={
                "Authorization": f"Bearer {self.resend_api_key}",
                "Content-Type": "application/json",
                "User-Agent": "MEDAL-App/1.0",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                if 200 <= resp.status < 300:
                    logger.info("Email delivered successfully via HTTPS API to %s", masked_recipient)
                    return True
                raise EmailDeliveryError(f"HTTPS email API returned status {resp.status}")
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="ignore")
            logger.error("HTTPS email API error for %s: %s - %s", masked_recipient, e.code, err_body)
            raise EmailDeliveryError(f"HTTPS email provider error ({e.code}): {err_body}") from e
        except Exception as e:
            logger.error("HTTPS email API connection failed for %s: %s", masked_recipient, e)
            raise EmailDeliveryError(f"Could not connect to HTTPS email API: {str(e)}") from e


def get_email_service() -> EmailService:
    """Dependency provider returning an EmailService instance with up-to-date environment settings."""
    return EmailService()
