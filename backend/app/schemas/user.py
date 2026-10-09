from datetime import datetime
from pydantic import BaseModel, ConfigDict, EmailStr


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    phone: str | None = None


class UserProfileUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    profile_image_url: str | None = None


class UserResponse(BaseModel):
    id: int
    email: EmailStr
    full_name: str
    phone: str | None = None
    profile_image_url: str | None = None
    role: str
    is_verified: bool
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ProfilePhotoResponse(BaseModel):
    message: str
    profile_image_url: str
    data: UserResponse

    model_config = ConfigDict(from_attributes=True)


class RegisterResponse(BaseModel):
    message: str
    data: UserResponse


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class LoginResponse(BaseModel):
    message: str
    access_token: str
    token_type: str = "bearer"
    data: UserResponse


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str
    reset_token: str | None = None


class VerifyOtpRequest(BaseModel):
    email: EmailStr
    otp: str


class VerifyOtpResponse(BaseModel):
    message: str
    reset_token: str


class ResendOtpRequest(BaseModel):
    email: EmailStr


class ResendOtpResponse(BaseModel):
    message: str
    cooldown_seconds: int | None = None


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class ResetPasswordResponse(BaseModel):
    message: str

