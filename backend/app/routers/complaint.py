from typing import List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.complaint import Complaint, ComplaintComment, ComplaintUpvote
from app.models.user import User
from app.routers.auth import get_current_user, require_role
from app.schemas.complaint import (
    CommentCreate,
    CommentResponse,
    ComplaintCreate,
    ComplaintFeedItem,
    ComplaintResponse,
    ComplaintStatsResponse,
    ComplaintStatusUpdate,
    ComplaintUpdate,
    UpvoteResponse,
)
from app.services.storage import BaseStorageService, get_storage_service

router = APIRouter(prefix="/complaints", tags=["Complaints"])

VALID_STATUSES = {"submitted", "under_review", "in_progress", "resolved", "rejected"}
VALID_CATEGORIES = {
    "road", "garbage", "waste", "water", "streetlight", "drainage",
    "health", "education", "sanitation", "infrastructure", "environment", "other"
}


import mimetypes


@router.post("/upload-evidence", status_code=status.HTTP_200_OK)
async def upload_evidence(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """Upload an image evidence for a citizen report/complaint."""
    content_type = file.content_type
    # If client sent generic application/octet-stream or empty content type, guess from filename
    if not content_type or content_type in ("application/octet-stream", "application/octetstream", "binary/octet-stream"):
        guessed_type, _ = mimetypes.guess_type(file.filename or "")
        if guessed_type:
            content_type = guessed_type

    if content_type and not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only image files are accepted as evidence",
        )
    file_url = await storage.upload_file(file, folder="reports")
    return {"image_url": file_url}


@router.post("", response_model=ComplaintResponse, status_code=status.HTTP_201_CREATED)
def create_complaint(
    complaint_in: ComplaintCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new complaint/report for the currently authenticated citizen."""
    new_complaint = Complaint(
        title=complaint_in.title.strip(),
        description=complaint_in.description.strip(),
        category=complaint_in.category.lower().strip(),
        status="submitted",
        location=complaint_in.location.strip(),
        image_url=complaint_in.image_url,
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
    query = db.query(Complaint)

    if current_user.role == "citizen":
        query = query.filter(Complaint.citizen_id == current_user.id)
    else:
        # Officials and Admins can see all complaints
        if status_filter:
            query = query.filter(Complaint.status == status_filter.lower())
        if category_filter:
            query = query.filter(Complaint.category == category_filter.lower())

    complaints = query.order_by(Complaint.created_at.desc()).all()
    return complaints


@router.get("/feed", response_model=List[ComplaintFeedItem], status_code=status.HTTP_200_OK)
def get_community_feed(
    category: Optional[str] = Query(None, alias="category"),
    db: Session = Depends(get_db),
):
    """
    Public Community Feed:
    - Returns all active, non-rejected complaints submitted by all citizens.
    - Ordered newest first (created_at desc).
    - Preserves citizen privacy (only full_name / initials, no phone/email).
    """
    query = (
        db.query(Complaint)
        .join(User, Complaint.citizen_id == User.id)
        .filter(Complaint.status != "rejected")
    )

    if category:
        cat_clean = category.strip().lower()
        if cat_clean in ("environment", "environmental"):
            query = query.filter(Complaint.category.in_(["environment", "garbage", "waste", "sanitation", "water"]))
        elif cat_clean in ("infrastructure", "road"):
            query = query.filter(Complaint.category.in_(["road", "streetlight", "drainage", "infrastructure"]))
        elif cat_clean not in ("all", "all reports"):
            query = query.filter(Complaint.category == cat_clean)

    complaints = query.order_by(Complaint.created_at.desc()).all()

    feed_items = []
    for c in complaints:
        citizen_name = c.citizen.full_name if c.citizen else "Anonymous Citizen"
        name_parts = citizen_name.split()
        initials = "".join([p[0].upper() for p in name_parts[:2]]) if name_parts else "AC"
        upvotes_total = len(c.upvotes)
        feed_items.append(
            ComplaintFeedItem(
                id=c.id,
                title=c.title,
                description=c.description,
                category=c.category,
                status=c.status,
                location=c.location,
                image_url=c.image_url,
                sdg_alignment=c.sdg_alignment,
                impact_level=c.impact_level,
                equity_classification=c.equity_classification,
                created_at=c.created_at,
                citizen_name=citizen_name,
                citizen_initials=initials,
                upvotes_count=upvotes_total,
                comments_count=len([comm for comm in c.comments if not getattr(comm, 'is_deleted', False)]),
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

    counts = {"submitted": 0, "under_review": 0, "in_progress": 0, "resolved": 0, "rejected": 0}
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
    """Update status of a complaint (Officials and Admins only)."""
    target_status = status_update.status.lower()
    if target_status not in VALID_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status '{status_update.status}'. Allowed statuses: {', '.join(sorted(VALID_STATUSES))}",
        )

    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Complaint not found",
        )

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
    if complaint_in.sdg_alignment is not None:
        complaint.sdg_alignment = complaint_in.sdg_alignment
    if complaint_in.impact_level is not None:
        complaint.impact_level = complaint_in.impact_level
    if complaint_in.equity_classification is not None:
        complaint.equity_classification = complaint_in.equity_classification

    db.commit()
    db.refresh(complaint)
    return complaint



@router.delete("/{complaint_id}", status_code=status.HTTP_200_OK)
def delete_complaint(
    complaint_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
        else:
            user_name = comm.user.full_name if comm.user else "Citizen"
            name_parts = user_name.split()
            initials = "".join([p[0].upper() for p in name_parts[:2]]) if name_parts else "C"
            comment_text = comm.comment
            avatar_url = comm.user.profile_image_url if comm.user else None

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
                created_at=comm.created_at,
                parent_comment_id=comm.parent_comment_id,
                is_deleted=comm.is_deleted,
            )
        )
    return results


@router.delete("/{complaint_id}/comments/{comment_id}", status_code=status.HTTP_200_OK)
def delete_complaint_comment(
    complaint_id: int,
    comment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Delete a comment on a civic complaint.
    - Requires authenticated user.
    - Enforces strict ownership (current_user.id == comment.user_id).
    - If non-author attempts deletion, returns 403 Forbidden.
    - If comment does not exist or belongs to another complaint, returns 404 Not Found.
    - If comment has replies: preserves thread integrity by soft-deleting
      ("This comment was deleted", is_deleted=True).
    - If comment has no replies: completely removes from database.
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
        # Leaf comment: hard delete
        db.delete(comment)
        db.commit()
        return {
            "message": "Comment permanently deleted",
            "comment_id": comment_id,
            "is_deleted": True,
            "has_replies": False,
        }



