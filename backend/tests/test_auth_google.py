"""Tests for Google OAuth Token Exchange (POST /auth/google).

Covers:
    ✅ Auto-registration of new user via Google ID Token.
    ✅ Login of existing user via Google ID Token.
    ✅ Invalid / unverified Google token rejection (401).
    ✅ Suspended / soft-deleted user rejection (403).
"""
from __future__ import annotations

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select, update

from app.db.models import User, UserStatus
from app.db.postgres import get_session_factory


@pytest.fixture(autouse=True)
def google_verifier(monkeypatch):
    async def verify(token, client_id=None):
        if not token.startswith('test_google:'):
            raise ValueError('Invalid token')
        email = token.split(':', 1)[1]
        return {'email': email, 'sub': 'test-user:' + email, 'email_verified': True, 'authoritative_email': True}
    monkeypatch.setattr('app.routers.auth.verify_google_id_token', verify)


def _email() -> str:
    return f"google_{uuid.uuid4().hex[:8]}@example.com"


async def _cleanup(email: str) -> None:
    factory = get_session_factory()
    async with factory() as session:
        result = await session.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            await session.execute(delete(User).where(User.id == user.id))
            await session.commit()


@pytest.mark.asyncio
async def test_google_auth_auto_register(client: AsyncClient) -> None:
    """New Google user is automatically created and logged in."""
    email = _email()
    try:
        r = await client.post(
            "/auth/google",
            json={"id_token": f"test_google:{email}", "country": "PK", "timezone": "Asia/Karachi"},
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert "access_token" in body

        # Verify profile via GET /auth/me
        token = body["access_token"]
        me = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200
        assert me.json()["email"] == email
        assert me.json()["country"] == "PK"
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_google_auth_existing_user_login(client: AsyncClient) -> None:
    """Existing email logs in seamlessly via Google OAuth."""
    email = _email()
    try:
        # 1. Register via regular password first
        reg = await client.post("/auth/register", json={"email": email, "password": "password123"})
        assert reg.status_code == 201

        # 2. Login via Google OAuth
        g_login = await client.post("/auth/google", json={"id_token": f"test_google:{email}"})
        assert g_login.status_code == 200
        token = g_login.json()["access_token"]

        me = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200
        assert me.json()["email"] == email
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_google_auth_invalid_token(client: AsyncClient) -> None:
    """Invalid token returns 401 Unauthorized."""
    r = await client.post("/auth/google", json={"id_token": "invalid_fake_token_12345"})
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_google_auth_suspended_user_blocked(client: AsyncClient) -> None:
    """Suspended/deleted user attempting Google login receives 403."""
    email = _email()
    try:
        reg = await client.post("/auth/google", json={"id_token": f"test_google:{email}"})
        assert reg.status_code == 200

        # Suspend user
        factory = get_session_factory()
        async with factory() as session:
            await session.execute(
                update(User).where(User.email == email).values(status=UserStatus.SUSPENDED)
            )
            await session.commit()

        # Attempt Google login
        r = await client.post("/auth/google", json={"id_token": f"test_google:{email}"})
        assert r.status_code == 403
    finally:
        await _cleanup(email)
