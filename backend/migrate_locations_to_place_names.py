"""One-off migration: replace raw "lat, lng" locations on existing complaints with
readable place names (reverse-geocoded). Coordinates are always preserved.

Usage (from the backend/ directory, with DATABASE_URL set):
    python migrate_locations_to_place_names.py            # dry run, prints what would change
    python migrate_locations_to_place_names.py --apply    # writes changes

Nominatim's usage policy allows ~1 request/second, so this sleeps between lookups.
Rows that cannot be geocoded are left untouched and can be retried by re-running.
"""
import argparse
import time

from dotenv import load_dotenv

load_dotenv()

from app.database.database import SessionLocal
from app.models.complaint import Complaint
from app.services.geocoding import looks_like_coordinates, parse_coordinates, reverse_geocode


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Persist changes (default is dry run)")
    args = parser.parse_args()

    db = SessionLocal()
    updated = skipped = 0
    try:
        for c in db.query(Complaint).order_by(Complaint.id).all():
            needs_name = looks_like_coordinates(c.location_address) and looks_like_coordinates(c.location)
            if not needs_name:
                continue

            lat, lng = c.latitude, c.longitude
            if lat is None or lng is None:
                parsed = parse_coordinates(c.location_address) or parse_coordinates(c.location)
                if parsed:
                    lat, lng = parsed
            if lat is None or lng is None:
                skipped += 1
                print(f"[skip] complaint {c.id}: no coordinates available")
                continue

            name = reverse_geocode(lat, lng)
            time.sleep(1.1)
            if not name:
                skipped += 1
                print(f"[skip] complaint {c.id}: geocoding failed for {lat}, {lng}")
                continue

            print(f"[{'update' if args.apply else 'dry-run'}] complaint {c.id}: {c.location!r} -> {name!r}")
            if args.apply:
                c.latitude, c.longitude = lat, lng
                c.location = name
                c.location_address = name
                db.commit()
            updated += 1
    finally:
        db.close()
    print(f"Done. {'Updated' if args.apply else 'Would update'}: {updated}, skipped: {skipped}")


if __name__ == "__main__":
    main()
