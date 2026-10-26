from datetime import datetime, timedelta, timezone
import logging
import mimetypes
from typing import List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.otp import PasswordResetOTP
from app.models.user import User
from app.models.authority_application import AuthorityApplication
from app.schemas.user import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    LoginResponse,
    ProfilePhotoResponse,
    RegisterResponse,
    ResendOtpRequest,
    ResendOtpResponse,
    ResetPasswordRequest,
    ResetPasswordResponse,
    UserCreate,
    UserProfileUpdate,
    UserResponse,
    VerifyOtpRequest,
    VerifyOtpResponse,
)
from app.services.email import EmailDeliveryError, EmailService, get_email_service, mask_email
from app.services.storage import BaseStorageService, get_storage_service
from app.utils.file_validation import MAX_IMAGE_SIZE_BYTES, validate_and_read_upload
from app.utils.security import (
    create_access_token,
    create_password_reset_token,
    create_verified_reset_token,
    decode_access_token,
    decode_password_reset_token,
    decode_verified_reset_token,
    generate_otp,
    hash_otp,
    hash_password,
    verify_otp_hash,
    verify_password,
)

router = APIRouter()
logger = logging.getLogger("medal.auth")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/login", auto_error=False)


def get_optional_current_user(
    token: Optional[str] = Depends(oauth2_scheme_optional),
    db: Session = Depends(get_db),
) -> Optional[User]:
    if not token:
        return None
    payload = decode_access_token(token)
    if payload is None:
        return None
    user_id = payload.get("sub")
    if user_id is None:
        return None
    try:
        user_id_int = int(user_id)
    except (ValueError, TypeError):
        return None
    return db.query(User).filter(User.id == user_id_int).first()


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_access_token(token)

    if payload is None:
        raise credentials_exception

    user_id = payload.get("sub")

    if user_id is None:
        raise credentials_exception

    try:
        user_id_int = int(user_id)
    except (ValueError, TypeError):
        raise credentials_exception

    user = db.query(User).filter(User.id == user_id_int).first()

    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )

    if user.role == "official" and user.approval_status != "approved":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Authority account is not approved.",
        )

    return user


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(user: UserCreate, db: Session = Depends(get_db)):
    # Check if email is already registered
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is already registered",
        )

    # Hash the password
    hashed_password = hash_password(user.password)

    # Create new user instance
    new_user = User(
        email=user.email,
        password_hash=hashed_password,
        full_name=user.full_name,
        phone=user.phone,
    )

    # Save to PostgreSQL
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "message": "User registered successfully",
        "data": new_user,
    }


@router.post("/login", response_model=LoginResponse, status_code=status.HTTP_200_OK)
def login(credentials: LoginRequest, db: Session = Depends(get_db)):
    # Find user by email
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Verify password against stored bcrypt hash
    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Check if account is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is inactive",
        )

    # Check authority approval status
    if user.role == "official":
        if user.approval_status == "pending":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your application is awaiting Admin approval.",
            )
        elif user.approval_status == "rejected":
            app_record = (
                db.query(AuthorityApplication)
                .filter(AuthorityApplication.user_id == user.id)
                .order_by(AuthorityApplication.id.desc())
                .first()
            )
            reason_msg = f": {app_record.rejection_reason}" if app_record and app_record.rejection_reason else "."
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Your Authority application was rejected{reason_msg}",
            )
        elif user.approval_status != "approved":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Authority account not approved for portal access.",
            )

    # Generate JWT access token
    access_token = create_access_token(
        data={"sub": str(user.id), "role": user.role}
    )

    return {
        "message": "Login successful",
        "access_token": access_token,
        "token_type": "bearer",
        "data": user,
    }


@router.post("/forgot-password", response_model=ForgotPasswordResponse, status_code=status.HTTP_200_OK)
def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db),
    email_service: EmailService = Depends(get_email_service),
):
    """
    Initiate password reset by sending a 6-digit OTP code to the user's email.
    Always returns a generic HTTP 200 message to protect user privacy.
    """
    normalized_email = request.email.strip().lower()
    masked = mask_email(normalized_email)
    logger.info("Forgot password request received for email: %s", masked)

    user = db.query(User).filter(User.email == normalized_email).first()

    # Privacy-preserving response when configured vs explicit dev mode notification
    is_configured = email_service.is_configured()
    if is_configured:
        generic_message = "If this email is registered, a 6-digit verification code has been sent."
        delivery_status = "sent"
    else:
        generic_message = (
            "[DEV MODE] Email provider not configured in backend/.env. "
            "Simulated OTP generated for local testing (no real email was sent). "
            "Configure SMTP_USER and SMTP_PASSWORD in backend/.env for real email delivery."
        )
        delivery_status = "dev_simulation"

    if not user:
        logger.info("Email %s not found in registered users. Returning generic privacy response.", masked)
        return {
            "message": generic_message,
            "reset_token": None,
            "delivery_status": delivery_status,
        }

    if not user.is_active:
        logger.warning("User account for %s is inactive. Returning generic privacy response.", masked)
        return {
            "message": generic_message,
            "reset_token": None,
            "delivery_status": delivery_status,
        }

    logger.info("Registered user found (ID: %s) for email %s. Verifying cooldown...", user.id, masked)
    now = datetime.now(timezone.utc)

    # Check cooldown: rate limit requests within 60 seconds
    recent_otp = (
        db.query(PasswordResetOTP)
        .filter(
            PasswordResetOTP.email == normalized_email,
            PasswordResetOTP.is_used == False,
        )
        .order_by(PasswordResetOTP.created_at.desc())
        .first()
    )
    if recent_otp and (now - recent_otp.created_at).total_seconds() < 60:
        wait_sec = int(60 - (now - recent_otp.created_at).total_seconds())
        logger.warning("Rate limit hit for %s. Re-request blocked (%ss cooldown remaining).", masked, wait_sec)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Please wait {wait_sec} seconds before requesting another verification code.",
        )

    # Invalidate any existing unused OTPs for this email
    db.query(PasswordResetOTP).filter(
        PasswordResetOTP.email == normalized_email,
        PasswordResetOTP.is_used == False,
    ).update({"is_used": True})

    # Generate secure 6-digit OTP
    otp = generate_otp(6)
    otp_hash = hash_otp(otp)
    expires_at = now + timedelta(minutes=10)

    otp_record = PasswordResetOTP(
        user_id=user.id,
        email=normalized_email,
        otp_hash=otp_hash,
        expires_at=expires_at,
        attempts_count=0,
        max_attempts=5,
        is_used=False,
    )
    db.add(otp_record)
    db.commit()
    logger.info("New OTP record stored in database for %s. Initiating email dispatch...", masked)

    try:
        delivered = email_service.send_password_reset_otp(
            to_email=normalized_email,
            otp=otp,
            expires_in_minutes=10,
        )
        if delivered:
            logger.info("Password reset OTP successfully dispatched via email for %s", masked)
        else:
            logger.warning(
                "Password reset OTP generated in development simulation mode for %s (no real email delivered).",
                masked,
            )
    except EmailDeliveryError as e:
        logger.error("Email delivery failed for %s: %s. Rolling back OTP record.", masked, e)
        # Safely clean up OTP record if email delivery failed
        try:
            db.delete(otp_record)
            db.commit()
        except Exception as db_err:
            logger.warning("DB cleanup exception during email failure rollback: %s", db_err)
            db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to send verification email. {str(e)}",
        ) from e
    except Exception as e:
        logger.error("Unexpected error during password reset dispatch for %s: %s", masked, e)
        try:
            db.delete(otp_record)
            db.commit()
        except Exception as db_err:
            logger.warning("DB cleanup exception during unexpected error rollback: %s", db_err)
            db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Email delivery service encountered an unexpected error. Please try again shortly.",
        ) from e

    return {
        "message": generic_message,
        "reset_token": None,
        "delivery_status": delivery_status,
    }


@router.post("/verify-otp", response_model=VerifyOtpResponse, status_code=status.HTTP_200_OK)
def verify_otp(
    request: VerifyOtpRequest,
    db: Session = Depends(get_db),
):
    """
    Verify the 6-digit OTP code sent to the user's email.
    Returns a verified reset token upon successful verification.
    """
    normalized_email = request.email.strip().lower()
    masked = mask_email(normalized_email)
    otp_input = request.otp.strip()

    logger.info("OTP verification attempted for email: %s", masked)

    if len(otp_input) != 6 or not otp_input.isdigit():
        logger.warning("Malformed OTP input submitted for %s", masked)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please enter a valid 6-digit numeric verification code.",
        )

    otp_record = (
        db.query(PasswordResetOTP)
        .filter(
            PasswordResetOTP.email == normalized_email,
            PasswordResetOTP.is_used == False,
        )
        .order_by(PasswordResetOTP.created_at.desc())
        .first()
    )

    if not otp_record:
        logger.warning("No active OTP found in database for %s", masked)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active verification code found for this email. Please request a new code.",
        )

    now = datetime.now(timezone.utc)
    # Check max attempts limit
    if otp_record.attempts_count >= otp_record.max_attempts:
        otp_record.is_used = True
        db.commit()
        logger.warning("Max verification attempts reached for %s. Invalidating OTP.", masked)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum verification attempts exceeded. Please request a new code.",
        )

    # Check expiration
    if now > otp_record.expires_at:
        otp_record.is_used = True
        db.commit()
        logger.warning("Expired OTP submitted for %s. Invalidating OTP.", masked)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification code has expired. Please request a new code.",
        )

    # Verify HMAC hash
    if not verify_otp_hash(otp_input, otp_record.otp_hash):
        otp_record.attempts_count += 1
        remaining = max(0, otp_record.max_attempts - otp_record.attempts_count)
        if remaining == 0:
            otp_record.is_used = True
        db.commit()
        msg = (
            f"Invalid verification code. {remaining} attempt(s) remaining."
            if remaining > 0
            else "Maximum verification attempts exceeded. Please request a new code."
        )
        logger.warning("Invalid OTP entered for %s (%s attempts remaining)", masked, remaining)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=msg,
        )

    # Mark OTP as consumed to prevent reuse
    otp_record.is_used = True
    db.commit()

    # Generate cryptographically signed reset token valid for 15 minutes
    reset_token = create_verified_reset_token(
        email=normalized_email,
        otp_id=otp_record.id,
    )
    logger.info("OTP verification succeeded for %s. Signed reset token generated.", masked)

    return {
        "message": "Verification code verified successfully.",
        "reset_token": reset_token,
    }


@router.post("/resend-otp", response_model=ResendOtpResponse, status_code=status.HTTP_200_OK)
def resend_otp(
    request: ResendOtpRequest,
    db: Session = Depends(get_db),
    email_service: EmailService = Depends(get_email_service),
):
    """
    Resend a new 6-digit OTP code to the user's email address with cooldown enforcement.
    """
    masked = mask_email(request.email)
    logger.info("Resend OTP requested for email: %s", masked)
    fp_res = forgot_password(
        request=ForgotPasswordRequest(email=request.email),
        db=db,
        email_service=email_service,
    )
    return {
        "message": fp_res["message"],
        "cooldown_seconds": 60,
    }


@router.post("/reset-password", response_model=ResetPasswordResponse, status_code=status.HTTP_200_OK)
def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    """
    Reset user password using a verified reset token obtained through OTP verification.
    """
    payload = decode_verified_reset_token(request.token)
    if not payload or not payload.get("sub"):
        logger.warning("Password reset rejected: Invalid or unverified reset token.")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token. Please verify your OTP again.",
        )

    email = payload["sub"]
    masked = mask_email(email)

    if len(request.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 6 characters long",
        )

    user = db.query(User).filter(User.email == email).first()
    if not user or not user.is_active:
        logger.warning("User account not found or inactive for email: %s", masked)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User account not found or inactive",
        )

    user.password_hash = hash_password(request.new_password)
    db.commit()
    logger.info("Password updated successfully in PostgreSQL for email: %s", masked)

    return {
        "message": "Password reset successfully. You can now log in with your new password.",
    }


@router.get("/me", response_model=UserResponse)
def read_current_user(
    current_user: User = Depends(get_current_user)
):
    return current_user


@router.patch("/me", response_model=UserResponse, status_code=status.HTTP_200_OK)
def update_current_user_profile(
    update_data: UserProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Allow authenticated user to update profile details (full_name, phone).
    Protected against unauthorized modifications of role, email, password, etc.
    """
    if update_data.full_name is not None:
        name_clean = update_data.full_name.strip()
        if len(name_clean) < 2:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Full name must be at least 2 characters long",
            )
        current_user.full_name = name_clean

    if update_data.phone is not None:
        phone_clean = update_data.phone.strip()
        current_user.phone = phone_clean if phone_clean else None

    if update_data.profile_image_url is not None:
        url_clean = update_data.profile_image_url.strip()
        current_user.profile_image_url = url_clean if url_clean else None

    db.commit()
    db.refresh(current_user)
    return current_user


@router.put("/users/me/profile-photo", response_model=ProfilePhotoResponse, status_code=status.HTTP_200_OK)
@router.put("/me/profile-photo", response_model=ProfilePhotoResponse, status_code=status.HTTP_200_OK)
async def update_profile_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    storage: BaseStorageService = Depends(get_storage_service),
):
    """
    Upload and update authenticated user's profile photo in Cloudinary.
    Saves image under medal/avatars/profiles/{user_id}/, cleans up old avatar,
    and updates user's profile_image_url and profile_image_public_id in PostgreSQL.
    """
    contents, verified_mime, ext = await validate_and_read_upload(
        file=file,
        allowed_types={"image/*"},
        max_size_bytes=MAX_IMAGE_SIZE_BYTES,
    )

    folder = f"medal/avatars/profiles/{current_user.id}"
    upload_res = await storage.upload_bytes(
        data=contents,
        filename=file.filename or f"avatar{ext}",
        folder=folder,
        content_type=verified_mime,
    )

    # Clean up previous avatar from Cloudinary if it exists
    old_public_id = current_user.profile_image_public_id
    if old_public_id and old_public_id != upload_res.public_id:
        try:
            await storage.delete_asset(old_public_id)
        except Exception as cleanup_err:
            logger.warning("Could not delete old avatar %s: %s", old_public_id, cleanup_err)

    current_user.profile_image_url = upload_res.secure_url
    current_user.profile_image_public_id = upload_res.public_id
    db.commit()
    db.refresh(current_user)

    return ProfilePhotoResponse(
        message="Profile photo updated successfully",
        profile_image_url=upload_res.secure_url,
        public_id=upload_res.public_id,
        data=UserResponse.model_validate(current_user),
    )


def require_role(*allowed_roles: str):
    def role_checker(
        current_user: User = Depends(get_current_user)
    ):
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return current_user

    return role_checker


@router.get("/admin-test")
def admin_test(
    current_user: User = Depends(require_role("admin"))
):
    return {"message": "Admin access granted"}


@router.get("/official-test")
def official_test(
    current_user: User = Depends(
        require_role("official", "admin")
    )
):
    return {"message": "Official access granted"}


@router.get("/users", response_model=List[UserResponse], status_code=status.HTTP_200_OK)
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("admin")),
):
    """List all registered users (Admin only)."""
    return db.query(User).order_by(User.id.asc()).all()







