import os
import uuid
from typing import Optional, Set, Tuple
from fastapi import HTTPException, UploadFile, status

# Allowed categories and MIME types
IMAGE_EXTENSIONS: Set[str] = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
DOCUMENT_EXTENSIONS: Set[str] = {".pdf", ".jpg", ".jpeg", ".png", ".webp"}

MAX_IMAGE_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MB
MAX_DOCUMENT_SIZE_BYTES: int = 15 * 1024 * 1024  # 15 MB


def detect_file_type_from_bytes(data: bytes) -> Optional[str]:
    """
    Inspects file signature (magic bytes) to determine actual content type.
    Does not trust client-supplied headers.
    """
    if len(data) < 4:
        return None

    # JPEG signature: FF D8 FF
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"

    # PNG signature: 89 50 4E 47 0D 0A 1A 0A
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"

    # GIF signature: GIF87a or GIF89a
    if data.startswith(b"GIF87a") or data.startswith(b"GIF89a"):
        return "image/gif"

    # WebP signature: RIFF....WEBP
    if len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp"

    # PDF signature: %PDF-
    if data.startswith(b"%PDF-") or b"%PDF-" in data[:1024]:
        return "application/pdf"

    return None


def get_extension_for_mime(mime_type: str) -> str:
    """Returns canonical file extension for verified MIME type."""
    mapping = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/gif": ".gif",
        "application/pdf": ".pdf",
    }
    return mapping.get(mime_type, ".bin")


async def validate_and_read_upload(
    file: UploadFile,
    allowed_types: Set[str],
    max_size_bytes: int,
) -> Tuple[bytes, str, str]:
    """
    Validates an uploaded file:
    1. Reads bytes safely and checks non-empty and max size.
    2. Validates magic bytes to detect real MIME type.
    3. Confirms MIME type is in allowed_types.
    4. Resets stream cursor.
    Returns: (file_bytes, verified_mime_type, file_extension)
    """
    filename = file.filename or "upload.bin"
    ext = os.path.splitext(filename)[1].lower()

    contents = await file.read()
    file_size = len(contents)

    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    if file_size > max_size_bytes:
        max_mb = max_size_bytes // (1024 * 1024)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File exceeds maximum allowed size of {max_mb}MB.",
        )

    # Detect real MIME type via magic bytes
    detected_mime = detect_file_type_from_bytes(contents)

    # Check against allowed types
    is_allowed = False
    if detected_mime and detected_mime in allowed_types:
        is_allowed = True
    elif "image/*" in allowed_types and detected_mime and detected_mime.startswith("image/"):
        is_allowed = True
    elif "application/pdf" in allowed_types and detected_mime == "application/pdf":
        is_allowed = True

    if not is_allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid or unsupported file format. Allowed types: {', '.join(sorted(allowed_types))}.",
        )

    # Reset file cursor for any subsequent streaming
    await file.seek(0)

    canonical_ext = get_extension_for_mime(detected_mime or "application/octet-stream")
    return contents, detected_mime or "application/octet-stream", canonical_ext


def generate_safe_asset_id(folder_prefix: str = "") -> str:
    """
    Generates a safe, unguessable public ID containing no PII, Aadhaar numbers, or secrets.
    Format: [folder_prefix/]asset_<uuid4_hex>
    """
    unique_id = f"asset_{uuid.uuid4().hex}"
    if folder_prefix:
        clean_prefix = folder_prefix.strip().strip("/")
        return f"{clean_prefix}/{unique_id}"
    return unique_id
