"""Offers router — catalog and redemption.

Routes
------
GET  /offers              List active offers available for redemption.
POST /offers/{id}/redeem  Spend points on an offer and receive a voucher.
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.models import Offer, OfferStatus, User
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.offers import OfferOut, RedeemOut
from app.services.offers import redeem_offer

router = APIRouter(prefix="/offers", tags=["offers"])


@router.get(
    "",
    response_model=list[OfferOut],
    summary="List active offers",
)
async def list_offers(
    session: AsyncSession = Depends(get_session),
    _: User = Depends(get_current_user),   # auth required, user not used in query
) -> list[OfferOut]:
    """Return all currently active, in-date, in-stock offers.

    Filters applied:
    - ``status = ACTIVE``
    - ``starts_at`` is NULL or in the past
    - ``ends_at`` is NULL or in the future
    - ``inventory`` is NULL (unlimited) or > 0
    """
    now = datetime.now(timezone.utc)

    result = await session.execute(
        select(Offer)
        .where(
            Offer.status == OfferStatus.ACTIVE,
            or_(Offer.starts_at.is_(None), Offer.starts_at <= now),
            or_(Offer.ends_at.is_(None), Offer.ends_at >= now),
            or_(Offer.inventory.is_(None), Offer.inventory > 0),
        )
        .order_by(Offer.points_cost)
    )
    offers = result.scalars().all()
    return [OfferOut.model_validate(o) for o in offers]


@router.post(
    "/{offer_id}/redeem",
    response_model=RedeemOut,
    status_code=status.HTTP_201_CREATED,
    summary="Redeem an offer — spend points, receive a voucher",
)
async def redeem(
    offer_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> RedeemOut:
    """Atomically deduct points and issue a single-use voucher.

    Returns the ``short_code`` for human entry at POS and the raw ``token``
    to embed in a QR code on the mobile client.

    Error codes:
    - **402** Insufficient points
    - **404** Offer not found
    - **409** Offer inactive / expired / out of stock
    """
    settings = get_settings()
    result = await redeem_offer(
        offer_id=offer_id,
        user=current_user,
        session=session,
        settings=settings,
    )
    return RedeemOut(
        voucher_id=result.voucher_id,
        short_code=result.short_code,
        token=result.token,
        expires_at=result.expires_at,
        points_spent=result.points_spent,
        balance=result.balance,
    )
