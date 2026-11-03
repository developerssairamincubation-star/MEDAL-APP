from datetime import datetime, timezone
from typing import Optional

# pyrefly: ignore [missing-import]
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, event, func, inspect
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Mapped, mapped_column

from app.database.database import Base


class School(Base):
    """A tenant of the institution platform. Every principal / teacher / student belongs to one."""
    __tablename__ = "schools"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    profile_image_url: Mapped[Optional[str]] = mapped_column(String, nullable=True, default=None)
    profile_image_public_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, default=None)
    role: Mapped[str] = mapped_column(String, nullable=False, default="citizen")
    approval_status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="approved",
        server_default="approved",
        index=True,
    )
    designation: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    department: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    jurisdiction: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    clearance_level: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    student_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    registration_number: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    preferences: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    # Institution roles (principal / staff / student) belong to exactly one school; others have none.
    school_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("schools.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    # For students: the teacher (staff user) they were added under. NULL for everyone else and for
    # students who registered themselves with a school code.
    teacher_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # Bumped to invalidate every token issued before (logout, password change, role change, ...).
    token_version: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    is_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )


@event.listens_for(User, "before_update")
def _revoke_tokens_on_security_change(mapper, connection, user: User) -> None:
    """Bump token_version whenever something that should end existing sessions changes.

    Covers every code path (API, scripts): password change/reset, role change,
    deactivation, and an authority being rejected / un-approved.
    """
    attrs = inspect(user).attrs
    if attrs.token_version.history.has_changes():
        return  # already bumped explicitly (e.g. logout)
    if (
        attrs.password_hash.history.has_changes()
        or attrs.role.history.has_changes()
        or (attrs.is_active.history.has_changes() and not user.is_active)
        or (attrs.approval_status.history.has_changes() and user.approval_status != "approved")
    ):
        user.token_version = (user.token_version or 0) + 1
