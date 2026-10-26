import sys
import uuid
from fastapi.testclient import TestClient
from main import app
from app.database.database import SessionLocal
from app.models.user import User
from app.models.authority_application import AuthorityApplication
from app.utils.security import hash_password

client = TestClient(app)


def test_complete_authority_workflow():
    db = SessionLocal()
    unique_suffix = uuid.uuid4().hex[:8]

    # 1. Prepare Admin Account
    admin_email = f"admin_{unique_suffix}@medal.gov.in"
    admin_password = "AdminSecretPass123!"
    admin_user = User(
        email=admin_email,
        password_hash=hash_password(admin_password),
        full_name="Master Administrator",
        role="admin",
        approval_status="approved",
        is_active=True,
        is_verified=True,
    )
    db.add(admin_user)

    # 2. Prepare Normal Citizen
    citizen_email = f"citizen_{unique_suffix}@example.com"
    citizen_password = "CitizenPass123!"
    citizen_user = User(
        email=citizen_email,
        password_hash=hash_password(citizen_password),
        full_name="Civic Citizen",
        role="citizen",
        approval_status="approved",
        is_active=True,
        is_verified=True,
    )
    db.add(citizen_user)
    db.commit()

    # 3. Test Authority Document Uploads
    pdf_content = b"%PDF-1.4 test official verification document"
    upload_pdf_resp = client.post(
        "/authority/upload-document",
        files={"file": ("official_aadhaar.pdf", pdf_content, "application/pdf")},
    )
    assert upload_pdf_resp.status_code == 201, upload_pdf_resp.text
    aadhaar_url = upload_pdf_resp.json()["document_url"]
    assert "authority-documents" in aadhaar_url or "cloudinary" in aadhaar_url or "http" in aadhaar_url

    jpg_content = (
        b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00"
        b"\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19"
        b"\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342"
        b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05"
        b"\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07"
        b"\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9"
    )
    upload_jpg_resp = client.post(
        "/authority/upload-document",
        files={"file": ("employment_gazette.jpg", jpg_content, "image/jpeg")},
    )
    assert upload_jpg_resp.status_code == 201, upload_jpg_resp.text
    gazette_url = upload_jpg_resp.json()["document_url"]
    assert "authority-documents" in gazette_url or "cloudinary" in gazette_url or "http" in gazette_url

    # Invalid extension test
    bad_upload_resp = client.post(
        "/authority/upload-document",
        files={"file": ("script.sh", b"echo hack", "application/x-sh")},
    )
    assert bad_upload_resp.status_code == 400
    assert "Invalid" in bad_upload_resp.json()["detail"]

    # 4. Test Authority Registration with uploaded documents
    officer_email = f"officer_{unique_suffix}@corporation.gov.in"
    officer_password = "OfficerPass123!"
    reg_payload = {
        "full_name": "Ramesh Sundaram",
        "official_email": officer_email,
        "password": officer_password,
        "official_phone": "+91 98451 22301",
        "designation": "Divisional Environmental Inspector",
        "department": "Ward 14 Sanitation Dept",
        "jurisdiction": "Zone 4, Pine River Catchment",
        "identity_number": "••••  ••••  8492",
        "clearance_level": "Level 2 (Inspection & Resolution Lead)",
        "aadhaar_document_url": aadhaar_url,
        "employment_document_url": gazette_url,
    }

    reg_resp = client.post("/authority/register", json=reg_payload)
    assert reg_resp.status_code == 201, reg_resp.text
    reg_data = reg_resp.json()
    assert reg_data["status"] == "pending"
    assert "AUTH-REV-2026-" in reg_data["reference_id"]
    app_id = reg_data["data"]["id"]
    user1_id = reg_data["data"]["user_id"]

    # 4. Duplicate Registration Rejection
    dup_resp = client.post("/authority/register", json=reg_payload)
    assert dup_resp.status_code == 400
    assert "already registered" in dup_resp.json()["detail"].lower()

    # 5. Pending Authority Login MUST be blocked
    pending_login_resp = client.post("/login", json={
        "email": officer_email,
        "password": officer_password,
    })
    assert pending_login_resp.status_code == 403
    assert "awaiting Admin approval" in pending_login_resp.json()["detail"]

    # 6. Unauthenticated Access to Admin Endpoints MUST be blocked
    unauth_resp = client.get("/admin/authority-applications")
    assert unauth_resp.status_code == 401

    # 7. Citizen Access to Admin Endpoints MUST be blocked
    citizen_login = client.post("/login", json={
        "email": citizen_email,
        "password": citizen_password,
    }).json()
    citizen_token = citizen_login["access_token"]
    citizen_headers = {"Authorization": f"Bearer {citizen_token}"}

    forbidden_resp = client.get("/admin/authority-applications", headers=citizen_headers)
    assert forbidden_resp.status_code == 403
    assert "Insufficient permissions" in forbidden_resp.json()["detail"]

    # 8. Admin Login
    admin_login = client.post("/login", json={
        "email": admin_email,
        "password": admin_password,
    }).json()
    admin_token = admin_login["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 9. Admin Lists Applications
    list_resp = client.get("/admin/authority-applications?status=pending", headers=admin_headers)
    assert list_resp.status_code == 200
    apps = list_resp.json()
    assert any(a["id"] == app_id for a in apps)

    # 10. Admin Rejection Flow
    reject_payload = {"reason": "Employment ID badge expired. Please re-upload current gazette order."}
    reject_resp = client.post(f"/admin/authority-applications/{app_id}/reject", json=reject_payload, headers=admin_headers)
    assert reject_resp.status_code == 200
    assert reject_resp.json()["application"]["status"] == "rejected"

    # 11. Rejected Officer Login MUST be blocked with rejection reason
    rej_login_resp = client.post("/login", json={
        "email": officer_email,
        "password": officer_password,
    })
    assert rej_login_resp.status_code == 403
    assert "rejected" in rej_login_resp.json()["detail"].lower()
    assert "badge expired" in rej_login_resp.json()["detail"].lower()

    # 12. Register a second officer for Approval Flow
    officer2_email = f"officer2_{unique_suffix}@corporation.gov.in"
    reg_payload2 = dict(reg_payload, official_email=officer2_email, full_name="Officer Priya Sharma")
    reg_resp2 = client.post("/authority/register", json=reg_payload2)
    assert reg_resp2.status_code == 201
    app2_id = reg_resp2.json()["data"]["id"]
    user2_id = reg_resp2.json()["data"]["user_id"]

    # 13. Admin Approves Application
    approve_resp = client.post(
        f"/admin/authority-applications/{app2_id}/approve",
        json={"clearance_level": "Level 2 (Inspection & Resolution Lead)"},
        headers=admin_headers,
    )
    assert approve_resp.status_code == 200
    assert approve_resp.json()["application"]["status"] == "approved"

    # 14. Approved Officer Login MUST SUCCEED
    approved_login_resp = client.post("/login", json={
        "email": officer2_email,
        "password": officer_password,
    })
    assert approved_login_resp.status_code == 200
    officer_token = approved_login_resp.json()["access_token"]
    assert approved_login_resp.json()["data"]["role"] == "official"
    assert approved_login_resp.json()["data"]["approval_status"] == "approved"

    # 15. Verify Approved Officer Token Grants Official Permissions
    officer_headers = {"Authorization": f"Bearer {officer_token}"}
    test_official_resp = client.get("/official-test", headers=officer_headers)
    assert test_official_resp.status_code == 200

    # 16. Approved Officer CANNOT access Admin endpoints (403 Forbidden)
    officer_admin_test = client.get("/admin/authority-applications", headers=officer_headers)
    assert officer_admin_test.status_code == 403
    assert "Insufficient permissions" in officer_admin_test.json()["detail"]

    # 17. Citizen CANNOT access official-test
    citizen_test_official = client.get("/official-test", headers=citizen_headers)
    assert citizen_test_official.status_code == 403

    # Clean up temporary test artifacts so single Admin invariant remains intact
    db.query(AuthorityApplication).filter(AuthorityApplication.id.in_([app_id, app2_id])).delete(synchronize_session=False)
    db.query(User).filter(User.id.in_([admin_user.id, citizen_user.id, user1_id, user2_id])).delete(synchronize_session=False)
    db.commit()
    db.close()
    print("\n[SUCCESS] Complete Authority Workflow Backend Tests Passed!")


if __name__ == "__main__":
    test_complete_authority_workflow()
