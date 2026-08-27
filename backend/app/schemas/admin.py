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
