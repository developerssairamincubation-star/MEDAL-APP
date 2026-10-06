from typing import Dict, List, Optional, Tuple
from app.schemas.image_analysis import CivicIssue, DetectedObject

ISSUE_LABELS: Dict[str, str] = {
    "waste_dumping": "Improper Waste Disposal",
    "road_damage": "Road / Pothole Damage",
    "water_pollution": "Water Contamination & Pollution",
    "water_leakage": "Water Supply Leakage",
    "air_pollution": "Air Pollution / Smoke",
    "streetlight_damage": "Streetlight / Electrical Hazard",
    "infrastructure_damage": "Public Infrastructure Damage",
    "tree_damage": "Tree / Greenery Hazard",
    "accessibility_issue": "Accessibility Obstacle",
    "public_safety": "Public Safety Hazard",
    "unknown": "Unable to determine",
}

# Future custom MEDAL model direct classes
CUSTOM_MEDAL_CLASSES = set(ISSUE_LABELS.keys()) - {"unknown"}

# Pretrained COCO object mappings with weights and minimum thresholds
WASTE_OBJECTS = {
    # COCO discrete objects
    "bottle": 1.0,
    "cup": 1.0,
    "banana": 0.8,
    "apple": 0.8,
    "sandwich": 0.9,
    "orange": 0.8,
    "broccoli": 0.8,
    "carrot": 0.8,
    "pizza": 0.9,
    "donut": 0.9,
    "cake": 0.9,
    "backpack": 0.85,  # Frequently marks garbage bags / sacks in civic waste piles
    "handbag": 0.85,
    "suitcase": 0.85,
    "bowl": 0.8,
    "wine glass": 0.8,
    "book": 0.7,
}

# Scene-level classes from YOLO classification (e.g. ImageNet)
SCENE_WASTE_CLASSES = {
    "ashcan": 1.0,         # Universal ImageNet class for garbage piles, dumpsters, waste heaps
    "garbage_truck": 0.95,
    "plastic_bag": 0.90,
    "packet": 0.85,
    "carton": 0.85,
    "bucket": 0.80,
    "barrel": 0.80,
    "rain_barrel": 0.80,
    "milk_can": 0.80,
    "mailbag": 0.75,
    "water_bottle": 0.90,
    "wine_bottle": 0.90,
    "beer_bottle": 0.90,
    "pop_bottle": 0.90,
    "pill_bottle": 0.85,
    "bottlecap": 0.85,
    "crate": 0.80,
}

SCENE_ROAD_CLASSES = {
    "volcano": 0.88,       # Craters, deep asphalt potholes, circular depressions
    "sandbar": 0.82,       # Broken unpaved surfaces, gravel/mud road trenches
    "cliff": 0.78,         # Fractured asphalt edges, pavement dropoffs
    "cliff_dwelling": 0.75,
    "crater": 0.88,
    "stone_wall": 0.70,
    "maze": 0.70,
    "streetcar": 0.75,
}

INFRASTRUCTURE_OBJECTS = {
    "traffic light": 1.0,
    "traffic_light": 1.0,
    "stop sign": 1.0,
    "fire hydrant": 1.0,
    "parking meter": 0.9,
    "parking_meter": 0.9,
    "bench": 0.8,
    "street_sign": 0.85,
    "pole": 0.80,
    "flagpole": 0.75,
    "table_lamp": 0.80,
    "lampshade": 0.75,
}

ROAD_VEHICLE_OBJECTS = {
    "car": 0.7,
    "truck": 0.7,
    "bus": 0.7,
    "motorcycle": 0.7,
    "bicycle": 0.6,
}

WATER_CLASSES = {
    "fountain": 0.85,
    "geyser": 0.85,
    "dam": 0.80,
    "lakeside": 0.75,
    "canoe": 0.75,
}

GREENERY_OBJECTS = {
    "potted plant": 0.9,
    "tree_frog": 0.8,
}


class CivicIssueService:
    """
    Converts YOLO detections and scene tags into MEDAL civic issue categories.
    
    Supports:
    1. Custom-trained MEDAL YOLO models (direct civic issue classes).
    2. Scene-level YOLO classification (e.g. ashcan -> waste dumping, volcano -> road damage).
    3. Multi-object heuristic detection clustering.
    """

    @classmethod
    def classify_detections(
        cls,
        detections: List[DetectedObject],
        confidence_threshold: float = 0.20,
    ) -> CivicIssue:
        if not detections:
            return cls._unknown_issue()

        # 1. Check for custom MEDAL classes (direct model inference)
        custom_matches = [
            d for d in detections
            if d.class_name.lower().replace(" ", "_") in CUSTOM_MEDAL_CLASSES
            and d.confidence >= confidence_threshold
        ]
        if custom_matches:
            best_custom = max(custom_matches, key=lambda d: d.confidence)
            cat = best_custom.class_name.lower().replace(" ", "_")
            return CivicIssue(
                label=ISSUE_LABELS.get(cat, cat.replace("_", " ").title()),
                category=cat,
                confidence=round(best_custom.confidence, 2),
            )

        # 2. Scene Classification / Heuristic Analysis
        # A: Waste Dumping (ashcan, plastic bags, bottles, cartons, or COCO waste items)
        scene_waste = [
            d for d in detections
            if d.class_name.lower().replace(" ", "_") in SCENE_WASTE_CLASSES
            and d.confidence >= 0.15
        ]
        coco_waste = [
            d for d in detections
            if d.class_name.lower() in WASTE_OBJECTS and d.confidence >= confidence_threshold
        ]

        if scene_waste or coco_waste:
            if scene_waste:
                best_scene = max(scene_waste, key=lambda d: d.confidence)
                cls_clean = best_scene.class_name.lower().replace(" ", "_")
                weight = SCENE_WASTE_CLASSES.get(cls_clean, 0.85)
                # If it's ashcan (garbage/refuse), confidence is very high
                if cls_clean == "ashcan":
                    final_conf = round(min(0.98, max(0.85, best_scene.confidence)), 2)
                else:
                    final_conf = round(min(0.95, max(0.72, best_scene.confidence * weight)), 2)
                return CivicIssue(
                    label=ISSUE_LABELS["waste_dumping"],
                    category="waste_dumping",
                    confidence=final_conf,
                )
            elif len(coco_waste) >= 2 or (len(coco_waste) == 1 and coco_waste[0].confidence >= 0.35):
                avg_conf = sum(d.confidence for d in coco_waste) / len(coco_waste)
                cluster_boost = min(0.12, (len(coco_waste) - 1) * 0.04)
                final_conf = round(min(0.96, max(0.72, avg_conf + cluster_boost)), 2)
                return CivicIssue(
                    label=ISSUE_LABELS["waste_dumping"],
                    category="waste_dumping",
                    confidence=final_conf,
                )

        # B: Road / Pothole Damage
        # Scene classes (volcano, sandbar, cliff) indicate cratered or fractured road surfaces
        scene_road = [
            d for d in detections
            if d.class_name.lower().replace(" ", "_") in SCENE_ROAD_CLASSES
            and d.confidence >= 0.08
        ]
        if scene_road:
            best_road = max(scene_road, key=lambda d: d.confidence)
            cls_clean = best_road.class_name.lower().replace(" ", "_")
            weight = SCENE_ROAD_CLASSES.get(cls_clean, 0.80)
            # Normalize confidence for crater/depression scene matches
            final_conf = round(min(0.92, max(0.75, best_road.confidence * 2.0 * weight)), 2)
            return CivicIssue(
                label=ISSUE_LABELS["road_damage"],
                category="road_damage",
                confidence=final_conf,
            )

        # C: Infrastructure / Streetlight
        infra_detections = [
            d for d in detections
            if (d.class_name.lower() in INFRASTRUCTURE_OBJECTS or d.class_name.lower().replace(" ", "_") in INFRASTRUCTURE_OBJECTS)
            and d.confidence >= confidence_threshold
        ]
        if infra_detections:
            best_infra = max(infra_detections, key=lambda d: d.confidence)
            cls_lower = best_infra.class_name.lower().replace("_", " ")
            if cls_lower in ("traffic light", "table lamp", "lampshade"):
                cat = "streetlight_damage"
            else:
                cat = "infrastructure_damage"
            return CivicIssue(
                label=ISSUE_LABELS[cat],
                category=cat,
                confidence=round(min(0.94, max(0.70, best_infra.confidence * 0.90)), 2),
            )

        # D: Water Supply / Pollution
        water_detections = [
            d for d in detections
            if d.class_name.lower().replace(" ", "_") in WATER_CLASSES
            and d.confidence >= 0.15
        ]
        if water_detections:
            best_water = max(water_detections, key=lambda d: d.confidence)
            cls_clean = best_water.class_name.lower().replace(" ", "_")
            cat = "water_leakage" if cls_clean in ("fountain", "geyser") else "water_pollution"
            return CivicIssue(
                label=ISSUE_LABELS[cat],
                category=cat,
                confidence=round(min(0.90, max(0.70, best_water.confidence * 0.85)), 2),
            )

        # E: Tree / Greenery hazard
        greenery_detections = [
            d for d in detections
            if (d.class_name.lower() in GREENERY_OBJECTS or d.class_name.lower().replace(" ", "_") in GREENERY_OBJECTS)
            and d.confidence >= 0.45
        ]
        if greenery_detections:
            best_green = max(greenery_detections, key=lambda d: d.confidence)
            return CivicIssue(
                label=ISSUE_LABELS["tree_damage"],
                category="tree_damage",
                confidence=round(best_green.confidence * 0.88, 2),
            )

        # F: Road context with multiple vehicles
        road_vehicles = [
            d for d in detections
            if d.class_name.lower() in ROAD_VEHICLE_OBJECTS and d.confidence >= 0.50
        ]
        if len(road_vehicles) >= 2:
            avg_conf = sum(d.confidence for d in road_vehicles) / len(road_vehicles)
            return CivicIssue(
                label=ISSUE_LABELS["road_damage"],
                category="road_damage",
                confidence=round(min(0.85, avg_conf * 0.85), 2),
            )

        # If no heuristic reliably matches, return unknown instead of inventing a prediction
        return cls._unknown_issue()

    @staticmethod
    def _unknown_issue() -> CivicIssue:
        return CivicIssue(
            label=ISSUE_LABELS["unknown"],
            category="unknown",
            confidence=0.0,
        )
