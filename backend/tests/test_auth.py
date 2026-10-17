"""Tests for POST /auth/register, POST /auth/login, GET /auth/me.

Each test uses a unique email so they are independent and can run in any
order.  Cleanup (DELETE from users) runs in a finally block so the DB
stays clean even on failure.
"""
from __future__ import annotations

import uuid

from tests.auth_helpers import register_verified

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.db.models import User
from app.db.postgres import get_session_factory


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _email() -> str:
    """Return a unique throw-away email for this test run."""
    return f"test_{uuid.uuid4().hex[:8]}@example.com"


async def _delete_user_by_email(email: str) -> None:
    """Remove a test user so the DB stays clean."""
    factory = get_session_factory()
    async with factory() as session:
        await session.execute(delete(User).where(User.email == email))
        await session.commit()


# ---------------------------------------------------------------------------
# /auth/register
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_register_success(client: AsyncClient) -> None:
    email = _email()
    try:
        resp = await client.post(
            "/auth/register",
            json={"email": email, "password": "strongpass1"},
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert "access_token" not in body
        assert body["verification_required"] is True
        assert body["email"] == email
    finally:
        await _delete_user_by_email(email)


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient) -> None:
    email = _email()
    try:
        await client.post("/auth/register", json={"email": email, "password": "strongpass1"})
        resp = await client.post("/auth/register", json={"email": email, "password": "anotherpass"})
        assert resp.status_code == 409
    finally:
        await _delete_user_by_email(email)


@pytest.mark.asyncio
async def test_register_weak_password(client: AsyncClient) -> None:
    resp = await client.post(
        "/auth/register",
        json={"email": _email(), "password": "short"},
    )
    assert resp.status_code == 422  # Pydantic min_length validation


# ---------------------------------------------------------------------------
# /auth/login
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_login_success(client: AsyncClient) -> None:
    email = _email()
    password = "strongpass1"
    try:
        await register_verified(client, json={"email": email, "password": password})
        resp = await client.post("/auth/login", json={"email": email, "password": password})
        assert resp.status_code == 200, resp.text
        assert "access_token" in resp.json()
    finally:
        await _delete_user_by_email(email)


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient) -> None:
    email = _email()
    try:
        await client.post("/auth/register", json={"email": email, "password": "correctpass"})
        resp = await client.post("/auth/login", json={"email": email, "password": "wrongpass!"})
        assert resp.status_code == 401
    finally:
        await _delete_user_by_email(email)


@pytest.mark.asyncio
async def test_login_unknown_email(client: AsyncClient) -> None:
    resp = await client.post(
        "/auth/login",
        json={"email": "nobody_unknown@example.com", "password": "doesnotmatter"},
    )
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# /auth/me
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_me_with_valid_token(client: AsyncClient) -> None:
    email = _email()
    try:
        reg = await register_verified(client, json={"email": email, "password": "strongpass1"})
        token = reg.json()["access_token"]
        resp = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["email"] == email
        assert body["status"] == "ACTIVE"
        assert "id" in body
    finally:
        await _delete_user_by_email(email)


@pytest.mark.asyncio
async def test_me_without_token(client: AsyncClient) -> None:
    resp = await client.get("/auth/me")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me_with_invalid_token(client: AsyncClient) -> None:
    resp = await client.get("/auth/me", headers={"Authorization": "Bearer totallyinvalidtoken"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_register_login_me_full_flow(client: AsyncClient) -> None:
    """End-to-end: register → login → /me must all return the same user."""
    email = _email()
    password = "endtoend99"
    try:
        reg = await register_verified(client, json={"email": email, "password": password})
        assert reg.status_code == 200

        login = await client.post("/auth/login", json={"email": email, "password": password})
        assert login.status_code == 200
        token = login.json()["access_token"]

        me = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200
        assert me.json()["email"] == email
    finally:
        await _delete_user_by_email(email)
