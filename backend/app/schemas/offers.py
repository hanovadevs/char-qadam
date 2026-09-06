"""Pydantic schemas for offers and voucher endpoints."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


# ---------------------------------------------------------------------------
# Offers
# ---------------------------------------------------------------------------

class OfferOut(BaseModel):
    """A single catalog offer returned by GET /offers."""
    id: str
    partner_id: str
    title: str
    description: str | None
    discount_type: str
    discount_value: float
    points_cost: int
    min_basket: float | None
    inventory: int | None       # None = unlimited
    starts_at: datetime | None
    ends_at: datetime | None
    status: str
    partner_name: str | None = None
    partner_location: str | None = None
    partner_google_maps_url: str | None = None

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Vouchers
# ---------------------------------------------------------------------------

class RedeemOut(BaseModel):
    """Response when a user redeems an offer."""
    voucher_id: str
    short_code: str             # human-readable merchant entry code  e.g. SR-7K4Q-92MX
    token: str                  # raw opaque token — embed in QR code
    expires_at: datetime
    points_spent: int
    balance: int                # remaining balance after spend


class VoucherOut(BaseModel):
    """A voucher entry in the wallet."""
    id: str
    offer_id: str
    short_code: str
    status: str                 # ISSUED | REDEEMED | EXPIRED | CANCELLED
    issued_at: datetime
    expires_at: datetime
    redeemed_at: datetime | None

    # Flattened offer summary for display
    offer_title: str
    offer_discount_type: str
    offer_discount_value: float

    model_config = {"from_attributes": True}
