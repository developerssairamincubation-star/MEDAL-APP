"""Directory of approved officials, used by the "@" tag autocomplete."""
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.user import User
from app.routers.auth import get_current_user

router = APIRouter(prefix="/officials", tags=["Officials"])


class OfficialSummary(BaseModel):
    id: int
    full_name: str
    designation: Optional[str] = None
    department: Optional[str] = None
    profile_image_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


@router.get("", response_model=List[OfficialSummary])
def search_officials(
    q: str = Query("", max_length=80),
    limit: int = Query(8, ge=1, le=25),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Approved officials whose name, designation or department matches `q`."""
    query = db.query(User).filter(
        User.role == "official",
        User.approval_status == "approved",
        User.is_active.is_(True),
    )
    term = q.strip().lower()
    if term:
        like = f"%{term}%"
        query = query.filter(
            or_(
                func.lower(User.full_name).like(like),
                func.lower(func.coalesce(User.designation, "")).like(like),
                func.lower(func.coalesce(User.department, "")).like(like),
            )
        )
    return query.order_by(User.full_name.asc()).limit(limit).all()
