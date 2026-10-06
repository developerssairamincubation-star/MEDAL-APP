from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class SdgAnalysisRequest(BaseModel):
    subject: Optional[str] = ""
    category: Optional[str] = ""
    description: str
    image_url: Optional[str] = None


class SdgAnalysisResponse(BaseModel):
    primary_sdg: int = Field(..., ge=1, le=17, description="Recommended primary UN SDG (1-17)")
    primary_sdg_name: str = Field(..., description="Full SDG name")
    secondary_sdgs: List[int] = Field(default_factory=list, description="Zero or more secondary SDGs (1-17)")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence score between 0 and 1")
    reason: str = Field(..., description="Short explanation of why the SDG was selected")



class ComplaintBase(BaseModel):
    title: str
    description: str
    category: str
    location: str
    image_url: Optional[str] = None
    sdg_alignment: Optional[str] = None
    impact_level: Optional[str] = None
    equity_classification: Optional[str] = None


class ComplaintCreate(ComplaintBase):
    pass


class ComplaintUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    location: Optional[str] = None
    image_url: Optional[str] = None
    sdg_alignment: Optional[str] = None
    impact_level: Optional[str] = None
    equity_classification: Optional[str] = None


class ComplaintStatusUpdate(BaseModel):
    status: str


class ComplaintResponse(ComplaintBase):
    id: int
    status: str
    citizen_id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ComplaintFeedItem(ComplaintBase):
    id: int
    status: str
    created_at: datetime
    citizen_name: str
    citizen_initials: str
    citizen_id: Optional[int] = None
    profile_image_url: Optional[str] = None
    upvotes_count: int = 0
    comments_count: int = 0
    reposts_count: int = 0
    has_reposted: bool = False

    model_config = ConfigDict(from_attributes=True)


class UpvoteResponse(BaseModel):
    complaint_id: int
    total_upvotes: int
    has_upvoted: bool


class RepostResponse(BaseModel):
    complaint_id: int
    total_reposts: int
    has_reposted: bool


class ComplaintStatsResponse(BaseModel):
    total_reports: int
    submitted: int
    under_review: int
    in_progress: int
    resolved: int
    rejected: int
    by_category: dict[str, int]


class CommentCreate(BaseModel):
    comment: Optional[str] = None
    content: Optional[str] = None
    parent_comment_id: Optional[int] = None


class CommentResponse(BaseModel):
    id: int
    complaint_id: int
    user_id: int
    user_name: str
    username: Optional[str] = None
    user_initials: str
    profile_image_url: Optional[str] = None
    comment: str
    content: Optional[str] = None
    created_at: datetime
    parent_comment_id: Optional[int] = None
    is_deleted: bool = False

    model_config = ConfigDict(from_attributes=True)


