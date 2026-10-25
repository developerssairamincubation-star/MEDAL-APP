"""
Verification of Comment Image/Photo Attachment Flow:
1. Register & authenticate citizen.
2. Create complaint.
3. Post text-only comment -> verify image_url is None.
4. Upload comment photo evidence -> verify valid image_url returned.
5. Post comment with image_url -> verify image_url persisted and returned.
6. Post threaded reply with image_url -> verify reply has image_url.
7. Retrieve comments list -> verify image_url is present on photo comments and None on text-only.
8. Test upload failure when non-image file is uploaded -> verify 400 Bad Request.
9. Soft-delete comment -> verify image_url is masked to None.
"""

import io
import uuid
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_comment_photo_flow():
    print("=" * 65)
    print("STARTING COMMENT PHOTO ATTACHMENT & PERSISTENCE TESTS")
    print("=" * 65)

    # 1. Register citizen
    uid = uuid.uuid4().hex[:8]
    email = f"user_{uid}@medal.app"
    pwd = "TestPassword123!"

    r_reg = client.post("/register", json={
        "email": email,
        "password": pwd,
        "full_name": "Test Citizen",
        "phone": "9841009999",
    })
    assert r_reg.status_code == 201
    token = client.post("/login", json={"email": email, "password": pwd}).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("  -> PASS: User registered and authenticated")

    # 2. Create complaint
    r_comp = client.post("/complaints", headers=headers, json={
        "title": "Pothole on Main Road",
        "description": "Deep pothole causing hazards near the bus stop.",
        "category": "road",
        "location": "Main Road, Sector 3",
    })
    assert r_comp.status_code == 201
    complaint_id = r_comp.json()["id"]
    print(f"  -> PASS: Complaint #{complaint_id} created")

    # 3. Post text-only comment
    r_text_comm = client.post(
        f"/complaints/{complaint_id}/comments",
        headers=headers,
        json={"comment": "I noticed this yesterday as well."},
    )
    assert r_text_comm.status_code == 201
    text_data = r_text_comm.json()
    assert text_data["comment"] == "I noticed this yesterday as well."
    assert text_data.get("image_url") is None
    text_comment_id = text_data["id"]
    print(f"  -> PASS: Text-only comment #{text_comment_id} created with image_url=None")

    # 4. Upload photo evidence
    fake_image_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb"
    r_upload = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("comment_evidence.jpg", io.BytesIO(fake_image_bytes), "image/jpeg")},
    )
    assert r_upload.status_code == 200, f"Upload failed: {r_upload.text}"
    uploaded_url = r_upload.json()["image_url"]
    assert uploaded_url, "Upload did not return image_url"
    print(f"  -> PASS: Photo uploaded to storage successfully: {uploaded_url}")

    # 5. Post comment with image
    r_photo_comm = client.post(
        f"/complaints/{complaint_id}/comments",
        headers=headers,
        json={
            "comment": "Here is a close-up picture of the damage.",
            "image_url": uploaded_url,
        },
    )
    assert r_photo_comm.status_code == 201
    photo_data = r_photo_comm.json()
    assert photo_data["comment"] == "Here is a close-up picture of the damage."
    assert photo_data["image_url"] == uploaded_url
    photo_comment_id = photo_data["id"]
    print(f"  -> PASS: Comment #{photo_comment_id} created with image_url persisted")

    # 6. Post threaded reply with image
    r_reply = client.post(
        f"/complaints/{complaint_id}/comments",
        headers=headers,
        json={
            "comment": "Here is an updated photo taken this morning.",
            "parent_comment_id": photo_comment_id,
            "image_url": uploaded_url,
        },
    )
    assert r_reply.status_code == 201
    reply_data = r_reply.json()
    assert reply_data["parent_comment_id"] == photo_comment_id
    assert reply_data["image_url"] == uploaded_url
    reply_id = reply_data["id"]
    print(f"  -> PASS: Threaded reply #{reply_id} created with image_url persisted")

    # 7. List comments
    r_list = client.get(f"/complaints/{complaint_id}/comments")
    assert r_list.status_code == 200
    all_comms = r_list.json()
    assert len(all_comms) == 3

    comm_map = {c["id"]: c for c in all_comms}
    assert comm_map[text_comment_id]["image_url"] is None
    assert comm_map[photo_comment_id]["image_url"] == uploaded_url
    assert comm_map[reply_id]["image_url"] == uploaded_url
    print("  -> PASS: GET /complaints/{id}/comments correctly returns image_url for photo comments and None for text-only")

    # 8. Test invalid file rejection (e.g. non-image)
    r_bad_upload = client.post(
        "/complaints/upload-evidence",
        headers=headers,
        files={"file": ("malicious.exe", io.BytesIO(b"MZ\x90\x00"), "application/x-msdownload")},
    )
    assert r_bad_upload.status_code == 400
    print("  -> PASS: Non-image file upload rejected with 400 Bad Request")

    # 9. Test soft-deletion hides image_url
    # photo_comment_id has reply_id, so deleting it performs soft-delete
    r_del = client.delete(f"/complaints/{complaint_id}/comments/{photo_comment_id}", headers=headers)
    assert r_del.status_code == 200
    r_list_after_del = client.get(f"/complaints/{complaint_id}/comments")
    comm_map_after = {c["id"]: c for c in r_list_after_del.json()}
    assert comm_map_after[photo_comment_id]["is_deleted"] is True
    assert comm_map_after[photo_comment_id]["image_url"] is None
    print("  -> PASS: Soft-deleted comment image_url masked to None")

    print("\n" + "=" * 65)
    print("ALL COMMENT PHOTO TESTS PASSED 100%!")
    print("=" * 65)


if __name__ == "__main__":
    test_comment_photo_flow()
