"""
MEDAL — Asset Migration Script: MinIO / Local Storage -> Cloudinary

Features:
- Discovers existing complaint images, profile photos, comment attachments, and authority documents.
- Supports dry-run mode (--dry-run) and live mode (--live).
- Preserves private document access restrictions.
- Updates database references (secure_url and public_id) only after successful upload.
- Avoids duplicate uploads if asset is already on Cloudinary.
- Generates a comprehensive summary report (JSON/console).
- Never deletes original source files.
"""

import argparse
import asyncio
import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import httpx
from sqlalchemy import text

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database.database import SessionLocal, engine
from app.models.authority_application import AuthorityApplication
from app.models.complaint import Complaint, ComplaintComment
from app.models.user import User
from app.services.storage import CloudinaryStorageService, get_storage_service

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("medal.migration")


def is_already_cloudinary(url: Optional[str]) -> bool:
    if not url:
        return False
    return "cloudinary.com" in url.lower() or "res.cloudinary.com" in url.lower()


def resolve_local_file_path(url: str, base_uploads_dir: str) -> Optional[str]:
    """Attempts to find a local file corresponding to a legacy relative or static URL."""
    clean_url = url.strip()
    if clean_url.startswith("/uploads/"):
        rel_path = clean_url[len("/uploads/"):]
        candidate = os.path.join(base_uploads_dir, rel_path.replace("/", os.sep))
        if os.path.isfile(candidate):
            return candidate

    # If it's a MinIO URL, e.g. http://localhost:9000/medal-evidence/reports/abc.jpg
    # check if filename exists locally in base_uploads_dir/reports
    if "/medal-evidence/" in clean_url or "/reports/" in clean_url:
        filename = clean_url.split("/")[-1]
        candidate_report = os.path.join(base_uploads_dir, "reports", filename)
        if os.path.isfile(candidate_report):
            return candidate_report
        candidate_direct = os.path.join(base_uploads_dir, filename)
        if os.path.isfile(candidate_direct):
            return candidate_direct

    return None


async def fetch_asset_bytes(url: str, base_uploads_dir: str) -> Optional[bytes]:
    """Retrieves file bytes from local disk fallback or HTTP endpoint."""
    local_path = resolve_local_file_path(url, base_uploads_dir)
    if local_path and os.path.isfile(local_path):
        try:
            with open(local_path, "rb") as f:
                return f.read()
        except Exception as e:
            logger.warning(f"Could not read local file {local_path}: {e}")

    # Try HTTP fetch if it is an absolute URL
    if url.startswith("http://") or url.startswith("https://"):
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(url)
                if resp.status_code == 200:
                    return resp.content
        except Exception as e:
            logger.debug(f"HTTP fetch failed for {url}: {e}")

    return None


async def run_migration(dry_run: bool = True, base_uploads_dir: str = "uploads", output_report: Optional[str] = None):
    logger.info("=" * 70)
    logger.info("MEDAL ASSET MIGRATION: MinIO / Local -> Cloudinary")
    logger.info("Mode: %s", "DRY-RUN (No changes applied)" if dry_run else "LIVE EXECUTION")
    logger.info("Base Uploads Dir: %s", os.path.abspath(base_uploads_dir))
    logger.info("=" * 70)

    db = SessionLocal()
    storage = CloudinaryStorageService() if not dry_run else None

    report: Dict[str, Any] = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "dry_run": dry_run,
        "complaints": {"scanned": 0, "migrated": 0, "skipped": 0, "failed": 0},
        "profiles": {"scanned": 0, "migrated": 0, "skipped": 0, "failed": 0},
        "comments": {"scanned": 0, "migrated": 0, "skipped": 0, "failed": 0},
        "authority_docs": {"scanned": 0, "migrated": 0, "skipped": 0, "failed": 0},
        "details": [],
    }

    try:
        # 1. Migrate Complaints
        complaints = db.query(Complaint).filter(Complaint.image_url.isnot(None)).all()
        for c in complaints:
            report["complaints"]["scanned"] += 1
            if is_already_cloudinary(c.image_url):
                report["complaints"]["skipped"] += 1
                continue

            data = await fetch_asset_bytes(c.image_url, base_uploads_dir)
            if not data:
                logger.warning(f"[Complaint #{c.id}] Source asset bytes unavailable for: {c.image_url}")
                report["complaints"]["failed"] += 1
                report["details"].append({
                    "entity": "complaint",
                    "id": c.id,
                    "old_url": c.image_url,
                    "status": "failed",
                    "reason": "Asset bytes could not be located locally or via HTTP",
                })
                continue

            if dry_run:
                logger.info(f"[DRY-RUN] Would migrate complaint #{c.id} ({len(data)} bytes) from {c.image_url}")
                report["complaints"]["migrated"] += 1
            else:
                try:
                    filename = c.image_url.split("/")[-1] if "/" in c.image_url else f"complaint_{c.id}.jpg"
                    upload_res = await storage.upload_bytes(
                        data=data,
                        filename=filename,
                        folder="medal/complaints",
                        is_private=False,
                    )
                    c.image_url = upload_res.secure_url
                    c.image_public_id = upload_res.public_id
                    db.commit()
                    report["complaints"]["migrated"] += 1
                    logger.info(f"[Complaint #{c.id}] Migrated -> {upload_res.secure_url} ({upload_res.public_id})")
                    report["details"].append({
                        "entity": "complaint",
                        "id": c.id,
                        "old_url": c.image_url,
                        "new_url": upload_res.secure_url,
                        "public_id": upload_res.public_id,
                        "status": "success",
                    })
                except Exception as err:
                    db.rollback()
                    logger.error(f"[Complaint #{c.id}] Upload failed: {err}")
                    report["complaints"]["failed"] += 1

        # 2. Migrate User Profiles
        users = db.query(User).filter(User.profile_image_url.isnot(None)).all()
        for u in users:
            report["profiles"]["scanned"] += 1
            if is_already_cloudinary(u.profile_image_url):
                report["profiles"]["skipped"] += 1
                continue

            data = await fetch_asset_bytes(u.profile_image_url, base_uploads_dir)
            if not data:
                logger.warning(f"[User #{u.id}] Profile photo bytes unavailable for: {u.profile_image_url}")
                report["profiles"]["failed"] += 1
                continue

            if dry_run:
                logger.info(f"[DRY-RUN] Would migrate user #{u.id} avatar ({len(data)} bytes) from {u.profile_image_url}")
                report["profiles"]["migrated"] += 1
            else:
                try:
                    upload_res = await storage.upload_bytes(
                        data=data,
                        filename=f"avatar_{u.id}.jpg",
                        folder=f"medal/avatars/profiles/{u.id}",
                        is_private=False,
                    )
                    u.profile_image_url = upload_res.secure_url
                    u.profile_image_public_id = upload_res.public_id
                    db.commit()
                    report["profiles"]["migrated"] += 1
                    logger.info(f"[User #{u.id}] Avatar Migrated -> {upload_res.secure_url}")
                except Exception as err:
                    db.rollback()
                    logger.error(f"[User #{u.id}] Avatar upload failed: {err}")
                    report["profiles"]["failed"] += 1

        # 3. Migrate Comment Attachments
        comments = db.query(ComplaintComment).filter(ComplaintComment.image_url.isnot(None)).all()
        for cm in comments:
            report["comments"]["scanned"] += 1
            if is_already_cloudinary(cm.image_url):
                report["comments"]["skipped"] += 1
                continue

            data = await fetch_asset_bytes(cm.image_url, base_uploads_dir)
            if not data:
                report["comments"]["failed"] += 1
                continue

            if dry_run:
                logger.info(f"[DRY-RUN] Would migrate comment #{cm.id} attachment from {cm.image_url}")
                report["comments"]["migrated"] += 1
            else:
                try:
                    upload_res = await storage.upload_bytes(
                        data=data,
                        filename=f"comment_{cm.id}.jpg",
                        folder=f"medal/comments/{cm.complaint_id}",
                        is_private=False,
                    )
                    cm.image_url = upload_res.secure_url
                    cm.image_public_id = upload_res.public_id
                    db.commit()
                    report["comments"]["migrated"] += 1
                except Exception as err:
                    db.rollback()
                    report["comments"]["failed"] += 1

        # 4. Migrate Authority Documents
        apps = db.query(AuthorityApplication).all()
        for a in apps:
            report["authority_docs"]["scanned"] += 1
            # Aadhaar
            if a.aadhaar_document_url and not is_already_cloudinary(a.aadhaar_document_url):
                data = await fetch_asset_bytes(a.aadhaar_document_url, base_uploads_dir)
                if data:
                    if dry_run:
                        report["authority_docs"]["migrated"] += 1
                    else:
                        upload_res = await storage.upload_bytes(
                            data=data,
                            filename="aadhaar.pdf",
                            folder="medal/authority-documents",
                            is_private=True,
                        )
                        a.aadhaar_document_url = upload_res.secure_url
                        a.aadhaar_public_id = upload_res.public_id
                        db.commit()
                        report["authority_docs"]["migrated"] += 1
            # Gazette
            if a.employment_document_url and not is_already_cloudinary(a.employment_document_url):
                data = await fetch_asset_bytes(a.employment_document_url, base_uploads_dir)
                if data:
                    if dry_run:
                        report["authority_docs"]["migrated"] += 1
                    else:
                        upload_res = await storage.upload_bytes(
                            data=data,
                            filename="employment.pdf",
                            folder="medal/authority-documents",
                            is_private=True,
                        )
                        a.employment_document_url = upload_res.secure_url
                        a.employment_public_id = upload_res.public_id
                        db.commit()
                        report["authority_docs"]["migrated"] += 1

    finally:
        db.close()

    logger.info("=" * 70)
    logger.info("MIGRATION SUMMARY:")
    logger.info("Complaints:     %s", report["complaints"])
    logger.info("User Profiles:  %s", report["profiles"])
    logger.info("Comments:       %s", report["comments"])
    logger.info("Authority Docs: %s", report["authority_docs"])
    logger.info("=" * 70)

    if output_report:
        with open(output_report, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        logger.info(f"Report saved to: {output_report}")

    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate assets to Cloudinary")
    parser.add_argument("--live", action="store_true", help="Execute live migration (default is dry-run)")
    parser.add_argument("--dry-run", action="store_true", default=True, help="Perform dry run without changing data")
    parser.add_argument("--uploads-dir", default=os.path.join(os.path.dirname(__file__), "uploads"), help="Local uploads path")
    parser.add_argument("--report", default="migration_report.json", help="Path to save output JSON report")
    args = parser.parse_args()

    is_dry_run = not args.live
    asyncio.run(run_migration(dry_run=is_dry_run, base_uploads_dir=args.uploads_dir, output_report=args.report))
