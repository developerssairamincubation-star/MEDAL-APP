import hashlib
import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import bcrypt
from dotenv import load_dotenv
from jose import JWTError, jwt

load_dotenv()

MIN_JWT_SECRET_BYTES = 32


def _load_jwt_secret() -> str:
    """JWT_SECRET is mandatory: there is deliberately no fallback value."""
    secret = os.getenv("JWT_SECRET", "")
    if len(secret.encode("utf-8")) < MIN_JWT_SECRET_BYTES:
        raise RuntimeError(
            f"JWT_SECRET must be set to at least {MIN_JWT_SECRET_BYTES} bytes. Generate one with: "
            'python -c "import secrets; print(secrets.token_urlsafe(48))"'
        )
    return secret


# JWT Configuration from environment variables
JWT_SECRET = _load_jwt_secret()
# Pinned: never read from the environment or from the token header.
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES") or "15")
RESET_TOKEN_EXPIRE_MINUTES = int(os.getenv("RESET_TOKEN_EXPIRE_MINUTES") or "15")

# Each role belongs to exactly one platform; the token carries it as the "plat" claim.
CITIZEN_PLATFORM = "citizen"
INSTITUTION_PLATFORM = "institution"
PLATFORM_BY_ROLE = {
    "citizen": CITIZEN_PLATFORM,
    "official": CITIZEN_PLATFORM,
    "admin": CITIZEN_PLATFORM,
    "principal": INSTITUTION_PLATFORM,
    "staff": INSTITUTION_PLATFORM,
    "student": INSTITUTION_PLATFORM,
}
INSTITUTION_ROLES = tuple(r for r, p in PLATFORM_BY_ROLE.items() if p == INSTITUTION_PLATFORM)


# Password Hashing Functions
def hash_password(password: str) -> str:
    """Hash a plaintext password using bcrypt."""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a bcrypt hash."""
    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        hashed_password.encode("utf-8")
    )


# JWT Token Functions
def create_access_token(
    data: dict[str, Any],
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create a signed JWT access token with payload claims and expiration."""
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=ALGORITHM)
    return encoded_jwt


def create_user_token(user: Any) -> str:
    """Access token bound to the user's platform and current token_version."""
    return create_access_token(
        data={
            "sub": str(user.id),
            "role": user.role,
            "plat": PLATFORM_BY_ROLE.get(user.role, ""),
            "tv": int(user.token_version or 0),
        }
    )


def decode_access_token(token: str) -> Optional[dict[str, Any]]:
    """Decode and verify a JWT access token. Returns decoded payload dict or None if invalid/expired."""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None


def verify_token(token: str) -> Optional[dict[str, Any]]:
    """Alias for decode_access_token to verify token validity and extract claims."""
    return decode_access_token(token)


def create_password_reset_token(
    email: str,
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create a temporary signed JWT token specifically for password reset."""
    to_encode = {"sub": email, "purpose": "password_reset"}

    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=RESET_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=ALGORITHM)
    return encoded_jwt


def decode_password_reset_token(token: str) -> Optional[str]:
    """Decode and verify a password reset token. Returns email if valid, or None if invalid/expired."""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        if payload.get("purpose") not in ("password_reset", "password_reset_verified"):
            return None
        email: Optional[str] = payload.get("sub")
        return email
    except JWTError:
        return None


def generate_otp(length: int = 6) -> str:
    """Generate a cryptographically secure numeric OTP string of given length."""
    return f"{secrets.randbelow(10**length):0{length}d}"


def hash_otp(otp: str) -> str:
    """Hash an OTP using HMAC-SHA256 with project JWT_SECRET."""
    return hmac.new(JWT_SECRET.encode("utf-8"), otp.encode("utf-8"), hashlib.sha256).hexdigest()


def verify_otp_hash(otp: str, hashed_otp: str) -> bool:
    """Verify an OTP string against its stored HMAC hash in constant time."""
    expected = hash_otp(otp)
    return hmac.compare_digest(expected, hashed_otp)


def create_verified_reset_token(
    email: str,
    otp_id: int,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create a temporary signed JWT token after OTP has been verified."""
    to_encode = {
        "sub": email,
        "otp_id": otp_id,
        "purpose": "password_reset_verified",
    }
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=RESET_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, JWT_SECRET, algorithm=ALGORITHM)


def decode_verified_reset_token(token: str) -> Optional[dict[str, Any]]:
    """Decode and verify a verified reset token. Returns payload dict or None."""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        if payload.get("purpose") not in ("password_reset_verified", "password_reset"):
            return None
        return payload
    except JWTError:
        return None



