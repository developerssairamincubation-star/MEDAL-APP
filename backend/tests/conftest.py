"""Hermetic test harness for the MEDAL backend.

* Uses a throwaway SQLite file. DATABASE_URL is forced *before* the app is
  imported, and the suite aborts if the engine does not point at SQLite, so the
  real (.env) database can never be touched.
* Email sender, storage and reverse-geocoder are replaced with fakes.
* Credentials come from env vars (TEST_*) with throwaway defaults; nothing is
  printed.
"""
import json
import os
import sys
import tempfile
import uuid

_TMP = tempfile.mkdtemp(prefix="medal-test-")
os.environ["DATABASE_URL"] = f"sqlite:///{os.path.join(_TMP, 'test.db')}"
os.environ["JWT_SECRET"] = os.getenv("TEST_JWT_SECRET", uuid.uuid4().hex + uuid.uuid4().hex)
os.environ.pop("ACCESS_TOKEN_EXPIRE_MINUTES", None)
os.environ["STORAGE_TYPE"] = "local"
for _k in ("SMTP_USER", "SMTP_PASSWORD", "RESEND_API_KEY", "OPENAI_API_KEY",
           "CLOUDINARY_CLOUD_NAME", "CLOUDINARY_API_KEY", "CLOUDINARY_API_SECRET"):
    os.environ[_k] = ""

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.database.database import Base, SessionLocal, engine  # noqa: E402

assert engine.url.get_backend_name() == "sqlite", "tests must run against SQLite only"

import app.models.authority_application  # noqa: E402,F401
import app.models.complaint  # noqa: E402,F401
import app.models.otp  # noqa: E402,F401
import app.models.student  # noqa: E402,F401
from app.models.user import School, User  # noqa: E402
from app.services.email import get_email_service  # noqa: E402
from app.services.seek_chapters import load_chapters  # noqa: E402
from app.services.storage import get_storage_service  # noqa: E402
from app.utils.security import INSTITUTION_ROLES, hash_password  # noqa: E402
from main import app  # noqa: E402

PASSWORD = os.getenv("TEST_USER_PASSWORD", "Str0ng-Test-Pass!")
ADMIN_EMAIL = os.getenv("TEST_ADMIN_EMAIL", "admin@example.com")
ADMIN_PASSWORD = os.getenv("TEST_ADMIN_PASSWORD", "Adm1n-Test-Pass!")


class FakeEmail:
    """Captures outgoing mail instead of sending it."""
    outbox: list = []

    def is_configured(self):
        return True

    def send_password_reset_otp(self, to_email, otp, expires_in_minutes=10):
        FakeEmail.outbox.append({"to": to_email, "kind": "password_reset", "otp": otp})
        return True

    def is_production(self):
        return False

    # Set to an exception instance to simulate a mail provider failure.
    fail_with = None

    def send_student_invite(self, to_email, student_name, teacher_name, school_name, temporary_password):
        if FakeEmail.fail_with is not None:
            raise FakeEmail.fail_with
        FakeEmail.outbox.append({
            "to": to_email, "kind": "student_invite", "student": student_name, "teacher": teacher_name,
            "school": school_name, "password": temporary_password,
        })
        return True


class FakeStorage:
    async def upload_bytes(self, data, filename, folder="", content_type="", is_private=False, custom_public_id=None):
        from app.services.storage import UploadResult
        pid = f"{folder}/{uuid.uuid4().hex[:8]}"
        return UploadResult(f"https://files.test/{pid}", public_id=pid, format="png")

    def generate_private_download_url(self, public_id, resource_type="image", expires_in=3600):
        return f"https://signed.test/{public_id}?exp={expires_in}"


@pytest.fixture(autouse=True)
def _isolation(monkeypatch):
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    FakeEmail.outbox.clear()
    FakeEmail.fail_with = None
    app.dependency_overrides[get_email_service] = lambda: FakeEmail()
    app.dependency_overrides[get_storage_service] = lambda: FakeStorage()
    # No network: reverse geocoding degrades to "no place name".
    monkeypatch.setattr("app.routers.complaint.reverse_geocode", lambda lat, lng: "Test Place")
    yield
    app.dependency_overrides.clear()


@pytest.fixture()
def client():
    return TestClient(app)  # no `with`: startup hook (real seed file) is not run


@pytest.fixture()
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def outbox():
    return FakeEmail.outbox


def _email(prefix):
    return f"{prefix}-{uuid.uuid4().hex[:8]}@example.com"


@pytest.fixture()
def make_school(db):
    def _make(code="TESTSCH", name=None):
        school = db.query(School).filter(School.code == code).first()
        if not school:
            school = School(code=code, name=name or f"School {code}")
            db.add(school)
            db.commit()
            db.refresh(school)
        return school
    return _make


@pytest.fixture()
def school(make_school):
    """The default school every institution test user belongs to unless told otherwise."""
    return make_school("TESTSCH")


@pytest.fixture()
def make_user(db, make_school):
    def _make(role="citizen", email=None, password=PASSWORD, approval_status="approved",
              full_name=None, is_active=True, **extra):
        if role in INSTITUTION_ROLES and "school_id" not in extra:
            extra["school_id"] = make_school("TESTSCH").id
        user = User(
            email=email or _email(role),
            password_hash=hash_password(password),
            full_name=full_name or f"Test {role.title()}",
            role=role,
            approval_status=approval_status,
            is_active=is_active,
            is_verified=approval_status == "approved",
            **extra,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    return _make


@pytest.fixture()
def login(client):
    def _login(email, password=PASSWORD):
        r = client.post("/login", json={"email": email, "password": password})
        return r
    return _login


@pytest.fixture()
def token_for(login):
    def _token(user, password=PASSWORD):
        r = login(user.email, password)
        assert r.status_code == 200, r.text
        return r.json()["access_token"]
    return _token


@pytest.fixture()
def auth(token_for):
    def _auth(user, password=PASSWORD):
        return {"Authorization": f"Bearer {token_for(user, password)}"}
    return _auth


@pytest.fixture()
def admin(make_user):
    return make_user("admin", email=ADMIN_EMAIL, password=ADMIN_PASSWORD, full_name="Test Admin")


@pytest.fixture()
def principal(make_user):
    return make_user("principal", full_name="Test Principal")


SEED = {
    "course_id": 1,
    "course": {"title": "SEEK Course", "description": "d", "what_you_will_learn": ["a", "b"]},
    "chapters": [
        {"key": "1.1", "module": 1, "module_title": "M1", "title": "C1", "type": "video", "duration": "10 mins", "url": None},
        {"key": "1.2", "module": 1, "module_title": "M1", "title": "C2", "type": "reading", "duration": "20 mins", "url": None},
        {"key": "2.1", "module": 2, "module_title": "M2", "title": "C3", "type": "quiz", "duration": "30 mins", "url": None},
        {"key": "2.2", "module": 2, "module_title": "M2", "title": "C4", "type": "practice", "duration": "40 mins", "url": None},
    ],
}


@pytest.fixture()
def seed_file(tmp_path):
    def _write(data=None, raw=None):
        path = tmp_path / f"seek-{uuid.uuid4().hex[:6]}.json"
        path.write_text(raw if raw is not None else json.dumps(data or SEED), encoding="utf-8")
        return str(path)
    return _write


@pytest.fixture()
def course(db, seed_file):
    """The SEEK course with 4 chapters, loaded through the real loader."""
    assert load_chapters(db, seed_file()) == 4
    from app.models.student import StudentCourseChapter
    return db.query(StudentCourseChapter).order_by(StudentCourseChapter.position).all()


def authority_payload(email=None, **over):
    body = {
        "full_name": "Ward Officer",
        "official_email": email or _email("official"),
        "password": PASSWORD,
        "designation": "Ward Officer",
        "department": "Sanitation",
        "jurisdiction": "Ward 12",
        "aadhaar_document_url": "https://files.test/aadhaar.pdf",
        "aadhaar_public_id": "medal/authority-documents/aadhaar",
        "employment_document_url": "https://files.test/employment.pdf",
        "employment_public_id": "medal/authority-documents/employment",
    }
    body.update(over)
    return body


@pytest.fixture()
def register_authority(client):
    def _reg(**over):
        return client.post("/authority/register", json=authority_payload(**over))
    return _reg


@pytest.fixture()
def approved_official(make_user):
    return make_user("official", designation="Ward Officer", department="Sanitation",
                     jurisdiction="Ward 12")


def complaint_payload(**over):
    body = {
        "title": "Garbage pile", "description": "Uncollected garbage", "category": "garbage",
        "location": "MG Road", "latitude": 12.9716, "longitude": 77.5946,
    }
    body.update(over)
    return body
