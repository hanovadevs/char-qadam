"""Points balance and ledger query helpers.

Kept in services/ so routers stay thin and the same queries can be
reused by the activity sync and the voucher redeem flow.
"""
from __future__ import annotations

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import LedgerReason, PointsLedger


async def get_balance(user_id: str, session: AsyncSession) -> int:
    """Return the current points balance for *user_id*.

    Balance = SUM(delta) over all ledger rows.  Append-only ledger means
    this is always correct — no cached balance to drift.
    """
    result = await session.execute(
        select(func.coalesce(func.sum(PointsLedger.delta), 0)).where(
            PointsLedger.user_id == user_id
        )
    )
    return int(result.scalar())


async def get_balance_breakdown(user_id: str, session: AsyncSession) -> dict:
    """Return balance, total_earned, and total_spent for *user_id*."""
    result = await session.execute(
        select(
            func.coalesce(func.sum(PointsLedger.delta), 0),
            func.coalesce(func.sum(case((PointsLedger.reason == LedgerReason.STEP_EARN, PointsLedger.delta), else_=0)), 0),
            func.coalesce(func.sum(case((PointsLedger.reason == LedgerReason.OFFER_SPEND, PointsLedger.delta), else_=0)), 0),
        ).where(PointsLedger.user_id == user_id)
    )
    balance, earned, spent = result.one()
    return {"balance": int(balance), "total_earned": int(earned), "total_spent": abs(int(spent))}
