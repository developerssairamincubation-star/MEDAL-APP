from abc import ABC, abstractmethod
import io
import json
import logging
import os
import uuid
from typing import Optional
from dotenv import load_dotenv
from fastapi import UploadFile

load_dotenv()
logger = logging.getLogger(__name__)


class BaseStorageService(ABC):
    """
    Abstract storage interface. Allows seamlessly switching between
    Local Disk, MinIO, AWS S3, Google Cloud Storage, or Firebase.
    """

    @abstractmethod
    async def upload_file(self, file: UploadFile, folder: str = "reports") -> str:
        """Upload a file from an UploadFile instance and return its accessible URL/path."""
        pass

    @abstractmethod
    async def upload_bytes(
        self,
        data: bytes,
        filename: str,
        content_type: str = "image/jpeg",
        folder: str = "reports",
    ) -> str:
        """Upload raw bytes and return its accessible URL/path."""
        pass


class LocalStorageService(BaseStorageService):
    """
    Local filesystem storage provider for development and standalone environments.
    """

    def __init__(self, base_upload_dir: str = "uploads"):
        self.base_upload_dir = base_upload_dir
        os.makedirs(self.base_upload_dir, exist_ok=True)

    async def upload_file(self, file: UploadFile, folder: str = "reports") -> str:
        target_dir = os.path.join(self.base_upload_dir, folder)
        os.makedirs(target_dir, exist_ok=True)

        original_ext = os.path.splitext(file.filename or "")[1].lower()
        if not original_ext:
            if file.content_type == "image/png":
                original_ext = ".png"
            elif file.content_type == "image/webp":
                original_ext = ".webp"
            elif file.content_type == "image/gif":
                original_ext = ".gif"
            else:
                original_ext = ".jpg"

        unique_filename = f"{uuid.uuid4().hex}{original_ext}"
        file_path = os.path.join(target_dir, unique_filename)

        contents = await file.read()
        with open(file_path, "wb") as f:
            f.write(contents)

        # Return standardized URL path served via FastAPI static mount
        return f"/uploads/{folder}/{unique_filename}"

    async def upload_bytes(
        self,
        data: bytes,
        filename: str,
        content_type: str = "image/jpeg",
        folder: str = "reports",
    ) -> str:
        target_dir = os.path.join(self.base_upload_dir, folder)
        os.makedirs(target_dir, exist_ok=True)

        original_ext = os.path.splitext(filename)[1].lower()
        if not original_ext:
            original_ext = ".jpg"

        unique_filename = f"{uuid.uuid4().hex}{original_ext}"
        file_path = os.path.join(target_dir, unique_filename)

        with open(file_path, "wb") as f:
            f.write(data)

        return f"/uploads/{folder}/{unique_filename}"


class MinioStorageService(BaseStorageService):
    """
    MinIO S3-compatible Object Storage service for report evidence and assets.
    """

    def __init__(
        self,
        endpoint: Optional[str] = None,
        access_key: Optional[str] = None,
        secret_key: Optional[str] = None,
        bucket_name: Optional[str] = None,
        secure: Optional[bool] = None,
        public_url: Optional[str] = None,
    ):
        try:
            from minio import Minio
            from minio.error import S3Error
        except ImportError as e:
            raise RuntimeError(
                "MinIO package is not installed. Please install 'minio==7.2.15' in requirements.txt"
            ) from e

        self.endpoint = endpoint or os.getenv("MINIO_ENDPOINT", "localhost:9000")
        self.access_key = access_key or os.getenv("MINIO_ACCESS_KEY", "minioadmin")
        self.secret_key = secret_key or os.getenv("MINIO_SECRET_KEY", "minioadminpassword")
        self.bucket_name = bucket_name or os.getenv("MINIO_BUCKET_NAME", "medal-evidence")

        secure_env = os.getenv("MINIO_SECURE", "False").strip().lower()
        self.secure = secure if secure is not None else (secure_env in ("true", "1", "yes"))

        # Base URL for public image access
        raw_public_url = public_url or os.getenv("MINIO_PUBLIC_URL")
        if raw_public_url:
            self.public_url = raw_public_url.rstrip("/")
        else:
            protocol = "https" if self.secure else "http"
            self.public_url = f"{protocol}://{self.endpoint}"

        try:
            self.client = Minio(
                endpoint=self.endpoint,
                access_key=self.access_key,
                secret_key=self.secret_key,
                secure=self.secure,
            )
            # Ensure the target bucket exists
            self._ensure_bucket_exists()
        except Exception as e:
            raise RuntimeError(
                f"Failed to initialize MinIO client at '{self.endpoint}': {e}"
            ) from e

    def _ensure_bucket_exists(self) -> None:
        """Create bucket if it doesn't exist and set public-read policy for image evidence."""
        if not self.client.bucket_exists(self.bucket_name):
            self.client.make_bucket(self.bucket_name)
            logger.info(f"Created MinIO bucket '{self.bucket_name}'")

        # Set public read bucket policy so uploaded photos can be displayed by Flutter Image.network
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{self.bucket_name}/*"],
                }
            ],
        }
        try:
            self.client.set_bucket_policy(self.bucket_name, json.dumps(policy))
        except Exception as policy_err:
            logger.warning(f"Could not apply public-read policy to bucket '{self.bucket_name}': {policy_err}")

    async def upload_file(self, file: UploadFile, folder: str = "reports") -> str:
        original_ext = os.path.splitext(file.filename or "")[1].lower()
        if not original_ext:
            if file.content_type == "image/png":
                original_ext = ".png"
            elif file.content_type == "image/webp":
                original_ext = ".webp"
            elif file.content_type == "image/gif":
                original_ext = ".gif"
            else:
                original_ext = ".jpg"

        unique_filename = f"{uuid.uuid4().hex}{original_ext}"
        object_name = f"{folder}/{unique_filename}"

        contents = await file.read()
        content_type = file.content_type or "image/jpeg"
        if content_type in ("application/octet-stream", "application/octetstream", "binary/octet-stream"):
            import mimetypes
            content_type = mimetypes.guess_type(unique_filename)[0] or "image/jpeg"

        data_stream = io.BytesIO(contents)
        self.client.put_object(
            bucket_name=self.bucket_name,
            object_name=object_name,
            data=data_stream,
            length=len(contents),
            content_type=content_type,
        )

        return f"{self.public_url}/{self.bucket_name}/{object_name}"

    async def upload_bytes(
        self,
        data: bytes,
        filename: str,
        content_type: str = "image/jpeg",
        folder: str = "reports",
    ) -> str:
        original_ext = os.path.splitext(filename)[1].lower()
        if not original_ext:
            original_ext = ".jpg"

        unique_filename = f"{uuid.uuid4().hex}{original_ext}"
        object_name = f"{folder}/{unique_filename}"

        data_stream = io.BytesIO(data)
        self.client.put_object(
            bucket_name=self.bucket_name,
            object_name=object_name,
            data=data_stream,
            length=len(data),
            content_type=content_type,
        )

        return f"{self.public_url}/{self.bucket_name}/{object_name}"


def _create_storage_service() -> BaseStorageService:
    """Factory creating the storage service configured in environment."""
    storage_type = os.getenv("STORAGE_TYPE", "local").strip().lower()

    if storage_type == "minio":
        return MinioStorageService()
    elif storage_type == "local":
        return LocalStorageService()
    else:
        raise ValueError(
            f"Unsupported STORAGE_TYPE='{storage_type}'. Supported values are 'minio' and 'local'."
        )


# Global storage service instance
_storage_service: Optional[BaseStorageService] = None


def get_storage_service() -> BaseStorageService:
    """Dependency provider for FastAPI route injection."""
    global _storage_service
    if _storage_service is None:
        _storage_service = _create_storage_service()
    return _storage_service
