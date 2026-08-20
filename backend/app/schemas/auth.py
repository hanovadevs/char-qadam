"""Pydantic v2 schemas for auth endpoints.

These are the request/response models for:
    POST /auth/register  → RegisterIn  → TokenOut
    POST /auth/login     → LoginIn     → TokenOut
    GET  /auth/me        →             → UserOut
"""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------

class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    country: str | None = Field(default=None, max_length=2)
    timezone: str | None = Field(default=None, max_length=64)


class LoginIn(BaseModel):
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


class UserOut(BaseModel):
    id: str
    email: EmailStr
    status: str
    country: str | None
    timezone: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
