import logging
import mimetypes
from typing import Optional
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.models.user import User
from app.routers.auth import get_optional_current_user
from app.schemas.image_analysis import ImageAnalysisResponse
from app.services.image_analysis_service import ImageAnalysisService

logger = logging.getLogger("medal.ml.api")

router = APIRouter(prefix="/api/v1/ml", tags=["ML Analysis"])

MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/bmp",
    "image/gif",
}


@router.post(
    "/analyze-image",
    response_model=ImageAnalysisResponse,
    status_code=status.HTTP_200_OK,
    summary="Analyze civic evidence image with YOLO & map to SDGs",
)
async def analyze_image(
    image: UploadFile = File(..., description="Evidence image file for civic issue and SDG analysis"),
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    """
    Analyzes an uploaded grievance evidence photo using YOLO computer vision.
    Extracts detected objects, determines likely civic issue category, and suggests
    relevant UN Sustainable Development Goals (SDGs).
    """
    user_info = f"user {current_user.id} ({current_user.email})" if current_user else "anonymous citizen"
    logger.info("Analysis request received from %s", user_info)

    # 1. Validate MIME type
    content_type = image.content_type
    if not content_type or content_type in ("application/octet-stream", "binary/octet-stream"):
        guessed_type, _ = mimetypes.guess_type(image.filename or "")
        if guessed_type:
            content_type = guessed_type

    if not content_type or not content_type.startswith("image/"):
        logger.warning("Rejected file upload with invalid content-type: %s", content_type)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file format. Please upload a valid image (JPEG, PNG, WEBP).",
        )

    # 2. Read image safely and validate file size
    try:
        contents = await image.read()
    except Exception as e:
        logger.error("Failed to read image contents: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to read the uploaded image.",
        )

    if len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The uploaded image file is empty.",
        )

    if len(contents) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image size exceeds maximum limit of {MAX_IMAGE_SIZE_BYTES // (1024 * 1024)}MB.",
        )

    logger.info("Image validated successfully: %d bytes, mime: %s", len(contents), content_type)

    # 3. Execute analysis pipeline
    analysis_service = ImageAnalysisService()
    result = analysis_service.analyze_image(contents)

    logger.info(
        "Analysis completed. Category: %s, Suggestions: %d",
        result.analysis.issue.category,
        len(result.analysis.sdgs),
    )
    return result
