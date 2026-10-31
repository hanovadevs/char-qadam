"""Pydantic schemas for activity endpoints."""
from __future__ import annotations

from pydantic import BaseModel, Field


class SyncIn(BaseModel):
    """Body for POST /activity/sync."""
    local_date: str = Field(
        pattern=r"^\d{4}-\d{2}-\d{2}$",
        description="Calendar date in the user's local timezone (YYYY-MM-DD).",
        examples=["2026-08-14"],
    )
    eligible_steps: int = Field(ge=0, description="Total steps for the day as read from the health API.")
    source: str = Field(default="health", max_length=32, description="'health' or 'manual'.")
    sync_key: str = Field(min_length=8, max_length=128, description="Client-generated idempotency key (UUID recommended).")


class SyncOut(BaseModel):
    """Response for POST /activity/sync."""
    local_date: str
    eligible_steps: int           # server-stored value (may be capped)
    points_awarded: int           # points earned in *this* sync (0 = no change / replay)
    balance: int                  # new running balance after this sync
    is_replay: bool               # True when sync_key was already processed (no-op)
    points_earned_today: int = 0
    steps_per_point: int = 100
    daily_step_cap: int = 20000


class ActivityPeriod(BaseModel):
    """Single period row in GET /activity response."""
    date: str                     # YYYY-MM-DD
    eligible_steps: int
    source: str | None = None     # health | manual_debug | background_workmanager


class ActivityRangeOut(BaseModel):
    """Response for GET /activity."""
    range: str                    # today | week | month
    total_steps: int
    days: list[ActivityPeriod]
