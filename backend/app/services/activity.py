"""Activity sync business logic.

Core invariants (from MVP_PLAN.md §1):
  - Server clamps eligible_steps to ``daily_step_cap``.
  - Upsert activity_daily by (user_id, local_date); append a STEP_EARN
    ledger entry for the **delta only** when the day's total increases.
  - Idempotent on sync_key: same key → no-op, 0 new points awarded.
  - Steps never decrease for a given day (late/out-of-order syncs ignored).
  - Earning rule (steps_per_point) lives in config — no formula in the app.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.db.models import ActivityDaily, LedgerReason, PointsLedger
from app.services.points import get_balance


@dataclass
class SyncResult:
    eligible_steps: int   # server-stored step count after this sync
    points_awarded: int   # new points minted in this call (0 = no change / replay)
    balance: int          # running balance after award
    is_replay: bool       # True when sync_key was already the current key → no-op


async def sync_activity(
    *,
    user_id: str,
    local_date: str,
    eligible_steps: int,
    source: str,
    sync_key: str,
    session: AsyncSession,
    settings: Settings,
) -> SyncResult:
    """Upsert today's step count and award points for any new steps.

    Called inside an already-open session; the caller must NOT commit before
    receiving the result (we commit here to keep the ledger write atomic).
    """
    # ------------------------------------------------------------------ clamp
    clamped = min(eligible_steps, settings.daily_step_cap)

    # ------------------------------------------------ fetch existing day row
    result = await session.execute(
        select(ActivityDaily)
        .where(
            ActivityDaily.user_id == user_id,
            ActivityDaily.local_date == local_date,
        )
        .with_for_update()          # row-level lock → safe under concurrent syncs
    )
    row: ActivityDaily | None = result.scalar_one_or_none()

    # ----------------------------------------------- idempotency: exact replay
    if row is not None and row.sync_key == sync_key:
        balance = await get_balance(user_id, session)
        return SyncResult(
            eligible_steps=row.eligible_steps,
            points_awarded=0,
            balance=balance,
            is_replay=True,
        )

    # ----------------------------------------- compute delta & update / insert
    if row is None:
        # First sync for this day
        old_steps = 0
        new_steps = clamped
        row = ActivityDaily(
            id=str(uuid.uuid4()),
            user_id=user_id,
            local_date=local_date,
            eligible_steps=new_steps,
            source=source,
            sync_key=sync_key,
            sync_version=1,
        )
        session.add(row)
    else:
        old_steps = row.eligible_steps
        # Never decrease the stored total — late / stale syncs are silent no-ops
        new_steps = max(clamped, old_steps)
        row.eligible_steps = new_steps
        row.sync_key = sync_key
        row.sync_version += 1
        row.source = source

    delta_steps = new_steps - old_steps          # always >= 0
    delta_points = delta_steps // settings.steps_per_point

    # ------------------------------------------ mint ledger entry if warranted
    if delta_points > 0:
        ledger = PointsLedger(
            id=str(uuid.uuid4()),
            user_id=user_id,
            delta=delta_points,
            reason=LedgerReason.STEP_EARN,
            ref_type="activity_daily",
            ref_id=row.id,
        )
        session.add(ledger)

    await session.commit()

    balance = await get_balance(user_id, session)
    return SyncResult(
        eligible_steps=new_steps,
        points_awarded=delta_points,
        balance=balance,
        is_replay=False,
    )
