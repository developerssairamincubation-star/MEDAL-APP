"""EmailService student invites over the real code paths (SMTP/Gmail and Resend), with fake transports."""
import email as email_lib
import json
import smtplib
from email.header import decode_header, make_header

import pytest

import app.services.email as email_mod
from app.services.email import EmailDeliveryError, EmailService


class FakeSMTP:
    """Records what the real code does to an SMTP server. Class-level knobs steer failures."""
    instances: list = []
    auth_error = False
    refuse = set()           # recipients the server refuses
    drop_after = None        # drop the connection after this many sent mails (once)
    connect_error = None

    def __init__(self, host, port, timeout=None, context=None):
        if FakeSMTP.connect_error:
            raise FakeSMTP.connect_error
        self.host, self.port, self.context = host, port, context
        self.events, self.sent = ["connect"], []
        self.esmtp_features = {"auth": "PLAIN LOGIN XOAUTH2"}
        FakeSMTP.instances.append(self)

    def ehlo(self): self.events.append("ehlo")
    def starttls(self, context=None): self.events.append("starttls")
    def auth(self, mechanism, fn):
        self.events.append(f"auth:{mechanism}")
        if FakeSMTP.auth_error:
            raise smtplib.SMTPAuthenticationError(535, b"Username and Password not accepted")
        self.auth_creds = (self.user, self.password)
    def login(self, user, password): self.events.append("login")
    def auth_plain(self, challenge=None): return ""
    def sendmail(self, sender, recipients, raw):
        if FakeSMTP.drop_after is not None and len(FakeSMTP.sent_total()) >= FakeSMTP.drop_after:
            FakeSMTP.drop_after = None
            raise smtplib.SMTPServerDisconnected("Connection unexpectedly closed")
        if recipients[0] in FakeSMTP.refuse:
            raise smtplib.SMTPRecipientsRefused({recipients[0]: (550, b"no such user")})
        self.sent.append((sender, recipients, raw))
    def quit(self): self.events.append("quit")
    def close(self): self.events.append("close")

    @staticmethod
    def sent_total():
        return [m for inst in FakeSMTP.instances for m in inst.sent]


@pytest.fixture(autouse=True)
def fake_smtp(monkeypatch):
    FakeSMTP.instances, FakeSMTP.auth_error, FakeSMTP.refuse = [], False, set()
    FakeSMTP.drop_after, FakeSMTP.connect_error = None, None
    monkeypatch.setattr(email_mod.smtplib, "SMTP", FakeSMTP)
    monkeypatch.setattr(email_mod.smtplib, "SMTP_SSL", FakeSMTP)
    monkeypatch.delenv("RENDER", raising=False)
    monkeypatch.delenv("ENVIRONMENT", raising=False)


def gmail(**over):
    kw = dict(smtp_host="smtp.gmail.com", smtp_port=587, smtp_user="school@gmail.com",
              smtp_password="abcd efgh ijkl mnop", from_email="school@gmail.com", from_name="MEDAL Civic Support")
    kw.update(over)
    return EmailService(**kw)


def parse(raw):
    msg = email_lib.message_from_string(raw)
    parts = {p.get_content_type(): p.get_payload(decode=True).decode("utf-8") for p in msg.walk() if not p.is_multipart()}
    return msg, parts


def invite(svc, **over):
    kw = dict(to_email="asha@example.com", student_name="Asha Kumar", teacher_name="Tara Teacher",
              school_name="Greenfield School", temporary_password="Tmp1234abc")
    kw.update(over)
    return svc.send_student_invite(**kw)


class TestSmtpSingle:
    def test_gmail_starttls_flow_and_message(self):
        assert invite(gmail()) is True
        (srv,) = FakeSMTP.instances
        assert (srv.host, srv.port) == ("smtp.gmail.com", 587)
        assert srv.events == ["connect", "starttls", "ehlo", "auth:PLAIN", "quit"]       # TLS before login, then close
        assert srv.auth_creds == ("school@gmail.com", "abcdefghijklmnop")                # app-password spaces stripped
        (sender, recipients, raw), = srv.sent
        assert (sender, recipients) == ("school@gmail.com", ["asha@example.com"])
        msg, parts = parse(raw)
        assert str(make_header(decode_header(msg["Subject"]))) == "Tara Teacher added you to MEDAL (Greenfield School)"
        assert msg["To"] == "asha@example.com" and "school@gmail.com" in msg["From"] and "MEDAL Civic Support" in msg["From"]
        for body in parts.values():
            assert "Tmp1234abc" in body and "asha@example.com" in body and "Greenfield School" in body

    def test_ssl_port_465_skips_starttls(self):
        assert invite(gmail(smtp_port=465)) is True
        assert FakeSMTP.instances[0].events == ["connect", "ehlo", "auth:PLAIN", "quit"]

    def test_html_is_escaped(self):
        invite(gmail(), student_name="<script>alert(1)</script>", teacher_name="T & Co")
        _, parts = parse(FakeSMTP.instances[0].sent[0][2])
        assert "<script>" not in parts["text/html"] and "&lt;script&gt;" in parts["text/html"]
        assert "T &amp; Co" in parts["text/html"]

    def test_bad_app_password_gives_an_actionable_error_and_closes_the_connection(self):
        FakeSMTP.auth_error = True
        with pytest.raises(EmailDeliveryError, match="App Password"):
            invite(gmail())
        assert FakeSMTP.instances[0].events[-1] == "close" and FakeSMTP.sent_total() == []

    def test_refused_recipient_is_a_delivery_error(self):
        FakeSMTP.refuse = {"asha@example.com"}
        with pytest.raises(EmailDeliveryError):
            invite(gmail())
        assert FakeSMTP.instances[0].events[-1] == "quit"

    def test_unreachable_server_in_production_mentions_the_render_smtp_block(self, monkeypatch):
        monkeypatch.setenv("RENDER", "true")
        FakeSMTP.connect_error = OSError("[Errno 101] Network is unreachable")
        with pytest.raises(EmailDeliveryError, match="free plan blocks outgoing SMTP"):
            invite(gmail())

    def test_unconfigured_dev_sends_nothing_and_unconfigured_production_refuses(self, monkeypatch):
        blank = EmailService(smtp_user="", smtp_password="")
        assert invite(blank) is False and FakeSMTP.instances == []
        monkeypatch.setenv("RENDER", "true")
        with pytest.raises(EmailDeliveryError, match="not configured"):
            invite(blank)


class TestSmtpBatch:
    ROWS = [("A", "a@example.com", "pw1"), ("B", "b@example.com", "pw2"), ("C", "c@example.com", "pw3")]

    def test_one_login_for_the_whole_file(self):
        results = gmail().send_student_invites(self.ROWS, "Tara Teacher", "Greenfield School")
        assert results == [("a@example.com", None), ("b@example.com", None), ("c@example.com", None)]
        (srv,) = FakeSMTP.instances                                           # ONE connection, ONE login
        assert srv.events.count("auth:PLAIN") == 1 and len(srv.sent) == 3 and srv.events[-1] == "quit"
        assert [m[1][0] for m in srv.sent] == ["a@example.com", "b@example.com", "c@example.com"]
        _, second = parse(srv.sent[1][2])
        assert "pw2" in second["text/plain"] and "pw1" not in second["text/plain"]   # each mail carries its own password

    def test_a_refused_recipient_does_not_stop_the_others(self):
        FakeSMTP.refuse = {"b@example.com"}
        results = dict(gmail().send_student_invites(self.ROWS, "T", "S"))
        assert results["a@example.com"] is None and results["c@example.com"] is None
        assert results["b@example.com"] and "Could not deliver" in results["b@example.com"]

    def test_dropped_connection_reconnects_and_carries_on(self):
        FakeSMTP.drop_after = 1                                               # server hangs up after the first mail
        results = gmail().send_student_invites(self.ROWS, "T", "S")
        assert [e for _, e in results] == [None, None, None]
        assert len(FakeSMTP.instances) == 2 and len(FakeSMTP.sent_total()) == 3

    def test_bad_credentials_fail_every_row_with_the_same_clear_message(self):
        FakeSMTP.auth_error = True
        results = gmail().send_student_invites(self.ROWS, "T", "S")
        assert [e for e, _ in results] == ["a@example.com", "b@example.com", "c@example.com"]
        assert all(err and "App Password" in err for _, err in results)

    def test_unconfigured_dev_reports_each_row_not_sent(self):
        results = EmailService(smtp_user="", smtp_password="").send_student_invites(self.ROWS, "T", "S")
        assert all(err == "email provider not configured" for _, err in results)


class TestResend:
    def test_resend_is_used_when_a_key_is_set(self, monkeypatch):
        captured = {}

        class Resp:
            status = 200
            def __enter__(self): return self
            def __exit__(self, *a): return False

        def fake_urlopen(req, timeout=None):
            captured["url"], captured["auth"] = req.full_url, req.headers.get("Authorization")
            captured["payload"] = json.loads(req.data.decode())
            return Resp()

        monkeypatch.setattr(email_mod.urllib.request, "urlopen", fake_urlopen)
        svc = EmailService(smtp_user="", smtp_password="", from_email="noreply@school.org", from_name="MEDAL")
        svc.resend_api_key = "re_test_key"
        assert invite(svc) is True
        assert captured["url"] == "https://api.resend.com/emails" and captured["auth"] == "Bearer re_test_key"
        assert captured["payload"]["to"] == ["asha@example.com"] and "Tmp1234abc" in captured["payload"]["text"]
        assert FakeSMTP.instances == []                                       # SMTP untouched
