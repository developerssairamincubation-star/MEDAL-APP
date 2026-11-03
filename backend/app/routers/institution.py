"""Principal / Staff institution API.

Everything here is computed from live rows: users (role staff / student) and
their SEEK chapter completions. Nothing is stored twice and nothing is mocked.
"""
import csv
import io
import logging
import secrets
import string
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import Response
from pydantic import BaseModel, EmailStr, TypeAdapter, ValidationError
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.student import (
    StudentChapterCompletion,
    StudentCourseChapter,
    StudentEnrollment,
    StudentNotification,
)
from app.models.user import School, User
from app.routers.auth import require_role
from app.routers.student import _chapters_payload, _time_ago
from app.services.email import EmailDeliveryError, EmailService, get_email_service
from app.services.seek_chapters import get_seek_course
from app.utils.security import hash_password

router = APIRouter(prefix="/institution", tags=["Institution"])
logger = logging.getLogger("medal.institution")

MAX_CSV_BYTES = 1_000_000
MAX_CSV_ROWS = 200
CSV_TEMPLATE = "name,email,department\nAsha Kumar,asha.kumar@example.com,Science\n"
_EMAIL = TypeAdapter(EmailStr)

ACTIVE_WINDOW = timedelta(days=30)


class StudentInviteRequest(BaseModel):
    name: str
    email: EmailStr
    department: Optional[str] = None


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
        "teacher_id": user.teacher_id,
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


def _members(db: Session, role: str, school_id: int, teacher_id: Optional[int] = None) -> List[dict]:
    query = db.query(User).filter(User.role == role, User.school_id == school_id, User.is_active.is_(True))
    if teacher_id is not None:
        query = query.filter(User.teacher_id == teacher_id)  # a teacher's own students only
    users = query.order_by(User.full_name.asc()).all()
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
    teacher_id = current_user.id if current_user.role == "staff" else None
    return _members(db, "student", _school_id(current_user), teacher_id)


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
    # Staff may look at their own students; only the principal sees other staff and all students.
    if current_user.role == "staff":
        if user.role != "student":
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        if user.teacher_id != current_user.id:
            raise HTTPException(status_code=404, detail="Member not found")

    seek = get_seek_course(db)
    total = _total_chapters(db)
    progress = _progress_by_user(db, [user.id]).get(user.id, {})
    return {
        "member": _member(user, progress, total),
        "course": _chapters_payload(db, user.id, seek.id) if seek else None,
    }


# ── add students under a teacher (staff) ────────────────────────────────

def _temp_password() -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(10))


def _email_in_use(db: Session, email: str) -> bool:
    return db.query(User.id).filter(func.lower(User.email) == email).first() is not None


def _new_student(db: Session, teacher: User, name: str, email: str, department: Optional[str]) -> tuple:
    """Create (flush, don't commit) a student under `teacher`; returns (user, temporary_password)."""
    temp_password = _temp_password()
    student = User(
        email=email,
        # Random one-time password the student replaces: a lighter bcrypt cost keeps a 200-row CSV fast.
        password_hash=hash_password(temp_password, rounds=10),
        full_name=name,
        role="student",
        school_id=teacher.school_id,
        teacher_id=teacher.id,
        department=(department or "").strip() or teacher.department,
        approval_status="approved",
        is_active=True,
        is_verified=True,
    )
    db.add(student)
    db.flush()
    seek = get_seek_course(db)
    if seek:
        db.add(StudentEnrollment(
            user_id=student.id,
            course_id=seek.id,
            start_date=datetime.now(timezone.utc).strftime("%d %b %Y"),
        ))
    db.add(StudentNotification(
        user_id=student.id,
        category="Academy",
        title="Welcome to SEEK Academy",
        description=f"{teacher.full_name} added you. Start your foundational SEEK course.",
        period_group="last_7_days",
    ))
    return student, temp_password


def _require_invites_possible(email_service: EmailService) -> None:
    """In production, refuse to create accounts nobody could be told about."""
    if not email_service.is_configured() and email_service.is_production():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Email is not configured on the server, so invites cannot be sent.",
        )


def _send_invite(email_service: EmailService, teacher: User, school_name: str, name: str, email: str, password: str) -> bool:
    return email_service.send_student_invite(
        to_email=email,
        student_name=name,
        teacher_name=teacher.full_name,
        school_name=school_name,
        temporary_password=password,
    )


def _school_name(db: Session, school_id: int) -> str:
    school = db.get(School, school_id)
    return school.name if school else "your school"


@router.post("/students/invite", status_code=status.HTTP_201_CREATED)
def invite_student(
    req: StudentInviteRequest,
    current_user: User = Depends(require_role("staff")),
    db: Session = Depends(get_db),
    email_service: EmailService = Depends(get_email_service),
):
    """Add one student under the calling teacher and e-mail them an invite."""
    _school_id(current_user)
    name = req.name.strip()
    email = req.email.lower().strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    if _email_in_use(db, email):
        raise HTTPException(status_code=400, detail="Email is already registered")
    _require_invites_possible(email_service)

    student, temp_password = _new_student(db, current_user, name, email, req.department)
    db.commit()
    db.refresh(student)

    email_sent, error = False, None
    try:
        email_sent = _send_invite(email_service, current_user, _school_name(db, current_user.school_id), name, email, temp_password)
    except EmailDeliveryError as exc:
        error = str(exc)
        logger.error("Student invite failed for user %s: %s", student.id, exc)

    return {
        "student": _member(student, {}, _total_chapters(db)),
        "email_sent": email_sent,
        # Only handed back when the e-mail could not be sent, so the teacher can pass it on.
        "temporary_password": None if email_sent else temp_password,
        "message": "Invite sent." if email_sent else (
            "Student added, but the invite e-mail could not be sent. Share the temporary password with them."
        ),
        "error": error,
    }


@router.get("/students/template")
def student_csv_template(current_user: User = Depends(require_role("staff"))):
    return Response(
        content=CSV_TEMPLATE,
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="students_template.csv"'},
    )


def _norm_header(h: str) -> str:
    return "".join(ch for ch in (h or "").lower() if ch.isalnum())


_HEADER_ALIASES = {
    "name": "name", "studentname": "name", "fullname": "name",
    "email": "email", "emailid": "email", "emailaddress": "email", "mail": "email", "mailid": "email",
    "department": "department", "dept": "department",
}


def _send_invites_in_background(
    email_service: EmailService, teacher_name: str, school_name: str, invites: List[tuple]
) -> None:
    """Runs after the response: one e-mail session for the whole file; failures are logged, not raised."""
    try:
        results = email_service.send_student_invites(
            [(name, email, password) for name, email, password in invites], teacher_name, school_name
        )
    except Exception as exc:
        logger.error("Student invite batch failed: %s", exc)
        return
    failed = [(email, err) for email, err in results if err]
    if failed:
        logger.error("%d of %d student invites failed (first: %s)", len(failed), len(results), failed[0][1])


@router.post("/students/bulk")
async def invite_students_csv(
    background: BackgroundTasks,
    file: UploadFile = File(...),
    current_user: User = Depends(require_role("staff")),
    db: Session = Depends(get_db),
    email_service: EmailService = Depends(get_email_service),
):
    """Add many students under the calling teacher from a CSV (columns: name, email, optional department).

    Valid rows are created even if others fail; the response lists every rejected row and why.
    """
    _school_id(current_user)
    raw = await file.read(MAX_CSV_BYTES + 1)
    if len(raw) > MAX_CSV_BYTES:
        raise HTTPException(status_code=413, detail="CSV file is too large (max 1 MB).")
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="The file is not valid UTF-8 text. Save it as CSV (UTF-8).")
    if not text.strip():
        raise HTTPException(status_code=400, detail="The file is empty.")

    reader = csv.reader(io.StringIO(text))
    try:
        header = next(reader)
    except StopIteration:
        raise HTTPException(status_code=400, detail="The file is empty.")
    columns = {}
    for idx, h in enumerate(header):
        key = _HEADER_ALIASES.get(_norm_header(h))
        if key and key not in columns:
            columns[key] = idx
    missing = [c for c in ("name", "email") if c not in columns]
    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Missing required column(s): {', '.join(missing)}. Expected header: name,email,department",
        )
    rows = [(n, r) for n, r in enumerate(reader, start=2) if any((c or "").strip() for c in r)]
    if not rows:
        raise HTTPException(status_code=400, detail="The file has a header but no student rows.")
    if len(rows) > MAX_CSV_ROWS:
        raise HTTPException(status_code=400, detail=f"Too many rows ({len(rows)}). The limit is {MAX_CSV_ROWS} per file.")
    _require_invites_possible(email_service)

    def cell(row, key):
        idx = columns.get(key)
        return (row[idx].strip() if idx is not None and idx < len(row) else "")

    created, errors, invites = [], [], []
    seen: set = set()
    for row_no, row in rows:
        name, email_raw, dept = cell(row, "name"), cell(row, "email"), cell(row, "department")
        email = email_raw.lower()
        if not name:
            errors.append({"row": row_no, "email": email_raw, "error": "Name is required"})
            continue
        try:
            _EMAIL.validate_python(email_raw)
        except ValidationError:
            errors.append({"row": row_no, "email": email_raw, "error": "Invalid email address"})
            continue
        if email in seen:
            errors.append({"row": row_no, "email": email_raw, "error": "Duplicate email in this file"})
            continue
        seen.add(email)
        if _email_in_use(db, email):
            errors.append({"row": row_no, "email": email_raw, "error": "Email is already registered"})
            continue
        student, temp_password = _new_student(db, current_user, name, email, dept)
        created.append((student, temp_password))
        invites.append((name, email, temp_password))
    db.commit()

    school_name = _school_name(db, current_user.school_id)
    configured = email_service.is_configured()
    if configured:
        background.add_task(_send_invites_in_background, email_service, current_user.full_name, school_name, invites)

    total_chapters = _total_chapters(db)
    return {
        "total_rows": len(rows),
        "created": len(created),
        "failed": len(errors),
        "errors": errors,
        "students": [_member(st, {}, total_chapters) for st, _ in created],
        "invites_queued": len(invites) if configured else 0,
        # Dev only (no email provider): hand the passwords back so the accounts are usable.
        "credentials": [] if configured else [
            {"email": st.email, "temporary_password": pw} for st, pw in created
        ],
    }
