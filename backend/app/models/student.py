from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.database import Base


class StudentCourse(Base):
    __tablename__ = "student_courses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    provider: Mapped[str] = mapped_column(String(128), default="UNESCO", nullable=False)
    department: Mapped[str] = mapped_column(String(128), nullable=False)
    category: Mapped[str] = mapped_column(String(64), default="SEEK", nullable=False)  # SDG 15, EMPATHY, LEADERSHIP, MINDFULNESS, SEEK
    duration: Mapped[str] = mapped_column(String(64), default="4 Weeks", nullable=False)
    rating: Mapped[float] = mapped_column(Float, default=4.8, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    what_you_will_learn: Mapped[str] = mapped_column(Text, nullable=True)  # JSON or newline-separated points
    language: Mapped[str] = mapped_column(String(64), default="English", nullable=False)
    certificate_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    enrollment_deadline: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    deadline_remaining_text: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    total_modules: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )


class StudentEnrollment(Base):
    __tablename__ = "student_enrollments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    course_id: Mapped[int] = mapped_column(Integer, ForeignKey("student_courses.id", ondelete="CASCADE"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(32), default="enrolled", nullable=False)  # enrolled, pending, completed
    progress_pct: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    completed_modules: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    start_date: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    end_date: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    credits_earned: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )

    course: Mapped["StudentCourse"] = relationship("StudentCourse")


class StudentCertificate(Base):
    __tablename__ = "student_certificates"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    certificate_no: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    completed_date_str: Mapped[str] = mapped_column(String(64), nullable=False)  # e.g., "COMPLETED MAY 2024"
    issuing_institution: Mapped[str] = mapped_column(String(128), default="Academic Excellence Academy", nullable=False)
    badge_type: Mapped[str] = mapped_column(String(64), default="verified", nullable=False)  # verified, star
    download_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )


class StudentNotification(Base):
    __tablename__ = "student_notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(64), nullable=False)  # Academy, Certificate, Streak, Learning Spree
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    period_group: Mapped[str] = mapped_column(String(32), default="last_7_days", nullable=False)  # last_7_days, last_30_days
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
