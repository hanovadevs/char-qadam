"""Tests for Phase B3: GET /offers, POST /offers/{id}/redeem, GET /vouchers.

MVP acceptance criteria tested:
    ✅ Redeem deducts points exactly once.
    ✅ Insufficient points are blocked (402).
    ✅ Out-of-stock offer is blocked (409).
    ✅ Expired offer is blocked (409).
    ✅ Voucher appears in wallet with correct status.
    ✅ Lazy expiry marks stale vouchers EXPIRED on next read.
"""
from __future__ import annotations
from zoneinfo import ZoneInfo

from tests.auth_helpers import register_verified

from tests.auth_helpers import auth_headers

import uuid
from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select, update

from app.db.models import (
    ActivityDaily,
    Offer,
    OfferStatus,
    Partner,
    PartnerStatus,
    PointsLedger,
    User,
    Voucher,
    VoucherStatus,
)
from app.db.postgres import get_session_factory


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _email() -> str:
    return f"b3_{uuid.uuid4().hex[:8]}@example.com"


def _auth(token: str) -> dict:
    return auth_headers(token)


async def _register(client: AsyncClient, email: str) -> str:
    r = await register_verified(client, json={"email": email, "password": "testpass123"})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


async def _sync_steps(client: AsyncClient, token: str, steps: int) -> None:
    """Give user some points via activity sync."""
    r = await client.post(
        "/activity/sync",
        json={
            "local_date": datetime.now(ZoneInfo('Asia/Karachi')).date().isoformat(),
            "eligible_steps": steps,
            "source": "manual",
            "sync_key": str(uuid.uuid4()),
        },
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text


async def _create_offer(
    *,
    points_cost: int = 100,
    inventory: int | None = None,
    ends_at: datetime | None = None,
    starts_at: datetime | None = None,
    status: OfferStatus = OfferStatus.ACTIVE,
) -> str:
    """Insert a test offer directly via DB and return its id."""
    factory = get_session_factory()
    async with factory() as session:
        # Ensure demo partner exists
        partner = await session.get(Partner, "00000000-0000-0000-0000-000000000001")
        if partner is None:
            partner = Partner(
                id="00000000-0000-0000-0000-000000000001",
                name="Test Partner",
                status=PartnerStatus.ACTIVE,
            )
            session.add(partner)

        now = datetime.now(timezone.utc)
        offer = Offer(
            id=str(uuid.uuid4()),
            partner_id="00000000-0000-0000-0000-000000000001",
            title=f"Test Offer {uuid.uuid4().hex[:4]}",
            discount_type="PERCENT",
            discount_value=10,
            points_cost=points_cost,
            inventory=inventory,
            starts_at=starts_at or (now - timedelta(hours=1)),
            ends_at=ends_at,
            status=status,
        )
        session.add(offer)
        await session.commit()
        return offer.id


async def _cleanup(email: str, *offer_ids: str) -> None:
    factory = get_session_factory()
    async with factory() as session:
        result = await session.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            # Delete vouchers referencing these offers (to satisfy FK)
            await session.execute(delete(Voucher).where(Voucher.user_id == user.id))
            await session.execute(delete(PointsLedger).where(PointsLedger.user_id == user.id))
            await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == user.id))
            await session.execute(delete(User).where(User.id == user.id))
        for oid in offer_ids:
            await session.execute(delete(Offer).where(Offer.id == oid))
        await session.commit()


# ---------------------------------------------------------------------------
# GET /offers
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_offers_returns_active(client: AsyncClient) -> None:
    email = _email()
    offer_id = await _create_offer(points_cost=50)
    try:
        token = await _register(client, email)
        r = await client.get("/offers", headers=_auth(token))
        assert r.status_code == 200
        ids = [o["id"] for o in r.json()]
        assert offer_id in ids
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_list_offers_hides_inactive(client: AsyncClient) -> None:
    email = _email()
    offer_id = await _create_offer(status=OfferStatus.INACTIVE)
    try:
        token = await _register(client, email)
        r = await client.get("/offers", headers=_auth(token))
        assert r.status_code == 200
        ids = [o["id"] for o in r.json()]
        assert offer_id not in ids
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_list_offers_hides_out_of_stock(client: AsyncClient) -> None:
    email = _email()
    offer_id = await _create_offer(inventory=0)
    try:
        token = await _register(client, email)
        r = await client.get("/offers", headers=_auth(token))
        assert r.status_code == 200
        ids = [o["id"] for o in r.json()]
        assert offer_id not in ids
    finally:
        await _cleanup(email, offer_id)


# ---------------------------------------------------------------------------
# POST /offers/{id}/redeem — ✅ MVP acceptance criteria
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_redeem_success(client: AsyncClient) -> None:
    """Redeem deducts points and returns a voucher with short_code + token."""
    email = _email()
    offer_id = await _create_offer(points_cost=50)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10_000)  # earn 100 points

        r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        assert r.status_code == 201, r.text
        body = r.json()
        assert body["points_spent"] == 50
        assert body["balance"] == 50                      # 100 − 50
        assert body["short_code"].startswith("SR-")
        assert len(body["token"]) > 20                    # opaque token present
        assert "voucher_id" in body
        assert "expires_at" in body
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_redeem_deducts_exactly_once(client: AsyncClient) -> None:
    """✅ Acceptance criterion: points are deducted exactly once per redeem."""
    email = _email()
    offer_id = await _create_offer(points_cost=30)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10_000)  # 100 points

        r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        assert r.status_code == 201
        assert r.json()["balance"] == 70           # 100 − 30

        bal = await client.get("/points/balance", headers=_auth(token))
        assert bal.json()["balance"] == 70         # confirmed via separate query
        assert bal.json()["total_spent"] == 30
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_redeem_insufficient_points(client: AsyncClient) -> None:
    """✅ Acceptance criterion: insufficient balance returns 402, no deduction."""
    email = _email()
    offer_id = await _create_offer(points_cost=500)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 1000)     # only 10 points

        r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        assert r.status_code == 402

        # Verify no points were deducted
        bal = await client.get("/points/balance", headers=_auth(token))
        assert bal.json()["balance"] == 10
        assert bal.json()["total_spent"] == 0
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_redeem_expired_offer(client: AsyncClient) -> None:
    """Expired offer returns 409."""
    email = _email()
    past = datetime.now(timezone.utc) - timedelta(days=1)
    offer_id = await _create_offer(points_cost=10, ends_at=past)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 5000)

        r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        assert r.status_code == 409
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_redeem_out_of_stock(client: AsyncClient) -> None:
    """Zero-inventory offer returns 409."""
    email = _email()
    offer_id = await _create_offer(points_cost=10, inventory=0)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 5000)

        r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        assert r.status_code == 409
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_redeem_decrements_inventory(client: AsyncClient) -> None:
    """Inventory drops by 1 after a successful redeem."""
    email = _email()
    offer_id = await _create_offer(points_cost=10, inventory=3)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 5000)      # 50 points

        await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))

        factory = get_session_factory()
        async with factory() as session:
            offer = await session.get(Offer, offer_id)
            assert offer.inventory == 2
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_redeem_unknown_offer(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register(client, email)
        r = await client.post(f"/offers/{uuid.uuid4()}/redeem", headers=_auth(token))
        assert r.status_code == 404
    finally:
        await _cleanup(email)


# ---------------------------------------------------------------------------
# GET /vouchers (wallet)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_wallet_active_voucher(client: AsyncClient) -> None:
    """Redeemed offer appears as active in the wallet."""
    email = _email()
    offer_id = await _create_offer(points_cost=20)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 5000)

        redeem_r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        assert redeem_r.status_code == 201
        voucher_id = redeem_r.json()["voucher_id"]

        wallet = await client.get("/vouchers?status=active", headers=_auth(token))
        assert wallet.status_code == 200
        ids = [v["id"] for v in wallet.json()]
        assert voucher_id in ids
    finally:
        await _cleanup(email, offer_id)


@pytest.mark.asyncio
async def test_wallet_lazy_expiry(client: AsyncClient) -> None:
    """Vouchers past expires_at are marked EXPIRED on the next wallet read."""
    email = _email()
    offer_id = await _create_offer(points_cost=20)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 5000)

        redeem_r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
        voucher_id = redeem_r.json()["voucher_id"]

        # Backdate expires_at directly in DB
        factory = get_session_factory()
        async with factory() as session:
            await session.execute(
                update(Voucher)
                .where(Voucher.id == voucher_id)
                .values(expires_at=datetime.now(timezone.utc) - timedelta(days=1))
            )
            await session.commit()

        # Reading the wallet should trigger lazy expiry
        wallet = await client.get("/vouchers?status=active", headers=_auth(token))
        assert wallet.status_code == 200
        active_ids = [v["id"] for v in wallet.json()]
        assert voucher_id not in active_ids        # no longer active

        expired = await client.get("/vouchers?status=expired", headers=_auth(token))
        expired_ids = [v["id"] for v in expired.json()]
        assert voucher_id in expired_ids           # now in expired list
    finally:
        await _cleanup(email, offer_id)
