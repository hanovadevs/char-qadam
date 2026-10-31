"""Service for sweeping and transitioning past-due vouchers to EXPIRED status."""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import List

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Voucher, VoucherStatus

logger = logging.getLogger(__name__)


async def sweep_expired_vouchers(session: AsyncSession) -> dict[str, int | list[str]]:
    """Find all vouchers where status='ISSUED' and expires_at < now(), and update to 'EXPIRED'.

    Returns a summary dict with the count and list of swept voucher IDs.
    """
    now = datetime.now(timezone.utc)

    result = await session.execute(
        update(Voucher)
        .where(
            Voucher.status == VoucherStatus.ISSUED,
            Voucher.expires_at < now,
        )
        .values(status=VoucherStatus.EXPIRED)
        .returning(Voucher.id, Voucher.short_code)
    )
    rows = result.all()
    await session.commit()

    swept_count = len(rows)
    swept_codes = [r.short_code for r in rows]

    if swept_count > 0:
        logger.info(f"Voucher expiration sweep: marked {swept_count} vouchers as EXPIRED: {swept_codes}")

    return {
        "swept_count": swept_count,
        "swept_codes": swept_codes,
    }
