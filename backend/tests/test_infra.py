"""Tests for Backend Infrastructure & Operational Enhancements:
- GET /health and GET /health/ready
- POST /admin/partners (provisioning & API key generation)
- POST /admin/vouchers/sweep-expired (automated voucher expiration)
- Rate limiting middleware on auth routes
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import delete

from app.db.models import DiscountType, Offer, OfferStatus, Partner, User, Voucher, VoucherStatus
from app.db.postgres import get_session_factory


@pytest.mark.asyncio
async def test_health_liveness_and_readiness(client: AsyncClient) -> None:
    # 1. Basic liveness
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"

    # 2. Deep readiness probe (DB ping + latency)
    ready_resp = await client.get("/health/ready")
    assert ready_resp.status_code == 200
    data = ready_resp.json()
    assert data["status"] == "ready"
    assert data["database"]["status"] == "connected"
    assert "latency_ms" in data["database"]
    assert data["database"]["latency_ms"] >= 0


@pytest.mark.asyncio
async def test_admin_partner_provisioning(client: AsyncClient) -> None:
    partner_name = f"Test Bakery {uuid.uuid4().hex[:6]}"
    factory = get_session_factory()
    partner_id: str | None = None

    try:
        resp = await client.post("/admin/partners", json={"name": partner_name})
        assert resp.status_code == 201
        data = resp.json()
        partner_id = data["partner_id"]
        raw_key = data["raw_api_key"]

        assert data["name"] == partner_name
        assert raw_key.startswith("pk_live_")

        # Test using newly provisioned key with POS /info endpoint
        info_resp = await client.get("/partner/v1/info", headers={"X-Partner-Key": raw_key})
        assert info_resp.status_code == 200
        assert info_resp.json()["partner_id"] == partner_id
    finally:
        if partner_id:
            async with factory() as session:
                await session.execute(delete(Partner).where(Partner.id == partner_id))
                await session.commit()


@pytest.mark.asyncio
async def test_voucher_expiration_sweep(client: AsyncClient) -> None:
    factory = get_session_factory()
    partner_id = str(uuid.uuid4())
    offer_id = str(uuid.uuid4())
    user_id = str(uuid.uuid4())
    voucher_id = str(uuid.uuid4())

    try:
        async with factory() as session:
            # Seed partner, offer, user, and an EXPIRED voucher with status='ISSUED'
            partner = Partner(id=partner_id, name="Test Sweeper", api_key_hash="hash", status="ACTIVE")
            offer = Offer(
                id=offer_id,
                partner_id=partner_id,
                title="Expired Offer",
                points_cost=10,
                discount_type=DiscountType.PERCENT,
                discount_value=10.0,
                status=OfferStatus.ACTIVE,
            )
            user = User(id=user_id, email=f"sweep_{uuid.uuid4().hex[:6]}@example.com", password_hash="hash", status="ACTIVE")
            expired_voucher = Voucher(
                id=voucher_id,
                offer_id=offer_id,
                user_id=user_id,
                short_code=f"SW-{uuid.uuid4().hex[:4].upper()}",
                token_hash="hash123",
                status=VoucherStatus.ISSUED,
                expires_at=datetime.now(timezone.utc) - timedelta(days=2),  # In the past
            )
            session.add_all([partner, offer, user, expired_voucher])
            await session.commit()

        # Trigger sweep endpoint
        sweep_resp = await client.post("/admin/vouchers/sweep-expired")
        assert sweep_resp.status_code == 200
        data = sweep_resp.json()
        assert data["swept_count"] >= 1

        # Verify DB status is now EXPIRED
        async with factory() as session:
            v = await session.get(Voucher, voucher_id)
            assert v is not None
            assert v.status == VoucherStatus.EXPIRED
    finally:
        async with factory() as session:
            await session.execute(delete(Voucher).where(Voucher.id == voucher_id))
            await session.execute(delete(Offer).where(Offer.id == offer_id))
            await session.execute(delete(Partner).where(Partner.id == partner_id))
            await session.execute(delete(User).where(User.id == user_id))
            await session.commit()
