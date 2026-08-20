"""Pydantic schemas for the partner-facing B4 API."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class ValidateIn(BaseModel):
    """Body for POST /partner/v1/vouchers/validate."""
    token: str = Field(min_length=10, description="Raw token from the QR code or manual entry.")


class ValidateOut(BaseModel):
    """Response: voucher is valid — POS can proceed."""
    voucher_id: str
    short_code: str
    offer_title: str
    discount_type: str
    discount_value: float
    expires_at: datetime
    nonce: str          # HMAC-signed; submit to /redeem within nonce_max_age_seconds


class PartnerRedeemIn(BaseModel):
    """Body for POST /partner/v1/vouchers/redeem."""
    nonce: str = Field(description="Nonce received from /validate.")
    store_id: str | None = Field(default=None, max_length=128)
    order_reference: str | None = Field(default=None, max_length=256)


class PartnerRedeemOut(BaseModel):
    """Response on successful POS redemption."""
    voucher_id: str
    short_code: str
    redeemed_at: datetime
    discount_type: str
    discount_value: float
