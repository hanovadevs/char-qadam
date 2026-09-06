"""Activity router — step sync and historical aggregates with anti-fraud date verification.

Routes
------
POST /activity/sync            Ingest a step count for a given day (idempotent).
GET  /activity?range=...       Aggregated step totals (today | week | month).
"""
from __future__ import annotations

from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.models import ActivityDaily, User
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.activity import ActivityPeriod, ActivityRangeOut, SyncIn, SyncOut
from app.services.activity import sync_activity

router = APIRouter(prefix="/activity", tags=["activity"])


@router.post(
    "/sync",
    response_model=SyncOut,
    summary="Sync daily step count (idempotent & anti-fraud verified)",
)
async def sync(
    body: SyncIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> SyncOut:
    """Ingest a step reading for a calendar day.

    Anti-Fraud invariants enforced:
    - Rejects future dates (> today).
    - Rejects stale historical dates (> 7 days past).
    - Steps are clamped to the server-configured daily cap.
    - Only the **increase** vs the previously stored total is awarded as points.
    - Replaying the same ``sync_key`` is a no-op (returns current state, 0 new points).
    """
    # 1. Anti-Fraud: Validate date bounds
    try:
        sync_date = date.fromisoformat(body.local_date)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD",
        )

    today = date.today()
    if sync_date > today:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot sync steps for a future date",
        )
    if sync_date < today - timedelta(days=7):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sync window expired. Steps can only be synced within 7 days.",
        )

    # 2. Execute sync service
    settings = get_settings()
    result = await sync_activity(
        user_id=current_user.id,
        local_date=body.local_date,
        eligible_steps=body.eligible_steps,
        source=body.source,
        sync_key=body.sync_key,
        session=session,
        settings=settings,
    )
    return SyncOut(
        local_date=body.local_date,
        eligible_steps=result.eligible_steps,
        points_awarded=result.points_awarded,
        balance=result.balance,
        is_replay=result.is_replay,
    )


@router.get(
    "",
    response_model=ActivityRangeOut,
    summary="Get aggregated step history",
)
async def get_activity(
    range: str = Query(default="today", pattern="^(today|week|month|3months|6months|year|all)$"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ActivityRangeOut:
    """Return step totals for today, previous weeks, or previous months.

    Days with no synced data are omitted from ``days`` but counted in the
    date window for ``total_steps``.
    """
    today = date.today()
    if range == "today":
        start = today
    elif range == "week":
        start = today - timedelta(days=6)
    elif range == "month":
        start = today - timedelta(days=29)
    elif range == "3months":
        start = today - timedelta(days=90)
    elif range == "6months":
        start = today - timedelta(days=180)
    elif range == "year":
        start = today - timedelta(days=365)
    else:  # all
        start = None

    end_str = today.isoformat()

    query = select(ActivityDaily).where(
        ActivityDaily.user_id == current_user.id,
        ActivityDaily.local_date <= end_str,
    )
    if start is not None:
        query = query.where(ActivityDaily.local_date >= start.isoformat())

    query = query.order_by(ActivityDaily.local_date)

    rows_result = await session.execute(query)
    rows = rows_result.scalars().all()

    days = [ActivityPeriod(date=r.local_date, eligible_steps=r.eligible_steps, source=r.source) for r in rows]
    total_steps = sum(d.eligible_steps for d in days)

    return ActivityRangeOut(range=range, total_steps=total_steps, days=days)
