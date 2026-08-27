"""Tests for Merchant / Cashier POS features:
- Short code validation (SR-XXXX-XXXX)
- GET /partner/v1/info
- GET /partner/v1/redemptions
- Full POS redemption cycle with store_id and order_reference
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import delete

from app.db.models import (
    DiscountType,
    Offer,
    OfferStatus,
    Partner,
    PartnerStatus,
    Redemption,
    User,
    Voucher,
)
from app.db.postgres import get_session_factory
from app.services.partner_auth import hash_api_key


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _partner_header(key: str) -> dict:
    return {"X-Partner-Key": key}


async def _create_partner() -> tuple[str, str]:
    raw_key = f"pos-key-{uuid.uuid4().hex}"
    factory = get_session_factory()
    async with factory() as session:
        partner = Partner(
            id=str(uuid.uuid4()),
            name="Apex Cafe & Bakery",
            api_key_hash=hash_api_key(raw_key),
            status=PartnerStatus.ACTIVE,
        )
        session.add(partner)
        await session.commit()
        return partner.id, raw_key


async def _cleanup(partner_id: str) -> None:
    factory = get_session_factory()
    async with factory() as session:
        await session.execute(delete(Redemption).where(Redemption.partner_id == partner_id))
        offer_ids = (await session.execute(
            __import__("sqlalchemy", fromlist=["select"]).select(Offer.id).where(Offer.partner_id == partner_id)
        )).scalars().all()
        if offer_ids:
            await session.execute(delete(Voucher).where(Voucher.offer_id.in_(offer_ids)))
        await session.execute(delete(Offer).where(Offer.partner_id == partner_id))
        await session.execute(delete(Partner).where(Partner.id == partner_id))
        await session.commit()


@pytest.mark.asyncio
async def test_partner_info_endpoint(client: AsyncClient) -> None:
    partner_id, raw_key = await _create_partner()
    try:
        resp = await client.get("/partner/v1/info", headers=_partner_header(raw_key))
        assert resp.status_code == 200
        data = resp.json()
        assert data["partner_id"] == partner_id
        assert data["name"] == "Apex Cafe & Bakery"
        assert data["status"] == "ACTIVE"
    finally:
        await _cleanup(partner_id)


@pytest.mark.asyncio
async def test_validate_and_redeem_by_short_code(client: AsyncClient) -> None:
    partner_id, raw_key = await _create_partner()
    email = f"pos_user_{uuid.uuid4().hex[:6]}@example.com"
    try:
        # 1. Register user and earn points
        reg = await client.post("/auth/register", json={"email": email, "password": "password123"})
        token = reg.json()["access_token"]
        await client.post(
            "/activity/sync",
            json={"local_date": "2026-08-28", "eligible_steps": 10000, "source": "test", "sync_key": str(uuid.uuid4())},
            headers=_auth(token),
        )

        # 2. Seed an offer
        offer_id = str(uuid.uuid4())
        factory = get_session_factory()
        async with factory() as session:
            offer = Offer(
                id=offer_id,
                partner_id=partner_id,
                title="Free Organic Coffee",
                description="Enjoy a free coffee",
                points_cost=50,
                discount_type=DiscountType.FREE_ITEM,
                discount_value=0.0,
                status=OfferStatus.ACTIVE,
            )
            session.add(offer)
            await session.commit()

        # 3. User redeems offer in mobile app to get voucher
        voucher_resp = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        assert voucher_resp.status_code == 201
        v_data = voucher_resp.json()
        short_code = v_data["short_code"]
        assert short_code is not None

        # 4. Cashier enters short code into POS terminal
        val_resp = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": short_code},
            headers=_partner_header(raw_key),
        )
        assert val_resp.status_code == 200, val_resp.text
        val_data = val_resp.json()
        assert val_data["short_code"] == short_code
        assert val_data["offer_title"] == "Free Organic Coffee"
        nonce = val_data["nonce"]

        # 5. Cashier submits POS redemption
        red_resp = await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": nonce, "store_id": "STORE_F7", "order_reference": "POS-ORD-9021"},
            headers=_partner_header(raw_key),
        )
        assert red_resp.status_code == 200, red_resp.text
        red_data = red_resp.json()
        assert red_data["short_code"] == short_code

        # 6. Verify audit history
        hist_resp = await client.get("/partner/v1/redemptions", headers=_partner_header(raw_key))
        assert hist_resp.status_code == 200
        history = hist_resp.json()
        assert len(history) >= 1
        assert history[0]["short_code"] == short_code
        assert history[0]["order_reference"] == "POS-ORD-9021"
        assert history[0]["store_id"] == "STORE_F7"
    finally:
        await _cleanup(partner_id)
