import io
import uuid
import mimetypes
from fastapi.testclient import TestClient
from main import app
from app.services.storage import get_storage_service, MinioStorageService
from app.database.database import get_db
from app.models.complaint import Complaint

client = TestClient(app)

def run_verification():
    print("=" * 70)
    print("RUNNING COMPREHENSIVE PHOTO UPLOAD & MINIO VERIFICATION")
    print("=" * 70)

    # 1. Register & Login test citizen
    uid = uuid.uuid4().hex[:8]
    email = f"photo_tester_{uid}@medal.app"
    password = "TestPassword123!"

    print(f"\n[1] Registering citizen: {email}")
    reg_res = client.post("/register", json={
        "email": email,
        "password": password,
        "full_name": "Photo Test Citizen",
        "phone": "9876543210"
    })
    assert reg_res.status_code == 201, f"Registration failed: {reg_res.text}"
    print(f"  -> Citizen registered successfully")

    login_res = client.post("/login", json={"email": email, "password": password})
    assert login_res.status_code == 200, f"Login failed: {login_res.text}"
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print(f"  -> JWT Token acquired")

    # 2. Test uploading standard image/jpeg
    print("\n[2] Testing POST /complaints/upload-evidence with image/jpeg...")
    sample_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00MEDAL_JPEG_EVIDENCE"
    res_jpeg = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("evidence_road.jpg", io.BytesIO(sample_jpeg), "image/jpeg")}
    )
    assert res_jpeg.status_code == 200, f"Upload image/jpeg failed: {res_jpeg.text}"
    jpeg_url = res_jpeg.json().get("image_url")
    print(f"  -> PASS: image/jpeg uploaded. URL: {jpeg_url}")

    # 3. Test uploading standard image/png
    print("\n[3] Testing POST /complaints/upload-evidence with image/png...")
    sample_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4"
    res_png = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("evidence_street.png", io.BytesIO(sample_png), "image/png")}
    )
    assert res_png.status_code == 200, f"Upload image/png failed: {res_png.text}"
    png_url = res_png.json().get("image_url")
    print(f"  -> PASS: image/png uploaded. URL: {png_url}")

    # 4. Test uploading with octet-stream MIME (fallback by filename extension)
    print("\n[4] Testing POST /complaints/upload-evidence with application/octet-stream + .jpg filename...")
    res_fallback = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("evidence_pothole.jpg", io.BytesIO(sample_jpeg), "application/octet-stream")}
    )
    assert res_fallback.status_code == 200, f"Upload fallback failed: {res_fallback.text}"
    fallback_url = res_fallback.json().get("image_url")
    print(f"  -> PASS: octet-stream with .jpg filename accepted. URL: {fallback_url}")

    # 5. Test rejecting non-image files (PDF / TXT)
    print("\n[5] Testing POST /complaints/upload-evidence rejection of non-images...")
    res_pdf = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("document.pdf", io.BytesIO(b"%PDF-1.4..."), "application/pdf")}
    )
    assert res_pdf.status_code == 400, f"PDF should be rejected: {res_pdf.status_code}"
    print(f"  -> PASS: PDF rejected with 400 ({res_pdf.json()['detail']})")

    res_txt = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("notes.txt", io.BytesIO(b"Hello world"), "text/plain")}
    )
    assert res_txt.status_code == 400, f"TXT should be rejected: {res_txt.status_code}"
    print(f"  -> PASS: TXT rejected with 400 ({res_txt.json()['detail']})")

    # 6. Verify objects directly in MinIO container
    print("\n[6] Verifying objects in MinIO bucket 'medal-evidence/reports/'...")
    storage = get_storage_service()
    if isinstance(storage, MinioStorageService):
        # Extract object name from URL
        for test_url, label in [(jpeg_url, "JPEG"), (png_url, "PNG"), (fallback_url, "Fallback JPEG")]:
            obj_name = "reports/" + test_url.split("/reports/")[1]
            stat = storage.client.stat_object(storage.bucket_name, obj_name)
            assert stat.size > 0, f"Object {obj_name} is empty"
            print(f"  -> PASS: Verified {label} object '{obj_name}' in MinIO (Size: {stat.size} bytes, Content-Type: {stat.content_type})")
    else:
        print(f"  -> Storage service is {type(storage).__name__}")

    # 7. Create Complaint with evidence URL and verify storage in PostgreSQL
    print("\n[7] Creating complaint in PostgreSQL with evidence URL...")
    complaint_payload = {
        "title": f"Verified Pothole on 5th Main Road {uid}",
        "description": "Large deep pothole causing traffic obstruction and accident risk.",
        "category": "road",
        "location": "5th Main Road, Ward 14",
        "image_url": jpeg_url,
        "sdg_alignment": "SDG 11: Sustainable Cities and Communities",
        "impact_level": "High",
        "equity_classification": "Standard Urban Zone"
    }
    comp_res = client.post("/complaints", headers=headers, json=complaint_payload)
    assert comp_res.status_code == 201, f"Complaint creation failed: {comp_res.text}"
    comp_data = comp_res.json()
    complaint_id = comp_data["id"]
    saved_img_url = comp_data.get("image_url")
    assert saved_img_url == jpeg_url, f"Expected {jpeg_url}, got {saved_img_url}"
    print(f"  -> PASS: Complaint #{complaint_id} created with image_url: {saved_img_url}")

    # 8. Query complaint back via GET /complaints/{id}
    print(f"\n[8] Querying complaint #{complaint_id} from PostgreSQL...")
    get_res = client.get(f"/complaints/{complaint_id}", headers=headers)
    assert get_res.status_code == 200, f"Failed to get complaint: {get_res.text}"
    fetched = get_res.json()
    assert fetched["image_url"] == jpeg_url
    print(f"  -> PASS: PostgreSQL confirmed complaint #{complaint_id} image_url = {fetched['image_url']}")

    print("\n" + "=" * 70)
    print("ALL VERIFICATIONS COMPLETED SUCCESSFULLY!")
    print("=" * 70)

if __name__ == "__main__":
    run_verification()
