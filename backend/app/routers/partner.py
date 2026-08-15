"""Partner-facing voucher validation and redemption API.

Routes (versioned — partners get /partner/v1 so we can break the contract
without affecting the consumer app which uses /auth, /activity, etc.)

POST /partner/v1/vouchers/validate   Look up a voucher by raw token; return nonce.
POST /partner/v1/vouchers/redeem     Consume the nonce; atomically mark voucher REDEEMED.

Auth: X-Partner-Key header (hashed API key stored in partners.api_key_hash).

Double-redeem guard
-------------------
The redeem UPDATE uses a conditional WHERE clause:
    WHERE id = :id AND status = 'ISSUED' AND expires_at > now()
PostgreSQL guarantees atomicity — exactly one concurrent transaction will
update the row; all others will see rowcount == 0 and receive 409.
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.models import (
    DiscountType,
    Offer,
    Partner,
    Redemption,
    Voucher,
    VoucherStatus,
)
from app.db.postgres import get_session
from app.deps import get_current_partner
from app.schemas.partner import PartnerRedeemIn, PartnerRedeemOut, ValidateIn, ValidateOut
from app.services.partner_auth import decode_nonce, generate_nonce

router = APIRouter(prefix="/partner/v1", tags=["partner"])


@router.post(
    "/vouchers/validate",
    response_model=ValidateOut,
    summary="Validate a voucher token (partner POS step 1)",
)
async def validate_voucher(
    body: ValidateIn,
    partner: Partner = Depends(get_current_partner),
    session: AsyncSession = Depends(get_session),
) -> ValidateOut:
    """Look up a voucher by its raw QR token.

    Returns the discount details and a short-lived ``nonce`` the POS must
    submit to ``/redeem`` within ``nonce_max_age_seconds``.

    - **404** Token not recognised.
    - **409** Voucher already redeemed, expired, or cancelled.
    """
    token_hash = hashlib.sha256(body.token.encode()).hexdigest()

    result = await session.execute(
        select(Voucher, Offer)
        .join(Offer, Voucher.offer_id == Offer.id)
        .where(Voucher.token_hash == token_hash)
    )
    row = result.one_or_none()

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voucher not found")

    voucher, offer = row
    now = datetime.now(timezone.utc)

    if voucher.status != VoucherStatus.ISSUED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Voucher is {voucher.status.value.lower()} — cannot validate",
        )
    if voucher.expires_at < now:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Voucher has expired",
        )

    settings = get_settings()
    nonce = generate_nonce(voucher.id, partner.id, settings)

    return ValidateOut(
        voucher_id=voucher.id,
        short_code=voucher.short_code,
        offer_title=offer.title,
        discount_type=offer.discount_type.value,
        discount_value=float(offer.discount_value),
        expires_at=voucher.expires_at,
        nonce=nonce,
    )


@router.post(
    "/vouchers/redeem",
    response_model=PartnerRedeemOut,
    summary="Redeem a voucher at POS (partner step 2)",
)
async def redeem_voucher(
    body: PartnerRedeemIn,
    partner: Partner = Depends(get_current_partner),
    session: AsyncSession = Depends(get_session),
) -> PartnerRedeemOut:
    """Consume a nonce from ``/validate`` and mark the voucher as REDEEMED.

    The conditional UPDATE ensures exactly one concurrent call succeeds —
    any duplicate/race returns **409**.

    - **409** Nonce invalid/expired, voucher already redeemed, or expired.
    """
    settings = get_settings()

    # 1. Decode and verify nonce
    try:
        voucher_id, nonce_partner_id = decode_nonce(body.nonce, settings)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))

    if nonce_partner_id != partner.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Nonce was issued to a different partner",
        )

    # 2. Atomic conditional UPDATE — the double-redeem guard
    now = datetime.now(timezone.utc)
    result = await session.execute(
        update(Voucher)
        .where(
            Voucher.id == voucher_id,
            Voucher.status == VoucherStatus.ISSUED,
            Voucher.expires_at > now,
        )
        .values(status=VoucherStatus.REDEEMED, redeemed_at=now)
        .returning(Voucher.id, Voucher.short_code, Voucher.offer_id)
    )
    updated = result.one_or_none()

    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Voucher is already redeemed, expired, or not found",
        )

    _, short_code, offer_id = updated

    # 3. Fetch offer for discount info
    offer = await session.get(Offer, offer_id)

    # 4. Insert Redemption audit row
    redemption = Redemption(
        id=str(uuid.uuid4()),
        voucher_id=voucher_id,
        partner_id=partner.id,
        store_id=body.store_id,
        order_reference=body.order_reference,
        discount_value=float(offer.discount_value),
        redeemed_at=now,
    )
    session.add(redemption)
    await session.commit()

    return PartnerRedeemOut(
        voucher_id=voucher_id,
        short_code=short_code,
        redeemed_at=now,
        discount_type=offer.discount_type.value,
        discount_value=float(offer.discount_value),
    )
