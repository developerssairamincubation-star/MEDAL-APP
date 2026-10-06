from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    x1: float
    y1: float
    x2: float
    y2: float


class DetectedObject(BaseModel):
    class_name: str = Field(..., alias="class", serialization_alias="class")
    confidence: float
    bounding_box: Optional[BoundingBox] = None

    class Config:
        populate_by_name = True


class SDGSuggestion(BaseModel):
    id: int
    name: str
    confidence: float


class CivicIssue(BaseModel):
    label: str
    category: str
    confidence: float


class AnalysisData(BaseModel):
    issue: CivicIssue
    detections: List[DetectedObject]
    sdgs: List[SDGSuggestion]


class ImageAnalysisResponse(BaseModel):
    success: bool
    analysis: AnalysisData
    message: str
