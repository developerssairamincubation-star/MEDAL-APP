import base64
import json
import logging
import os
import re
from typing import Any, Dict, List, Optional
import httpx
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

SDG_CATALOG: Dict[int, str] = {
    1: "SDG 1: No Poverty",
    2: "SDG 2: Zero Hunger",
    3: "SDG 3: Good Health and Well-being",
    4: "SDG 4: Quality Education",
    5: "SDG 5: Gender Equality",
    6: "SDG 6: Clean Water and Sanitation",
    7: "SDG 7: Affordable and Clean Energy",
    8: "SDG 8: Decent Work and Economic Growth",
    9: "SDG 9: Industry, Innovation and Infrastructure",
    10: "SDG 10: Reduced Inequalities",
    11: "SDG 11: Sustainable Cities and Communities",
    12: "SDG 12: Responsible Consumption and Production",
    13: "SDG 13: Climate Action",
    14: "SDG 14: Life Below Water",
    15: "SDG 15: Life on Land",
    16: "SDG 16: Peace, Justice and Strong Institutions",
    17: "SDG 17: Partnerships for the Goals",
}

# Heuristic patterns for robust fallback classification when external AI is unreachable
_FALLBACK_RULES = [
    {
        "keywords": ["water", "sewage", "drain", "drainage", "leak", "drinking water", "pipe", "contamination", "pipeline", "canal"],
        "primary": 6,
        "secondary": [11, 3],
        "reason": "The grievance relates directly to water supply, sanitation systems, or wastewater management.",
    },
    {
        "keywords": ["garbage", "trash", "waste", "dump", "dumping", "litter", "debris", "landfill", "solid waste"],
        "primary": 11,
        "secondary": [12, 3],
        "reason": "The grievance addresses waste accumulation and public cleanliness in residential and urban areas.",
    },
    {
        "keywords": ["pothole", "road", "street", "highway", "bridge", "streetlight", "lighting", "sidewalk", "traffic", "infrastructure", "footpath"],
        "primary": 9,
        "secondary": [11],
        "reason": "The issue involves municipal transport infrastructure, road safety, and civic physical assets.",
    },
    {
        "keywords": ["hospital", "clinic", "health", "sanitation", "disease", "medical", "doctor", "mosquito", "dengue", "hygiene", "epidemic"],
        "primary": 3,
        "secondary": [6, 11],
        "reason": "The grievance highlights public health risks, community disease prevention, or healthcare access.",
    },
    {
        "keywords": ["school", "education", "student", "teacher", "classroom", "books", "college", "children", "library"],
        "primary": 4,
        "secondary": [10],
        "reason": "The issue affects educational institutions, student learning conditions, or school infrastructure.",
    },
    {
        "keywords": ["electricity", "power", "blackout", "energy", "transformer", "wire", "voltage", "solar", "grid"],
        "primary": 7,
        "secondary": [9, 11],
        "reason": "The report concerns electrical utility access, power outages, and reliable community energy supply.",
    },
    {
        "keywords": ["workplace", "labor", "worker", "employment", "wage", "salary", "job", "harassment", "conduct", "discrimination"],
        "primary": 8,
        "secondary": [10, 16],
        "reason": "The complaint concerns workplace conduct, labor rights, fair compensation, or employment conditions.",
    },
    {
        "keywords": ["tree", "park", "forest", "animal", "wildlife", "soil", "greenery", "plant", "deforestation"],
        "primary": 15,
        "secondary": [11, 13],
        "reason": "The report involves terrestrial ecosystems, urban greenery protection, and biodiversity conservation.",
    },
    {
        "keywords": ["pollution", "smoke", "emission", "air quality", "climate", "heat", "factory smoke", "fumes"],
        "primary": 13,
        "secondary": [3, 11],
        "reason": "The issue relates to air emissions, environmental degradation, and local climate action.",
    },
    {
        "keywords": ["police", "corruption", "bribe", "crime", "safety", "violence", "court", "law", "extortion", "security"],
        "primary": 16,
        "secondary": [11],
        "reason": "The report involves public safety, legal accountability, and strong civic governance institutions.",
    },
    {
        "keywords": ["lake", "pond", "fish", "marine", "sea", "ocean", "river life", "wetland"],
        "primary": 14,
        "secondary": [6, 15],
        "reason": "The report concerns aquatic ecosystems, water body preservation, and aquatic habitats.",
    },
]


class AiSdgService:
    """
    Multimodal AI Service to evaluate and classify civic grievances into UN SDGs (1-17).
    Supports OpenAI-compatible Vision API with automatic fallback for high availability.
    """

    @classmethod
    def _validate_and_sanitize(cls, raw: Dict[str, Any]) -> Dict[str, Any]:
        """Validates that SDG IDs are strictly between 1 and 17 and structure is conformant."""
        try:
            primary_id = int(raw.get("primary_sdg", 11))
        except (ValueError, TypeError):
            primary_id = 11

        if primary_id < 1 or primary_id > 17:
            primary_id = 11

        secondary_ids: List[int] = []
        raw_secondaries = raw.get("secondary_sdgs", [])
        if isinstance(raw_secondaries, list):
            for s in raw_secondaries:
                try:
                    s_int = int(s)
                    if 1 <= s_int <= 17 and s_int != primary_id and s_int not in secondary_ids:
                        secondary_ids.append(s_int)
                except (ValueError, TypeError):
                    continue

        try:
            confidence = float(raw.get("confidence", 0.85))
            confidence = max(0.0, min(1.0, confidence))
        except (ValueError, TypeError):
            confidence = 0.85

        reason = str(raw.get("reason", "")).strip()
        if not reason:
            reason = f"Identified as closely aligning with {SDG_CATALOG.get(primary_id, 'SDG ' + str(primary_id))} based on reported civic conditions."

        return {
            "primary_sdg": primary_id,
            "primary_sdg_name": SDG_CATALOG.get(primary_id, f"SDG {primary_id}"),
            "secondary_sdgs": secondary_ids,
            "confidence": round(confidence, 2),
            "reason": reason,
        }

    @classmethod
    def _rule_based_fallback(
        cls,
        subject: str,
        category: str,
        description: str,
    ) -> Dict[str, Any]:
        """Semantic heuristic fallback to guarantee reliable responses even without network or AI credentials."""
        full_text = f"{subject} {category} {description}".lower()

        best_match = None
        highest_score = 0

        for rule in _FALLBACK_RULES:
            score = sum(1 for kw in rule["keywords"] if kw in full_text)
            if score > highest_score:
                highest_score = score
                best_match = rule

        if best_match and highest_score > 0:
            primary = best_match["primary"]
            secondaries = best_match["secondary"]
            confidence = min(0.92, 0.70 + (highest_score * 0.05))
            reason = best_match["reason"]
        else:
            # Default to SDG 11 (Sustainable Cities and Communities) for general civic reports
            primary = 11
            secondaries = [12]
            confidence = 0.75
            reason = "The grievance concerns civic infrastructure and community living conditions."

        return cls._validate_and_sanitize({
            "primary_sdg": primary,
            "secondary_sdgs": secondaries,
            "confidence": confidence,
            "reason": reason,
        })

    @classmethod
    async def analyze(
        cls,
        subject: str,
        category: str,
        description: str,
        image_bytes: Optional[bytes] = None,
        mime_type: str = "image/jpeg",
        image_url: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Analyzes a civic grievance using multimodal AI (OpenAI API) or graceful fallback.
        """
        api_key = os.getenv("OPENAI_API_KEY", "").strip()
        model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip()

        # If no valid API key is configured, immediately invoke the robust local semantic classifier
        if not api_key or api_key.startswith("your_") or api_key == "change_me":
            logger.info("OPENAI_API_KEY not configured. Using high-precision heuristic SDG classifier.")
            return cls._rule_based_fallback(subject, category, description)

        prompt_text = (
            f"Please evaluate this citizen grievance and recommend the impacted UN Sustainable Development Goal(s).\n\n"
            f"Subject: {subject.strip() or 'Not specified'}\n"
            f"Category: {category.strip() or 'General'}\n"
            f"Detailed Description: {description.strip()}\n"
        )
        if image_bytes or image_url:
            prompt_text += "\nEvidence Image attached: Yes (analyze both the image visual content and the text)."
        else:
            prompt_text += "\nEvidence Image attached: None (evaluate based on text provided)."

        system_instruction = (
            "You are an expert UN Sustainable Development Goals (SDG) evaluation assistant for civic grievances in the MEDAL platform.\n"
            "You analyze citizen grievance reports (Subject, Category, Detailed Description, and optional Evidence Image) "
            "and classify them into the appropriate UN Sustainable Development Goals (1-17).\n\n"
            "The AI can ONLY select from these 17 SDGs:\n"
            "SDG 1 - No Poverty\n"
            "SDG 2 - Zero Hunger\n"
            "SDG 3 - Good Health and Well-being\n"
            "SDG 4 - Quality Education\n"
            "SDG 5 - Gender Equality\n"
            "SDG 6 - Clean Water and Sanitation\n"
            "SDG 7 - Affordable and Clean Energy\n"
            "SDG 8 - Decent Work and Economic Growth\n"
            "SDG 9 - Industry, Innovation and Infrastructure\n"
            "SDG 10 - Reduced Inequalities\n"
            "SDG 11 - Sustainable Cities and Communities\n"
            "SDG 12 - Responsible Consumption and Production\n"
            "SDG 13 - Climate Action\n"
            "SDG 14 - Life Below Water\n"
            "SDG 15 - Life on Land\n"
            "SDG 16 - Peace, Justice and Strong Institutions\n"
            "SDG 17 - Partnerships for the Goals\n\n"
            "You must consider BOTH textual information and visual evidence. "
            "If the image contradicts the description, do not blindly trust the description. "
            "If there is no image, continue using the available text.\n\n"
            "The model must never invent an SDG number.\n"
            "You MUST respond ONLY with a raw JSON object with this exact structure:\n"
            "{\n"
            '  "primary_sdg": 11,\n'
            '  "secondary_sdgs": [12],\n'
            '  "confidence": 0.88,\n'
            '  "reason": "The grievance concerns waste accumulation in a public community area."\n'
            "}\n"
            "Rules:\n"
            "- primary_sdg: exactly one integer from 1-17.\n"
            "- secondary_sdgs: array of zero or more integers from 1-17, not duplicating primary_sdg.\n"
            "- confidence: number between 0.0 and 1.0.\n"
            "- reason: concise 1-2 sentence explanation of why this SDG was selected.\n"
            "Do not return Markdown formatting, backticks, or any conversational text. Return only valid JSON."
        )

        user_content: List[Dict[str, Any]] = [{"type": "text", "text": prompt_text}]

        if image_bytes:
            encoded_image = base64.b64encode(image_bytes).decode("utf-8")
            data_uri = f"data:{mime_type};base64,{encoded_image}"
            user_content.append({
                "type": "image_url",
                "image_url": {"url": data_uri, "detail": "low"},
            })
        elif image_url and (image_url.startswith("http://") or image_url.startswith("https://")):
            user_content.append({
                "type": "image_url",
                "image_url": {"url": image_url, "detail": "low"},
            })

        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_instruction},
                {"role": "user", "content": user_content},
            ],
            "temperature": 0.2,
            "max_tokens": 400,
        }

        try:
            async with httpx.AsyncClient(timeout=25.0) as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )

            if response.status_code != 200:
                logger.warning(
                    "OpenAI API returned status %s: %s. Falling back to heuristic classifier.",
                    response.status_code,
                    response.text[:200],
                )
                return cls._rule_based_fallback(subject, category, description)

            res_data = response.json()
            raw_text = res_data["choices"][0]["message"]["content"].strip()

            # Clean any possible markdown code block wrapper ```json ... ```
            cleaned = re.sub(r"^```(?:json)?\s*", "", raw_text, flags=re.MULTILINE)
            cleaned = re.sub(r"\s*```$", "", cleaned, flags=re.MULTILINE).strip()

            parsed = json.loads(cleaned)
            return cls._validate_and_sanitize(parsed)

        except Exception as e:
            logger.warning("Error invoking OpenAI API: %s. Using heuristic fallback.", e)
            return cls._rule_based_fallback(subject, category, description)
