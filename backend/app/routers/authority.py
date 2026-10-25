from datetime import datetime, timezone
import logging
import mimetypes
import os
from typing import Optional
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from pydantic import EmailStr
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.authority_application import AuthorityApplication
from app.models.user import User
from app.schemas.authority import (
    AuthorityApplicationResponse,
    AuthorityRegisterRequest,
    AuthorityRegisterResponse,
    DocumentUploadResponse,
)
from app.services.storage import BaseStorageService, get_storage_service
from app.utils.security import hash_password

router = APIRouter(prefix="/authority", tags=["Authority"])
logger = logging.getLogger("medal.authority")

ALLOWED_DOC_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".webp"}
MAX_DOC_SIZE_BYTES = 15 * 1024 * 1024  # 15 MB limit


@router.post(
    "/upload-document",
    response_model=DocumentUploadResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_authority_document(
    file: UploadFile = File(...),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """
    Secure document upload endpoint for Authority onboarding (Aadhaar, Gazette, Official ID).
    Stores documents under verification/ folder in object storage.
    """
    filename = file.filename or "document.pdf"
    ext = os.path.splitext(filename)[1].lower()

    if ext not in ALLOWED_DOC_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file extension '{ext}'. Allowed types: PDF, PNG, JPG, JPEG, WEBP.",
        )

    # Read bytes and check size
    contents = await file.read()
    if len(contents) > MAX_DOC_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File exceeds maximum allowed size of 15MB.",
        )

    # Reset cursor for storage provider upload
    await file.seek(0)

    try:
        doc_url = await storage.upload_file(file, folder="verification")
    except Exception as e:
        logger.error(f"Failed to upload authority document: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to store document in storage service.",
        )

    return DocumentUploadResponse(
        message="Document uploaded successfully",
        document_url=doc_url,
        filename=filename,
    )


@router.post(
    "/register",
    response_model=AuthorityRegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_authority(
    req: AuthorityRegisterRequest,
    db: Session = Depends(get_db),
):
    """
    Submit an Authority registration application with verified document references.
    Creates an inactive/unapproved user with pending status awaiting Admin review.
    """
    normalized_email = req.official_email.strip().lower()

    # Prevent duplicate registration with same email
    existing_user = db.query(User).filter(User.email == normalized_email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Official email is already registered in the system.",
        )

    # Create new user with official role and pending approval status
    hashed = hash_password(req.password)
    new_user = User(
        email=normalized_email,
        password_hash=hashed,
        full_name=req.full_name.strip(),
        phone=req.official_phone.strip() if req.official_phone else None,
        role="official",
        approval_status="pending",
        designation=req.designation.strip(),
        department=req.department.strip(),
        jurisdiction=req.jurisdiction.strip(),
        clearance_level=req.clearance_level.strip(),
        is_verified=False,
        is_active=True,
    )
    db.add(new_user)
    db.flush()

    # Create AuthorityApplication record
    application = AuthorityApplication(
        user_id=new_user.id,
        full_name=req.full_name.strip(),
        official_email=normalized_email,
        official_phone=req.official_phone.strip() if req.official_phone else None,
        designation=req.designation.strip(),
        department=req.department.strip(),
        jurisdiction=req.jurisdiction.strip(),
        identity_number=req.identity_number.strip() if req.identity_number else None,
        clearance_level=req.clearance_level.strip(),
        aadhaar_document_url=req.aadhaar_document_url.strip(),
        employment_document_url=req.employment_document_url.strip(),
        status="pending",
    )
    db.add(application)
    db.commit()
    db.refresh(application)

    ref_id = f"AUTH-REV-2026-{application.id:04d}"

    return AuthorityRegisterResponse(
        message="Authority application submitted successfully. Awaiting administrative review.",
        reference_id=ref_id,
        status="pending",
        data=AuthorityApplicationResponse.model_validate(application),
    )


@router.get("/application-status")
def get_application_status(
    email: EmailStr = Query(..., description="Official email address used during registration"),
    db: Session = Depends(get_db),
):
    """
    Check current status of an Authority onboarding application.
    """
    normalized_email = email.strip().lower()
    app_record = (
        db.query(AuthorityApplication)
        .filter(AuthorityApplication.official_email == normalized_email)
        .order_by(AuthorityApplication.id.desc())
        .first()
    )

    if not app_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No authority application found for the provided email.",
        )

    return {
        "email": normalized_email,
        "status": app_record.status,
        "reference_id": f"AUTH-REV-2026-{app_record.id:04d}",
        "full_name": app_record.full_name,
        "designation": app_record.designation,
        "department": app_record.department,
        "clearance_level": app_record.clearance_level,
        "rejection_reason": app_record.rejection_reason if app_record.status == "rejected" else None,
        "submitted_at": app_record.created_at,
        "reviewed_at": app_record.reviewed_at,
    }
