from datetime import datetime, timezone
from typing import Optional

# pyrefly: ignore [missing-import]
from sqlalchemy import Boolean, DateTime, Integer, String, func
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Mapped, mapped_column

from app.database.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    profile_image_url: Mapped[Optional[str]] = mapped_column(String, nullable=True, default=None)
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
    is_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
