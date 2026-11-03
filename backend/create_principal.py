#!/usr/bin/env python3
"""
Provision the initial Principal account for the MEDAL Institution portal.

The Principal then adds Staff from the app; Students register themselves.

Usage:
    python create_principal.py --email principal@school.edu --password "StrongPass123" --name "Full Name"
Or set PRINCIPAL_EMAIL / PRINCIPAL_PASSWORD / PRINCIPAL_NAME in backend/.env and run:
    python create_principal.py
Re-running with the same email updates that account's name and password.
"""

import argparse
import getpass
import os
import sys

from dotenv import load_dotenv

load_dotenv()

from app.database.database import Base, SessionLocal, engine
import app.models.user  # noqa: F401  (registers the users table)
from app.models.user import User
from app.utils.security import hash_password


def main():
    parser = argparse.ArgumentParser(description="Provision the initial MEDAL Principal account.")
    parser.add_argument("--email", default=os.getenv("PRINCIPAL_EMAIL"))
    parser.add_argument("--password", default=os.getenv("PRINCIPAL_PASSWORD"))
    parser.add_argument("--name", default=os.getenv("PRINCIPAL_NAME", "Principal"))
    parser.add_argument("--phone", default=os.getenv("PRINCIPAL_PHONE"))
    args = parser.parse_args()

    email = (args.email or input("Principal email: ")).strip().lower()
    if "@" not in email:
        print("Error: a valid email address is required.", file=sys.stderr)
        sys.exit(1)
    password = args.password or getpass.getpass("Principal password (min 8 chars): ")
    if len(password) < 8:
        print("Error: password must be at least 8 characters.", file=sys.stderr)
        sys.exit(1)

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        if user and user.role not in ("principal",):
            print(f"Error: {email} already exists with role '{user.role}'.", file=sys.stderr)
            sys.exit(1)
        if user:
            user.full_name = args.name
            user.password_hash = hash_password(password)
            action = "Updated"
        else:
            user = User(
                email=email,
                password_hash=hash_password(password),
                full_name=args.name,
                phone=args.phone,
                role="principal",
                approval_status="approved",
                is_active=True,
                is_verified=True,
            )
            db.add(user)
            action = "Created"
        db.commit()
        print(f"{action} Principal account: {email}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
