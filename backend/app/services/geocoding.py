"""Reverse geocoding helper: turns latitude/longitude into a readable place name.

Uses OpenStreetMap Nominatim (free, no API key). Callers must keep usage low
(<= 1 request/second) and always degrade gracefully: on any failure this returns
None and the caller keeps whatever location text it already has.
"""
import logging
import re
from typing import Optional

import requests

logger = logging.getLogger(__name__)

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"
USER_AGENT = "MEDAL-Grievance-App/1.0 (reverse geocoding for civic reports)"
TIMEOUT_SECONDS = 4

_COORD_RE = re.compile(r"^\s*-?\d{1,3}(?:\.\d+)?\s*[,;\s]\s*-?\d{1,3}(?:\.\d+)?\s*$")
# Labels/symbols clients put around raw coordinates, e.g. "Lat: 12.97, Lng: 80.27" or "12.97° N, 80.27° E".
_COORD_NOISE_RE = re.compile(r"(?i)\b(latitude|longitude|lat|lng|lon|long)\b|[:°]|(?<=[\d°])\s*[NSEW]\b")


def _strip_coord_noise(text: str) -> str:
    return _COORD_NOISE_RE.sub(" ", text).strip()


def looks_like_coordinates(text: Optional[str]) -> bool:
    """True for strings such as '12.9716, 77.5946' or 'Lat: 12.97, Lng: 77.59' (and empty/None)."""
    if text is None or not text.strip():
        return True
    return bool(_COORD_RE.match(_strip_coord_noise(text)))


def parse_coordinates(text: Optional[str]) -> Optional[tuple[float, float]]:
    """Parse a 'lat, lng' string into floats, or None if it is not one."""
    if not text:
        return None
    cleaned = _strip_coord_noise(text)
    if not _COORD_RE.match(cleaned):
        return None
    parts = [p for p in re.split(r"[,;\s]+", cleaned) if p]
    try:
        lat, lng = float(parts[0]), float(parts[1])
    except (ValueError, IndexError):
        return None
    if -90 <= lat <= 90 and -180 <= lng <= 180:
        return lat, lng
    return None


def _format_address(payload: dict) -> Optional[str]:
    addr = payload.get("address") or {}
    street = addr.get("road") or addr.get("pedestrian") or addr.get("footway")
    area = (
        addr.get("suburb")
        or addr.get("neighbourhood")
        or addr.get("quarter")
        or addr.get("city_district")
    )
    city = (
        addr.get("city")
        or addr.get("town")
        or addr.get("village")
        or addr.get("municipality")
        or addr.get("county")
    )
    state = addr.get("state")

    parts: list[str] = []
    for value in (street, area, city, state):
        if value and value not in parts:
            parts.append(value)
    if parts:
        return ", ".join(parts[:4])

    display = payload.get("display_name")
    if display:
        return ", ".join(p.strip() for p in display.split(",")[:3])
    return None


def reverse_geocode(latitude: float, longitude: float) -> Optional[str]:
    """Return a short human-readable place name, or None if unavailable."""
    try:
        resp = requests.get(
            NOMINATIM_URL,
            params={
                "format": "jsonv2",
                "lat": f"{latitude:.6f}",
                "lon": f"{longitude:.6f}",
                "zoom": 16,
                "addressdetails": 1,
            },
            headers={"User-Agent": USER_AGENT, "Accept-Language": "en"},
            timeout=TIMEOUT_SECONDS,
        )
        if resp.status_code != 200:
            logger.warning("Reverse geocode HTTP %s for %s,%s", resp.status_code, latitude, longitude)
            return None
        return _format_address(resp.json())
    except Exception as exc:  # network errors, bad JSON, timeouts
        logger.warning("Reverse geocode failed for %s,%s: %s", latitude, longitude, exc)
        return None
