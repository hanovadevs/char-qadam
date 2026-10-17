"""Partner-facing voucher validation, redemption, and POS terminal API.

Routes (versioned — /partner/v1)
--------------------------------
GET  /partner/v1/info                 Verify partner API key and return profile info.
GET  /partner/v1/redemptions          List recent in-store redemptions for store audit.
POST /partner/v1/vouchers/validate   Look up voucher by raw token OR short_code; return nonce.
POST /partner/v1/vouchers/redeem     Consume nonce; atomically mark voucher REDEEMED.

Auth: X-Partner-Key header (hashed API key stored in partners.api_key_hash).
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.models import (
    Offer,
    Partner,
    Redemption,
    Voucher,
    VoucherStatus,
)
from app.db.postgres import get_session
from app.deps import get_current_partner
from app.schemas.partner import (
    PartnerInfoOut,
    PartnerRedeemIn,
    PartnerRedeemOut,
    RedemptionHistoryItemOut,
    ValidateIn,
    ValidateOut,
)
from app.services.partner_auth import decode_nonce, generate_nonce

router = APIRouter(prefix="/partner/v1", tags=["partner"])


@router.get(
    "/info",
    response_model=PartnerInfoOut,
    summary="Return authenticated partner details for POS terminal",
)
async def get_partner_info(
    partner: Partner = Depends(get_current_partner),
) -> PartnerInfoOut:
    """Verify partner API key credentials and return store details."""
    return PartnerInfoOut(
        partner_id=partner.id,
        name=partner.name,
        status=partner.status.value,
    )


@router.get(
    "/redemptions",
    response_model=list[RedemptionHistoryItemOut],
    summary="List recent in-store redemptions for partner POS",
)
async def list_redemptions(
    limit: int = Query(25, ge=1, le=100),
    partner: Partner = Depends(get_current_partner),
    session: AsyncSession = Depends(get_session),
) -> list[RedemptionHistoryItemOut]:
    """Fetch audit history of vouchers redeemed at this partner's POS."""
    result = await session.execute(
        select(Redemption, Voucher)
        .join(Voucher, Redemption.voucher_id == Voucher.id)
        .where(Redemption.partner_id == partner.id)
        .order_by(Redemption.redeemed_at.desc())
        .limit(limit)
    )
    rows = result.all()
    return [
        RedemptionHistoryItemOut(
            id=r.id,
            voucher_id=v.id,
            short_code=v.short_code,
            store_id=r.store_id,
            order_reference=r.order_reference,
            discount_value=float(r.discount_value),
            redeemed_at=r.redeemed_at,
        )
        for r, v in rows
    ]


@router.post(
    "/vouchers/validate",
    response_model=ValidateOut,
    summary="Validate a voucher token or short code (POS step 1)",
)
async def validate_voucher(
    body: ValidateIn,
    partner: Partner = Depends(get_current_partner),
    session: AsyncSession = Depends(get_session),
) -> ValidateOut:
    """Look up a voucher by its raw QR token OR human short_code (e.g. SR-XXXX-XXXX).

    Returns discount details and a short-lived HMAC ``nonce`` the POS must
    submit to ``/redeem`` within ``nonce_max_age_seconds``.

    - **404** Token/Code not recognised.
    - **409** Voucher already redeemed, expired, or cancelled.
    """
    input_str = body.token.strip()
    token_hash = hashlib.sha256(input_str.encode()).hexdigest()

    result = await session.execute(
        select(Voucher, Offer)
        .join(Offer, Voucher.offer_id == Offer.id)
        .where(
            Offer.partner_id == partner.id,
            (Voucher.token_hash == token_hash)
            | (Voucher.short_code == input_str.upper())
        )
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
    summary="Redeem a voucher at POS (POS step 2)",
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
            Voucher.offer_id.in_(select(Offer.id).where(Offer.partner_id == partner.id)),
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
