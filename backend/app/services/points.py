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
    result = await session.execute(
        select(
            func.coalesce(func.sum(PointsLedger.delta), 0).label("balance"),
            func.coalesce(
                func.sum(
                    PointsLedger.delta.operate(
                        lambda col: func.nullif(col, None)
                    )
                ),
                0,
            ).label("dummy"),  # placeholder; computed below per-reason
        ).where(PointsLedger.user_id == user_id)
    )

    # Simpler: three targeted queries (small table in MVP, index on user_id)
    balance = await get_balance(user_id, session)

    earned_result = await session.execute(
        select(func.coalesce(func.sum(PointsLedger.delta), 0)).where(
            PointsLedger.user_id == user_id,
            PointsLedger.reason == LedgerReason.STEP_EARN,
        )
    )
    total_earned = int(earned_result.scalar())

    spent_result = await session.execute(
        select(func.coalesce(func.sum(PointsLedger.delta), 0)).where(
            PointsLedger.user_id == user_id,
            PointsLedger.reason == LedgerReason.OFFER_SPEND,
        )
    )
    total_spent = abs(int(spent_result.scalar()))  # stored as negative; return positive

    return {"balance": balance, "total_earned": total_earned, "total_spent": total_spent}
