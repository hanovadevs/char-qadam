"""Pydantic schemas for points endpoints."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class BalanceOut(BaseModel):
    """Response for GET /points/balance."""
    balance: int
    total_earned: int             # lifetime STEP_EARN sum
    total_spent: int              # lifetime OFFER_SPEND sum (positive number)


class LedgerEntryOut(BaseModel):
    """A single row in the points ledger."""
    id: str
    delta: int
    reason: str
    ref_type: str | None
    ref_id: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class LedgerPageOut(BaseModel):
    """Paginated response for GET /points/history."""
    total: int
    limit: int
    offset: int
    entries: list[LedgerEntryOut]
