"""Tests for Forgot Password and Reset Password endpoints:
- POST /auth/forgot-password
- POST /auth/reset-password
"""
from __future__ import annotations

import uuid
# pyrefly: ignore [missing-import]
import pytest
# pyrefly: ignore [missing-import]
from httpx import AsyncClient
# pyrefly: ignore [missing-import]
from sqlalchemy import delete

from app.db.models import User


def _email() -> str:
    return f"reset_{uuid.uuid4().hex[:8]}@example.com"


async def _cleanup(email: str) -> None:
    from app.db.postgres import get_session_factory
    factory = get_session_factory()
    async with factory() as session:
        result = await session.execute(
            __import__("sqlalchemy", fromlist=["select"]).select(User).where(User.email == email)
        )
        user = result.scalar_one_or_none()
        if user:
            await session.execute(delete(User).where(User.id == user.id))
            await session.commit()


@pytest.mark.asyncio
async def test_forgot_password_and_reset_flow(client: AsyncClient, monkeypatch) -> None:
    email = _email()
    password_old = "oldpassword123"
    password_new = "newpassword456"
    from app.config import get_settings
    settings = get_settings()
    monkeypatch.setattr(settings, 'smtp_host', 'smtp.test')
    monkeypatch.setattr(settings, 'smtp_from', 'support@stepsy.test')
    delivered = []
    monkeypatch.setattr('app.routers.auth.send_password_reset_email', lambda email, token, settings: delivered.append((email, token)))

    try:
        # 1. Register user
        reg_resp = await client.post("/auth/register", json={"email": email, "password": password_old})
        assert reg_resp.status_code == 201

        # 2. Request forgot password
        forgot_resp = await client.post("/auth/forgot-password", json={"email": email})
        assert forgot_resp.status_code == 200
        data = forgot_resp.json()
        assert "message" in data
        assert data.get('reset_token') is None
        assert delivered[0][0] == email
        reset_token = delivered[0][1]

        # 3. Reset password with valid token
        reset_resp = await client.post(
            "/auth/reset-password",
            json={"reset_token": reset_token, "new_password": password_new},
        )
        assert reset_resp.status_code == 200
        assert "successfully updated" in reset_resp.json()["message"]

        replay = await client.post('/auth/reset-password', json={'reset_token': reset_token, 'new_password': 'another-password'})
        assert replay.status_code == 400

        # 4. Old password must fail
        fail_login = await client.post("/auth/login", json={"email": email, "password": password_old})
        assert fail_login.status_code == 401

        # 5. New password must succeed
        success_login = await client.post("/auth/login", json={"email": email, "password": password_new})
        assert success_login.status_code == 200
        assert "access_token" in success_login.json()
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_reset_password_invalid_token(client: AsyncClient) -> None:
    resp = await client.post(
        "/auth/reset-password",
        json={"reset_token": "invalid.jwt.token", "new_password": "newpassword123"},
    )
    assert resp.status_code == 400
