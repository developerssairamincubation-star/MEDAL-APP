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

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger("medal.admin")


@router.get(
    "/authority-applications",
    response_model=List[AuthorityApplicationResponse],
    status_code=status.HTTP_200_OK,
)
def list_authority_applications(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by pending, approved, rejected, or all"),
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_role("admin")),
):
    """
    List authority registration applications for Admin review.
    Accessible only by authenticated Admins.
    """
    query = db.query(AuthorityApplication)
    if status_filter and status_filter.lower() != "all":
        query = query.filter(AuthorityApplication.status == status_filter.lower().strip())
    
    applications = query.order_by(AuthorityApplication.id.desc()).all()
    return applications


@router.get(
    "/authority-applications/{application_id}",
    response_model=AuthorityApplicationResponse,
    status_code=status.HTTP_200_OK,
)
def get_authority_application(
    application_id: int,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_role("admin")),
):
    """
    Retrieve full application details, identity document URLs, and official credentials.
    Accessible only by authenticated Admins.
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
    return application


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
