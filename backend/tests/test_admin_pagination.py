"""Bounded admin reads retain deterministic navigation and search filters."""
import uuid
import pytest
from sqlalchemy import delete
from app.db.models import User
from app.db.postgres import get_session_factory, get_read_session_factory

@pytest.mark.asyncio
async def test_user_pages_are_bounded_disjoint_and_keep_filters(admin_client):
    prefix = 'paged-' + uuid.uuid4().hex
    ids = [str(uuid.uuid4()) for _ in range(3)]
    async with get_session_factory()() as session:
        session.add_all([User(id=uid, email=f'{prefix}-{i}@example.com', password_hash='unused-test-hash') for i, uid in enumerate(ids)])
        await session.commit()
    try:
        first = await admin_client.get('/admin/users', params={'search': prefix, 'limit': 2})
        last = await admin_client.get('/admin/users', params={'search': prefix, 'limit': 2, 'offset': 2})
        assert first.status_code == last.status_code == 200
        assert len(first.json()) == 2 and len(last.json()) == 1
        assert {row['id'] for row in first.json() + last.json()} == set(ids)
        assert (await admin_client.get('/admin/users', params={'search': prefix, 'limit': 2})).json() == first.json()
        assert (await admin_client.get('/admin/users', params={'search': prefix, 'status': 'SUSPENDED'})).json() == []
        for params in [{'limit': 0}, {'limit': 201}, {'offset': -1}]:
            assert (await admin_client.get('/admin/users', params=params)).status_code == 422
    finally:
        async with get_session_factory()() as session:
            await session.execute(delete(User).where(User.id.in_(ids)))
            await session.commit()


@pytest.mark.asyncio
async def test_read_pool_avoids_transactions_while_writes_keep_them():
    from sqlalchemy import text
    async with get_read_session_factory()() as session:
        await session.execute(text('SELECT 1'))
        connection = await session.connection()
        raw = await connection.get_raw_connection()
        assert not raw.driver_connection.is_in_transaction()
    async with get_session_factory()() as session:
        await session.execute(text('SELECT 1'))
        connection = await session.connection()
        raw = await connection.get_raw_connection()
        assert raw.driver_connection.is_in_transaction()
