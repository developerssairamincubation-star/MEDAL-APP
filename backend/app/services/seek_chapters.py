"""Chapter data source for the single SEEK course.

Chapters live in the ``student_course_chapters`` table. They are loaded from
``data/seek_course_chapters.json`` at startup (upsert by course + key), so the
content and links can be changed by editing that file or the table directly.
"""
import json
import logging
import os
from typing import Optional

from sqlalchemy.orm import Session

from app.database.database import Base, engine
from app.models.student import (
    StudentCertificate,
    StudentChapterCompletion,
    StudentCourse,
    StudentCourseChapter,
    StudentEnrollment,
    StudentNotification,
)

logger = logging.getLogger("medal.seek")

SEED_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "data",
    "seek_course_chapters.json",
)


def get_seek_course(db: Session) -> Optional[StudentCourse]:
    """The one SEEK course shown to students: the lowest-id course."""
    return db.query(StudentCourse).order_by(StudentCourse.id.asc()).first()


def _total_duration(chapters) -> str:
    """Sum the "N mins" chapter durations into a readable course length."""
    minutes = 0
    for ch in chapters:
        digits = "".join(c for c in str(ch.get("duration", "")).split(" ")[0] if c.isdigit())
        minutes += int(digits) if digits else 0
    hours, mins = divmod(minutes, 60)
    if not minutes:
        return ""
    return f"{hours}h {mins}m" if hours and mins else (f"{hours}h" if hours else f"{mins}m")


def _upsert_course(db: Session, data: dict) -> Optional[StudentCourse]:
    """Create or update the SEEK course from the data file's "course" block."""
    info = data.get("course")
    course_id = data.get("course_id")
    course = None
    if course_id is not None:
        course = db.query(StudentCourse).filter(StudentCourse.id == course_id).first()
    course = course or get_seek_course(db)
    if not info:
        return course
    chapters = data.get("chapters", [])
    if not course:
        course = StudentCourse(
            id=course_id,
            title=info["title"],
            department=info.get("department", "SEEK Programme"),
            description=info.get("description", ""),
        )
        db.add(course)
    course.title = info["title"]
    course.provider = info.get("provider", course.provider)
    course.department = info.get("department", course.department)
    course.category = info.get("category", course.category)
    course.language = info.get("language", course.language)
    course.certificate_available = bool(info.get("certificate_available", True))
    course.description = info.get("description", course.description)
    course.what_you_will_learn = "\n".join(info.get("what_you_will_learn", []))
    course.duration = _total_duration(chapters)
    course.total_modules = len({int(c.get("module", 1)) for c in chapters}) or course.total_modules
    # Nothing here is a real figure for this course, so none is shown.
    course.rating = 0.0
    course.enrollment_deadline = None
    course.deadline_remaining_text = None
    course.image_url = None
    db.commit()
    db.refresh(course)
    return course


def load_chapters(db: Session, path: str = SEED_FILE) -> int:
    if not os.path.exists(path):
        return 0
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    course = _upsert_course(db, data)
    if not course:
        return 0
    count = 0
    for idx, ch in enumerate(data.get("chapters", [])):
        key = str(ch["key"])
        row = db.query(StudentCourseChapter).filter(
            StudentCourseChapter.course_id == course.id,
            StudentCourseChapter.chapter_key == key,
        ).first()
        if not row:
            row = StudentCourseChapter(course_id=course.id, chapter_key=key, title=ch["title"])
            db.add(row)
        row.position = idx
        row.module_number = int(ch.get("module", 1))
        row.module_title = ch.get("module_title", "")
        row.title = ch["title"]
        row.chapter_type = ch.get("type", "reading")
        row.duration = ch.get("duration", "")
        row.content_url = ch.get("url")
        count += 1
    db.commit()
    return count


def init_chapters() -> None:
    """Create the student/course tables if needed and load the seed file. Never raises."""
    from app.database.database import SessionLocal

    try:
        Base.metadata.create_all(
            bind=engine,
            tables=[
                StudentCourse.__table__,
                StudentEnrollment.__table__,
                StudentCertificate.__table__,
                StudentNotification.__table__,
                StudentCourseChapter.__table__,
                StudentChapterCompletion.__table__,
            ],
        )
        db = SessionLocal()
        try:
            logger.info("SEEK chapters loaded: %s", load_chapters(db))
        finally:
            db.close()
    except Exception:
        logger.exception("Could not initialise SEEK chapters")
