"""Principal / Staff institution API.

Everything here is computed from live rows: users (role staff / student) and
their SEEK chapter completions. Nothing is stored twice and nothing is mocked.
"""
import secrets
import string
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.student import StudentChapterCompletion, StudentCourseChapter
from app.models.user import User
from app.routers.auth import require_role
from app.routers.student import _chapters_payload, _time_ago
from app.services.seek_chapters import get_seek_course
from app.utils.security import hash_password

router = APIRouter(prefix="/institution", tags=["Institution"])

ACTIVE_WINDOW = timedelta(days=30)


class StaffCreateRequest(BaseModel):
    name: str
    email: EmailStr
    department: Optional[str] = None
    designation: Optional[str] = None
    phone: Optional[str] = None


# ── helpers ─────────────────────────────────────────────────────────────

def _aware(when: Optional[datetime]) -> Optional[datetime]:
    if when is not None and when.tzinfo is None:
        return when.replace(tzinfo=timezone.utc)
    return when


def _total_chapters(db: Session) -> int:
    seek = get_seek_course(db)
    if not seek:
        return 0
    return db.query(func.count(StudentCourseChapter.id)).filter(
        StudentCourseChapter.course_id == seek.id
    ).scalar() or 0


def _progress_by_user(db: Session, user_ids: List[int]) -> Dict[int, dict]:
    """{user_id: {completed, last_active}} from chapter completions."""
    if not user_ids:
        return {}
    rows = (
        db.query(
            StudentChapterCompletion.user_id,
            func.count(StudentChapterCompletion.id),
            func.max(StudentChapterCompletion.completed_at),
        )
        .filter(StudentChapterCompletion.user_id.in_(user_ids))
        .group_by(StudentChapterCompletion.user_id)
        .all()
    )
    return {uid: {"completed": n, "last_active": _aware(last)} for uid, n, last in rows}


def _member(user: User, progress: dict, total: int) -> dict:
    completed = progress.get("completed", 0)
    last_active = progress.get("last_active")
    if total and completed >= total:
        state = "completed"
    elif completed:
        state = "in_progress"
    else:
        state = "not_started"
    return {
        "id": user.id,
        "name": user.full_name,
        "email": user.email,
        "phone": user.phone,
        "role": user.role,
        "department": user.department,
        "designation": user.designation,
        "student_id": user.student_id,
        "approval_status": user.approval_status,
        "joined_at": _aware(user.created_at).isoformat() if user.created_at else None,
        "completed_chapters": completed,
        "total_chapters": total,
        "progress_pct": (completed / total) if total else 0.0,
        "status": state,
        "last_active": last_active.isoformat() if last_active else None,
    }


def _school_id(user: User) -> int:
    """The caller's school. Every institution query is filtered by it; no school -> no data."""
    if user.school_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is not assigned to a school")
    return user.school_id


def _members(db: Session, role: str, school_id: int) -> List[dict]:
    users = (
        db.query(User)
        .filter(User.role == role, User.school_id == school_id, User.is_active.is_(True))
        .order_by(User.full_name.asc())
        .all()
    )
    total = _total_chapters(db)
    progress = _progress_by_user(db, [u.id for u in users])
    return [_member(u, progress.get(u.id, {}), total) for u in users]


# ── dashboard (principal + staff) ───────────────────────────────────────

@router.get("/dashboard")
def institution_dashboard(
    current_user: User = Depends(require_role("principal", "staff")),
    db: Session = Depends(get_db),
):
    school_id = _school_id(current_user)
    total = _total_chapters(db)
    staff = _members(db, "staff", school_id)
    students = _members(db, "student", school_id)

    now = datetime.now(timezone.utc)
    active = sum(1 for s in students if s["last_active"] and now - datetime.fromisoformat(s["last_active"]) <= ACTIVE_WINDOW)
    certified = sum(1 for m in staff + students if m["status"] == "completed")
    pending = (
        db.query(func.count(User.id))
        .filter(User.role == "student", User.school_id == school_id, User.approval_status == "pending")
        .scalar()
        or 0
    )

    rows = (
        db.query(StudentChapterCompletion, StudentCourseChapter, User)
        .join(StudentCourseChapter, StudentCourseChapter.id == StudentChapterCompletion.chapter_id)
        .join(User, User.id == StudentChapterCompletion.user_id)
        .filter(User.role.in_(["staff", "student"]), User.school_id == school_id)
        .order_by(StudentChapterCompletion.completed_at.desc(), StudentChapterCompletion.id.desc())
        .limit(10)
        .all()
    )
    recent = [
        {
            "name": user.full_name,
            "role": user.role,
            "action": f"Completed chapter: {chapter.title}",
            "time_ago": _time_ago(comp.completed_at),
            "completed_at": _aware(comp.completed_at).isoformat(),
        }
        for comp, chapter, user in rows
    ]

    return {
        "total_staff": len(staff),
        "total_students": len(students),
        "certification_ready": certified,
        "active_students": active,
        "inactive_students": len(students) - active,
        "enrollment_pending": pending,
        "total_chapters": total,
        "recent_activity": recent,
    }


# ── staff (principal) ───────────────────────────────────────────────────

@router.get("/staff")
def list_staff(
    current_user: User = Depends(require_role("principal")),
    db: Session = Depends(get_db),
):
    return _members(db, "staff", _school_id(current_user))


@router.post("/staff", status_code=status.HTTP_201_CREATED)
def add_staff(
    req: StaffCreateRequest,
    current_user: User = Depends(require_role("principal")),
    db: Session = Depends(get_db),
):
    school_id = _school_id(current_user)
    email = req.email.lower().strip()
    if not req.name.strip():
        raise HTTPException(status_code=400, detail="Name is required")
    if db.query(User).filter(func.lower(User.email) == email).first():
        raise HTTPException(status_code=400, detail="Email is already registered")

    alphabet = string.ascii_letters + string.digits
    temp_password = "".join(secrets.choice(alphabet) for _ in range(10))
    staff = User(
        email=email,
        password_hash=hash_password(temp_password),
        full_name=req.name.strip(),
        phone=(req.phone or "").strip() or None,
        role="staff",
        school_id=school_id,
        department=(req.department or "").strip() or None,
        designation=(req.designation or "").strip() or None,
        approval_status="approved",
        is_active=True,
        is_verified=True,
    )
    db.add(staff)
    db.commit()
    db.refresh(staff)

    member = _member(staff, {}, _total_chapters(db))
    # Shown once so the principal can hand it over; only the hash is stored.
    return {"staff": member, "temporary_password": temp_password}


# ── students (principal + staff) ────────────────────────────────────────

@router.get("/students")
def list_students(
    current_user: User = Depends(require_role("principal", "staff")),
    db: Session = Depends(get_db),
):
    return _members(db, "student", _school_id(current_user))


# ── per-member progress ─────────────────────────────────────────────────

@router.get("/members/{user_id}/progress")
def member_progress(
    user_id: int,
    current_user: User = Depends(require_role("principal", "staff")),
    db: Session = Depends(get_db),
):
    school_id = _school_id(current_user)
    user = (
        db.query(User)
        .filter(User.id == user_id, User.role.in_(["staff", "student"]), User.school_id == school_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="Member not found")
    # Staff may look at students; only the principal sees other staff.
    if current_user.role == "staff" and user.role != "student":
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    seek = get_seek_course(db)
    total = _total_chapters(db)
    progress = _progress_by_user(db, [user.id]).get(user.id, {})
    return {
        "member": _member(user, progress, total),
        "course": _chapters_payload(db, user.id, seek.id) if seek else None,
    }
