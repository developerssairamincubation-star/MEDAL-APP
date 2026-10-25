"""
Isolated unit and integration test suite for Authority Login and Role Enforcement.
Uses an in-memory SQLite database via FastAPI dependency override (get_db).
Completely isolated from the live PostgreSQL database.
"""

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from app.database.database import Base, get_db
from app.models.user import User
from app.utils.security import hash_password, create_access_token


# 1. Setup in-memory SQLite engine
SQLITE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLITE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


def setup_test_fixtures():
    """Create all tables in memory and seed test accounts."""
    Base.metadata.create_all(bind=engine)
    db = TestingSession()

    # Seed Official user
    official = User(
        email="officer@corporation.gov.in",
        password_hash=hash_password("OfficerPass123!"),
        full_name="Rajesh Varma",
        role="official",
        is_verified=True,
        is_active=True,
    )
    # Seed Admin user
    admin = User(
        email="commissioner@corporation.gov.in",
        password_hash=hash_password("AdminPass123!"),
        full_name="Municipal Commissioner",
        role="admin",
        is_verified=True,
        is_active=True,
    )
    # Seed Citizen user
    citizen = User(
        email="citizen@example.com",
        password_hash=hash_password("CitizenPass123!"),
        full_name="Jane Citizen",
        role="citizen",
        is_verified=True,
        is_active=True,
    )
    # Seed Inactive Official user
    inactive_officer = User(
        email="inactive.officer@corporation.gov.in",
        password_hash=hash_password("InactivePass123!"),
        full_name="Former Officer",
        role="official",
        is_verified=True,
        is_active=False,
    )

    db.add_all([official, admin, citizen, inactive_officer])
    db.commit()
    db.close()


def test_authority_login_and_roles():
    setup_test_fixtures()

    print("=" * 65)
    print("STARTING AUTHORITY LOGIN & ROLE ENFORCEMENT TEST SUITE")
    print("=" * 65)

    # 1. Successful Official Login
    print("\n[TEST 1] Testing official login with valid credentials...")
    res = client.post("/login", json={
        "email": "officer@corporation.gov.in",
        "password": "OfficerPass123!",
    })
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    data = res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["data"]["role"] == "official"
    assert data["data"]["email"] == "officer@corporation.gov.in"
    official_token = data["access_token"]
    print("  -> PASS: Official login returned 200 OK, valid JWT, and role='official'")

    # 2. Official Access to Protected Official Endpoint
    print("\n[TEST 2] Verifying official token grants access to /official-test...")
    official_res = client.get("/official-test", headers={"Authorization": f"Bearer {official_token}"})
    assert official_res.status_code == 200
    assert official_res.json()["message"] == "Official access granted"
    print("  -> PASS: Official token successfully accessed /official-test")

    # 3. Successful Admin Login
    print("\n[TEST 3] Testing admin login with valid credentials...")
    res = client.post("/login", json={
        "email": "commissioner@corporation.gov.in",
        "password": "AdminPass123!",
    })
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert data["data"]["role"] == "admin"
    admin_token = data["access_token"]
    print("  -> PASS: Admin login returned 200 OK, valid JWT, and role='admin'")

    # 4. Admin Access to Protected Official Endpoint
    print("\n[TEST 4] Verifying admin token grants access to /official-test...")
    admin_official_res = client.get("/official-test", headers={"Authorization": f"Bearer {admin_token}"})
    assert admin_official_res.status_code == 200
    print("  -> PASS: Admin token successfully accessed /official-test")

    # 5. Citizen Login Returns Citizen Role
    print("\n[TEST 5] Testing citizen login (returns role='citizen')...")
    res = client.post("/login", json={
        "email": "citizen@example.com",
        "password": "CitizenPass123!",
    })
    assert res.status_code == 200
    data = res.json()
    assert data["data"]["role"] == "citizen"
    citizen_token = data["access_token"]
    print("  -> PASS: Citizen login succeeded with role='citizen'")

    # 6. Citizen Token Denied on Authority/Official Endpoints
    print("\n[TEST 6] Verifying citizen token is DENIED (403) on /official-test...")
    citizen_res = client.get("/official-test", headers={"Authorization": f"Bearer {citizen_token}"})
    assert citizen_res.status_code == 403, f"Expected 403, got {citizen_res.status_code}"
    assert citizen_res.json()["detail"] == "Insufficient permissions"
    print("  -> PASS: Citizen token strictly rejected with 403 Forbidden")

    # 7. Invalid Password Rejection (401)
    print("\n[TEST 7] Testing invalid password rejection (401)...")
    res = client.post("/login", json={
        "email": "officer@corporation.gov.in",
        "password": "WrongPassword!",
    })
    assert res.status_code == 401
    assert "detail" in res.json()
    print("  -> PASS: Invalid password rejected with 401 Unauthorized")

    # 8. Non-existent User Rejection (401)
    print("\n[TEST 8] Testing non-existent user rejection (401)...")
    res = client.post("/login", json={
        "email": "unknown.officer@corporation.gov.in",
        "password": "AnyPassword123!",
    })
    assert res.status_code == 401
    print("  -> PASS: Non-existent email rejected with 401 Unauthorized")

    # 9. Inactive User Rejection (400)
    print("\n[TEST 9] Testing inactive account rejection (400)...")
    res = client.post("/login", json={
        "email": "inactive.officer@corporation.gov.in",
        "password": "InactivePass123!",
    })
    assert res.status_code == 400
    assert "Account is inactive" in res.json()["detail"]
    print("  -> PASS: Inactive officer account rejected with 400 Bad Request")

    # 10. Unauthenticated Access Rejection (401)
    print("\n[TEST 10] Testing unauthenticated access to /official-test...")
    res = client.get("/official-test")
    assert res.status_code == 401
    print("  -> PASS: Unauthenticated access rejected with 401 Unauthorized")

    print("\n" + "=" * 65)
    print("ALL 10 AUTHORITY LOGIN & ROLE ENFORCEMENT BACKEND TESTS PASSED!")
    print("=" * 65)


if __name__ == "__main__":
    test_authority_login_and_roles()
