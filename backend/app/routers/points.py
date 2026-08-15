"""Points router — balance and ledger history.

Routes
------
GET /points/balance    Current balance + lifetime earned/spent breakdown.
GET /points/history    Paginated ledger entries (newest first).
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import PointsLedger, User
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.points import BalanceOut, LedgerEntryOut, LedgerPageOut
from app.services.points import get_balance_breakdown

router = APIRouter(prefix="/points", tags=["points"])


@router.get(
    "/balance",
    response_model=BalanceOut,
    summary="Get current points balance",
)
async def balance(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> BalanceOut:
    """Return the authenticated user's current balance and lifetime stats."""
    breakdown = await get_balance_breakdown(current_user.id, session)
    return BalanceOut(**breakdown)


@router.get(
    "/history",
    response_model=LedgerPageOut,
    summary="Get paginated points ledger",
)
async def history(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> LedgerPageOut:
    """Return a paginated list of ledger entries for the authenticated user.

    Entries are ordered newest-first.  Use ``limit`` and ``offset`` to page.
    """
    # Total count
    count_result = await session.execute(
        select(func.count()).where(PointsLedger.user_id == current_user.id)
    )
    total = int(count_result.scalar())

    # Page of entries
    entries_result = await session.execute(
        select(PointsLedger)
        .where(PointsLedger.user_id == current_user.id)
        .order_by(PointsLedger.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    entries = entries_result.scalars().all()

    return LedgerPageOut(
        total=total,
        limit=limit,
        offset=offset,
        entries=[LedgerEntryOut.model_validate(e) for e in entries],
    )
