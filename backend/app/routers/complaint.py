import json
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile, status
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload, selectinload

from app.database.database import get_db
from app.models.complaint import Complaint, ComplaintComment, ComplaintRepost, ComplaintUpvote
from app.models.user import User
from app.routers.auth import get_current_user, get_optional_current_user, require_role
from app.schemas.complaint import (
    CommentCreate,
    CommentResponse,
    ComplaintCreate,
    ComplaintFeedItem,
    ComplaintResponse,
    ComplaintStatsResponse,
    ComplaintStatusUpdate,
    ComplaintUpdate,
    EvidenceUploadResponse,
    RepostResponse,
    SdgAnalysisResponse,
    UpvoteResponse,
)
from app.services.ai_sdg_service import AiSdgService
from app.services.geocoding import looks_like_coordinates, reverse_geocode
from app.services.storage import BaseStorageService, get_storage_service
from app.utils.file_validation import (
    MAX_IMAGE_SIZE_BYTES,
    validate_and_read_upload,
)

router = APIRouter(prefix="/complaints", tags=["Complaints"])


VALID_STATUSES = {"submitted", "under_review", "assigned", "in_progress", "resolved", "rejected"}
VALID_CATEGORIES = {
    "road", "garbage", "waste", "water", "streetlight", "drainage",
    "health", "education", "sanitation", "infrastructure", "environment", "other"
}

ENVIRONMENTAL_CATEGORIES = [
    "environment",
    "environmental",
    "environment_&_greenery",
    "garbage",
    "garbage_&_solid_waste",
    "waste",
    "sanitation",
    "health_&_sanitation",
]

INFRASTRUCTURE_CATEGORIES = [
    "infrastructure",
    "road",
    "road_&_potholes",
    "streetlight",
    "streetlight_&_lighting",
    "drainage",
    "drainage_&_sewage",
    "educational_infrastructure",
]


import mimetypes


@router.post("/upload-evidence", response_model=EvidenceUploadResponse, status_code=status.HTTP_200_OK)
async def upload_evidence(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """
    Secure complaint evidence upload to Cloudinary.
    Validates file size (max 10MB) and inspects magic bytes.
    Saves under medal/complaints with safe, unguessable public IDs.
    """
    contents, verified_mime, ext = await validate_and_read_upload(
        file=file,
        allowed_types={"image/*"},
        max_size_bytes=MAX_IMAGE_SIZE_BYTES,
    )

    upload_result = await storage.upload_bytes(
        data=contents,
        filename=file.filename or f"evidence{ext}",
        folder="medal/complaints",
        content_type=verified_mime,
    )

    return EvidenceUploadResponse(
        image_url=upload_result.secure_url,
        public_id=upload_result.public_id,
        format=upload_result.format,
        bytes=upload_result.bytes,
    )


@router.post("/analyze-sdg", response_model=SdgAnalysisResponse, status_code=status.HTTP_200_OK)
async def analyze_complaint_sdg(
    request: Request,
    subject: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    evidence: Optional[UploadFile] = File(None),
    image_url: Optional[str] = Form(None),
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    """
    AI-powered SDG evaluation endpoint.
    Analyzes subject, category, detailed description, and optional evidence image
    to recommend United Nations Sustainable Development Goals (SDG 1 - 17).
    """
    # Gracefully accept application/json if provided
    content_type_header = request.headers.get("content-type", "")
    if content_type_header.startswith("application/json"):
        try:
            body = await request.json()
            if isinstance(body, dict):
                subject = body.get("subject", subject) or ""
                category = body.get("category", category) or ""
                description = body.get("description", description) or ""
                image_url = body.get("image_url", image_url)
        except Exception:
            pass

    subject_val = (subject or "").strip()
    category_val = (category or "").strip()
    description_val = (description or "").strip()

    if not description_val:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Description is required for SDG evaluation.",
        )

    image_bytes: Optional[bytes] = None
    mime_type = "image/jpeg"

    if evidence is not None and evidence.filename:
        c_type = evidence.content_type
        if not c_type or c_type in ("application/octet-stream", "application/octetstream", "binary/octet-stream"):
            guessed_type, _ = mimetypes.guess_type(evidence.filename or "")
            if guessed_type:
                c_type = guessed_type

        if c_type and not c_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only image files are accepted as evidence",
            )
        image_bytes = await evidence.read()
        mime_type = c_type or "image/jpeg"

    result = await AiSdgService.analyze(
        subject=subject_val,
        category=category_val,
        description=description_val,
        image_bytes=image_bytes,
        mime_type=mime_type,
        image_url=image_url,
    )

    return SdgAnalysisResponse(**result)


@router.post("", response_model=ComplaintResponse, status_code=status.HTTP_201_CREATED)
def create_complaint(
    complaint_in: ComplaintCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new complaint/report for the currently authenticated citizen."""
    location_text = complaint_in.location.strip() if complaint_in.location else (complaint_in.location_address or "")
    location_address = complaint_in.location_address

    # Store a readable place name instead of raw "lat, lng" text; coordinates are kept.
    if (
        complaint_in.latitude is not None
        and complaint_in.longitude is not None
        and looks_like_coordinates(location_address)
    ):
        place_name = reverse_geocode(complaint_in.latitude, complaint_in.longitude)
        if place_name:
            location_address = place_name
            if looks_like_coordinates(location_text):
                location_text = place_name

    mention_payload = None
    if complaint_in.mentions:
        officials = (
            db.query(User)
            .filter(
                User.id.in_(set(complaint_in.mentions)),
                User.role == "official",
                User.approval_status == "approved",
            )
            .all()
        )
        if officials:
            mention_payload = json.dumps(
                [{"id": o.id, "name": o.full_name} for o in officials]
            )

    new_complaint = Complaint(
        mentioned_officials=mention_payload,
        title=complaint_in.title.strip(),
        description=complaint_in.description.strip(),
        category=complaint_in.category.lower().strip(),
        status="submitted",
        location=location_text,
        latitude=complaint_in.latitude,
        longitude=complaint_in.longitude,
        location_address=location_address,
        image_url=complaint_in.image_url,
        image_public_id=complaint_in.image_public_id,
        sdg_alignment=complaint_in.sdg_alignment,
        impact_level=complaint_in.impact_level,
        equity_classification=complaint_in.equity_classification,
        citizen_id=current_user.id,
    )
    db.add(new_complaint)
    db.commit()
    db.refresh(new_complaint)
    return new_complaint



@router.get("", response_model=List[ComplaintResponse], status_code=status.HTTP_200_OK)
def list_complaints(
    status_filter: Optional[str] = Query(None, alias="status"),
    category_filter: Optional[str] = Query(None, alias="category"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    List complaints:
    - Citizens only see their own complaints.
    - Officials and Admins see all complaints with optional filtering.
    """
    query = db.query(Complaint).options(joinedload(Complaint.citizen))

    if current_user.role == "citizen":
        query = query.filter(Complaint.citizen_id == current_user.id)
    else:
        # Officials and Admins can see all complaints
        if status_filter:
            query = query.filter(Complaint.status == status_filter.lower())
        if category_filter:
            query = query.filter(func.lower(Complaint.category) == category_filter.strip().lower())

    complaints = query.order_by(Complaint.created_at.desc()).all()
    return complaints


@router.get("/feed", response_model=List[ComplaintFeedItem], status_code=status.HTTP_200_OK)
def get_community_feed(
    category: Optional[str] = Query(None, alias="category"),
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    """
    Public Community Feed:
    - Returns all active, non-rejected complaints submitted by all citizens.
    - Ordered newest first (created_at desc).
    - Uses eager loading (joinedload & selectinload) to eliminate N+1 queries.
    - Supports limit/offset pagination (default limit=30, offset=0).
    - Includes accurate has_reposted flag when citizen is authenticated.
    - Preserves citizen privacy (only full_name / initials, no phone/email).
    """
    query = (
        db.query(Complaint)
        .options(
            joinedload(Complaint.citizen),
            selectinload(Complaint.upvotes),
            selectinload(Complaint.reposts),
            selectinload(Complaint.comments),
        )
        .filter(Complaint.status != "rejected")
    )

    if category:
        cat_clean = category.strip().lower()
        cat_normalized = cat_clean.replace(" ", "_")
        if cat_clean in ("all", "all reports", "") or cat_normalized in ("all", "all_reports"):
            pass  # Union of all categories — no category restriction
        elif cat_clean in ("environment", "environmental") or cat_normalized in ("environment", "environmental"):
            query = query.filter(func.lower(Complaint.category).in_(ENVIRONMENTAL_CATEGORIES))
        elif cat_clean in ("infrastructure",) or cat_normalized in ("infrastructure",):
            query = query.filter(func.lower(Complaint.category).in_(INFRASTRUCTURE_CATEGORIES))
        elif cat_normalized in ("road", "road_&_potholes"):
            query = query.filter(func.lower(Complaint.category).in_(["road", "road_&_potholes"]))
        elif cat_normalized in ("streetlight", "streetlight_&_lighting"):
            query = query.filter(func.lower(Complaint.category).in_(["streetlight", "streetlight_&_lighting"]))
        elif cat_normalized in ("drainage", "drainage_&_sewage"):
            query = query.filter(func.lower(Complaint.category).in_(["drainage", "drainage_&_sewage"]))
        elif cat_normalized in ("garbage", "garbage_&_solid_waste", "waste"):
            query = query.filter(func.lower(Complaint.category).in_(["garbage", "garbage_&_solid_waste", "waste"]))
        elif cat_normalized in ("water", "water_supply_&_leakage"):
            query = query.filter(func.lower(Complaint.category).in_(["water", "water_supply_&_leakage"]))
        elif cat_normalized in ("workplace_conduct", "workplace"):
            query = query.filter(func.lower(Complaint.category) == "workplace_conduct")
        else:
            query = query.filter(func.lower(Complaint.category) == cat_normalized)

    complaints = (
        query.order_by(Complaint.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    user_reposted_ids = set()
    user_upvoted_ids = set()
    if current_user and complaints:
        complaint_ids = [c.id for c in complaints]
        user_upvoted_ids = set(
            u[0]
            for u in db.query(ComplaintUpvote.complaint_id)
            .filter(
                ComplaintUpvote.user_id == current_user.id,
                ComplaintUpvote.complaint_id.in_(complaint_ids),
            )
            .all()
        )
        user_reposted_ids = set(
            r[0]
            for r in db.query(ComplaintRepost.complaint_id)
            .filter(
                ComplaintRepost.user_id == current_user.id,
                ComplaintRepost.complaint_id.in_(complaint_ids),
            )
            .all()
        )

    feed_items = []
    for c in complaints:
        citizen_name = c.citizen.full_name if c.citizen else "Anonymous Citizen"
        name_parts = citizen_name.split()
        initials = "".join([p[0].upper() for p in name_parts[:2]]) if name_parts else "AC"
        upvotes_total = len(c.upvotes)
        reposts_total = len(c.reposts)
        comments_total = len([comm for comm in c.comments if not getattr(comm, 'is_deleted', False)])
        feed_items.append(
            ComplaintFeedItem(
                id=c.id,
                mentions=c.mentions,
                title=c.title,
                description=c.description,
                category=c.category,
                status=c.status,
                location=c.location,
                latitude=c.latitude,
                longitude=c.longitude,
                location_address=c.location_address,
                image_url=c.image_url,
                sdg_alignment=c.sdg_alignment,
                impact_level=c.impact_level,
                equity_classification=c.equity_classification,
                created_at=c.created_at,
                citizen_name=citizen_name,
                citizen_initials=initials,
                citizen_id=c.citizen_id,
                profile_image_url=c.citizen.profile_image_url if c.citizen else None,
                upvotes_count=upvotes_total,
                comments_count=comments_total,
                reposts_count=reposts_total,
                has_upvoted=(c.id in user_upvoted_ids),
                has_reposted=(c.id in user_reposted_ids),
                citizen_role=c.citizen.role if c.citizen else None,
            )
        )
    return feed_items


@router.post("/{complaint_id}/upvote", response_model=UpvoteResponse, status_code=status.HTTP_200_OK)
def toggle_complaint_upvote(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Toggle upvote for a civic complaint:
    - If current user already upvoted, removes the upvote.
    - If not upvoted, creates a new upvote record.
    - Returns updated total_upvotes and has_upvoted status.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    existing = (
        db.query(ComplaintUpvote)
        .filter(
            ComplaintUpvote.complaint_id == complaint_id,
            ComplaintUpvote.user_id == current_user.id,
        )
        .first()
    )

    if existing:
        db.delete(existing)
        db.commit()
        has_upvoted = False
    else:
        new_upvote = ComplaintUpvote(complaint_id=complaint_id, user_id=current_user.id)
        db.add(new_upvote)
        db.commit()
        has_upvoted = True

    total = db.query(ComplaintUpvote).filter(ComplaintUpvote.complaint_id == complaint_id).count()

    return UpvoteResponse(
        complaint_id=complaint_id,
        total_upvotes=total,
        has_upvoted=has_upvoted,
    )


@router.get("/{complaint_id}/upvote-status", response_model=UpvoteResponse, status_code=status.HTTP_200_OK)
def get_complaint_upvote_status(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Check upvote count and whether current user has upvoted."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    existing = (
        db.query(ComplaintUpvote)
        .filter(
            ComplaintUpvote.complaint_id == complaint_id,
            ComplaintUpvote.user_id == current_user.id,
        )
        .first()
    )
    total = db.query(ComplaintUpvote).filter(ComplaintUpvote.complaint_id == complaint_id).count()

    return UpvoteResponse(
        complaint_id=complaint_id,
        total_upvotes=total,
        has_upvoted=existing is not None,
    )


@router.post("/{complaint_id}/repost", response_model=RepostResponse, status_code=status.HTTP_200_OK)
def toggle_complaint_repost(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Toggle repost for a civic complaint:
    - If current user already reposted, removes the repost (undo).
    - If not reposted, creates a new repost record.
    - Returns updated total_reposts and has_reposted status.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    existing = (
        db.query(ComplaintRepost)
        .filter(
            ComplaintRepost.complaint_id == complaint_id,
            ComplaintRepost.user_id == current_user.id,
        )
        .first()
    )

    if existing:
        db.delete(existing)
        db.commit()
        has_reposted = False
    else:
        new_repost = ComplaintRepost(complaint_id=complaint_id, user_id=current_user.id)
        db.add(new_repost)
        db.commit()
        has_reposted = True

    total = db.query(ComplaintRepost).filter(ComplaintRepost.complaint_id == complaint_id).count()

    return RepostResponse(
        complaint_id=complaint_id,
        total_reposts=total,
        has_reposted=has_reposted,
    )


@router.get("/{complaint_id}/repost-status", response_model=RepostResponse, status_code=status.HTTP_200_OK)
def get_complaint_repost_status(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Check repost count and whether current user has already reposted."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    existing = (
        db.query(ComplaintRepost)
        .filter(
            ComplaintRepost.complaint_id == complaint_id,
            ComplaintRepost.user_id == current_user.id,
        )
        .first()
    )
    total = db.query(ComplaintRepost).filter(ComplaintRepost.complaint_id == complaint_id).count()

    return RepostResponse(
        complaint_id=complaint_id,
        total_reposts=total,
        has_reposted=existing is not None,
    )


@router.get("/stats", response_model=ComplaintStatsResponse, status_code=status.HTTP_200_OK)
def get_complaint_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("official", "admin")),
):
    """
    Analytics summary for Municipal Officials & Administrators:
    Provides breakdown of complaint volumes, resolution pipeline, and category distributions.
    """
    complaints = db.query(Complaint).all()
    total = len(complaints)

    counts = {
        "submitted": 0,
        "under_review": 0,
        "assigned": 0,
        "in_progress": 0,
        "resolved": 0,
        "rejected": 0,
    }
    by_cat: dict[str, int] = {}

    for c in complaints:
        st = c.status.lower()
        if st in counts:
            counts[st] += 1
        cat = c.category.lower()
        by_cat[cat] = by_cat.get(cat, 0) + 1

    return ComplaintStatsResponse(
        total_reports=total,
        submitted=counts["submitted"],
        under_review=counts["under_review"],
        assigned=counts["assigned"],
        in_progress=counts["in_progress"],
        resolved=counts["resolved"],
        rejected=counts["rejected"],
        by_category=by_cat,
    )


@router.get("/{complaint_id}", response_model=ComplaintResponse, status_code=status.HTTP_200_OK)
def get_complaint(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieve details for a single complaint."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    # Citizens can only view their own complaints
    if current_user.role == "citizen" and complaint.citizen_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this complaint",
        )

    return complaint


@router.patch("/{complaint_id}/status", response_model=ComplaintResponse, status_code=status.HTTP_200_OK)
def update_complaint_status(
    complaint_id: int,
    status_update: ComplaintStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("official", "admin")),
):
    """Update status, officer notes, and rejection reason of a complaint (Officials and Admins only)."""
    target_status = status_update.status.lower().strip()
    if target_status not in VALID_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status '{status_update.status}'. Allowed statuses: {', '.join(sorted(VALID_STATUSES))}",
        )

    if target_status == "submitted":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot revert complaint status back to 'submitted'",
        )

    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    # Validation for rejection reason
    cleaned_rejection_reason = (
        status_update.rejection_reason.strip()
        if status_update.rejection_reason is not None
        else None
    )

    if target_status == "rejected":
        if cleaned_rejection_reason:
            complaint.rejection_reason = cleaned_rejection_reason
        elif not complaint.rejection_reason:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A rejection reason must be provided when rejecting a complaint",
            )
        # Note: If cleaned_rejection_reason is empty/None but complaint already has one,
        # we preserve the existing rejection_reason (do not overwrite with empty).
    else:
        # Status is not 'rejected'
        if cleaned_rejection_reason:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Rejection reason can only be provided when status is 'rejected'",
            )

    # Optional officer note update
    if status_update.officer_notes is not None:
        cleaned_notes = status_update.officer_notes.strip()
        if cleaned_notes:
            complaint.officer_notes = cleaned_notes

    complaint.status = target_status
    db.commit()
    db.refresh(complaint)
    return complaint


@router.patch("/{complaint_id}", response_model=ComplaintResponse, status_code=status.HTTP_200_OK)
def update_complaint(
    complaint_id: int,
    complaint_in: ComplaintUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update complaint details."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    # Permission check
    if current_user.role == "citizen":
        if complaint.citizen_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to edit this complaint",
            )
        if complaint.status != "submitted":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot edit a complaint that is already under review or processed",
            )

    if complaint_in.title is not None:
        complaint.title = complaint_in.title
    if complaint_in.description is not None:
        complaint.description = complaint_in.description
    if complaint_in.category is not None:
        complaint.category = complaint_in.category.lower()
    if complaint_in.location is not None:
        complaint.location = complaint_in.location
    if complaint_in.image_url is not None:
        complaint.image_url = complaint_in.image_url
    if complaint_in.image_public_id is not None:
        complaint.image_public_id = complaint_in.image_public_id
    if complaint_in.sdg_alignment is not None:
        complaint.sdg_alignment = complaint_in.sdg_alignment
    if complaint_in.impact_level is not None:
        complaint.impact_level = complaint_in.impact_level
    if complaint_in.equity_classification is not None:
        complaint.equity_classification = complaint_in.equity_classification
    if complaint_in.officer_notes is not None:
        complaint.officer_notes = complaint_in.officer_notes
    if complaint_in.rejection_reason is not None:
        complaint.rejection_reason = complaint_in.rejection_reason

    db.commit()
    db.refresh(complaint)
    return complaint



@router.delete("/{complaint_id}", status_code=status.HTTP_200_OK)
async def delete_complaint(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """Delete a complaint (Admin can delete any; Citizen can delete own if still in 'submitted' status)."""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    if current_user.role == "admin":
        pass  # Admin has full delete permissions
    elif current_user.role == "citizen" and complaint.citizen_id == current_user.id:
        if complaint.status != "submitted":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete a complaint that is already being processed",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to delete this complaint",
        )

    # Clean up Cloudinary asset if tracked
    if complaint.image_public_id:
        await storage.delete_asset(complaint.image_public_id)

    db.delete(complaint)
    db.commit()
    return {"message": "Complaint deleted successfully"}


@router.post("/{complaint_id}/comments", response_model=CommentResponse, status_code=status.HTTP_201_CREATED)
def add_complaint_comment(
    complaint_id: int,
    comment_in: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Post a citizen comment or reply on a civic complaint.
    - Persisted in PostgreSQL complaint_comments table.
    - Supports parent_comment_id for threaded discussion.
    - Validates parent comment belongs to the same complaint.
    - Requires authenticated user.
    - Validates non-empty comment text.
    """
    raw_text = comment_in.content if comment_in.content is not None else comment_in.comment
    text_clean = (raw_text or "").strip()
    if not text_clean:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Comment cannot be empty",
        )

    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    # Validate parent_comment_id if provided
    if comment_in.parent_comment_id is not None:
        parent_comment = db.query(ComplaintComment).filter(ComplaintComment.id == comment_in.parent_comment_id).first()
        if not parent_comment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Parent comment not found",
            )
        if parent_comment.complaint_id != complaint_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Parent comment belongs to a different complaint",
            )

    new_comment = ComplaintComment(
        complaint_id=complaint_id,
        user_id=current_user.id,
        parent_comment_id=comment_in.parent_comment_id,
        comment=text_clean,
        image_url=comment_in.image_url,
        image_public_id=comment_in.image_public_id,
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)

    user_name = current_user.full_name or "Citizen"
    name_parts = user_name.split()
    initials = "".join([p[0].upper() for p in name_parts[:2]]) if name_parts else "C"

    return CommentResponse(
        id=new_comment.id,
        complaint_id=new_comment.complaint_id,
        user_id=new_comment.user_id,
        user_name=user_name,
        username=user_name,
        user_initials=initials,
        profile_image_url=current_user.profile_image_url,
        comment=new_comment.comment,
        content=new_comment.comment,
        image_url=new_comment.image_url,
        image_public_id=new_comment.image_public_id,
        created_at=new_comment.created_at,
        parent_comment_id=new_comment.parent_comment_id,
    )


@router.get("/{complaint_id}/comments", response_model=List[CommentResponse], status_code=status.HTTP_200_OK)
def list_complaint_comments(
    complaint_id: int,
    db: Session = Depends(get_db),
):
    """
    Retrieve all comments for a civic complaint in chronological order.
    Includes parent_comment_id, profile_image_url, and author metadata for threading.
    """
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

    comments = (
        db.query(ComplaintComment)
        .filter(ComplaintComment.complaint_id == complaint_id)
        .order_by(ComplaintComment.created_at.asc())
        .all()
    )

    results = []
    for comm in comments:
        if comm.is_deleted:
            user_name = "[deleted]"
            initials = "D"
            comment_text = "This comment was deleted"
            avatar_url = None
            comment_image_url = None
        else:
            user_name = comm.user.full_name if comm.user else "Citizen"
            name_parts = user_name.split()
            initials = "".join([p[0].upper() for p in name_parts[:2]]) if name_parts else "C"
            comment_text = comm.comment
            avatar_url = comm.user.profile_image_url if comm.user else None
            comment_image_url = comm.image_url

        results.append(
            CommentResponse(
                id=comm.id,
                complaint_id=comm.complaint_id,
                user_id=comm.user_id,
                user_name=user_name,
                username=user_name,
                user_initials=initials,
                profile_image_url=avatar_url,
                comment=comment_text,
                content=comment_text,
                image_url=comment_image_url,
                image_public_id=comm.image_public_id,
                created_at=comm.created_at,
                parent_comment_id=comm.parent_comment_id,
                is_deleted=comm.is_deleted,
            )
        )
    return results


@router.delete("/{complaint_id}/comments/{comment_id}", status_code=status.HTTP_200_OK)
async def delete_complaint_comment(
    complaint_id: int,
    comment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """
    Delete a comment on a civic complaint.
    - Requires authenticated user.
    - Enforces strict ownership (current_user.id == comment.user_id).
    - If non-author attempts deletion, returns 403 Forbidden.
    - If comment does not exist or belongs to another complaint, returns 404 Not Found.
    - If comment has replies: preserves thread integrity by soft-deleting
      ("This comment was deleted", is_deleted=True).
    - If comment has no replies: completely removes from database and cleans up stored image.
    """
    comment = db.query(ComplaintComment).filter(ComplaintComment.id == comment_id).first()
    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comment not found",
        )

    if comment.complaint_id != complaint_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comment not found in this complaint",
        )

    if comment.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete your own comments",
        )

    # Check if this comment has replies
    has_replies = len(comment.replies) > 0

    if has_replies:
        # Preserve thread structure: soft-delete
        comment.is_deleted = True
        comment.comment = "This comment was deleted"
        db.commit()
        db.refresh(comment)
        return {
            "message": "Comment marked as deleted",
            "comment_id": comment.id,
            "is_deleted": True,
            "has_replies": True,
        }
    else:
        # Leaf comment: clean up attached image if exists and hard delete
        if comment.image_public_id:
            await storage.delete_asset(comment.image_public_id)

        db.delete(comment)
        db.commit()
        return {
            "message": "Comment permanently deleted",
            "comment_id": comment_id,
            "is_deleted": True,
            "has_replies": False,
        }



