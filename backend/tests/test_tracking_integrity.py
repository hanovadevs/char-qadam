import asyncio
from tests.auth_helpers import register_verified

import uuid
from datetime import datetime, timezone

import pytest

from app.services.local_date import local_today


def test_pakistan_midnight_precedes_utc_midnight():
    now = datetime(2026, 10, 16, 20, 0, tzinfo=timezone.utc)
    assert local_today('Asia/Karachi', now=now).isoformat() == '2026-10-17'
    assert local_today('UTC', now=now).isoformat() == '2026-10-16'
    assert local_today(None, now=now).isoformat() == '2026-10-17'


@pytest.mark.asyncio
async def test_simultaneous_first_day_syncs_do_not_duplicate_awards(client):
    email = f'concurrent_{uuid.uuid4().hex}@example.com'
    registered = await register_verified(client, json={'email': email, 'password': 'test-password-123'})
    token = registered.json()['access_token']
    headers = {'Authorization': f'Bearer {token}'}
    date = local_today().isoformat()
    responses = await asyncio.gather(*[
        client.post('/activity/sync', headers=headers, json={
            'local_date': date, 'eligible_steps': steps, 'source': 'health', 'sync_key': str(uuid.uuid4())
        }) for steps in [1000, 2000, 1500, 3000]
    ])
    assert all(r.status_code == 200 for r in responses), [r.text for r in responses]
    assert sum(r.json()['points_awarded'] for r in responses) == 30
    balance = await client.get('/points/balance', headers=headers)
    assert balance.json()['balance'] == 30
    replay = await client.post('/activity/sync', headers=headers, json={
        'local_date': date, 'eligible_steps': 3000, 'sync_key': str(uuid.uuid4())
    })
    assert replay.json()['points_awarded'] == 0
    assert replay.json()['points_earned_today'] == 30
    # Refresh is read-only: the snapshot agrees, and repeated reads neither
    # change the day's version nor append ledger entries.
    from app.db.models import ActivityDaily
    from sqlalchemy import select
    from app.db.postgres import get_session_factory
    user_id = registered.json()['user']['id']
    async with get_session_factory()() as session:
        version_before = await session.scalar(select(ActivityDaily.sync_version).where(
            ActivityDaily.user_id == user_id, ActivityDaily.local_date == date))
    for _ in range(2):
        snapshot = await client.get('/activity/today', headers=headers)
        assert snapshot.status_code == 200
        assert snapshot.json()['eligible_steps'] == 3000
        assert snapshot.json()['balance'] == 30
        assert snapshot.json()['points_earned_today'] == 30
        assert snapshot.json()['points_awarded'] == 0
    async with get_session_factory()() as session:
        assert await session.scalar(select(ActivityDaily.sync_version).where(
            ActivityDaily.user_id == user_id, ActivityDaily.local_date == date)) == version_before
    # Delete only the isolated test user's rows.
    from app.db.postgres import get_session_factory
    from app.db.models import ActivityDaily, PointsLedger, User
    from sqlalchemy import delete
    async with get_session_factory()() as session:
        await session.execute(delete(PointsLedger).where(PointsLedger.user_id == registered.json().get('user_id', '')))
        user_id = (await client.get('/auth/me', headers=headers)).json()['id']
        await session.execute(delete(PointsLedger).where(PointsLedger.user_id == user_id))
        await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == user_id))
        await session.execute(delete(User).where(User.id == user_id))
        await session.commit()
