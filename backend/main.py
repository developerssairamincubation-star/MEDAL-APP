import os
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routers.auth import router as auth_router
from app.routers.complaint import router as complaint_router
from app.routers.authority import router as authority_router
from app.routers.admin import router as admin_router
from app.routers.student import router as student_router

app = FastAPI(title="MEDAL API", version="1.0.0")

# Enable CORS for Flutter app communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static file serving for uploads (evidence/images)
uploads_dir = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

from app.services.storage import get_storage_service

app.include_router(auth_router)
app.include_router(complaint_router)
app.include_router(authority_router)
app.include_router(admin_router)
app.include_router(student_router)


@app.get("/")
def read_root():
    return {"message": "MEDAL Backend is running"}


@app.get("/health")
def health_check():
    """Lightweight connectivity check — verifies backend and storage readiness."""
    try:
        storage = get_storage_service()
        storage_health = storage.check_health()
    except Exception as e:
        storage_health = {"status": "unhealthy", "error": str(e)}

    return {
        "status": "ok" if storage_health.get("status") == "healthy" else "degraded",
        "service": "MEDAL API",
        "storage": storage_health,
    }
