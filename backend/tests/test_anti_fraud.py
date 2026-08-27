"""Tests for Anti-Fraud & Data Integrity Controls:
- Rejecting future date sync attempts (> today)
- Rejecting stale historical sync attempts (> 7 days past)
- Admin fraud flags endpoint
- Admin user suspension endpoint
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import delete

from app.db.models import ActivityDaily, User, UserStatus
from app.db.postgres import get_session_factory
from app.services.security import create_access_token


@pytest.mark.asyncio
async def test_sync_rejects_future_dates(client: AsyncClient) -> None:
    factory = get_session_factory()
    user_id = str(uuid.uuid4())
    token = create_access_token(user_id)

    try:
        async with factory() as session:
            user = User(
                id=user_id,
                email=f"future_{uuid.uuid4().hex[:6]}@example.com",
                password_hash="hash",
                status=UserStatus.ACTIVE,
            )
            session.add(user)
            await session.commit()

        # Attempt to sync for tomorrow
        tomorrow = (date.today() + timedelta(days=1)).isoformat()
        resp = await client.post(
            "/activity/sync",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "local_date": tomorrow,
                "eligible_steps": 5000,
                "source": "pedometer",
                "sync_key": str(uuid.uuid4()),
            },
        )
        assert resp.status_code == 400
        assert "Cannot sync steps for a future date" in resp.json()["detail"]
    finally:
        async with factory() as session:
            await session.execute(delete(User).where(User.id == user_id))
            await session.commit()


@pytest.mark.asyncio
async def test_sync_rejects_stale_dates(client: AsyncClient) -> None:
    factory = get_session_factory()
    user_id = str(uuid.uuid4())
    token = create_access_token(user_id)

    try:
        async with factory() as session:
            user = User(
                id=user_id,
                email=f"stale_{uuid.uuid4().hex[:6]}@example.com",
                password_hash="hash",
                status=UserStatus.ACTIVE,
            )
            session.add(user)
            await session.commit()

        # Attempt to sync for 10 days ago (past 7-day threshold)
        stale_date = (date.today() - timedelta(days=10)).isoformat()
        resp = await client.post(
            "/activity/sync",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "local_date": stale_date,
                "eligible_steps": 5000,
                "source": "pedometer",
                "sync_key": str(uuid.uuid4()),
            },
        )
        assert resp.status_code == 400
        assert "Sync window expired" in resp.json()["detail"]
    finally:
        async with factory() as session:
            await session.execute(delete(User).where(User.id == user_id))
            await session.commit()


@pytest.mark.asyncio
async def test_admin_fraud_flags_and_user_suspension(client: AsyncClient) -> None:
    factory = get_session_factory()
    user_id = str(uuid.uuid4())

    try:
        async with factory() as session:
            user = User(
                id=user_id,
                email=f"fraud_{uuid.uuid4().hex[:6]}@example.com",
                password_hash="hash",
                status=UserStatus.ACTIVE,
            )
            act = ActivityDaily(
                id=str(uuid.uuid4()),
                user_id=user_id,
                local_date=date.today().isoformat(),
                eligible_steps=19000,
                source="pedometer",
                sync_key=str(uuid.uuid4()),
                sync_version=1,
            )
            session.add_all([user, act])
            await session.commit()

        # 1. Fetch fraud flags
        flags_resp = await client.get("/admin/fraud/flags")
        assert flags_resp.status_code == 200
        data = flags_resp.json()
        target = next((u for u in data if u["user_id"] == user_id), None)
        assert target is not None
        assert "HIGH_DAILY_AVERAGE_CADENCE" in target["flags"]

        # 2. Suspend user
        suspend_resp = await client.post(
            f"/admin/users/{user_id}/status",
            json={"status": "SUSPENDED", "reason": "Suspected bot step generation"},
        )
        assert suspend_resp.status_code == 200
        assert suspend_resp.json()["status"] == "SUSPENDED"

        # Verify DB
        async with factory() as session:
            refreshed = await session.get(User, user_id)
            assert refreshed is not None
            assert refreshed.status == UserStatus.SUSPENDED
    finally:
        async with factory() as session:
            await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == user_id))
            await session.execute(delete(User).where(User.id == user_id))
            await session.commit()
