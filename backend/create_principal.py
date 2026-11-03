#!/usr/bin/env python3
"""
Provision the initial Principal account for the MEDAL Institution portal.

The Principal then adds Staff from the app; Students register themselves.

Each principal belongs to one school; the school is created if its code is new. Teachers the
principal adds, and students who register with the school code, belong to the same school.

Usage:
    python create_principal.py --email principal@school.edu --password "StrongPass123" --name "Full Name" \\
        --school-code GREENFIELD --school-name "Greenfield School"
Or set PRINCIPAL_EMAIL / PRINCIPAL_PASSWORD / PRINCIPAL_NAME / PRINCIPAL_SCHOOL_CODE / PRINCIPAL_SCHOOL_NAME
in backend/.env and run:
    python create_principal.py
Re-running with the same email updates that account's name, password and school.
"""

import argparse
import getpass
import os
import sys

from dotenv import load_dotenv

load_dotenv()

from app.database.database import Base, SessionLocal, engine
import app.models.user  # noqa: F401  (registers the users table)
from app.models.user import School, User
from app.utils.security import hash_password


def main():
    parser = argparse.ArgumentParser(description="Provision the initial MEDAL Principal account.")
    parser.add_argument("--email", default=os.getenv("PRINCIPAL_EMAIL"))
    parser.add_argument("--password", default=os.getenv("PRINCIPAL_PASSWORD"))
    parser.add_argument("--name", default=os.getenv("PRINCIPAL_NAME", "Principal"))
    parser.add_argument("--phone", default=os.getenv("PRINCIPAL_PHONE"))
    parser.add_argument("--school-code", default=os.getenv("PRINCIPAL_SCHOOL_CODE"))
    parser.add_argument("--school-name", default=os.getenv("PRINCIPAL_SCHOOL_NAME"))
    args = parser.parse_args()

    email = (args.email or input("Principal email: ")).strip().lower()
    if "@" not in email:
        print("Error: a valid email address is required.", file=sys.stderr)
        sys.exit(1)
    password = args.password or getpass.getpass("Principal password (min 8 chars): ")
    if len(password) < 8:
        print("Error: password must be at least 8 characters.", file=sys.stderr)
        sys.exit(1)

    school_code = (args.school_code or input("School code (given to students at sign-up): ")).strip().upper()
    if not school_code:
        print("Error: a school code is required.", file=sys.stderr)
        sys.exit(1)

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        school = db.query(School).filter(School.code == school_code).first()
        if not school:
            school = School(code=school_code, name=(args.school_name or school_code).strip())
            db.add(school)
            db.flush()
        user = db.query(User).filter(User.email == email).first()
        if user and user.role not in ("principal",):
            print(f"Error: {email} already exists with role '{user.role}'.", file=sys.stderr)
            sys.exit(1)
        if user:
            user.full_name = args.name
            user.password_hash = hash_password(password)
            user.school_id = school.id
            action = "Updated"
        else:
            user = User(
                email=email,
                password_hash=hash_password(password),
                full_name=args.name,
                phone=args.phone,
                role="principal",
                school_id=school.id,
                approval_status="approved",
                is_active=True,
                is_verified=True,
            )
            db.add(user)
            action = "Created"
        db.commit()
        print(f"{action} Principal account: {email} (school {school.code})")
    finally:
        db.close()


if __name__ == "__main__":
    main()
