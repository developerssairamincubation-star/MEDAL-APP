from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.database import Base
from app.models.user import User


class Complaint(Base):
    __tablename__ = "complaints"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="submitted")
    location: Mapped[str] = mapped_column(String, nullable=False)
    image_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    sdg_alignment: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    impact_level: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    equity_classification: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    citizen_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
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

    # Relationship to User
    citizen: Mapped["User"] = relationship("User")
    # Relationship to Upvotes
    upvotes: Mapped[List["ComplaintUpvote"]] = relationship("ComplaintUpvote", back_populates="complaint", cascade="all, delete-orphan")
    # Relationship to Comments
    comments: Mapped[List["ComplaintComment"]] = relationship("ComplaintComment", back_populates="complaint", cascade="all, delete-orphan", order_by="ComplaintComment.created_at.asc()")


class ComplaintUpvote(Base):
    __tablename__ = "complaint_upvotes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    complaint_id: Mapped[int] = mapped_column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )

    __table_args__ = (
        UniqueConstraint("user_id", "complaint_id", name="uq_user_complaint_upvote"),
    )

    complaint: Mapped["Complaint"] = relationship("Complaint", back_populates="upvotes")
    user: Mapped["User"] = relationship("User")


class ComplaintComment(Base):
    __tablename__ = "complaint_comments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    complaint_id: Mapped[int] = mapped_column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    parent_comment_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("complaint_comments.id", ondelete="CASCADE"), nullable=True, index=True)
    comment: Mapped[str] = mapped_column(Text, nullable=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )

    complaint: Mapped["Complaint"] = relationship("Complaint", back_populates="comments")
    user: Mapped["User"] = relationship("User")
    parent: Mapped[Optional["ComplaintComment"]] = relationship("ComplaintComment", remote_side=[id], back_populates="replies")
    replies: Mapped[List["ComplaintComment"]] = relationship("ComplaintComment", back_populates="parent", cascade="all, delete-orphan", order_by="ComplaintComment.created_at.asc()")


