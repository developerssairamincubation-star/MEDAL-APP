from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field


class AuthorityRegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    official_email: EmailStr
    password: str = Field(..., min_length=6, max_length=128)
    official_phone: Optional[str] = Field(None, max_length=64)
    designation: str = Field(..., min_length=2, max_length=255)
    department: str = Field(..., min_length=2, max_length=255)
    jurisdiction: str = Field(..., min_length=2, max_length=255)
    identity_number: Optional[str] = Field(None, max_length=64)
    clearance_level: str = Field(
        default="Level 2 (Inspection & Resolution Lead)",
        max_length=128,
    )
    aadhaar_document_url: str = Field(..., min_length=5, max_length=1024)
    employment_document_url: str = Field(..., min_length=5, max_length=1024)


class AuthorityApplicationResponse(BaseModel):
    id: int
    user_id: int
    full_name: str
    official_email: str
    official_phone: Optional[str] = None
    designation: str
    department: str
    jurisdiction: str
    identity_number: Optional[str] = None
    clearance_level: str
    aadhaar_document_url: str
    employment_document_url: str
    status: str
    rejection_reason: Optional[str] = None
    reviewed_by_id: Optional[int] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AuthorityRegisterResponse(BaseModel):
    message: str
    reference_id: str
    status: str
    data: AuthorityApplicationResponse


class ApproveApplicationRequest(BaseModel):
    clearance_level: Optional[str] = None


class RejectApplicationRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=1000)


class DocumentUploadResponse(BaseModel):
    message: str
    document_url: str
    filename: str
