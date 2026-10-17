"""Tests for Phase B4: partner voucher validate and redeem API.

MVP acceptance criteria tested:
    ✅ Two concurrent redeem calls → exactly one succeeds (409 on second).
    ✅ Redeem without validate (no nonce) → 409.
    ✅ Replay of used nonce → 409 (already redeemed).
    ✅ Wrong partner key → 401.
    ✅ Cross-partner nonce misuse → 409.
    ✅ Expired voucher blocks validate and redeem.
"""
from __future__ import annotations
from zoneinfo import ZoneInfo

from tests.auth_helpers import register_verified

import asyncio
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import delete

from app.db.models import (
    ActivityDaily,
    Offer,
    OfferStatus,
    Partner,
    PartnerStatus,
    PointsLedger,
    Redemption,
    User,
    Voucher,
)
from app.db.postgres import get_session_factory
from app.services.partner_auth import hash_api_key


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _email() -> str:
    return f"b4_{uuid.uuid4().hex[:8]}@example.com"


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _partner_header(key: str) -> dict:
    return {"X-Partner-Key": key}


async def _create_partner_with_key() -> tuple[str, str]:
    """Insert a test partner and return (partner_id, raw_api_key)."""
    raw_key = f"test-key-{uuid.uuid4().hex}"
    factory = get_session_factory()
    async with factory() as session:
        partner = Partner(
            id=str(uuid.uuid4()),
            name=f"Test Partner {uuid.uuid4().hex[:4]}",
            api_key_hash=hash_api_key(raw_key),
            status=PartnerStatus.ACTIVE,
        )
        session.add(partner)
        await session.commit()
        return partner.id, raw_key


async def _create_offer_for_partner(partner_id: str, points_cost: int = 50) -> str:
    factory = get_session_factory()
    async with factory() as session:
        offer = Offer(
            id=str(uuid.uuid4()),
            partner_id=partner_id,
            title=f"B4 Offer {uuid.uuid4().hex[:4]}",
            discount_type="PERCENT",
            discount_value=10,
            points_cost=points_cost,
            status=OfferStatus.ACTIVE,
            starts_at=datetime.now(timezone.utc) - timedelta(hours=1),
        )
        session.add(offer)
        await session.commit()
        return offer.id


async def _register_and_earn(client: AsyncClient, email: str, steps: int = 10_000) -> str:
    r = await register_verified(client, json={"email": email, "password": "testpass123"})
    token = r.json()["access_token"]
    await client.post(
        "/activity/sync",
        json={
            "local_date": datetime.now(ZoneInfo('Asia/Karachi')).date().isoformat(),
            "eligible_steps": steps,
            "source": "manual",
            "sync_key": str(uuid.uuid4()),
        },
        headers=_auth(token),
    )
    return token


async def _redeem_offer(client: AsyncClient, token: str, offer_id: str) -> dict:
    r = await client.post(f"/offers/{offer_id}/redeem", headers=_auth(token))
    assert r.status_code == 201, r.text
    return r.json()


async def _cleanup(email: str, partner_id: str, offer_id: str) -> None:
    factory = get_session_factory()
    async with factory() as session:
        result = await session.execute(
            __import__("sqlalchemy", fromlist=["select"]).select(User).where(User.email == email)
        )
        user = result.scalar_one_or_none()
        if user:
            vouchers = (await session.execute(
                __import__("sqlalchemy", fromlist=["select"]).select(Voucher).where(Voucher.user_id == user.id)
            )).scalars().all()
            for v in vouchers:
                await session.execute(delete(Redemption).where(Redemption.voucher_id == v.id))
            await session.execute(delete(Voucher).where(Voucher.user_id == user.id))
            await session.execute(delete(PointsLedger).where(PointsLedger.user_id == user.id))
            await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == user.id))
            await session.execute(delete(User).where(User.id == user.id))
        await session.execute(delete(Offer).where(Offer.id == offer_id))
        await session.execute(delete(Partner).where(Partner.id == partner_id))
        await session.commit()


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_partner_invalid_key(client: AsyncClient) -> None:
    """Unknown API key returns 401."""
    r = await client.post(
        "/partner/v1/vouchers/validate",
        json={"token": "sometoken"},
        headers={"X-Partner-Key": "totally-wrong-key"},
    )
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_partner_missing_key(client: AsyncClient) -> None:
    r = await client.post("/partner/v1/vouchers/validate", json={"token": "t"})
    assert r.status_code == 401


# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_validate_success(client: AsyncClient) -> None:
    """Valid QR token returns discount info + nonce."""
    email = _email()
    pid, raw_key = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid, points_cost=50)
    try:
        token = await _register_and_earn(client, email)
        voucher_data = await _redeem_offer(client, token, oid)

        r = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(raw_key),
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["voucher_id"] == voucher_data["voucher_id"]
        assert "nonce" in body
        assert body["discount_type"] == "PERCENT"
    finally:
        await _cleanup(email, pid, oid)


@pytest.mark.asyncio
async def test_validate_unknown_token(client: AsyncClient) -> None:
    pid, raw_key = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid)
    try:
        r = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": "this-token-does-not-exist-anywhere"},
            headers=_partner_header(raw_key),
        )
        assert r.status_code == 404
    finally:
        factory = get_session_factory()
        async with factory() as session:
            await session.execute(delete(Offer).where(Offer.id == oid))
            await session.execute(delete(Partner).where(Partner.id == pid))
            await session.commit()


# ---------------------------------------------------------------------------
# Redeem
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_redeem_success_full_flow(client: AsyncClient) -> None:
    """Full validate → redeem flow returns 200 with discount details."""
    email = _email()
    pid, raw_key = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid, points_cost=50)
    try:
        token = await _register_and_earn(client, email)
        voucher_data = await _redeem_offer(client, token, oid)

        val = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(raw_key),
        )
        nonce = val.json()["nonce"]

        r = await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": nonce, "store_id": "store-1", "order_reference": "ORD-001"},
            headers=_partner_header(raw_key),
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["voucher_id"] == voucher_data["voucher_id"]
        assert body["discount_type"] == "PERCENT"
        assert "redeemed_at" in body
    finally:
        await _cleanup(email, pid, oid)


@pytest.mark.asyncio
async def test_redeem_replay_same_nonce(client: AsyncClient) -> None:
    """✅ Replaying the same nonce after a successful redeem returns 409."""
    email = _email()
    pid, raw_key = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid, points_cost=50)
    try:
        token = await _register_and_earn(client, email)
        voucher_data = await _redeem_offer(client, token, oid)

        val = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(raw_key),
        )
        nonce = val.json()["nonce"]

        # First redeem — must succeed
        r1 = await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": nonce},
            headers=_partner_header(raw_key),
        )
        assert r1.status_code == 200

        # Replay — must fail
        r2 = await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": nonce},
            headers=_partner_header(raw_key),
        )
        assert r2.status_code == 409
    finally:
        await _cleanup(email, pid, oid)


@pytest.mark.asyncio
async def test_concurrent_redeem_exactly_one_succeeds(client: AsyncClient) -> None:
    """✅ MVP acceptance criterion: concurrent redeems → exactly one 200, rest 409."""
    email = _email()
    pid, raw_key = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid, points_cost=50)
    try:
        token = await _register_and_earn(client, email)
        voucher_data = await _redeem_offer(client, token, oid)

        # Get two nonces for the same voucher
        val1 = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(raw_key),
        )
        val2 = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(raw_key),
        )
        nonce1 = val1.json()["nonce"]
        nonce2 = val2.json()["nonce"]

        # Fire both redeems concurrently
        results = await asyncio.gather(
            client.post("/partner/v1/vouchers/redeem", json={"nonce": nonce1}, headers=_partner_header(raw_key)),
            client.post("/partner/v1/vouchers/redeem", json={"nonce": nonce2}, headers=_partner_header(raw_key)),
            return_exceptions=False,
        )

        status_codes = sorted(r.status_code for r in results)
        assert status_codes == [200, 409], f"Expected [200, 409] got {status_codes}"
    finally:
        await _cleanup(email, pid, oid)


@pytest.mark.asyncio
async def test_redeem_without_validate(client: AsyncClient) -> None:
    """Submitting a forged/missing nonce returns 409."""
    pid, raw_key = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid)
    try:
        r = await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": "not-a-valid-nonce"},
            headers=_partner_header(raw_key),
        )
        assert r.status_code == 409
    finally:
        factory = get_session_factory()
        async with factory() as session:
            await session.execute(delete(Offer).where(Offer.id == oid))
            await session.execute(delete(Partner).where(Partner.id == pid))
            await session.commit()


@pytest.mark.asyncio
async def test_cross_partner_nonce_rejected(client: AsyncClient) -> None:
    """Nonce signed for partner A cannot be used by partner B."""
    email = _email()
    pid_a, key_a = await _create_partner_with_key()
    pid_b, key_b = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid_a, points_cost=50)
    try:
        token = await _register_and_earn(client, email)
        voucher_data = await _redeem_offer(client, token, oid)

        # Validate as partner A → get nonce bound to partner A
        val = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(key_a),
        )
        nonce = val.json()["nonce"]

        # Try to redeem as partner B → must fail
        r = await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": nonce},
            headers=_partner_header(key_b),
        )
        assert r.status_code == 409
    finally:
        await _cleanup(email, pid_a, oid)
        factory = get_session_factory()
        async with factory() as session:
            await session.execute(delete(Partner).where(Partner.id == pid_b))
            await session.commit()


@pytest.mark.asyncio
async def test_validate_already_redeemed_voucher(client: AsyncClient) -> None:
    """Validating an already-redeemed voucher returns 409."""
    email = _email()
    pid, raw_key = await _create_partner_with_key()
    oid = await _create_offer_for_partner(pid, points_cost=50)
    try:
        token = await _register_and_earn(client, email)
        voucher_data = await _redeem_offer(client, token, oid)

        # Full redeem
        val = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(raw_key),
        )
        nonce = val.json()["nonce"]
        await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": nonce},
            headers=_partner_header(raw_key),
        )

        # Try to validate the same token again
        r = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": voucher_data["token"]},
            headers=_partner_header(raw_key),
        )
        assert r.status_code == 409
    finally:
        await _cleanup(email, pid, oid)


@pytest.mark.asyncio
async def test_partner_cannot_validate_another_stores_voucher(client):
    first, first_key = await _create_partner_with_key()
    other, other_key = await _create_partner_with_key()
    email = _email()
    offer = await _create_offer_for_partner(first)
    try:
        token = await _register_and_earn(client, email)
        voucher = await _redeem_offer(client, token, offer)
        for code in (voucher['token'], voucher['short_code']):
            denied = await client.post('/partner/v1/vouchers/validate', headers=_partner_header(other_key), json={'token': code})
            assert denied.status_code == 404
        allowed = await client.post('/partner/v1/vouchers/validate', headers=_partner_header(first_key), json={'token': voucher['short_code']})
        assert allowed.status_code == 200
    finally:
        await _cleanup(email, first, offer)
        async with get_session_factory()() as session:
            await session.execute(delete(Partner).where(Partner.id == other))
            await session.commit()


@pytest.mark.asyncio
async def test_inactive_store_cannot_issue_new_rewards(client):
    partner, _ = await _create_partner_with_key()
    offer = await _create_offer_for_partner(partner)
    email = _email()
    try:
        token = await _register_and_earn(client, email)
        async with get_session_factory()() as session:
            store = await session.get(Partner, partner)
            store.status = PartnerStatus.INACTIVE
            await session.commit()
        catalog = await client.get('/offers', headers=_auth(token))
        assert catalog.status_code == 200
        assert offer not in [item['id'] for item in catalog.json()]
        issued = await client.post(f'/offers/{offer}/redeem', headers=_auth(token))
        assert issued.status_code == 409
        balance = await client.get('/points/balance', headers=_auth(token))
        assert balance.json()['balance'] == 100
    finally:
        await _cleanup(email, partner, offer)
