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

class PasswordInput(BaseModel):
    @field_validator("password", "new_password", check_fields=False)
    @classmethod
    def validate_password_bytes(cls, value):
        if value is not None and len(value.encode("utf-8")) > 72:
            raise ValueError("Password must be at most 72 UTF-8 bytes")
        return value


class RegisterIn(PasswordInput):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    country: str | None = Field(default=None, max_length=2)
    timezone: str | None = Field(default=None, max_length=64)


class LoginIn(PasswordInput):
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

    model_config = {"from_attributes": True}


class ForgotPasswordIn(BaseModel):
    email: EmailStr


class ForgotPasswordOut(BaseModel):
    message: str
    reset_token: str | None = None  # Populated in debug/dev mode


class ResetPasswordIn(PasswordInput):
    reset_token: str = Field(min_length=10)
    new_password: str = Field(min_length=8, max_length=128)


class ResetPasswordOut(BaseModel):
    message: str
