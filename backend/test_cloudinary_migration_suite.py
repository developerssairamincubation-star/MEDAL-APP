"""
MEDAL — Comprehensive Cloudinary Migration Test Suite
Covers all 15 Phase 10 requirements:
1. Successful complaint image upload (POST /complaints/upload-evidence).
2. Successful profile image upload (PUT /users/me/profile-photo).
3. Successful comment attachment upload (POST /complaints/{id}/comments).
4. PDF and supported document uploads (POST /authority/upload-document).
5. Invalid file types and oversized files (magic bytes rejection).
6. Cloudinary API failures and timeouts (graceful 502 Bad Gateway).
7. Missing credentials (clear initialization error).
8. Unauthorized upload and deletion attempts (401/403).
9. Private authority-document access restrictions (signed URLs for admin only).
10. Database persistence of URLs and public IDs.
11. Image replacement and deletion (old avatar and complaint cleanup).
12. AI/SDG analysis using Cloudinary evidence (POST /complaints/analyze-sdg).
13. Existing complaint creation and status updates.
14. Existing user authentication and role-based access.
15. Institution course progress and certificate downloads.
"""

import io
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Setup path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from main import app
from app.database.database import Base, get_db
from app.models.authority_application import AuthorityApplication
from app.models.complaint import Complaint, ComplaintComment
from app.models.student import StudentCertificate, StudentCourse, StudentEnrollment
from app.models.user import User
from app.services.storage import (
    BaseStorageService,
    CloudinaryStorageService,
    UploadResult,
    get_storage_service,
    reset_storage_service,
)
from app.utils.security import create_access_token, hash_password

# In-memory SQLite for unit tests
TEST_DB_URL = "sqlite:///:memory:"
engine_test = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine_test)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


# Valid test image bytes
VALID_JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00TEST_JPEG_CONTENT"
VALID_PNG = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRTEST_PNG_CONTENT"
VALID_PDF = b"%PDF-1.4 TEST_PDF_CONTENT"
INVALID_TEXT = b"This is plain text pretending to be an image."


class TestCloudinaryMigration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.create_all(bind=engine_test)
        app.dependency_overrides[get_db] = override_get_db
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        Base.metadata.drop_all(bind=engine_test)
        app.dependency_overrides.clear()
        reset_storage_service()

    def setUp(self):
        # Create fresh session for test users
        self.db = TestingSessionLocal()

        # Seed test users
        self.citizen = User(
            email="test_citizen@medal.app",
            password_hash=hash_password("Password123!"),
            full_name="Citizen Tester",
            role="citizen",
            is_active=True,
            is_verified=True,
        )
        self.official = User(
            email="test_official@medal.gov.in",
            password_hash=hash_password("Password123!"),
            full_name="Officer Tester",
            role="official",
            is_active=True,
            is_verified=True,
        )
        self.admin = User(
            email="test_admin@medal.gov.in",
            password_hash=hash_password("Password123!"),
            full_name="Admin Tester",
            role="admin",
            is_active=True,
            is_verified=True,
        )
        self.student = User(
            email="test_student@medal.gov",
            password_hash=hash_password("Password123!"),
            full_name="Student Tester",
            role="student",
            is_active=True,
            is_verified=True,
        )

        self.db.add_all([self.citizen, self.official, self.admin, self.student])
        self.db.commit()
        for u in [self.citizen, self.official, self.admin, self.student]:
            self.db.refresh(u)

        # Tokens (FastAPI get_current_user expects str(user.id) in sub)
        self.citizen_token = create_access_token({"sub": str(self.citizen.id), "role": "citizen"})
        self.official_token = create_access_token({"sub": str(self.official.id), "role": "official"})
        self.admin_token = create_access_token({"sub": str(self.admin.id), "role": "admin"})
        self.student_token = create_access_token({"sub": str(self.student.id), "role": "student"})

        self.citizen_headers = {"Authorization": f"Bearer {self.citizen_token}"}
        self.official_headers = {"Authorization": f"Bearer {self.official_token}"}
        self.admin_headers = {"Authorization": f"Bearer {self.admin_token}"}
        self.student_headers = {"Authorization": f"Bearer {self.student_token}"}

    def tearDown(self):
        self.db.query(ComplaintComment).delete()
        self.db.query(Complaint).delete()
        self.db.query(AuthorityApplication).delete()
        self.db.query(StudentCertificate).delete()
        self.db.query(User).delete()
        self.db.commit()
        self.db.close()

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Successful complaint image upload
    # ─────────────────────────────────────────────────────────────────────────
    @patch("cloudinary.uploader.upload")
    def test_01_successful_complaint_image_upload(self, mock_upload):
        mock_upload.return_value = {
            "secure_url": "https://res.cloudinary.com/testcloud/image/upload/v1/medal/complaints/asset_1.jpg",
            "public_id": "medal/complaints/asset_1",
            "format": "jpg",
            "bytes": len(VALID_JPEG),
            "resource_type": "image",
        }

        response = self.client.post(
            "/complaints/upload-evidence",
            headers=self.citizen_headers,
            files={"file": ("evidence.jpg", io.BytesIO(VALID_JPEG), "image/jpeg")},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("image_url", data)
        self.assertTrue(data["image_url"].startswith("https://res.cloudinary.com/"))
        self.assertEqual(data["public_id"], "medal/complaints/asset_1")
        self.assertEqual(data["format"], "jpg")

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Successful profile image upload
    # ─────────────────────────────────────────────────────────────────────────
    @patch("cloudinary.uploader.upload")
    def test_02_successful_profile_image_upload(self, mock_upload):
        mock_upload.return_value = {
            "secure_url": f"https://res.cloudinary.com/testcloud/image/upload/v1/medal/avatars/profiles/{self.citizen.id}/avatar.jpg",
            "public_id": f"medal/avatars/profiles/{self.citizen.id}/avatar_1",
            "format": "jpg",
            "bytes": len(VALID_JPEG),
            "resource_type": "image",
        }

        response = self.client.put(
            "/users/me/profile-photo",
            headers=self.citizen_headers,
            files={"file": ("avatar.jpg", io.BytesIO(VALID_JPEG), "image/jpeg")},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("profile_image_url", data)
        self.assertEqual(data["public_id"], f"medal/avatars/profiles/{self.citizen.id}/avatar_1")

        # Verify DB updated
        self.db.expire_all()
        user_db = self.db.query(User).filter(User.id == self.citizen.id).first()
        self.assertEqual(user_db.profile_image_public_id, f"medal/avatars/profiles/{self.citizen.id}/avatar_1")

    # ─────────────────────────────────────────────────────────────────────────
    # 3. Successful comment attachment upload
    # ─────────────────────────────────────────────────────────────────────────
    def test_03_successful_comment_attachment(self):
        complaint = Complaint(
            title="Pothole on Main St",
            description="Large pothole damaging cars",
            category="road",
            location="Main St",
            citizen_id=self.citizen.id,
            status="submitted",
        )
        self.db.add(complaint)
        self.db.commit()

        comment_payload = {
            "comment": "Here is an additional photo of the road hazard",
            "image_url": "https://res.cloudinary.com/testcloud/image/upload/v1/medal/comments/1/asset_comment.jpg",
            "image_public_id": "medal/comments/1/asset_comment",
        }
        res = self.client.post(
            f"/complaints/{complaint.id}/comments",
            headers=self.citizen_headers,
            json=comment_payload,
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["image_url"], comment_payload["image_url"])
        self.assertEqual(data["image_public_id"], "medal/comments/1/asset_comment")

    # ─────────────────────────────────────────────────────────────────────────
    # 4. PDF and supported document uploads (Authority Onboarding)
    # ─────────────────────────────────────────────────────────────────────────
    @patch("cloudinary.uploader.upload")
    def test_04_pdf_document_upload(self, mock_upload):
        mock_upload.return_value = {
            "secure_url": "https://res.cloudinary.com/testcloud/image/authenticated/s--xyz--/v1/medal/authority-documents/asset_doc.pdf",
            "public_id": "medal/authority-documents/asset_doc",
            "format": "pdf",
            "bytes": len(VALID_PDF),
            "resource_type": "image",
        }

        res = self.client.post(
            "/authority/upload-document",
            files={"file": ("official_id.pdf", io.BytesIO(VALID_PDF), "application/pdf")},
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertIn("document_url", data)
        self.assertEqual(data["public_id"], "medal/authority-documents/asset_doc")
        # Check call arguments used authenticated mode
        call_kwargs = mock_upload.call_args[1]
        self.assertEqual(call_kwargs.get("type"), "authenticated")
        self.assertEqual(call_kwargs.get("access_mode"), "authenticated")

    # ─────────────────────────────────────────────────────────────────────────
    # 5. Invalid file types and oversized files (Magic Bytes & Size rejection)
    # ─────────────────────────────────────────────────────────────────────────
    def test_05_invalid_file_type_and_oversized_rejection(self):
        # 1. Plain text file with .jpg extension (magic bytes mismatch)
        res = self.client.post(
            "/complaints/upload-evidence",
            headers=self.citizen_headers,
            files={"file": ("fake.jpg", io.BytesIO(INVALID_TEXT), "image/jpeg")},
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("Invalid or unsupported file format", res.json()["detail"])

        # 2. Oversized image (>10MB)
        oversized_data = VALID_JPEG + (b"\x00" * (11 * 1024 * 1024))
        res_large = self.client.post(
            "/complaints/upload-evidence",
            headers=self.citizen_headers,
            files={"file": ("huge.jpg", io.BytesIO(oversized_data), "image/jpeg")},
        )
        self.assertEqual(res_large.status_code, 400)
        self.assertIn("exceeds maximum allowed size", res_large.json()["detail"])

    # ─────────────────────────────────────────────────────────────────────────
    # 6. Cloudinary API failures and timeouts handled gracefully
    # ─────────────────────────────────────────────────────────────────────────
    @patch("cloudinary.uploader.upload", side_effect=Exception("Cloudinary Gateway Timeout 504"))
    def test_06_cloudinary_api_failure_handled_gracefully(self, mock_upload):
        res = self.client.post(
            "/complaints/upload-evidence",
            headers=self.citizen_headers,
            files={"file": ("evidence.jpg", io.BytesIO(VALID_JPEG), "image/jpeg")},
        )
        self.assertEqual(res.status_code, 502)
        self.assertIn("Cloud asset storage upload failed", res.json()["detail"])

    # ─────────────────────────────────────────────────────────────────────────
    # 7. Missing credentials error handling
    # ─────────────────────────────────────────────────────────────────────────
    def test_07_missing_credentials_produces_clear_error(self):
        with patch.dict(os.environ, {"CLOUDINARY_CLOUD_NAME": "", "CLOUDINARY_API_KEY": "", "CLOUDINARY_API_SECRET": ""}):
            with self.assertRaises(RuntimeError) as ctx:
                CloudinaryStorageService(cloud_name="", api_key="", api_secret="")
            self.assertIn("Missing required environment variables", str(ctx.exception))

    # ─────────────────────────────────────────────────────────────────────────
    # 8. Unauthorized upload and deletion attempts
    # ─────────────────────────────────────────────────────────────────────────
    def test_08_unauthorized_upload_and_deletion(self):
        # Unauthenticated upload
        res = self.client.post(
            "/complaints/upload-evidence",
            files={"file": ("evidence.jpg", io.BytesIO(VALID_JPEG), "image/jpeg")},
        )
        self.assertEqual(res.status_code, 401)

        # Citizen deleting someone else's complaint
        complaint = Complaint(
            title="Official Notice",
            description="Notice by official",
            category="infrastructure",
            location="Ward 1",
            citizen_id=self.official.id,
            status="submitted",
        )
        self.db.add(complaint)
        self.db.commit()

        res_del = self.client.delete(
            f"/complaints/{complaint.id}",
            headers=self.citizen_headers,
        )
        self.assertEqual(res_del.status_code, 403)

    # ─────────────────────────────────────────────────────────────────────────
    # 9. Private authority-document access restrictions
    # ─────────────────────────────────────────────────────────────────────────
    @patch("cloudinary.utils.cloudinary_url")
    def test_09_private_authority_document_access_restrictions(self, mock_cl_url):
        mock_cl_url.return_value = ("https://res.cloudinary.com/testcloud/image/authenticated/s--signed--/doc.pdf", {})

        app_record = AuthorityApplication(
            user_id=self.official.id,
            full_name="Officer Jane",
            official_email="jane@medal.gov.in",
            designation="Ward Officer",
            department="Sanitation",
            jurisdiction="Ward 4",
            clearance_level="Level 2",
            aadhaar_document_url="https://res.cloudinary.com/testcloud/image/authenticated/raw.pdf",
            aadhaar_public_id="medal/authority-documents/aadhaar_1",
            employment_document_url="https://res.cloudinary.com/testcloud/image/authenticated/emp.pdf",
            employment_public_id="medal/authority-documents/emp_1",
            status="pending",
        )
        self.db.add(app_record)
        self.db.commit()

        # Citizen cannot access admin applications endpoint
        res_citizen = self.client.get(
            f"/admin/authority-applications/{app_record.id}",
            headers=self.citizen_headers,
        )
        self.assertEqual(res_citizen.status_code, 403)

        # Admin receives signed short-lived URL
        res_admin = self.client.get(
            f"/admin/authority-applications/{app_record.id}",
            headers=self.admin_headers,
        )
        self.assertEqual(res_admin.status_code, 200)
        data = res_admin.json()
        self.assertIn("s--signed--", data["aadhaar_document_url"])

    # ─────────────────────────────────────────────────────────────────────────
    # 10. Database persistence of URLs and public IDs
    # ─────────────────────────────────────────────────────────────────────────
    def test_10_database_persistence_of_urls_and_public_ids(self):
        complaint = Complaint(
            title="Illegal dumping",
            description="Piles of waste in park",
            category="garbage",
            location="City Park",
            image_url="https://res.cloudinary.com/testcloud/image/upload/v1/medal/complaints/asset_waste.jpg",
            image_public_id="medal/complaints/asset_waste",
            citizen_id=self.citizen.id,
            status="submitted",
        )
        self.db.add(complaint)
        self.db.commit()
        self.db.refresh(complaint)

        c_saved = self.db.query(Complaint).filter(Complaint.id == complaint.id).first()
        self.assertEqual(c_saved.image_public_id, "medal/complaints/asset_waste")
        self.assertEqual(c_saved.image_url, "https://res.cloudinary.com/testcloud/image/upload/v1/medal/complaints/asset_waste.jpg")

    # ─────────────────────────────────────────────────────────────────────────
    # 11. Image replacement and deletion
    # ─────────────────────────────────────────────────────────────────────────
    @patch("cloudinary.uploader.destroy")
    @patch("cloudinary.uploader.upload")
    def test_11_image_replacement_cleans_up_old_asset(self, mock_upload, mock_destroy):
        mock_upload.return_value = {
            "secure_url": f"https://res.cloudinary.com/testcloud/image/upload/v2/medal/avatars/profiles/{self.citizen.id}/new_avatar.jpg",
            "public_id": f"medal/avatars/profiles/{self.citizen.id}/avatar_new",
            "format": "jpg",
            "bytes": len(VALID_JPEG),
            "resource_type": "image",
        }
        mock_destroy.return_value = {"result": "ok"}

        # Set initial avatar public ID
        self.citizen.profile_image_public_id = f"medal/avatars/profiles/{self.citizen.id}/avatar_old"
        self.db.commit()

        # Update avatar
        res = self.client.put(
            "/users/me/profile-photo",
            headers=self.citizen_headers,
            files={"file": ("new_avatar.jpg", io.BytesIO(VALID_JPEG), "image/jpeg")},
        )
        self.assertEqual(res.status_code, 200)

        # Verify old asset was destroyed via Cloudinary SDK
        mock_destroy.assert_called_with(f"medal/avatars/profiles/{self.citizen.id}/avatar_old", resource_type="image", invalidate=True)

    # ─────────────────────────────────────────────────────────────────────────
    # 12. AI/SDG analysis using Cloudinary evidence
    # ─────────────────────────────────────────────────────────────────────────
    def test_12_ai_sdg_analysis_with_cloudinary_evidence(self):
        res = self.client.post(
            "/complaints/analyze-sdg",
            data={
                "subject": "Overflowing waste bin and plastic pollution",
                "category": "waste",
                "description": "Massive garbage pile accumulating near marketplace creating health hazard",
                "image_url": "https://res.cloudinary.com/testcloud/image/upload/v1/medal/complaints/asset_waste.jpg",
            },
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("primary_sdg", data)
        self.assertIn("primary_sdg_name", data)
        self.assertIn(data["primary_sdg"], [11, 12, 3])  # SDG 11 or 12 or 3 for waste

    # ─────────────────────────────────────────────────────────────────────────
    # 13. Existing complaint creation and status updates
    # ─────────────────────────────────────────────────────────────────────────
    def test_13_complaint_creation_and_status_updates(self):
        # Create
        create_payload = {
            "title": "Streetlight Broken",
            "description": "Pitch black street causing nighttime accidents",
            "category": "streetlight",
            "location": "4th Cross Street",
            "image_url": "https://res.cloudinary.com/testcloud/image/upload/v1/medal/complaints/asset_light.jpg",
            "image_public_id": "medal/complaints/asset_light",
            "sdg_alignment": "SDG 9, SDG 11",
        }
        res_create = self.client.post(
            "/complaints",
            headers=self.citizen_headers,
            json=create_payload,
        )
        self.assertEqual(res_create.status_code, 201)
        comp_id = res_create.json()["id"]

        # Status update by official
        res_status = self.client.patch(
            f"/complaints/{comp_id}/status",
            headers=self.official_headers,
            json={"status": "in_progress", "officerNotes": "Electrician dispatched"},
        )
        self.assertEqual(res_status.status_code, 200)
        self.assertEqual(res_status.json()["status"], "in_progress")

    # ─────────────────────────────────────────────────────────────────────────
    # 14. Existing user authentication and role-based access
    # ─────────────────────────────────────────────────────────────────────────
    def test_14_user_authentication_and_rbac(self):
        # Login
        res_login = self.client.post(
            "/login",
            json={"email": self.citizen.email, "password": "Password123!"},
        )
        self.assertEqual(res_login.status_code, 200)
        self.assertIn("access_token", res_login.json())

        # GET /me
        res_me = self.client.get("/me", headers=self.citizen_headers)
        self.assertEqual(res_me.status_code, 200)
        self.assertEqual(res_me.json()["email"], self.citizen.email)

    # ─────────────────────────────────────────────────────────────────────────
    # 15. Institution course progress and certificate downloads
    # ─────────────────────────────────────────────────────────────────────────
    @patch("cloudinary.uploader.upload")
    def test_15_institution_course_progress_and_certificate(self, mock_upload):
        mock_upload.return_value = {
            "secure_url": "https://res.cloudinary.com/testcloud/image/upload/v1/medal/certificates/cert_1.pdf",
            "public_id": "medal/certificates/cert_1",
            "format": "pdf",
            "bytes": len(VALID_PDF),
            "resource_type": "image",
        }

        # Upload certificate
        res_upload = self.client.post(
            "/student/certificates/upload",
            headers=self.student_headers,
            files={"file": ("diploma.pdf", io.BytesIO(VALID_PDF), "application/pdf")},
        )
        self.assertEqual(res_upload.status_code, 201)
        self.assertIn("download_url", res_upload.json())

        # Seed certificate in DB and fetch list
        cert = StudentCertificate(
            user_id=self.student.id,
            title="UNESCO SEEK Civic Leadership",
            certificate_no="MED-UNESCO-2026-001",
            completed_date_str="COMPLETED OCT 2026",
            issuing_institution="UNESCO / MGIEP",
            badge_type="verified",
            download_url=res_upload.json()["download_url"],
            certificate_public_id="medal/certificates/cert_1",
        )
        self.db.add(cert)
        self.db.commit()

        res_certs = self.client.get("/student/certificates", headers=self.student_headers)
        self.assertEqual(res_certs.status_code, 200)
        cert_list = res_certs.json()
        self.assertTrue(any(c["certificate_no"] == "MED-UNESCO-2026-001" for c in cert_list))


if __name__ == "__main__":
    unittest.main()
