"""Pydantic v2 schemas for auth endpoints.

These are the request/response models for:
    POST /auth/register  → RegisterIn  → TokenOut
    POST /auth/login     → LoginIn     → TokenOut
    GET  /auth/me        →             → UserOut
"""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------

class EmailIn(BaseModel):
    email: EmailStr

    @field_validator('email')
    @classmethod
    def normalize_email(cls, value):
        return str(value).lower()


class RegisterIn(EmailIn):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    country: str | None = Field(default=None, max_length=2)
    timezone: str | None = Field(default=None, max_length=64)


class LoginIn(EmailIn):
    email: EmailStr
    password: str


class GoogleAuthIn(BaseModel):
    id_token: str = Field(min_length=10, description="Google OAuth ID Token or Supabase OAuth Token")
    country: str | None = Field(default=None, max_length=2)
    timezone: str | None = Field(default=None, max_length=64)


# ---------------------------------------------------------------------------
# Responses
# ---------------------------------------------------------------------------

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str = "USER"
    partner_id: str | None = None
    partner_name: str | None = None
    user: UserOut | None = None


class VerificationOut(BaseModel):
    verification_required: bool = True
    verification_token: str
    email: EmailStr
    message: str = 'Enter the six-digit code sent to your email. It expires in 10 minutes.'
    resend_after_seconds: int = 60


class VerifyEmailIn(BaseModel):
    verification_token: str = Field(min_length=10, max_length=4096)
    code: str = Field(pattern=r'^\d{6}$')


class ResendVerificationIn(BaseModel):
    verification_token: str = Field(min_length=10, max_length=4096)


class UserOut(BaseModel):
    id: str
    email: EmailStr
    status: str
    role: str = "USER"
    partner_id: str | None = None
    partner_name: str | None = None
    country: str | None = None
    timezone: str | None = None
    created_at: datetime
    email_verified: bool = True

    model_config = {"from_attributes": True}


class ForgotPasswordIn(EmailIn):
    email: EmailStr


class ForgotPasswordOut(BaseModel):
    message: str
    reset_token: str | None = None  # Always empty; delivery is through verified email access.


class ResetPasswordIn(BaseModel):
    reset_token: str = Field(min_length=10)
    new_password: str = Field(min_length=8, max_length=128)


class ResetPasswordOut(BaseModel):
    message: str
