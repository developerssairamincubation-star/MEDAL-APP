from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator


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
    location: Optional[str] = None
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0, description="Latitude between -90 and 90")
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0, description="Longitude between -180 and 180")
    location_address: Optional[str] = None
    image_url: Optional[str] = None
    image_public_id: Optional[str] = None
    sdg_alignment: Optional[str] = None
    impact_level: Optional[str] = None
    equity_classification: Optional[str] = None
    officer_notes: Optional[str] = None
    rejection_reason: Optional[str] = None

    @model_validator(mode="after")
    def validate_location(self) -> "ComplaintBase":
        has_location = bool(self.location and self.location.strip())
        has_address = bool(self.location_address and self.location_address.strip())
        has_coords = self.latitude is not None and self.longitude is not None
        if not (has_location or has_address or has_coords):
            raise ValueError("Location, address, or valid coordinates must be provided.")
        if not has_location:
            if has_address:
                self.location = self.location_address
            elif has_coords:
                self.location = f"{self.latitude}, {self.longitude}"
        if not has_address and has_location:
            self.location_address = self.location
        return self


class ComplaintCreate(ComplaintBase):
    pass


class ComplaintUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    location: Optional[str] = None
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    location_address: Optional[str] = None
    image_url: Optional[str] = None
    image_public_id: Optional[str] = None
    sdg_alignment: Optional[str] = None
    impact_level: Optional[str] = None
    equity_classification: Optional[str] = None
    officer_notes: Optional[str] = None
    rejection_reason: Optional[str] = None


class ComplaintStatusUpdate(BaseModel):
    status: str
    officer_notes: Optional[str] = Field(default=None, alias="officerNotes")
    rejection_reason: Optional[str] = Field(default=None, alias="rejectionReason")

    model_config = ConfigDict(populate_by_name=True)


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
    assigned: int = 0
    in_progress: int
    resolved: int
    rejected: int
    by_category: dict[str, int]


class EvidenceUploadResponse(BaseModel):
    image_url: str
    public_id: Optional[str] = None
    format: Optional[str] = None
    bytes: Optional[int] = None


class CommentCreate(BaseModel):
    comment: Optional[str] = None
    content: Optional[str] = None
    parent_comment_id: Optional[int] = None
    image_url: Optional[str] = None
    image_public_id: Optional[str] = None


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
    image_url: Optional[str] = None
    image_public_id: Optional[str] = None
    created_at: datetime
    parent_comment_id: Optional[int] = None
    is_deleted: bool = False

    model_config = ConfigDict(from_attributes=True)


