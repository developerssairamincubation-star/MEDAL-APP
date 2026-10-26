import asyncio
import io
import logging
import mimetypes
import os
import time
import uuid
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional
from dotenv import load_dotenv
from fastapi import HTTPException, UploadFile, status

from app.utils.file_validation import (
    detect_file_type_from_bytes,
    generate_safe_asset_id,
    get_extension_for_mime,
)

load_dotenv()
logger = logging.getLogger("medal.storage")


class UploadResult(str):
    """
    Structured upload result inheriting from str for 100% backward compatibility
    with legacy callers that expect `file_url: str = await storage.upload_file(...)`.
    Exposes asset metadata: `secure_url`, `public_id`, `resource_type`, `format`, `bytes`.
    """
    secure_url: str
    public_id: str
    resource_type: str
    format: str
    bytes: int
    version: Optional[int]
    access_mode: str

    def __new__(
        cls,
        secure_url: str,
        public_id: str = "",
        resource_type: str = "image",
        format: str = "",
        bytes: int = 0,
        version: Optional[int] = None,
        access_mode: str = "public",
    ):
        obj = super().__new__(cls, secure_url)
        obj.secure_url = secure_url
        obj.public_id = public_id
        obj.resource_type = resource_type
        obj.format = format
        obj.bytes = bytes
        obj.version = version
        obj.access_mode = access_mode
        return obj

    def to_dict(self) -> Dict[str, Any]:
        return {
            "secure_url": self.secure_url,
            "public_id": self.public_id,
            "resource_type": self.resource_type,
            "format": self.format,
            "bytes": self.bytes,
            "version": self.version,
            "access_mode": self.access_mode,
        }


class BaseStorageService(ABC):
    """
    Abstract storage interface for MEDAL assets.
    """

    @abstractmethod
    async def upload_file(
        self,
        file: UploadFile,
        folder: str = "medal/complaints",
        is_private: bool = False,
        custom_public_id: Optional[str] = None,
    ) -> UploadResult:
        """Upload a file from an UploadFile instance and return an UploadResult."""
        pass

    @abstractmethod
    async def upload_bytes(
        self,
        data: bytes,
        filename: str,
        folder: str = "medal/complaints",
        content_type: str = "image/jpeg",
        is_private: bool = False,
        custom_public_id: Optional[str] = None,
    ) -> UploadResult:
        """Upload raw bytes and return an UploadResult."""
        pass

    @abstractmethod
    async def delete_asset(
        self,
        public_id: str,
        resource_type: str = "image",
        is_private: bool = False,
    ) -> bool:
        """Deletes an asset by public_id."""
        pass

    @abstractmethod
    def generate_private_download_url(
        self,
        public_id: str,
        resource_type: str = "image",
        expires_in: int = 3600,
    ) -> str:
        """Generates a short-lived authorized URL for a private asset."""
        pass

    @abstractmethod
    def check_health(self) -> Dict[str, Any]:
        """Health check verifying storage readiness."""
        pass


class CloudinaryStorageService(BaseStorageService):
    """
    Cloudinary storage provider using official Cloudinary Python SDK.
    Supports secure HTTPS uploads, structured asset IDs, private/authenticated delivery,
    and automatic format/quality optimization.
    """

    def __init__(
        self,
        cloud_name: Optional[str] = None,
        api_key: Optional[str] = None,
        api_secret: Optional[str] = None,
    ):
        load_dotenv()
        self.cloud_name = cloud_name or os.getenv("CLOUDINARY_CLOUD_NAME", "").strip()
        self.api_key = api_key or os.getenv("CLOUDINARY_API_KEY", "").strip()
        self.api_secret = api_secret or os.getenv("CLOUDINARY_API_SECRET", "").strip()

        if not self.cloud_name or not self.api_key or not self.api_secret:
            missing = []
            if not self.cloud_name:
                missing.append("CLOUDINARY_CLOUD_NAME")
            if not self.api_key:
                missing.append("CLOUDINARY_API_KEY")
            if not self.api_secret:
                missing.append("CLOUDINARY_API_SECRET")
            raise RuntimeError(
                f"Cloudinary configuration incomplete. Missing required environment variables: {', '.join(missing)}"
            )

        try:
            import cloudinary
            import cloudinary.api
            import cloudinary.uploader
            import cloudinary.utils

            self._cloudinary = cloudinary
            self._uploader = cloudinary.uploader
            self._api = cloudinary.api
            self._utils = cloudinary.utils

            self._cloudinary.config(
                cloud_name=self.cloud_name,
                api_key=self.api_key,
                api_secret=self.api_secret,
                secure=True,
            )
            logger.info("Cloudinary storage provider initialized successfully for cloud '%s'.", self.cloud_name)
        except ImportError as exc:
            raise RuntimeError(
                "The 'cloudinary' package is not installed. Please install it with 'pip install cloudinary'."
            ) from exc

    def check_health(self) -> Dict[str, Any]:
        """Validates configuration and verifies that credentials are ready."""
        if not self.cloud_name or not self.api_key or not self.api_secret:
            return {"status": "unhealthy", "provider": "cloudinary", "error": "Credentials missing"}
        return {
            "status": "healthy",
            "provider": "cloudinary",
            "cloud_name": self.cloud_name,
            "secure": True,
        }

    def _determine_resource_type(self, ext: str, mime_type: str) -> str:
        """Determines appropriate Cloudinary resource_type: image, raw, or auto."""
        ext_lower = ext.lower()
        if ext_lower in (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tiff"):
            return "image"
        if mime_type.startswith("image/"):
            return "image"
        # Non-image files like PDFs, documents, text files are stored as raw
        return "raw"

    async def upload_file(
        self,
        file: UploadFile,
        folder: str = "medal/complaints",
        is_private: bool = False,
        custom_public_id: Optional[str] = None,
    ) -> UploadResult:
        contents = await file.read()
        filename = file.filename or "upload.jpg"
        content_type = file.content_type or "image/jpeg"
        await file.seek(0)

        return await self.upload_bytes(
            data=contents,
            filename=filename,
            folder=folder,
            content_type=content_type,
            is_private=is_private,
            custom_public_id=custom_public_id,
        )

    async def upload_bytes(
        self,
        data: bytes,
        filename: str,
        folder: str = "medal/complaints",
        content_type: str = "image/jpeg",
        is_private: bool = False,
        custom_public_id: Optional[str] = None,
    ) -> UploadResult:
        if len(data) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot upload empty file.",
            )

        # Inspect bytes to detect real MIME type
        detected_mime = detect_file_type_from_bytes(data)
        actual_mime = detected_mime or content_type
        ext = get_extension_for_mime(actual_mime)

        clean_folder = folder.strip().strip("/")
        if not custom_public_id:
            safe_id = f"asset_{uuid.uuid4().hex}"
            full_public_id = f"{clean_folder}/{safe_id}"
        else:
            full_public_id = f"{clean_folder}/{custom_public_id.strip('/')}"

        resource_type = self._determine_resource_type(ext, actual_mime)

        # Configure upload options
        upload_options: Dict[str, Any] = {
            "public_id": full_public_id,
            "resource_type": resource_type,
            "overwrite": True,
            "unique_filename": False,
            "use_filename": False,
        }

        # Apply authenticated / private delivery for sensitive docs
        if is_private:
            upload_options["type"] = "authenticated"
            upload_options["access_mode"] = "authenticated"
        else:
            upload_options["type"] = "upload"

        # Execute upload synchronously in thread pool to not block asyncio event loop
        loop = asyncio.get_event_loop()
        try:
            stream = io.BytesIO(data)
            response = await loop.run_in_executor(
                None,
                lambda: self._uploader.upload(stream, **upload_options),
            )
        except Exception as err:
            logger.error("Cloudinary upload failed for public_id '%s': %s", full_public_id, err)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Cloud asset storage upload failed. Please try again.",
            ) from err

        secure_url = response.get("secure_url") or response.get("url")
        public_id = response.get("public_id", full_public_id)
        fmt = response.get("format", ext.lstrip("."))
        bytes_count = response.get("bytes", len(data))
        version = response.get("version")
        access_mode = "authenticated" if is_private else "public"

        return UploadResult(
            secure_url=secure_url,
            public_id=public_id,
            resource_type=resource_type,
            format=fmt,
            bytes=bytes_count,
            version=version,
            access_mode=access_mode,
        )

    async def delete_asset(
        self,
        public_id: str,
        resource_type: str = "image",
        is_private: bool = False,
    ) -> bool:
        if not public_id:
            return False

        loop = asyncio.get_event_loop()
        try:
            destroy_options: Dict[str, Any] = {
                "resource_type": resource_type,
                "invalidate": True,
            }
            if is_private:
                destroy_options["type"] = "authenticated"

            res = await loop.run_in_executor(
                None,
                lambda: self._uploader.destroy(public_id, **destroy_options),
            )
            result_str = res.get("result", "")
            return result_str in ("ok", "not found")
        except Exception as err:
            logger.warning("Failed to delete Cloudinary asset '%s': %s", public_id, err)
            return False

    def generate_private_download_url(
        self,
        public_id: str,
        resource_type: str = "image",
        expires_in: int = 3600,
    ) -> str:
        """
        Generates a short-lived authenticated URL signed with Cloudinary API secret.
        """
        if not public_id:
            return ""

        # Auto-detect raw if resource_type is default "image" but public_id has non-image ext
        if resource_type == "image" and any(public_id.lower().endswith(doc_ext) for doc_ext in (".pdf", ".doc", ".docx", ".txt")):
            resource_type = "raw"

        expires_at = int(time.time()) + expires_in
        signed_url, _ = self._utils.cloudinary_url(
            public_id,
            sign_url=True,
            type="authenticated",
            resource_type=resource_type,
            secure=True,
            expires_at=expires_at,
        )
        return signed_url


class LocalStorageService(BaseStorageService):
    """
    Local filesystem storage provider for isolated offline testing.
    """

    def __init__(self, base_upload_dir: str = "uploads"):
        self.base_upload_dir = base_upload_dir
        os.makedirs(self.base_upload_dir, exist_ok=True)

    def check_health(self) -> Dict[str, Any]:
        return {"status": "healthy", "provider": "local", "directory": self.base_upload_dir}

    async def upload_file(
        self,
        file: UploadFile,
        folder: str = "medal/complaints",
        is_private: bool = False,
        custom_public_id: Optional[str] = None,
    ) -> UploadResult:
        contents = await file.read()
        filename = file.filename or "upload.jpg"
        content_type = file.content_type or "image/jpeg"
        await file.seek(0)

        return await self.upload_bytes(
            data=contents,
            filename=filename,
            folder=folder,
            content_type=content_type,
            is_private=is_private,
            custom_public_id=custom_public_id,
        )

    async def upload_bytes(
        self,
        data: bytes,
        filename: str,
        folder: str = "medal/complaints",
        content_type: str = "image/jpeg",
        is_private: bool = False,
        custom_public_id: Optional[str] = None,
    ) -> UploadResult:
        clean_folder = folder.strip().strip("/")
        target_dir = os.path.join(self.base_upload_dir, clean_folder)
        os.makedirs(target_dir, exist_ok=True)

        detected_mime = detect_file_type_from_bytes(data)
        actual_mime = detected_mime or content_type
        ext = get_extension_for_mime(actual_mime)

        safe_id = custom_public_id or f"asset_{uuid.uuid4().hex}"
        unique_filename = f"{safe_id}{ext}"
        file_path = os.path.join(target_dir, unique_filename)

        with open(file_path, "wb") as f:
            f.write(data)

        public_id = f"{clean_folder}/{safe_id}"
        secure_url = f"/uploads/{clean_folder}/{unique_filename}"
        resource_type = "image" if actual_mime.startswith("image/") else "raw"

        return UploadResult(
            secure_url=secure_url,
            public_id=public_id,
            resource_type=resource_type,
            format=ext.lstrip("."),
            bytes=len(data),
            access_mode="private" if is_private else "public",
        )

    async def delete_asset(
        self,
        public_id: str,
        resource_type: str = "image",
        is_private: bool = False,
    ) -> bool:
        file_path = os.path.join(self.base_upload_dir, public_id)
        for ext in (".jpg", ".jpeg", ".png", ".webp", ".pdf", ".bin"):
            candidate = f"{file_path}{ext}"
            if os.path.isfile(candidate):
                try:
                    os.remove(candidate)
                    return True
                except Exception:
                    return False
        return False

    def generate_private_download_url(
        self,
        public_id: str,
        resource_type: str = "image",
        expires_in: int = 3600,
    ) -> str:
        return f"/uploads/{public_id}"


def _create_storage_service() -> BaseStorageService:
    """Factory creating the storage service configured in environment."""
    storage_type = os.getenv("STORAGE_TYPE", "cloudinary").strip().lower()

    if storage_type in ("cloudinary", "cloud"):
        return CloudinaryStorageService()
    elif storage_type == "local":
        logger.warning("Using LocalStorageService. Set STORAGE_TYPE=cloudinary for production cloud storage.")
        return LocalStorageService()
    else:
        raise ValueError(
            f"Unsupported STORAGE_TYPE='{storage_type}'. Supported values are 'cloudinary' and 'local'."
        )


_storage_service: Optional[BaseStorageService] = None


def get_storage_service() -> BaseStorageService:
    """Dependency provider for FastAPI route injection."""
    global _storage_service
    if _storage_service is None:
        _storage_service = _create_storage_service()
    return _storage_service


def reset_storage_service() -> None:
    """Resets storage service singleton for testing."""
    global _storage_service
    _storage_service = None
