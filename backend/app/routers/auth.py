import mimetypes
from typing import List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.user import User
from app.schemas.user import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    LoginResponse,
    ProfilePhotoResponse,
    RegisterResponse,
    ResetPasswordRequest,
    ResetPasswordResponse,
    UserCreate,
    UserProfileUpdate,
    UserResponse,
)
from app.services.storage import BaseStorageService, get_storage_service
from app.utils.security import (
    create_access_token,
    create_password_reset_token,
    decode_access_token,
    decode_password_reset_token,
    hash_password,
    verify_password,
)

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")


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

    return user


oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/login", auto_error=False)


def get_optional_current_user(
    token: Optional[str] = Depends(oauth2_scheme_optional),
    db: Session = Depends(get_db),
) -> Optional[User]:
    if not token:
        return None
    try:
        payload = decode_access_token(token)
        if payload is None:
            return None
        user_id = payload.get("sub")
        if user_id is None:
            return None
        user = db.query(User).filter(User.id == int(user_id)).first()
        return user if (user and user.is_active) else None
    except Exception:
        return None


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
def forgot_password(request: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """
    Generate a password reset token for the given email address.
    Always returns HTTP 200 with an identical message to avoid revealing email existence.
    """
    normalized_email = request.email.strip().lower()
    user = db.query(User).filter(User.email == normalized_email).first()

    reset_token = None
    if user and user.is_active:
        reset_token = create_password_reset_token(user.email)

    return {
        "message": "If this email is registered, password reset instructions have been sent.",
        "reset_token": reset_token,
    }


@router.post("/reset-password", response_model=ResetPasswordResponse, status_code=status.HTTP_200_OK)
def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    """
    Reset user password using a valid, unexpired reset token.
    """
    email = decode_password_reset_token(request.token)
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )

    if len(request.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 6 characters long",
        )

    user = db.query(User).filter(User.email == email).first()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )

    user.password_hash = hash_password(request.new_password)
    db.commit()

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
    Upload and update authenticated user's profile photo in MinIO object storage.
    Saves image under profiles/{user_id}/ and updates user's profile_image_url in PostgreSQL.
    """
    content_type = file.content_type
    # If client sent generic application/octet-stream or empty content type, guess from filename
    if not content_type or content_type in ("application/octet-stream", "application/octetstream", "binary/octet-stream"):
        guessed_type, _ = mimetypes.guess_type(file.filename or "")
        if guessed_type:
            content_type = guessed_type

    if not content_type or not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only image files are accepted for profile photo",
        )

    folder = f"profiles/{current_user.id}"
    file_url = await storage.upload_file(file, folder=folder)

    current_user.profile_image_url = file_url
    db.commit()
    db.refresh(current_user)

    return {
        "message": "Profile photo updated successfully",
        "profile_image_url": file_url,
        "data": current_user,
    }


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







