from typing import Dict, List
from app.schemas.image_analysis import SDGSuggestion

# Centralized SDG Mapping Configuration aligned with UN Sustainable Development Goals
SDG_MAPPING: Dict[str, List[Dict[str, any]]] = {
    "waste_dumping": [
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.97},
        {"id": 12, "name": "Responsible Consumption and Production", "relevance_factor": 0.93},
    ],
    "road_damage": [
        {"id": 9, "name": "Industry, Innovation and Infrastructure", "relevance_factor": 0.96},
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.91},
    ],
    "water_pollution": [
        {"id": 6, "name": "Clean Water and Sanitation", "relevance_factor": 0.98},
        {"id": 14, "name": "Life Below Water", "relevance_factor": 0.92},
    ],
    "water_leakage": [
        {"id": 6, "name": "Clean Water and Sanitation", "relevance_factor": 0.96},
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.90},
    ],
    "air_pollution": [
        {"id": 3, "name": "Good Health and Well-being", "relevance_factor": 0.94},
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.91},
        {"id": 13, "name": "Climate Action", "relevance_factor": 0.88},
    ],
    "tree_damage": [
        {"id": 13, "name": "Climate Action", "relevance_factor": 0.93},
        {"id": 15, "name": "Life on Land", "relevance_factor": 0.96},
    ],
    "accessibility_issue": [
        {"id": 10, "name": "Reduced Inequalities", "relevance_factor": 0.95},
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.92},
    ],
    "streetlight_damage": [
        {"id": 7, "name": "Affordable and Clean Energy", "relevance_factor": 0.94},
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.90},
    ],
    "infrastructure_damage": [
        {"id": 9, "name": "Industry, Innovation and Infrastructure", "relevance_factor": 0.97},
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.92},
    ],
    "public_safety": [
        {"id": 11, "name": "Sustainable Cities and Communities", "relevance_factor": 0.93},
        {"id": 16, "name": "Peace, Justice and Strong Institutions", "relevance_factor": 0.90},
    ],
}


class SDGMappingService:
    """
    Engine to map identified civic issues to relevant UN Sustainable Development Goals.
    Calculates SDG confidence as a function of the issue confidence and domain relevance factor.
    """

    @staticmethod
    def map_issue_to_sdgs(category: str, issue_confidence: float) -> List[SDGSuggestion]:
        if not category or category == "unknown" or issue_confidence <= 0.0:
            return []

        targets = SDG_MAPPING.get(category, [])
        suggestions: List[SDGSuggestion] = []

        for target in targets:
            rel_factor = target.get("relevance_factor", 0.90)
            # SDG confidence: scaled by relevance factor, bounded between 0.50 and 0.98
            calculated_conf = round(min(0.98, max(0.50, issue_confidence * rel_factor)), 2)
            suggestions.append(
                SDGSuggestion(
                    id=target["id"],
                    name=target["name"],
                    confidence=calculated_conf,
                )
            )

        # Sort descending by confidence
        suggestions.sort(key=lambda s: s.confidence, reverse=True)
        return suggestions
