import os
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routers.auth import router as auth_router
from app.routers.complaint import router as complaint_router

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

app.include_router(auth_router)
app.include_router(complaint_router)


@app.get("/")
def read_root():
    return {"message": "MEDAL Backend is running"}


@app.get("/health")
def health_check():
    """Lightweight connectivity check — use this to verify backend is reachable from the phone."""
    return {"status": "ok", "service": "MEDAL API"}
