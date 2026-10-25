#!/usr/bin/env python3
"""
Provision or update a secure Admin account for the MEDAL application.

Usage:
    python create_admin.py --email admin@medal.gov.in --password "SuperSecretPass123!" --name "Chief Administrator"
Or set environment variables in backend/.env:
    ADMIN_EMAIL=admin@medal.gov.in
    ADMIN_PASSWORD=SuperSecretPass123!
    ADMIN_NAME="Chief Administrator"
Then run:
    python create_admin.py
"""

import argparse
import getpass
import os
import sys
from dotenv import load_dotenv

load_dotenv()

from app.database.database import SessionLocal
from app.models.user import User
from app.utils.security import hash_password


def parse_args():
    parser = argparse.ArgumentParser(description="Provision or update a secure MEDAL single Admin account.")
    parser.add_argument("--check", "-c", action="store_true", help="Check existing Admin provisioning status without making changes")
    parser.add_argument("--email", default=os.getenv("ADMIN_EMAIL"), help="Admin official email address")
    parser.add_argument("--password", default=os.getenv("ADMIN_PASSWORD"), help="Admin password (min 8 chars)")
    parser.add_argument("--name", default=os.getenv("ADMIN_NAME", "System Administrator"), help="Admin full name")
    parser.add_argument("--phone", default=os.getenv("ADMIN_PHONE"), help="Admin phone number (optional)")
    return parser.parse_args()


def main():
    args = parse_args()

    # Read-only status inspection
    if args.check:
        db = SessionLocal()
        try:
            admins = db.query(User).filter(User.role == "admin").all()
            if not admins:
                print("No Admin account currently provisioned.")
                print("Run 'python create_admin.py' to provision the single Admin account.")
            else:
                print(f"MEDAL Admin Status: {len(admins)} Admin account(s) found.")
                for a in admins:
                    print(f"  - User ID: {a.id} | Email: {a.email} | Name: {a.full_name} | Status: {a.approval_status} | Active: {a.is_active}")
                if len(admins) > 1:
                    print("\nWarning: Multiple admin accounts detected. Re-run 'python create_admin.py' with target email to enforce single Admin policy.")
                else:
                    print("\nVerified: Single Admin invariant satisfied.")
            return
        finally:
            db.close()

    email = args.email
    if not email:
        email = input("Enter Admin Email: ").strip()

    if not email or "@" not in email:
        print("Error: A valid email address is required.", file=sys.stderr)
        sys.exit(1)

    email = email.lower().strip()

    password = args.password
    if not password:
        password = getpass.getpass("Enter Admin Password (min 8 chars): ").strip()
        confirm = getpass.getpass("Confirm Admin Password: ").strip()
        if password != confirm:
            print("Error: Passwords do not match.", file=sys.stderr)
            sys.exit(1)

    if len(password) < 8:
        print("Error: Password must be at least 8 characters long for Admin accounts.", file=sys.stderr)
        sys.exit(1)

    name = args.name.strip() if args.name else "System Administrator"
    phone = args.phone.strip() if args.phone else None

    db = SessionLocal()
    try:
        # Enforce single Admin invariant: demote any other existing admin accounts
        other_admins = db.query(User).filter(User.role == "admin", User.email != email).all()
        if other_admins:
            print(f"Enforcing single Admin invariant: demoting {len(other_admins)} other admin account(s) to 'citizen' role...")
            for oa in other_admins:
                print(f"  - Reassigned former admin ID {oa.id} ({oa.email}) to role='citizen'")
                oa.role = "citizen"
            db.flush()

        user = db.query(User).filter(User.email == email).first()
        hashed = hash_password(password)

        if user:
            print(f"User with email '{email}' found (ID: {user.id}). Updating to Admin role...")
            user.role = "admin"
            user.approval_status = "approved"
            user.password_hash = hashed
            user.full_name = name
            if phone:
                user.phone = phone
            user.is_active = True
            user.is_verified = True
            db.commit()
            db.refresh(user)
            print(f"Successfully updated user ID {user.id} ({user.email}) to the single Admin role.")
        else:
            print(f"Creating new Admin user '{email}'...")
            new_admin = User(
                email=email,
                password_hash=hashed,
                full_name=name,
                phone=phone,
                role="admin",
                approval_status="approved",
                is_active=True,
                is_verified=True,
            )
            db.add(new_admin)
            db.commit()
            db.refresh(new_admin)
            print(f"Successfully created single Admin user ID {new_admin.id} ({new_admin.email}) with role 'admin'.")

        # Verify single admin invariant
        total_admins = db.query(User).filter(User.role == "admin").count()
        print(f"Verified: Database now has exactly {total_admins} Admin account ({email}).")

    except Exception as e:
        db.rollback()
        print(f"Database error during admin provisioning: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
