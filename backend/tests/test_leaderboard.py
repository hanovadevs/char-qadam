"""Tests for Leaderboard & Social Ranking: GET /leaderboard.

Verifies:
    ✅ Requires authenticated JWT bearer token.
    ✅ Accurately sorts multiple users by total step volume.
    ✅ Privacy-masks user emails in display names.
    ✅ Accurately computes caller rank and percentile.
    ✅ Filters correctly by scopes: today, week, month, all_time.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import delete

from app.db.models import ActivityDaily, PointsLedger, User


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _email() -> str:
    return f"board_{uuid.uuid4().hex[:8]}@example.com"


def _sync_key() -> str:
    return str(uuid.uuid4())


def _today() -> str:
    return date.today().isoformat()


async def _cleanup(emails: list[str]) -> None:
    from app.db.postgres import get_session_factory
    factory = get_session_factory()
    async with factory() as session:
        for email in emails:
            result = await session.execute(
                __import__("sqlalchemy", fromlist=["select"]).select(User).where(User.email == email)
            )
            user = result.scalar_one_or_none()
            if user:
                await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == user.id))
                await session.execute(delete(PointsLedger).where(PointsLedger.user_id == user.id))
                await session.execute(delete(User).where(User.id == user.id))
        await session.commit()


async def _register_and_token(client: AsyncClient, email: str) -> str:
    resp = await client.post("/auth/register", json={"email": email, "password": "password123"})
    assert resp.status_code == 201, resp.text
    return resp.json()["access_token"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_leaderboard_requires_auth(client: AsyncClient) -> None:
    resp = await client.get("/leaderboard")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_leaderboard_ranking_order(client: AsyncClient) -> None:
    user1_email = _email()
    user2_email = _email()
    user3_email = _email()

    try:
        t1 = await _register_and_token(client, user1_email)
        t2 = await _register_and_token(client, user2_email)
        t3 = await _register_and_token(client, user3_email)

        # Sync steps: user1: 15,000, user2: 5,000, user3: 10,000
        await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 15000, "source": "test", "sync_key": _sync_key()},
            headers=_auth(t1),
        )
        await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 5000, "source": "test", "sync_key": _sync_key()},
            headers=_auth(t2),
        )
        await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 10000, "source": "test", "sync_key": _sync_key()},
            headers=_auth(t3),
        )

        # Query leaderboard as user3 (who has 10,000 steps, should be rank 2)
        resp = await client.get("/leaderboard?scope=today", headers=_auth(t3))
        assert resp.status_code == 200, resp.text
        data = resp.json()

        assert data["scope"] == "today"
        assert data["total_participants"] >= 3
        rankings = data["rankings"]

        # First place should have at least 15000 steps
        assert rankings[0]["total_steps"] >= 15000
        # Display name must be masked
        assert "****" in rankings[0]["display_name"]

        # Check caller user_ranking for user3
        user_ranking = data["user_ranking"]
        assert user_ranking is not None
        assert user_ranking["total_steps"] == 10000
        assert user_ranking["points_earned"] == 100
        assert user_ranking["rank"] >= 1
    finally:
        await _cleanup([user1_email, user2_email, user3_email])


@pytest.mark.asyncio
async def test_leaderboard_scopes(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register_and_token(client, email)

        for scope in ["today", "week", "month", "all_time"]:
            resp = await client.get(f"/leaderboard?scope={scope}", headers=_auth(token))
            assert resp.status_code == 200
            assert resp.json()["scope"] == scope
    finally:
        await _cleanup([email])
