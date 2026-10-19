"""Vouchers router — wallet (My Rewards).

Routes
------
GET /vouchers?status=active|redeemed|expired   List user's vouchers by status.

Lazy expiry: on each read, ISSUED vouchers past ``expires_at`` are marked
EXPIRED in-place.  A scheduled job can take over this duty post-MVP.
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Offer, User, Voucher, VoucherStatus
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.offers import VoucherOut

router = APIRouter(prefix="/vouchers", tags=["vouchers"])


async def _expire_stale(vouchers: list[Voucher], session: AsyncSession) -> None:
    """Mark any ISSUED vouchers that have passed their expiry as EXPIRED."""
    now = datetime.now(timezone.utc)
    stale = [v for v in vouchers if v.status == VoucherStatus.ISSUED and v.expires_at < now]
    if stale:
        for v in stale:
            v.status = VoucherStatus.EXPIRED
            v.redeemed_at = None
        await session.commit()


@router.get(
    "",
    response_model=list[VoucherOut],
    summary="List vouchers in the user's wallet",
)
async def list_vouchers(
    status: str = Query(
        default="active",
        pattern="^(active|redeemed|expired|cancelled)$",
        description="Filter: 'active' = ISSUED & not expired, 'redeemed', 'expired', 'cancelled'",
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[VoucherOut]:
    """Return the authenticated user's vouchers filtered by status.

    ``active`` returns vouchers that are ISSUED and not yet expired.
    Expired ISSUED vouchers are lazily updated to EXPIRED on this read.
    """
    # Fetch all user vouchers (with their offer for display fields)
    result = await session.execute(
        select(Voucher, Offer)
        .join(Offer, Voucher.offer_id == Offer.id)
        .where(Voucher.user_id == current_user.id)
        .order_by(Voucher.issued_at.desc())
    )
    rows = result.all()
    vouchers = [row[0] for row in rows]
    offers_map = {row[0].id: row[1] for row in rows}

    # Lazy expiry pass
    await _expire_stale(vouchers, session)

    # Filter by requested status
    now = datetime.now(timezone.utc)
    if status == "active":
        filtered = [
            v for v in vouchers
            if v.status == VoucherStatus.ISSUED and v.expires_at >= now
        ]
    elif status == "redeemed":
        filtered = [v for v in vouchers if v.status == VoucherStatus.REDEEMED]
    elif status == 'cancelled':
        filtered = [v for v in vouchers if v.status == VoucherStatus.CANCELLED]
    else:  # expired
        filtered = [v for v in vouchers if v.status == VoucherStatus.EXPIRED]

    return [
        VoucherOut(
            id=v.id,
            offer_id=v.offer_id,
            short_code=v.short_code,
            status=v.status.value,
            issued_at=v.issued_at,
            expires_at=v.expires_at,
            redeemed_at=v.redeemed_at,
            offer_title=offers_map[v.id].title,
            offer_discount_type=offers_map[v.id].discount_type.value,
            offer_discount_value=float(offers_map[v.id].discount_value),
        )
        for v in filtered
    ]
