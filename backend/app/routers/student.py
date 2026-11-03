from datetime import datetime, timedelta, timezone
import logging
from typing import Optional
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.user import School, User
from app.models.student import (
    StudentCertificate,
    StudentChapterCompletion,
    StudentCourse,
    StudentCourseChapter,
    StudentEnrollment,
    StudentNotification,
)
from app.routers.auth import get_institution_platform_user
from app.services.seek_chapters import get_seek_course
from app.services.storage import BaseStorageService, get_storage_service
from app.utils.file_validation import (
    MAX_DOCUMENT_SIZE_BYTES,
    validate_and_read_upload,
)
from app.utils.security import create_user_token, hash_password, verify_password

logger = logging.getLogger("medal.student")
router = APIRouter(prefix="/student", tags=["Student"])


# ── Schemas ─────────────────────────────────────────────────────────────

class StudentRegisterRequest(BaseModel):
    school_code: str
    name: str
    email: EmailStr
    department: str
    student_id: str
    registration_number: str
    password: str
    confirm_password: str


class StudentProfileUpdateRequest(BaseModel):
    phone: Optional[str] = None
    department: Optional[str] = None
    preferences: Optional[str] = None
    name: Optional[str] = None


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str


# ── Chapter progress helpers ────────────────────────────────────────────

def _course_chapters(db: Session, course_id: int):
    return (
        db.query(StudentCourseChapter)
        .filter(StudentCourseChapter.course_id == course_id)
        .order_by(StudentCourseChapter.position.asc(), StudentCourseChapter.id.asc())
        .all()
    )


def _completion_map(db: Session, user_id: int, chapter_ids):
    if not chapter_ids:
        return {}
    rows = (
        db.query(StudentChapterCompletion)
        .filter(
            StudentChapterCompletion.user_id == user_id,
            StudentChapterCompletion.chapter_id.in_(list(chapter_ids)),
        )
        .all()
    )
    return {r.chapter_id: r for r in rows}


def _course_progress(db: Session, user_id: int, course_id: int):
    """(completed, total, fraction) from the student's real chapter completions."""
    chapters = _course_chapters(db, course_id)
    done = _completion_map(db, user_id, [c.id for c in chapters])
    total = len(chapters)
    completed = len(done)
    return completed, total, (completed / total if total else 0.0)


def _sync_enrollment(db: Session, user_id: int, course_id: int):
    """Keep the enrollment row in step with chapter completions."""
    chapters = _course_chapters(db, course_id)
    done = _completion_map(db, user_id, [c.id for c in chapters])
    total, completed = len(chapters), len(done)
    pct = completed / total if total else 0.0

    modules = {}
    for c in chapters:
        modules.setdefault(c.module_number, []).append(c.id in done)
    done_modules = sum(1 for flags in modules.values() if all(flags))

    enr = db.query(StudentEnrollment).filter(
        StudentEnrollment.user_id == user_id,
        StudentEnrollment.course_id == course_id,
    ).first()
    if not enr:
        enr = StudentEnrollment(
            user_id=user_id,
            course_id=course_id,
            start_date=datetime.now(timezone.utc).strftime("%d %b %Y"),
        )
        db.add(enr)
    enr.progress_pct = pct
    enr.completed_modules = done_modules
    enr.status = "completed" if total and completed == total else "enrolled"
    db.commit()
    return enr


def _minutes(duration: str) -> int:
    digits = "".join(c for c in str(duration or "").split(" ")[0] if c.isdigit())
    return int(digits) if digits else 0


def _learning_streak(db: Session, user_id: int) -> int:
    """Consecutive days (ending today or yesterday) with a completed chapter."""
    rows = db.query(StudentChapterCompletion.completed_at).filter(
        StudentChapterCompletion.user_id == user_id
    ).all()
    days = {r[0].date() for r in rows if r[0]}
    if not days:
        return 0
    today = datetime.now(timezone.utc).date()
    day = today if today in days else today - timedelta(days=1)
    streak = 0
    while day in days:
        streak += 1
        day -= timedelta(days=1)
    return streak


def _time_ago(when: Optional[datetime]) -> str:
    if not when:
        return ""
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    secs = int((datetime.now(timezone.utc) - when).total_seconds())
    if secs < 60:
        return "just now"
    if secs < 3600:
        return f"{secs // 60}m ago"
    if secs < 86400:
        return f"{secs // 3600}h ago"
    return f"{secs // 86400}d ago"


def _chapters_payload(db: Session, user_id: int, course_id: int):
    chapters = _course_chapters(db, course_id)
    done = _completion_map(db, user_id, [c.id for c in chapters])
    modules = {}
    for c in chapters:
        mod = modules.setdefault(
            c.module_number,
            {"number": c.module_number, "title": c.module_title, "chapters": []},
        )
        comp = done.get(c.id)
        mod["chapters"].append({
            "id": c.id,
            "key": c.chapter_key,
            "title": c.title,
            "type": c.chapter_type,
            "duration": c.duration,
            "url": c.content_url,
            "completed": comp is not None,
            "completed_at": comp.completed_at.isoformat() if comp else None,
        })
    total = len(chapters)
    completed = len(done)
    return {
        "course_id": course_id,
        "total_chapters": total,
        "completed_chapters": completed,
        "progress_pct": completed / total if total else 0.0,
        "modules": [modules[k] for k in sorted(modules)],
    }


# ── 1. Student Registration ─────────────────────────────────────────────

@router.post("/register", status_code=status.HTTP_201_CREATED)
def register_student(req: StudentRegisterRequest, db: Session = Depends(get_db)):
    # 1. Validate password confirmation
    if req.password != req.confirm_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Passwords do not match",
        )
    if len(req.password) < 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 4 characters long",
        )

    # 2. Check for duplicate email
    existing_email = db.query(User).filter(User.email == req.email.lower().strip()).first()
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email address already exists",
        )

    # The student joins exactly one school, identified by the code the school gives out.
    school = db.query(School).filter(func.lower(School.code) == req.school_code.strip().lower()).first()
    if not school:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unknown school code",
        )

    # 3. Check duplicate student ID / registration number (unique within a school)
    clean_student_id = req.student_id.strip()
    clean_reg_no = req.registration_number.strip()
    if clean_student_id:
        existing_sid = db.query(User).filter(User.student_id == clean_student_id, User.school_id == school.id).first()
        if existing_sid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Student ID '{clean_student_id}' is already registered",
            )

    if clean_reg_no:
        existing_reg = db.query(User).filter(User.registration_number == clean_reg_no, User.school_id == school.id).first()
        if existing_reg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Registration number '{clean_reg_no}' is already registered",
            )

    # 4. Create new Student User
    hashed = hash_password(req.password)
    new_user = User(
        email=req.email.lower().strip(),
        password_hash=hashed,
        full_name=req.name.strip(),
        department=req.department.strip(),
        student_id=clean_student_id,
        registration_number=clean_reg_no,
        role="student",
        school_id=school.id,
        approval_status="approved",
        is_active=True,
        is_verified=True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Seed default introductory enrollment for new student
    course1 = db.query(StudentCourse).filter(StudentCourse.id == 1).first()
    if course1:
        enrollment = StudentEnrollment(
            user_id=new_user.id,
            course_id=course1.id,
            status="enrolled",
            progress_pct=0.0,
            completed_modules=0,
            start_date=datetime.now(timezone.utc).strftime("%d %b %Y"),
            credits_earned=0,
        )
        db.add(enrollment)
        db.commit()

    # Welcome notification
    welcome_notif = StudentNotification(
        user_id=new_user.id,
        category="Academy",
        title="Welcome to SEEK Academy",
        description="Your institutional account is verified. Start your foundational SEEK course.",
        period_group="last_7_days",
    )
    db.add(welcome_notif)
    db.commit()

    token = create_user_token(new_user)

    return {
        "message": "Student account created successfully",
        "access_token": token,
        "token_type": "bearer",
        "data": {
            "id": new_user.id,
            "email": new_user.email,
            "full_name": new_user.full_name,
            "role": new_user.role,
            "department": new_user.department,
            "student_id": new_user.student_id,
            "registration_number": new_user.registration_number,
        },
    }


# ── 2. Student Dashboard ────────────────────────────────────────────────

@router.get("/dashboard")
def get_student_dashboard(
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    # Single SEEK course: every figure below is derived from live chapter completions.
    enrollments = db.query(StudentEnrollment).filter(StudentEnrollment.user_id == current_user.id).all()
    seek = get_seek_course(db)

    enrolled_active = [e for e in enrollments if e.status in ("enrolled", "completed")]
    pending_enrollments = [e for e in enrollments if e.status == "pending"]

    completed_ch, total_ch, fraction = (0, 0, 0.0)
    if seek:
        completed_ch, total_ch, fraction = _course_progress(db, current_user.id, seek.id)

    # Daily insights / recent activity: the chapters the student finished most recently.
    recent_rows = (
        db.query(StudentChapterCompletion, StudentCourseChapter)
        .join(StudentCourseChapter, StudentCourseChapter.id == StudentChapterCompletion.chapter_id)
        .filter(StudentChapterCompletion.user_id == current_user.id)
        .order_by(StudentChapterCompletion.completed_at.desc(), StudentChapterCompletion.id.desc())
        .limit(5)
        .all()
    )
    recent_activity = [
        {
            "chapter_id": ch.id,
            "course_id": ch.course_id,
            "title": ch.title,
            "module_title": ch.module_title,
            "chapter_type": ch.chapter_type,
            "completed_at": comp.completed_at.isoformat(),
        }
        for comp, ch in recent_rows
    ]

    study_minutes = sum(
        _minutes(ch.duration)
        for _, ch in db.query(StudentChapterCompletion, StudentCourseChapter)
        .join(StudentCourseChapter, StudentCourseChapter.id == StudentChapterCompletion.chapter_id)
        .filter(StudentChapterCompletion.user_id == current_user.id)
        .all()
    )
    credits_sum = sum(e.credits_earned for e in enrollments)
    cert_count = len([e for e in enrollments if e.status == "completed" or (e.progress_pct or 0) >= 1.0])

    return {
        "welcome_name": current_user.full_name,
        "streak_days": _learning_streak(db, current_user.id),
        "overall_completion_pct": int(round(fraction * 100)),
        "stats": {
            "certifications_ready": cert_count,
            "enrolled_courses": len(enrolled_active),
            "credits_earned": credits_sum,
            "enrollment_pending": len(pending_enrollments),
        },
        "chapters": {"completed": completed_ch, "total": total_ch},
        "recent_activity": recent_activity,
        "study_minutes": study_minutes,
        "study_hours": round(study_minutes / 60, 1),
    }


# ── 3. Courses Discovery & Academy ─────────────────────────────────────

@router.get("/courses")
def get_courses(
    search: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    seek = get_seek_course(db)
    if not seek:
        return []
    # There is exactly one SEEK course; its chapters carry the content.
    query = db.query(StudentCourse).filter(StudentCourse.id == seek.id)

    if search:
        s = f"%{search.strip().lower()}%"
        query = query.filter(
            (StudentCourse.title.ilike(s)) |
            (StudentCourse.description.ilike(s)) |
            (StudentCourse.category.ilike(s)) |
            (StudentCourse.department.ilike(s))
        )

    if category:
        query = query.filter(StudentCourse.category.ilike(f"%{category.strip()}%"))

    courses = query.order_by(StudentCourse.id.asc()).all()

    # Match student enrollment status
    enrollment_map = {
        e.course_id: e
        for e in db.query(StudentEnrollment).filter(StudentEnrollment.user_id == current_user.id).all()
    }

    results = []
    for c in courses:
        enr = enrollment_map.get(c.id)
        completed_ch, total_ch, progress = _course_progress(db, current_user.id, c.id)
        if enr:
            enr_status = enr.status  # enrolled, pending, completed
        else:
            enr_status = "not_enrolled"

        results.append({
            "id": c.id,
            "title": c.title,
            "provider": c.provider,
            "department": c.department,
            "category": c.category,
            "duration": c.duration,
            "rating": c.rating,
            "description": c.description,
            "what_you_will_learn": [line for line in (c.what_you_will_learn or "").split("\n") if line.strip()],
            "language": c.language,
            "certificate_available": c.certificate_available,
            "enrollment_deadline": c.enrollment_deadline,
            "deadline_remaining_text": c.deadline_remaining_text,
            "image_url": c.image_url,
            "enrollment_status": enr_status,
            "progress_pct": progress,
            "completed_chapters": completed_ch,
            "total_chapters": total_ch,
        })

    return results


# ── 4. Course Details ──────────────────────────────────────────────────

@router.get("/courses/{course_id}")
def get_course_detail(
    course_id: int,
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    course = db.query(StudentCourse).filter(StudentCourse.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    enr = db.query(StudentEnrollment).filter(
        StudentEnrollment.user_id == current_user.id,
        StudentEnrollment.course_id == course_id,
    ).first()

    status_str = enr.status if enr else "not_enrolled"
    completed_ch, total_ch, progress = _course_progress(db, current_user.id, course.id)

    return {
        "id": course.id,
        "title": course.title,
        "provider": course.provider,
        "department": course.department,
        "category": course.category,
        "duration": course.duration,
        "rating": course.rating,
        "description": course.description,
        "what_you_will_learn": [line for line in (course.what_you_will_learn or "").split("\n") if line.strip()],
        "language": course.language,
        "certificate_available": course.certificate_available,
        "enrollment_deadline": course.enrollment_deadline,
        "deadline_remaining_text": course.deadline_remaining_text,
        "image_url": course.image_url,
        "enrollment_status": status_str,
        "progress_pct": progress,
        "completed_chapters": completed_ch,
        "total_chapters": total_ch,
    }


@router.get("/courses/{course_id}/chapters")
def get_course_chapters(
    course_id: int,
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    if not db.query(StudentCourse).filter(StudentCourse.id == course_id).first():
        raise HTTPException(status_code=404, detail="Course not found")
    return _chapters_payload(db, current_user.id, course_id)


class ChapterCompletionRequest(BaseModel):
    completed: bool = True


@router.put("/chapters/{chapter_id}/completion")
def set_chapter_completion(
    chapter_id: int,
    req: ChapterCompletionRequest,
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    chapter = db.query(StudentCourseChapter).filter(StudentCourseChapter.id == chapter_id).first()
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")

    existing = db.query(StudentChapterCompletion).filter(
        StudentChapterCompletion.user_id == current_user.id,
        StudentChapterCompletion.chapter_id == chapter_id,
    ).first()
    if req.completed and not existing:
        db.add(StudentChapterCompletion(user_id=current_user.id, chapter_id=chapter_id))
        db.commit()
    elif not req.completed and existing:
        db.delete(existing)
        db.commit()

    was_done = (
        db.query(StudentEnrollment)
        .filter(StudentEnrollment.user_id == current_user.id,
                StudentEnrollment.course_id == chapter.course_id,
                StudentEnrollment.status == "completed")
        .first()
        is not None
    )
    enr = _sync_enrollment(db, current_user.id, chapter.course_id)
    if enr.status == "completed" and not was_done:
        course = db.query(StudentCourse).filter(StudentCourse.id == chapter.course_id).first()
        db.add(StudentNotification(
            user_id=current_user.id,
            category="Certificate Issued",
            title="Certificate ready",
            description=f"You completed {course.title if course else 'the course'}. View your certificate.",
            period_group="last_7_days",
        ))
        db.commit()
    return _chapters_payload(db, current_user.id, chapter.course_id)


# ── 5. Course Enrollment Action ────────────────────────────────────────

@router.post("/courses/{course_id}/enroll")
def enroll_in_course(
    course_id: int,
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    course = db.query(StudentCourse).filter(StudentCourse.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    enr = db.query(StudentEnrollment).filter(
        StudentEnrollment.user_id == current_user.id,
        StudentEnrollment.course_id == course_id,
    ).first()

    if enr and enr.status in ("enrolled", "completed"):
        return {
            "message": "Already enrolled in this course",
            "enrollment_status": enr.status,
            "course_id": course.id,
        }

    if not enr:
        enr = StudentEnrollment(
            user_id=current_user.id,
            course_id=course.id,
            status="enrolled",
            progress_pct=0.0,
            completed_modules=0,
            start_date=datetime.now(timezone.utc).strftime("%d %b %Y"),
        )
        db.add(enr)
    else:
        enr.status = "enrolled"

    # Also log notification
    notif = StudentNotification(
        user_id=current_user.id,
        category="Academy",
        title="Enrollment Confirmed",
        description=f"Successfully enrolled in {course.title}. Start learning your modules today.",
        period_group="last_7_days",
    )
    db.add(notif)
    db.commit()

    return {
        "message": f"Successfully enrolled in {course.title}",
        "enrollment_status": "enrolled",
        "course_id": course.id,
    }


# ── 6. Pending Courses Screen ──────────────────────────────────────────

@router.get("/pending-courses")
def get_pending_courses(
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    # Courses this user has requested but is not yet enrolled in.
    pending_ids = [
        e.course_id for e in db.query(StudentEnrollment).filter(
            StudentEnrollment.user_id == current_user.id,
            StudentEnrollment.status == "pending",
        ).all()
    ]
    courses = db.query(StudentCourse).filter(StudentCourse.id.in_(pending_ids)).all() if pending_ids else []

    enrollment_map = {
        e.course_id: e
        for e in db.query(StudentEnrollment).filter(StudentEnrollment.user_id == current_user.id).all()
    }

    results = []
    for c in courses:
        enr = enrollment_map.get(c.id)
        results.append({
            "id": c.id,
            "title": c.title,
            "provider": c.provider,
            "enrollment_status": enr.status if enr else "pending",
            "image_url": c.image_url,
        })
    return results


# ── 7. Course Progress Screen ──────────────────────────────────────────

@router.get("/progress")
def get_course_progress(
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    seek = get_seek_course(db)
    enrollments = db.query(StudentEnrollment).filter(
        StudentEnrollment.user_id == current_user.id,
        StudentEnrollment.status.in_(["enrolled", "completed"]),
        StudentEnrollment.course_id == (seek.id if seek else -1),
    ).all()

    progress_list = []
    for e in enrollments:
        course = db.query(StudentCourse).filter(StudentCourse.id == e.course_id).first()
        if course:
            comp_m, total_m, live_pct = _course_progress(db, current_user.id, course.id)
            progress_list.append({
                "course_id": course.id,
                "title": course.title,
                "provider": course.provider,
                "category": course.category,
                "progress_pct": live_pct,
                "completed_modules": comp_m,
                "total_modules": total_m,
                "completed_chapters": comp_m,
                "total_chapters": total_m,
                "remaining_modules": max(0, total_m - comp_m),
                "status": "Completed" if total_m and comp_m >= total_m else "In Progress",
                "image_url": course.image_url,
            })
    return progress_list


# ── 8. Certificates Screen ─────────────────────────────────────────────

@router.get("/certificates")
def get_student_certificates(
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    """Certificates exist only for courses the student has completed.

    A certificate is issued (once) for every enrollment that is completed
    (status "completed" or progress at 100%). Nothing is returned for
    courses still in progress.
    """
    completed = db.query(StudentEnrollment).filter(
        StudentEnrollment.user_id == current_user.id,
    ).all()
    completed = [e for e in completed if e.status == "completed" or (e.progress_pct or 0) >= 1.0]

    issued = []
    for enr in completed:
        course = db.query(StudentCourse).filter(StudentCourse.id == enr.course_id).first()
        if not course:
            continue
        cert_no = f"MED-C{course.id}-U{current_user.id}"
        cert = db.query(StudentCertificate).filter(
            StudentCertificate.user_id == current_user.id,
            StudentCertificate.certificate_no == cert_no,
        ).first()
        if not cert:
            when = datetime.now(timezone.utc)
            cert = StudentCertificate(
                user_id=current_user.id,
                title=course.title,
                certificate_no=cert_no,
                completed_date_str=f"COMPLETED {when.strftime('%b %Y').upper()}",
                issuing_institution=course.provider or "Academic Excellence Academy",
                badge_type="verified",
            )
            db.add(cert)
            db.commit()
            db.refresh(cert)
        issued.append(cert)

    issued.sort(key=lambda c: c.id, reverse=True)
    return [
        {
            "id": c.id,
            "title": c.title,
            "certificate_no": c.certificate_no,
            "completed_date_str": c.completed_date_str,
            "issuing_institution": c.issuing_institution,
            "badge_type": c.badge_type,
            "download_url": c.download_url or f"/certificates/download/{c.certificate_no}.pdf",
        }
        for c in issued
    ]


@router.post("/certificates/upload", status_code=status.HTTP_201_CREATED)
async def upload_certificate_document(
    file: UploadFile = File(...),
    current_user: User = Depends(get_institution_platform_user),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """
    Upload course completion certificate to Cloudinary under medal/certificates.
    Supports PDF and certificate badge images up to 15MB.
    """
    contents, verified_mime, ext = await validate_and_read_upload(
        file=file,
        allowed_types={"image/*", "application/pdf"},
        max_size_bytes=MAX_DOCUMENT_SIZE_BYTES,
    )
    res = await storage.upload_bytes(
        data=contents,
        filename=file.filename or f"certificate{ext}",
        folder="medal/certificates",
        content_type=verified_mime,
    )
    return {
        "message": "Certificate uploaded successfully",
        "download_url": res.secure_url,
        "public_id": res.public_id,
        "format": res.format,
    }


# ── 9. Notifications Screen ───────────────────────────────────────────

@router.get("/notifications")
def get_student_notifications(
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    notifs = db.query(StudentNotification).filter(
        StudentNotification.user_id == current_user.id
    ).order_by(StudentNotification.id.desc()).all()

    last_7 = []
    last_30 = []

    for n in notifs:
        item = {
            "id": n.id,
            "category": n.category,
            "title": n.title,
            "description": n.description,
            "is_read": n.is_read,
            "time_ago": _time_ago(n.created_at),
        }
        created = n.created_at if n.created_at.tzinfo else n.created_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) - created <= timedelta(days=7):
            last_7.append(item)
        else:
            last_30.append(item)

    return {
        "last_7_days": last_7,
        "last_30_days": last_30,
        "unread_count": sum(1 for n in notifs if not n.is_read),
    }


# ── 10. Student Profile Update ─────────────────────────────────────────

@router.patch("/profile")
def update_student_profile(
    req: StudentProfileUpdateRequest,
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    if req.phone is not None:
        current_user.phone = req.phone.strip() if req.phone.strip() else None
    if req.department is not None and req.department.strip():
        current_user.department = req.department.strip()
    if req.preferences is not None:
        current_user.preferences = req.preferences.strip()
    if req.name is not None and req.name.strip():
        current_user.full_name = req.name.strip()

    db.commit()
    db.refresh(current_user)

    return {
        "message": "Profile updated successfully",
        "data": {
            "id": current_user.id,
            "name": current_user.full_name,
            "email": current_user.email,
            "phone": current_user.phone,
            "department": current_user.department,
            "student_id": current_user.student_id,
            "registration_number": current_user.registration_number,
            "preferences": current_user.preferences,
            "study_hours": 7,
            "certificates_count": db.query(StudentCertificate).filter(StudentCertificate.user_id == current_user.id).count(),
        },
    }


# ── 11. Manage Password ───────────────────────────────────────────────

@router.post("/manage-password")
def change_student_password(
    req: PasswordChangeRequest,
    current_user: User = Depends(get_institution_platform_user),
    db: Session = Depends(get_db),
):
    if not verify_password(req.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    if len(req.new_password) < 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 4 characters long",
        )

    current_user.password_hash = hash_password(req.new_password)
    db.commit()

    return {"message": "Password updated successfully"}
