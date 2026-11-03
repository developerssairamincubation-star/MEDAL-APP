"""Self-contained check (SQLite + TestClient, no network):
- /officials returns only approved officials and filters by the typed text
- tagged officials are validated, stored with the post and returned by feed/detail
- /student/certificates returns nothing until a course is completed

Run:  python -m pytest test_mentions_and_certificates_local.py
"""
import os
import tempfile

os.environ.setdefault("DATABASE_URL", f"sqlite:///{tempfile.mkdtemp()}/medal_test2.db")
os.environ.setdefault("SECRET_KEY", "test-secret")
os.environ.setdefault("CLOUDINARY_CLOUD_NAME", "test")
os.environ.setdefault("CLOUDINARY_API_KEY", "test")
os.environ.setdefault("CLOUDINARY_API_SECRET", "test")

from fastapi.testclient import TestClient

import main
import app.routers.complaint as complaint_router
from app.database.database import Base, SessionLocal, engine
from app.models.student import StudentCourse, StudentEnrollment
from app.models.user import User
from app.utils.security import hash_password


def _user(db, email, name, role="citizen", approval="approved", **extra):
    u = User(email=email, password_hash=hash_password("Password123!"), full_name=name,
             role=role, approval_status=approval, is_active=True, is_verified=True, **extra)
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def _login(client, email):
    token = client.post("/login", json={"email": email, "password": "Password123!"}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_officials_search_and_mentions(monkeypatch):
    monkeypatch.setattr(complaint_router, "reverse_geocode", lambda lat, lng: "Gandhipuram, Coimbatore")
    Base.metadata.create_all(engine)
    db = SessionLocal()
    ravi = _user(db, "ravi@gov.in", "Ravi Kumar", "official", designation="Ward Officer", department="Sanitation")
    meena = _user(db, "meena@gov.in", "Meena Iyer", "official", designation="Engineer", department="Roads")
    pending = _user(db, "pend@gov.in", "Ravi Pending", "official", approval="pending")
    _user(db, "cit@example.com", "Asha Citizen")
    ravi_id, meena_id, pending_id = ravi.id, meena.id, pending.id
    db.close()

    client = TestClient(main.app)
    headers = _login(client, "cit@example.com")

    names = [o["full_name"] for o in client.get("/officials", headers=headers).json()]
    assert names == ["Meena Iyer", "Ravi Kumar"]  # approved only, alphabetical

    assert [o["full_name"] for o in client.get("/officials?q=rav", headers=headers).json()] == ["Ravi Kumar"]
    assert [o["full_name"] for o in client.get("/officials?q=roads", headers=headers).json()] == ["Meena Iyer"]
    assert client.get("/officials?q=zzz", headers=headers).json() == []
    assert client.get("/officials").status_code in (401, 403)

    body = {"title": "Garbage", "description": "Overflowing bin @Ravi Kumar", "category": "garbage",
            "location": "Gandhipuram", "mentions": [ravi_id, pending_id, 99999]}
    created = client.post("/complaints", json=body, headers=headers).json()
    assert created["mentions"] == [{"id": ravi_id, "name": "Ravi Kumar"}]  # pending / unknown ids dropped

    feed_item = client.get("/complaints/feed", headers=headers).json()[0]
    assert feed_item["mentions"] == [{"id": ravi_id, "name": "Ravi Kumar"}]
    detail = client.get(f"/complaints/{created['id']}", headers=headers).json()
    assert detail["mentions"] == [{"id": ravi_id, "name": "Ravi Kumar"}]

    plain = client.post("/complaints", json={**body, "mentions": []}, headers=headers).json()
    assert plain["mentions"] == []


def test_certificates_only_after_completion():
    Base.metadata.create_all(engine)
    db = SessionLocal()
    stu = _user(db, "stu@example.com", "Stu Dent", "student")
    course = StudentCourse(title="SEEK Foundation", provider="UNESCO MGIEP", department="Education", description="Intro", what_you_will_learn="Empathy", total_modules=4)
    db.add(course)
    db.commit()
    db.refresh(course)
    enr = StudentEnrollment(user_id=stu.id, course_id=course.id, status="enrolled", progress_pct=0.32)
    db.add(enr)
    db.commit()
    enr_id = enr.id
    db.close()

    client = TestClient(main.app)
    headers = _login(client, "stu@example.com")
    assert client.get("/student/certificates", headers=headers).json() == []

    db = SessionLocal()
    e = db.get(StudentEnrollment, enr_id)
    e.progress_pct, e.status = 1.0, "completed"
    db.commit()
    db.close()

    certs = client.get("/student/certificates", headers=headers).json()
    assert len(certs) == 1 and certs[0]["title"] == "SEEK Foundation"
    assert len(client.get("/student/certificates", headers=headers).json()) == 1  # not duplicated
