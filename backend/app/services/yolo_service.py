import io
import logging
import os
import time
from typing import List, Optional
from PIL import Image

from app.schemas.image_analysis import BoundingBox, DetectedObject

logger = logging.getLogger("medal.ml.yolo")

DEFAULT_MODEL_PATH = os.getenv("YOLO_MODEL_PATH", os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "models", "yolo26n.pt"))
DEFAULT_CLS_MODEL_PATH = os.getenv("YOLO_CLS_MODEL_PATH", os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "models", "yolo26n-cls.pt"))
DEFAULT_CONFIDENCE_THRESHOLD = float(os.getenv("YOLO_CONFIDENCE_THRESHOLD", "0.20"))
DEFAULT_IOU_THRESHOLD = float(os.getenv("YOLO_IOU_THRESHOLD", "0.45"))


class YOLOService:
    """
    Model abstraction wrapper for Ultralytics YOLO inference.
    Loads both YOLO object detection and scene classification models once during
    application lifecycle and reuses them across requests.
    """

    _instance: Optional["YOLOService"] = None

    def __init__(self, model_path: Optional[str] = None, cls_model_path: Optional[str] = None):
        self.model_path = model_path or DEFAULT_MODEL_PATH
        self.cls_model_path = cls_model_path or DEFAULT_CLS_MODEL_PATH
        self.model = None
        self.cls_model = None
        self.model_version = os.path.basename(self.model_path)
        self.load_model()

    @classmethod
    def get_instance(cls) -> "YOLOService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def load_model(self) -> None:
        try:
            from ultralytics import YOLO

            logger.info("Initializing YOLO detection model from %s", self.model_path)
            if not os.path.exists(self.model_path):
                os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
                try:
                    self.model = YOLO("yolo11n.pt")
                except Exception:
                    self.model = YOLO("yolov8n.pt")
                try:
                    self.model.save(self.model_path)
                except Exception:
                    pass
            else:
                self.model = YOLO(self.model_path)

            logger.info("YOLO detection model loaded: %s", self.model_version)

            # Load scene classification model
            logger.info("Initializing YOLO classification model from %s", self.cls_model_path)
            if os.path.exists(self.cls_model_path):
                self.cls_model = YOLO(self.cls_model_path)
                logger.info("YOLO classification model loaded: %s", os.path.basename(self.cls_model_path))
            else:
                logger.warning("Classification weights %s not found. Attempting base download...", self.cls_model_path)
                try:
                    self.cls_model = YOLO("yolo11n-cls.pt")
                    self.cls_model.save(self.cls_model_path)
                    logger.info("YOLO classification model loaded and saved.")
                except Exception as ex:
                    logger.warning("Could not load classification model: %s", ex)
                    self.cls_model = None

        except Exception as e:
            logger.error("Failed to load YOLO models: %s", e, exc_info=True)
            self.model = None
            self.cls_model = None

    def predict(
        self,
        image_bytes: bytes,
        confidence_threshold: Optional[float] = None,
        iou_threshold: Optional[float] = None,
    ) -> List[DetectedObject]:
        """
        Runs YOLO object detection and scene classification on raw image bytes.
        Returns discrete bounding-box detections plus high-confidence scene classes.
        """
        if self.model is None and self.cls_model is None:
            logger.warning("YOLO models are not initialized, attempting reload...")
            self.load_model()
            if self.model is None and self.cls_model is None:
                raise RuntimeError("YOLO models are unavailable on the server.")

        conf = confidence_threshold if confidence_threshold is not None else DEFAULT_CONFIDENCE_THRESHOLD
        iou = iou_threshold if iou_threshold is not None else DEFAULT_IOU_THRESHOLD

        # Read image safely using PIL
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        detections: List[DetectedObject] = []

        start_time = time.time()

        # 1. Run Object Detection
        if self.model is not None:
            try:
                results = self.model.predict(source=image, conf=conf, iou=iou, verbose=False)
                if results and len(results) > 0:
                    first_result = results[0]
                    boxes = first_result.boxes
                    if boxes is not None:
                        for box in boxes:
                            cls_id = int(box.cls[0].item())
                            box_conf = float(box.conf[0].item())
                            class_name = first_result.names.get(cls_id, f"class_{cls_id}")

                            xyxy = box.xyxy[0].tolist()
                            bbox = BoundingBox(
                                x1=round(xyxy[0], 2),
                                y1=round(xyxy[1], 2),
                                x2=round(xyxy[2], 2),
                                y2=round(xyxy[3], 2),
                            )

                            detections.append(
                                DetectedObject(
                                    class_name=class_name,
                                    confidence=round(box_conf, 2),
                                    bounding_box=bbox,
                                )
                            )
            except Exception as e:
                logger.warning("Detection inference error: %s", e)

        # 2. Run Scene Classification (provides scene context when discrete bounding boxes are scarce)
        if self.cls_model is not None:
            try:
                cls_results = self.cls_model.predict(source=image, verbose=False)
                if cls_results and len(cls_results) > 0:
                    first_cls = cls_results[0]
                    if hasattr(first_cls, "probs") and first_cls.probs is not None:
                        top5_indices = first_cls.probs.top5
                        top5_confs = first_cls.probs.top5conf.tolist()
                        for c_id, c_conf in zip(top5_indices, top5_confs):
                            # Include top predictions above 5% confidence
                            if c_conf >= 0.05:
                                scene_class = first_cls.names.get(c_id, f"class_{c_id}")
                                detections.append(
                                    DetectedObject(
                                        class_name=scene_class,
                                        confidence=round(float(c_conf), 2),
                                        bounding_box=None,
                                    )
                                )
            except Exception as e:
                logger.warning("Classification inference error: %s", e)

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("YOLO pipeline completed in %dms, generated %d detections/scene tags", duration_ms, len(detections))
        return detections
