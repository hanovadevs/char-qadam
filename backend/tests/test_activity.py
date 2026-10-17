"""Tests for Phase B2: POST /activity/sync, GET /activity, GET /points/*.

MVP acceptance criterion tested here:
    ✅ Replayed sync_key does NOT double-award points.
    ✅ Steps are clamped to daily_step_cap.
    ✅ Only the delta vs previous total earns new points.
    ✅ Points never decrease when a lower step count arrives later.
"""
from __future__ import annotations

from tests.auth_helpers import register_verified

import uuid
from datetime import date

import pytest
from httpx import AsyncClient
from sqlalchemy import delete

from app.db.models import ActivityDaily, PointsLedger, User


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _email() -> str:
    return f"act_{uuid.uuid4().hex[:8]}@example.com"


def _sync_key() -> str:
    return str(uuid.uuid4())


def _today() -> str:
    return date.today().isoformat()


async def _cleanup(email: str) -> None:
    """Delete test user and all associated rows."""
    from app.db.postgres import get_session_factory
    factory = get_session_factory()
    async with factory() as session:
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
    resp = await register_verified(client, json={"email": email, "password": "testpassword1"})
    assert resp.status_code == 200, resp.text
    return resp.json()["access_token"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# POST /activity/sync — basic sync
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_sync_awards_points(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register_and_token(client, email)
        resp = await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 1000, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        # 1000 steps / 100 steps_per_point = 10 points
        assert body["points_awarded"] == 10
        assert body["balance"] == 10
        assert body["eligible_steps"] == 1000
        assert body["is_replay"] is False
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_sync_caps_steps_at_daily_cap(client: AsyncClient) -> None:
    """Steps above daily_step_cap (20 000) must be clamped."""
    email = _email()
    try:
        token = await _register_and_token(client, email)
        resp = await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 99_999, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["eligible_steps"] == 20_000          # capped
        assert body["points_awarded"] == 200             # 20000 / 100
    finally:
        await _cleanup(email)


# ---------------------------------------------------------------------------
# ✅ MVP acceptance criterion: replayed sync must NOT double-award
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_replay_does_not_double_award(client: AsyncClient) -> None:
    """Sending the same sync_key twice must award points exactly once."""
    email = _email()
    try:
        token = await _register_and_token(client, email)
        key = _sync_key()
        payload = {"local_date": _today(), "eligible_steps": 5000, "source": "manual", "sync_key": key}

        # First call — should award 50 points
        r1 = await client.post("/activity/sync", json=payload, headers=_auth(token))
        assert r1.status_code == 200
        assert r1.json()["points_awarded"] == 50
        assert r1.json()["is_replay"] is False

        # Second call with SAME key — must be a no-op
        r2 = await client.post("/activity/sync", json=payload, headers=_auth(token))
        assert r2.status_code == 200
        assert r2.json()["points_awarded"] == 0          # ← no double-award
        assert r2.json()["balance"] == 50                # unchanged
        assert r2.json()["is_replay"] is True

        # Third replay — still no-op
        r3 = await client.post("/activity/sync", json=payload, headers=_auth(token))
        assert r3.status_code == 200
        assert r3.json()["points_awarded"] == 0
        assert r3.json()["balance"] == 50
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_delta_only_award_on_step_increase(client: AsyncClient) -> None:
    """Syncing more steps on the same day only awards points for the delta."""
    email = _email()
    try:
        token = await _register_and_token(client, email)
        today = _today()

        # First sync: 3000 steps → 30 points
        r1 = await client.post(
            "/activity/sync",
            json={"local_date": today, "eligible_steps": 3000, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        assert r1.json()["points_awarded"] == 30
        assert r1.json()["balance"] == 30

        # Second sync same day: 7000 steps → delta = 4000 → 40 more points
        r2 = await client.post(
            "/activity/sync",
            json={"local_date": today, "eligible_steps": 7000, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        assert r2.json()["points_awarded"] == 40         # delta only
        assert r2.json()["balance"] == 70                # 30 + 40
        assert r2.json()["eligible_steps"] == 7000
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_small_increment_syncs_do_not_lose_points(client: AsyncClient) -> None:
    """Frequent small-delta syncs must not drop sub-threshold remainders.

    Regression: points were previously computed as ``delta_steps // 100`` per
    sync, so a client syncing < 100 steps at a time earned 0 points forever.
    Points must instead track floor(total_steps / 100)."""
    email = _email()
    try:
        token = await _register_and_token(client, email)
        today = _today()

        # Sync in 30-step increments up to 300 total. Each individual delta is
        # < 100 steps, so the old per-delta logic would have awarded 0 points.
        last = None
        for steps in range(30, 301, 30):
            last = await client.post(
                "/activity/sync",
                json={"local_date": today, "eligible_steps": steps, "source": "manual", "sync_key": _sync_key()},
                headers=_auth(token),
            )
            assert last.status_code == 200, last.text

        # 300 total steps / 100 = 3 points, regardless of how it was chunked.
        assert last.json()["eligible_steps"] == 300
        assert last.json()["balance"] == 3
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_lower_steps_later_no_deduction(client: AsyncClient) -> None:
    """A later sync with fewer steps must NOT reduce points (stale reading)."""
    email = _email()
    try:
        token = await _register_and_token(client, email)
        today = _today()

        await client.post(
            "/activity/sync",
            json={"local_date": today, "eligible_steps": 8000, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        # Stale reading arrives with lower count
        r = await client.post(
            "/activity/sync",
            json={"local_date": today, "eligible_steps": 2000, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        assert r.json()["points_awarded"] == 0           # no new points
        assert r.json()["eligible_steps"] == 8000        # stored value unchanged
        assert r.json()["balance"] == 80                 # 8000/100
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_sync_requires_auth(client: AsyncClient) -> None:
    resp = await client.post(
        "/activity/sync",
        json={"local_date": _today(), "eligible_steps": 1000, "source": "manual", "sync_key": _sync_key()},
    )
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# GET /activity
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_activity_today(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register_and_token(client, email)
        await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 4000, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        r = await client.get("/activity?range=today", headers=_auth(token))
        assert r.status_code == 200
        body = r.json()
        assert body["range"] == "today"
        assert body["total_steps"] == 4000
        assert len(body["days"]) == 1
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_get_activity_extended_ranges(client: AsyncClient) -> None:
    """Extended activity ranges (month, 3months, 6months, year, all) must return valid responses."""
    email = _email()
    try:
        token = await _register_and_token(client, email)
        await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 7500, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        for r_param in ["week", "month", "3months", "6months", "year", "all"]:
            r = await client.get(f"/activity?range={r_param}", headers=_auth(token))
            assert r.status_code == 200, f"Failed for range={r_param}: {r.text}"
            body = r.json()
            assert body["range"] == r_param
            assert body["total_steps"] >= 7500
    finally:
        await _cleanup(email)


# ---------------------------------------------------------------------------
# GET /points/balance and /points/history
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_points_balance(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register_and_token(client, email)
        await client.post(
            "/activity/sync",
            json={"local_date": _today(), "eligible_steps": 5000, "source": "manual", "sync_key": _sync_key()},
            headers=_auth(token),
        )
        r = await client.get("/points/balance", headers=_auth(token))
        assert r.status_code == 200
        body = r.json()
        assert body["balance"] == 50
        assert body["total_earned"] == 50
        assert body["total_spent"] == 0
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
async def test_points_history_paginated(client: AsyncClient) -> None:
    email = _email()
    try:
        token = await _register_and_token(client, email)
        today = _today()
        # Generate 3 ledger entries across 3 different days (by manipulating local_date)
        for i, steps in enumerate([1000, 2000, 3000]):
            from datetime import date, timedelta
            d = (date.fromisoformat(today) - timedelta(days=i)).isoformat()
            await client.post(
                "/activity/sync",
                json={"local_date": d, "eligible_steps": steps, "source": "manual", "sync_key": _sync_key()},
                headers=_auth(token),
            )
        r = await client.get("/points/history?limit=2&offset=0", headers=_auth(token))
        assert r.status_code == 200
        body = r.json()
        assert body["total"] == 3
        assert len(body["entries"]) == 2
        assert body["limit"] == 2
        assert body["offset"] == 0
    finally:
        await _cleanup(email)
