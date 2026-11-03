"""Self-contained check (SQLite + TestClient, geocoder stubbed, no network):
new posts store a readable place name while keeping coordinates, and the feed /
detail responses include the complainant's name and role.

Run:  python -m pytest test_location_geocoding_local.py
"""
import os
import tempfile

os.environ.setdefault("DATABASE_URL", f"sqlite:///{tempfile.mkdtemp()}/medal_test.db")
os.environ.setdefault("SECRET_KEY", "test-secret")
os.environ.setdefault("CLOUDINARY_CLOUD_NAME", "test")
os.environ.setdefault("CLOUDINARY_API_KEY", "test")
os.environ.setdefault("CLOUDINARY_API_SECRET", "test")

from fastapi.testclient import TestClient

import main
import app.routers.complaint as complaint_router
from app.database.database import Base, engine
from app.services.geocoding import looks_like_coordinates, parse_coordinates

PLACE = "Gandhipuram, Coimbatore, Tamil Nadu"


def test_coordinate_detection():
    assert looks_like_coordinates("Lat: 11.016800, Lng: 76.955800")
    assert looks_like_coordinates("11.0168, 76.9558")
    assert looks_like_coordinates(None)
    assert not looks_like_coordinates("Bharathiyar Road, Coimbatore")
    assert parse_coordinates("Lat: 11.0168, Lng: 76.9558") == (11.0168, 76.9558)


def test_post_gets_place_name_and_complainant_info(monkeypatch):
    monkeypatch.setattr(complaint_router, "reverse_geocode", lambda lat, lng: PLACE)
    Base.metadata.create_all(engine)
    client = TestClient(main.app)

    client.post("/register", json={"email": "cit@example.com", "password": "Password123!", "full_name": "Asha Citizen"})
    token = client.post("/login", json={"email": "cit@example.com", "password": "Password123!"}).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    for address in ("Lat: 11.016800, Lng: 76.955800", None):
        body = {
            "title": "Pothole", "description": "Big pothole", "category": "road",
            "location": "Lat: 11.016800, Lng: 76.955800", "latitude": 11.0168, "longitude": 76.9558,
        }
        if address:
            body["location_address"] = address
        created = client.post("/complaints", json=body, headers=headers).json()
        assert created["location"] == PLACE and created["location_address"] == PLACE
        assert created["latitude"] == 11.0168 and created["longitude"] == 76.9558

    feed_item = client.get("/complaints/feed", headers=headers).json()[0]
    assert feed_item["location_address"] == PLACE
    assert feed_item["citizen_name"] == "Asha Citizen" and feed_item["citizen_role"] == "citizen"

    detail = client.get(f"/complaints/{feed_item['id']}", headers=headers).json()
    assert detail["citizen_name"] == "Asha Citizen" and detail["citizen_role"] == "citizen"
