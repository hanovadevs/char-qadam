"""Pydantic schemas for user profile endpoints."""
from __future__ import annotations

from pydantic import BaseModel, Field


class PatchUserIn(BaseModel):
    """Body for PATCH /users/me.

    All fields are optional — only supplied fields are updated.
    Email is intentionally excluded: it is the identity key and
    cannot be changed without a separate verification flow.
    """
    country: str | None = Field(default=None, max_length=2, description="ISO 3166-1 alpha-2 country code.")
    timezone: str | None = Field(default=None, max_length=64, description="IANA timezone string, e.g. 'Asia/Karachi'.")
    password: str | None = Field(default=None, min_length=8, max_length=128, description="New password (min 8 chars). Stored as bcrypt hash.")
