"""Pydantic schemas for admin endpoints."""
from __future__ import annotations

from typing import List, Optional
from pydantic import BaseModel, Field


class CreatePartnerIn(BaseModel):
    name: str = Field(min_length=2, max_length=255, description="Name of the merchant partner")


class CreatePartnerOut(BaseModel):
    partner_id: str
    name: str
    status: str
    raw_api_key: str = Field(description="Raw API key. Store safely, it will not be shown again.")


class SweepExpiredOut(BaseModel):
    swept_count: int
    swept_codes: List[str]
    message: str


class FraudAuditItemOut(BaseModel):
    user_id: str
    email: str
    status: str
    total_lifetime_steps: int
    days_recorded: int
    risk_score: int
    flags: List[str]


class UpdateUserStatusIn(BaseModel):
    status: str = Field(pattern="^(ACTIVE|SUSPENDED|DELETED)$")
    reason: Optional[str] = None
