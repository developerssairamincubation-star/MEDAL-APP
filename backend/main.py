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
from app.routers.institution import router as institution_router
from app.routers.officials import router as officials_router

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
app.include_router(officials_router)
app.include_router(institution_router)

from app.services.seek_chapters import init_chapters


@app.on_event("startup")
def _load_seek_chapters():
    init_chapters()


@app.get("/")
def read_root():
    return {"message": "MEDAL Backend is running"}


@app.api_route("/health", methods=["GET", "HEAD"])
def health_check():
    """Lightweight liveness probe for uptime pingers / keep-warm cron.

    Does no database or storage I/O so it answers instantly once the process is up.
    """
    return {"status": "ok", "service": "MEDAL API"}


@app.get("/health/storage")
def storage_health_check(deep: bool = False):
    """Checks storage configuration. With ?deep=true it also makes an authenticated
    Cloudinary call, which reveals invalid/mismatched API credentials."""
    try:
        storage = get_storage_service()
        storage_health = storage.check_health()
        if deep and storage_health.get("status") == "healthy" and hasattr(storage, "check_connection"):
            storage_health = {**storage_health, **storage.check_connection()}
    except Exception as e:
        storage_health = {"status": "unhealthy", "error": str(e)}

    return {
        "status": "ok" if storage_health.get("status") == "healthy" else "degraded",
        "service": "MEDAL API",
        "storage": storage_health,
    }
