import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

from app.db.postgres import get_session_factory
from app.db.base import Base
from tests.test_offers import _auth, _cleanup, _create_offer, _email, _register


@pytest.mark.asyncio
async def test_api_owner_works_but_unprivileged_role_cannot_read_or_write(client):
    email = _email()
    offer = await _create_offer(points_cost=0)
    role = 'stepsy_probe_' + uuid.uuid4().hex[:12]
    role_created = False
    try:
        token = await _register(client, email)
        assert (await client.get('/offers', headers=_auth(token))).status_code == 200
        async with get_session_factory()() as session:
            rows = (await session.execute(text("SELECT relname, relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND relkind='r'"))).all()
            assert {row.relname for row in rows} == set(Base.metadata.tables) | {'alembic_version'}
            assert all(r.relrowsecurity for r in rows)
            user_id = await session.scalar(text('SELECT id FROM users WHERE email=:email'), {'email': email})
            await session.execute(text(f'CREATE ROLE {role} NOLOGIN'))
            await session.execute(text(f'GRANT USAGE ON SCHEMA public TO {role}'))
            await session.execute(text(f'GRANT SELECT ON users, vouchers, redemption_requests, device_bindings, device_activity_daily, merchant_ledgers TO {role}'))
            await session.execute(text(f'GRANT INSERT ON merchant_ledgers TO {role}'))
            await session.execute(text(f'GRANT INSERT ON redemption_requests TO {role}'))
            await session.commit()
            role_created = True
            await session.execute(text(f'SET LOCAL ROLE {role}'))
            assert await session.scalar(text('SELECT count(*) FROM users')) == 0
            assert await session.scalar(text('SELECT count(*) FROM vouchers')) == 0
            assert await session.scalar(text('SELECT count(*) FROM device_bindings')) == 0
            assert await session.scalar(text('SELECT count(*) FROM device_activity_daily')) == 0
            assert await session.scalar(text('SELECT count(*) FROM merchant_ledgers')) == 0
            with pytest.raises(DBAPIError, match='row-level security'):
                async with session.begin_nested():
                    await session.execute(text("INSERT INTO merchant_ledgers(id,partner_id,request_id,period,starts_on,ends_on,timezone,row_count,fixed_discount_total,sha256) VALUES (:id,:partner,:request,'week','2026-01-01','2026-01-07','Asia/Karachi',0,0,:hash)"),
                        {'id': str(uuid.uuid4()), 'partner': str(uuid.uuid4()), 'request': str(uuid.uuid4()), 'hash': '0' * 64})
            with pytest.raises(DBAPIError, match='row-level security'):
                async with session.begin_nested():
                    await session.execute(text('INSERT INTO redemption_requests(id,user_id,request_key,offer_id,response_ciphertext) VALUES (:id,:user_id,:key,:offer,:body)'),
                        {'id': str(uuid.uuid4()), 'user_id': user_id, 'key': str(uuid.uuid4()), 'offer': offer, 'body': 'not-an-authorized-receipt'})
            await session.rollback()
    finally:
        if role_created:
            async with get_session_factory()() as session:
                await session.execute(text(f'REVOKE ALL ON users, vouchers, redemption_requests, device_bindings, device_activity_daily, merchant_ledgers FROM {role}'))
                await session.execute(text(f'REVOKE USAGE ON SCHEMA public FROM {role}'))
                await session.execute(text(f'DROP ROLE {role}'))
                await session.commit()
        await _cleanup(email, offer)
