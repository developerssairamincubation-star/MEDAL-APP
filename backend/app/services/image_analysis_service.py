import logging
from typing import Optional, Tuple
from app.schemas.image_analysis import (
    AnalysisData,
    CivicIssue,
    ImageAnalysisResponse,
)
from app.services.civic_issue_service import CivicIssueService
from app.services.sdg_mapping_service import SDGMappingService
from app.services.yolo_service import YOLOService

logger = logging.getLogger("medal.ml.pipeline")


class ImageAnalysisService:
    """
    Orchestration service combining YOLO object detection,
    civic issue classification, and SDG mapping.
    """

    def __init__(self, yolo_service: Optional[YOLOService] = None):
        self.yolo_service = yolo_service or YOLOService.get_instance()

    def analyze_image(self, image_bytes: bytes) -> ImageAnalysisResponse:
        logger.info("Image analysis pipeline started")

        try:
            # Step 1: Run YOLO object detection
            detections = self.yolo_service.predict(image_bytes)
        except Exception as e:
            logger.error("YOLO inference failed: %s", e, exc_info=True)
            # Return unknown state gracefully rather than failing hard
            return ImageAnalysisResponse(
                success=True,
                analysis=AnalysisData(
                    issue=CivicIssue(
                        label="Unable to determine",
                        category="unknown",
                        confidence=0.0,
                    ),
                    detections=[],
                    sdgs=[],
                ),
                message="The image could not be confidently classified. Please select the SDG manually.",
            )

        # Step 2: Determine civic issue category
        issue = CivicIssueService.classify_detections(detections)
        logger.info("Civic issue determined: %s (confidence: %.2f)", issue.category, issue.confidence)

        # Step 3: Map issue to SDGs
        sdgs = SDGMappingService.map_issue_to_sdgs(issue.category, issue.confidence)
        logger.info("Generated %d SDG suggestions", len(sdgs))

        if issue.category == "unknown" or not sdgs:
            return ImageAnalysisResponse(
                success=True,
                analysis=AnalysisData(
                    issue=issue,
                    detections=detections,
                    sdgs=[],
                ),
                message="The image could not be confidently classified. Please select the SDG manually.",
            )

        return ImageAnalysisResponse(
            success=True,
            analysis=AnalysisData(
                issue=issue,
                detections=detections,
                sdgs=sdgs,
            ),
            message="Image analyzed successfully",
        )
