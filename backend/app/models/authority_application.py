from datetime import datetime, timezone
from typing import Optional

# pyrefly: ignore [missing-import]
from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.database import Base


class AuthorityApplication(Base):
    __tablename__ = "authority_applications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    official_email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    official_phone: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    designation: Mapped[str] = mapped_column(String(255), nullable=False)
    department: Mapped[str] = mapped_column(String(255), nullable=False)
    jurisdiction: Mapped[str] = mapped_column(String(255), nullable=False)
    identity_number: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    clearance_level: Mapped[str] = mapped_column(
        String(128),
        nullable=False,
        default="Level 2 (Inspection & Resolution Lead)",
        server_default="Level 2 (Inspection & Resolution Lead)",
    )
    aadhaar_document_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    aadhaar_public_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    employment_document_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    employment_public_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="pending",
        server_default="pending",
        index=True,
    )
    rejection_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    reviewed_by_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    user = relationship("User", foreign_keys=[user_id], backref="authority_applications")
    reviewed_by = relationship("User", foreign_keys=[reviewed_by_id])
