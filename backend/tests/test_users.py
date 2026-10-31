"""Tests for Phase B5: PATCH /users/me, DELETE /users/me.

Covers:
    ✅ Patch country and timezone.
    ✅ Patch password — old password fails login, new password works.
    ✅ Empty patch body is a no-op (returns unchanged profile).
    ✅ Partial patch (only one field) leaves other fields untouched.
    ✅ DELETE soft-deletes — subsequent /auth/me returns 403.
    ✅ DELETE invalidates the JWT immediately (token reuse returns 403).
    ✅ Unauthenticated PATCH and DELETE return 401.
"""
from __future__ import annotations

from tests.auth_helpers import register_verified

from tests.auth_helpers import auth_headers

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select, func

from app.db.models import (ActivityDaily, PointsLedger, User, Voucher, Device,
    SupportTicket, SupportMessage, SupportAIUsage, RedemptionRequest)
from app.services.security import decode_access_claims
from app.db.postgres import get_session_factory


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _email() -> str:
    return f"b5_{uuid.uuid4().hex[:8]}@example.com"


def _auth(token: str) -> dict:
    return auth_headers(token)


_registered_ids = {}


async def _register(client: AsyncClient, email: str, password: str = "startpass1") -> str:
    r = await register_verified(client, json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    token = r.json()["access_token"]
    _registered_ids[email] = decode_access_claims(token)["sub"]
    return token


async def _cleanup(email: str) -> None:
    factory = get_session_factory()
    async with factory() as session:
        result = await session.execute(
            __import__("sqlalchemy", fromlist=["select"]).select(User).where(User.id == _registered_ids.get(email))
        )
        user = result.scalar_one_or_none()
        if user:
            await session.execute(delete(Voucher).where(Voucher.user_id == user.id))
            await session.execute(delete(PointsLedger).where(PointsLedger.user_id == user.id))
            await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == user.id))
            await session.execute(delete(User).where(User.id == user.id))
        await session.commit()


# ---------------------------------------------------------------------------
# PATCH /users/me
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_patch_country_and_timezone(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register(client, email)
        r = await client.patch(
            "/users/me",
            json={"country": "PK", "timezone": "Asia/Karachi"},
            headers=_auth(token),
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["country"] == "PK"
        assert body["timezone"] == "Asia/Karachi"
        assert body["email"] == email
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_patch_password_old_fails_new_works(client: AsyncClient) -> None:
    """After a password change, old password must fail and new password must work."""
    email = _email()
    old_pass = "startpass1"
    new_pass = "newpass9999"
    try:
        token = await _register(client, email, old_pass)

        patch = await client.patch(
            "/users/me",
            json={"password": new_pass},
            headers=_auth(token),
        )
        assert patch.status_code == 200

        # Old password → should fail
        old_login = await client.post("/auth/login", json={"email": email, "password": old_pass})
        assert old_login.status_code == 401

        # New password → should succeed
        new_login = await client.post("/auth/login", json={"email": email, "password": new_pass})
        assert new_login.status_code == 200
        assert "access_token" in new_login.json()
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_patch_empty_body_is_noop(client: AsyncClient) -> None:
    """Sending an empty patch body returns the profile unchanged."""
    email = _email()
    try:
        token = await _register(client, email)
        r = await client.patch("/users/me", json={}, headers=_auth(token))
        assert r.status_code == 200
        assert r.json()["email"] == email
        assert r.json()["status"] == "ACTIVE"
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_patch_only_country_leaves_timezone_unchanged(client: AsyncClient) -> None:
    """Partial patch: updating country must not clear timezone."""
    email = _email()
    try:
        token = await _register(client, email)

        # Set both fields first
        await client.patch(
            "/users/me",
            json={"country": "PK", "timezone": "Asia/Karachi"},
            headers=_auth(token),
        )

        # Update only country
        r = await client.patch(
            "/users/me",
            json={"country": "US"},
            headers=_auth(token),
        )
        assert r.status_code == 200
        body = r.json()
        assert body["country"] == "US"
        assert body["timezone"] == "Asia/Karachi"   # must be preserved
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_patch_weak_password_rejected(client: AsyncClient) -> None:
    """Password shorter than 8 chars returns 422."""
    email = _email()
    try:
        token = await _register(client, email)
        r = await client.patch(
            "/users/me",
            json={"password": "short"},
            headers=_auth(token),
        )
        assert r.status_code == 422
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_patch_requires_auth(client: AsyncClient) -> None:
    r = await client.patch("/users/me", json={"country": "PK"})
    assert r.status_code == 401


# ---------------------------------------------------------------------------
# DELETE /users/me
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_delete_returns_204(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register(client, email)
        r = await client.delete("/users/me", headers=_auth(token))
        assert r.status_code == 204
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_delete_erases_profile_and_private_data(client: AsyncClient) -> None:
    """A non-login tombstone remains, without profile, health or support data."""
    email = _email()
    try:
        token = await _register(client, email)
        user_id = _registered_ids[email]
        factory = get_session_factory()
        async with factory() as session:
            user = await session.get(User, user_id)
            old_hash = user.password_hash
            user.google_subject = 'subject-' + uuid.uuid4().hex
            user.country = 'PK'
            user.timezone = 'Asia/Karachi'
            session.add(ActivityDaily(user_id=user_id, local_date='2026-10-31', eligible_steps=1500,
                source='health', sync_key=uuid.uuid4().hex))
            session.add(Device(user_id=user_id, platform='android'))
            ticket = SupportTicket(user_id=user_id, subject='Private message', category='account')
            session.add(ticket)
            await session.flush()
            ticket_id = ticket.id
            session.add(SupportMessage(ticket_id=ticket_id, author='USER', body='Private support details'))
            await session.commit()
        assert (await client.delete('/users/me', headers=_auth(token))).status_code == 204
        async with factory() as session:
            user = await session.get(User, user_id)
            assert user.status.value == 'DELETED'
            assert user.email == f'deleted-{user_id}@deleted.invalid'
            assert user.password_hash != old_hash
            assert user.google_subject is None and user.email_verified_at is None
            assert user.country is None and user.timezone is None
            assert user.verification_code_hash is None
            for model in (ActivityDaily, Device, SupportTicket, SupportAIUsage, RedemptionRequest):
                assert await session.scalar(select(func.count()).select_from(model).where(model.user_id == user_id)) == 0
            assert await session.scalar(select(func.count()).select_from(SupportMessage).where(SupportMessage.ticket_id == ticket_id)) == 0
        # Deletion must release the email for a genuinely new account.
        fresh = await register_verified(client, json={'email': email, 'password': 'newpass12345'})
        assert fresh.status_code == 200, fresh.text
        new_id = decode_access_claims(fresh.json()['access_token'])['sub']
        assert new_id != user_id
        async with factory() as session:
            await session.execute(delete(User).where(User.id == new_id))
            await session.commit()
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_delete_invalidates_jwt(client: AsyncClient) -> None:
    """After DELETE, using the same JWT token returns 403 (account deleted)."""
    email = _email()
    try:
        token = await _register(client, email)
        await client.delete("/users/me", headers=_auth(token))

        # Old token must now be rejected
        me = await client.get("/auth/me", headers=_auth(token))
        assert me.status_code == 401
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_delete_blocks_login(client: AsyncClient) -> None:
    """Deleted account cannot log in with correct credentials."""
    email = _email()
    password = "startpass1"
    try:
        token = await _register(client, email, password)
        await client.delete("/users/me", headers=_auth(token))

        login = await client.post("/auth/login", json={"email": email, "password": password})
        assert login.status_code == 401
        assert 'access_token' not in login.json()
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_delete_requires_auth(client: AsyncClient) -> None:
    r = await client.delete("/users/me")
    assert r.status_code == 401
