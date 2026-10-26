from datetime import datetime, timezone
import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.authority_application import AuthorityApplication
from app.models.user import User
from app.routers.auth import require_role
from app.schemas.authority import (
    ApproveApplicationRequest,
    AuthorityApplicationResponse,
    RejectApplicationRequest,
)
from app.services.storage import BaseStorageService, get_storage_service

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger("medal.admin")


def _enrich_application_with_signed_urls(
    app: AuthorityApplication,
    storage: BaseStorageService,
) -> AuthorityApplicationResponse:
    """Generates short-lived authorized access URLs for sensitive verification documents."""
    resp = AuthorityApplicationResponse.model_validate(app)
    if app.aadhaar_public_id:
        signed_aadhaar = storage.generate_private_download_url(
            app.aadhaar_public_id,
            resource_type="image",
            expires_in=3600,
        )
        if signed_aadhaar:
            resp.aadhaar_document_url = signed_aadhaar
    if app.employment_public_id:
        signed_emp = storage.generate_private_download_url(
            app.employment_public_id,
            resource_type="image",
            expires_in=3600,
        )
        if signed_emp:
            resp.employment_document_url = signed_emp
    return resp


@router.get(
    "/authority-applications",
    response_model=List[AuthorityApplicationResponse],
    status_code=status.HTTP_200_OK,
)
def list_authority_applications(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by pending, approved, rejected, or all"),
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_role("admin")),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """
    List authority registration applications for Admin review.
    Accessible only by authenticated Admins.
    Generates short-lived authorized URLs for sensitive documents.
    """
    query = db.query(AuthorityApplication)
    if status_filter and status_filter.lower() != "all":
        query = query.filter(AuthorityApplication.status == status_filter.lower().strip())
    
    applications = query.order_by(AuthorityApplication.id.desc()).all()
    return [_enrich_application_with_signed_urls(app, storage) for app in applications]


@router.get(
    "/authority-applications/{application_id}",
    response_model=AuthorityApplicationResponse,
    status_code=status.HTTP_200_OK,
)
def get_authority_application(
    application_id: int,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_role("admin")),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """
    Retrieve full application details, identity document URLs, and official credentials.
    Accessible only by authenticated Admins.
    Generates short-lived authorized URLs for sensitive documents.
    """
    application = (
        db.query(AuthorityApplication)
        .filter(AuthorityApplication.id == application_id)
        .first()
    )
    if not application:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Authority application #{application_id} not found.",
        )
    return _enrich_application_with_signed_urls(application, storage)


@router.post(
    "/authority-applications/{application_id}/approve",
    status_code=status.HTTP_200_OK,
)
def approve_authority_application(
    application_id: int,
    req: Optional[ApproveApplicationRequest] = None,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_role("admin")),
):
    """
    Approve an Authority application and onboard the officer into the system.
    Updates the linked user account to approved official status and sets designated clearance level.
    """
    application = (
        db.query(AuthorityApplication)
        .filter(AuthorityApplication.id == application_id)
        .first()
    )
    if not application:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Authority application #{application_id} not found.",
        )

    # Update clearance level if provided by Admin
    if req and req.clearance_level and req.clearance_level.strip():
        application.clearance_level = req.clearance_level.strip()

    now = datetime.now(timezone.utc)
    application.status = "approved"
    application.rejection_reason = None
    application.reviewed_by_id = current_admin.id
    application.reviewed_at = now

    # Update linked User record
    user = db.query(User).filter(User.id == application.user_id).first()
    if user:
        user.approval_status = "approved"
        user.role = "official"
        user.is_verified = True
        user.clearance_level = application.clearance_level
        user.designation = application.designation
        user.department = application.department
        user.jurisdiction = application.jurisdiction

    db.commit()
    db.refresh(application)

    return {
        "message": f"Officer {application.full_name} onboarded and approved successfully.",
        "application": AuthorityApplicationResponse.model_validate(application),
    }


@router.post(
    "/authority-applications/{application_id}/reject",
    status_code=status.HTTP_200_OK,
)
def reject_authority_application(
    application_id: int,
    req: RejectApplicationRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_role("admin")),
):
    """
    Reject an Authority application with a specified administrative reason.
    Updates the linked user account to rejected status.
    """
    application = (
        db.query(AuthorityApplication)
        .filter(AuthorityApplication.id == application_id)
        .first()
    )
    if not application:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Authority application #{application_id} not found.",
        )

    reason = req.reason.strip()
    now = datetime.now(timezone.utc)
    application.status = "rejected"
    application.rejection_reason = reason
    application.reviewed_by_id = current_admin.id
    application.reviewed_at = now

    # Update linked User record
    user = db.query(User).filter(User.id == application.user_id).first()
    if user:
        user.approval_status = "rejected"

    db.commit()
    db.refresh(application)

    return {
        "message": f"Authority application #{application_id} for {application.full_name} rejected.",
        "application": AuthorityApplicationResponse.model_validate(application),
    }
