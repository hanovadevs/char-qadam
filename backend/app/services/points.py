"""Points balance and ledger query helpers.

Kept in services/ so routers stay thin and the same queries can be
reused by the activity sync and the voucher redeem flow.
"""
from __future__ import annotations

from sqlalchemy import func, select
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
    # One snapshot and one network round trip for all three ledger aggregates.
    row = (await session.execute(select(
        func.coalesce(func.sum(PointsLedger.delta), 0),
        func.coalesce(func.sum(PointsLedger.delta).filter(PointsLedger.reason == LedgerReason.STEP_EARN), 0),
        func.coalesce(func.sum(PointsLedger.delta).filter(PointsLedger.reason == LedgerReason.OFFER_SPEND), 0),
    ).where(PointsLedger.user_id == user_id))).one()
    balance, total_earned, total_spent = int(row[0]), int(row[1]), abs(int(row[2]))

    return {"balance": balance, "total_earned": total_earned, "total_spent": total_spent}
