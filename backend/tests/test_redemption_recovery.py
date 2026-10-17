"""Real-Postgres regressions for ambiguous and concurrent reward purchases."""
import asyncio
import uuid

import pytest
from cryptography.fernet import Fernet
from sqlalchemy import select, text, update

from app.config import get_settings
from app.db.models import Offer, RedemptionRequest, Voucher
from app.db.postgres import get_session_factory
from tests.test_offers import _auth, _cleanup, _create_offer, _email, _register, _sync_steps


@pytest.mark.asyncio
async def test_same_purchase_replays_after_stock_exhausted(client):
    email, key = _email(), str(uuid.uuid4())
    offer = await _create_offer(points_cost=50, inventory=1)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        headers = {**_auth(token), 'Idempotency-Key': key}
        first = await client.post(f'/offers/{offer}/redeem', headers=headers)
        second = await client.post(f'/offers/{offer}/redeem', headers=headers)
        assert first.status_code == second.status_code == 201
        assert second.json() == {**first.json(), 'is_replay': True}
        assert first.json()['balance'] == 50
        wallet = (await client.get('/vouchers', headers=_auth(token))).json()
        assert [v['id'] for v in wallet] == [first.json()['voucher_id']]
        async with get_session_factory()() as session:
            receipt = (await session.execute(select(RedemptionRequest).where(RedemptionRequest.request_key == key))).scalar_one()
            assert first.json()['token'] not in receipt.response_ciphertext
            assert first.json()['short_code'] not in receipt.response_ciphertext
            assert await session.scalar(text("SELECT relrowsecurity FROM pg_class WHERE oid='redemption_requests'::regclass"))
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_concurrent_purchase_retries_issue_once(client):
    email, key = _email(), str(uuid.uuid4())
    offer = await _create_offer(points_cost=50, inventory=1)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        responses = await asyncio.gather(*[
            client.post(f'/offers/{offer}/redeem', headers={**_auth(token), 'Idempotency-Key': key})
            for _ in range(4)
        ])
        assert all(r.status_code == 201 for r in responses), [r.text for r in responses]
        assert len({r.json()['voucher_id'] for r in responses}) == 1
        assert sum(not r.json()['is_replay'] for r in responses) == 1
        assert all(r.json()['balance'] == 50 for r in responses)
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_key_cannot_be_rebound_to_another_offer(client):
    email, key = _email(), str(uuid.uuid4())
    first, second = await _create_offer(points_cost=0), await _create_offer(points_cost=0)
    try:
        token = await _register(client, email)
        headers = {**_auth(token), 'Idempotency-Key': key}
        assert (await client.post(f'/offers/{first}/redeem', headers=headers)).status_code == 201
        assert (await client.post(f'/offers/{second}/redeem', headers=headers)).status_code == 409
    finally:
        await _cleanup(email, first, second)


@pytest.mark.asyncio
async def test_same_key_is_scoped_to_each_account(client):
    emails, key = [_email(), _email()], str(uuid.uuid4())
    offer = await _create_offer(points_cost=0)
    try:
        tokens = [await _register(client, e) for e in emails]
        results = [await client.post(f'/offers/{offer}/redeem', headers={**_auth(t), 'Idempotency-Key': key}) for t in tokens]
        assert all(r.status_code == 201 for r in results)
        assert results[0].json()['voucher_id'] != results[1].json()['voucher_id']
    finally:
        await _cleanup(emails[0])
        await _cleanup(emails[1], offer)


@pytest.mark.asyncio
async def test_unfunded_request_can_retry_after_funding(client):
    email, key = _email(), str(uuid.uuid4())
    offer = await _create_offer(points_cost=50)
    try:
        token = await _register(client, email)
        headers = {**_auth(token), 'Idempotency-Key': key}
        assert (await client.post(f'/offers/{offer}/redeem', headers=headers)).status_code == 402
        await _sync_steps(client, token, 10000)
        result = await client.post(f'/offers/{offer}/redeem', headers=headers)
        assert result.status_code == 201
        assert result.json()['balance'] == 50
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_key_rotation_preserves_old_receipt(client, monkeypatch):
    email, key = _email(), str(uuid.uuid4())
    offer = await _create_offer(points_cost=0)
    try:
        token = await _register(client, email)
        headers = {**_auth(token), 'Idempotency-Key': key}
        first = await client.post(f'/offers/{offer}/redeem', headers=headers)
        old = get_settings().redemption_receipt_keys
        monkeypatch.setattr(get_settings(), 'redemption_receipt_keys', Fernet.generate_key().decode()+','+old)
        replay = await client.post(f'/offers/{offer}/redeem', headers=headers)
        assert replay.status_code == 201
        assert replay.json() == {**first.json(), 'is_replay': True}
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_missing_encryption_configuration_cannot_spend(client, monkeypatch):
    email = _email()
    offer = await _create_offer(points_cost=50, inventory=1)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        monkeypatch.setattr(get_settings(), 'redemption_receipt_keys', '')
        response = await client.post(f'/offers/{offer}/redeem', headers={**_auth(token), 'Idempotency-Key': str(uuid.uuid4())})
        assert response.status_code == 503
        assert (await client.get('/vouchers', headers=_auth(token))).json() == []
        async with get_session_factory()() as session:
            assert (await session.get(Offer, offer)).inventory == 1
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_short_code_collision_keeps_transaction_usable(client, monkeypatch):
    from app.services import offers
    email = _email()
    offer = await _create_offer(points_cost=50)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        first = (await client.post(f'/offers/{offer}/redeem', headers=_auth(token))).json()
        codes = iter([first['short_code'], 'SR-'+uuid.uuid4().hex[:12].upper()])
        monkeypatch.setattr(offers, '_generate_short_code', lambda: next(codes))
        second = await client.post(f'/offers/{offer}/redeem', headers={**_auth(token), 'Idempotency-Key': str(uuid.uuid4())})
        assert second.status_code == 201, second.text
        assert second.json()['balance'] == 0
        assert second.json()['voucher_id'] != first['voucher_id']
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_price_change_requires_new_confirmation(client):
    email, key = _email(), str(uuid.uuid4())
    offer = await _create_offer(points_cost=50, inventory=2)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        headers = {**_auth(token), 'Idempotency-Key': key}
        assert (await client.post(f'/offers/{offer}/redeem', headers=headers, json={'expected_points_cost': 40})).status_code == 409
        first = await client.post(f'/offers/{offer}/redeem', headers=headers, json={'expected_points_cost': 50})
        assert first.status_code == 201
        assert (await client.post(f'/offers/{offer}/redeem', headers=headers, json={'expected_points_cost': 40})).status_code == 409
        replay = await client.post(f'/offers/{offer}/redeem', headers=headers, json={'expected_points_cost': 50})
        assert replay.status_code == 201
        assert replay.json()['balance'] == 50
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_unreadable_receipt_cannot_create_another_purchase(client):
    email, key = _email(), str(uuid.uuid4())
    offer = await _create_offer(points_cost=50, inventory=2)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        headers = {**_auth(token), 'Idempotency-Key': key}
        assert (await client.post(f'/offers/{offer}/redeem', headers=headers)).status_code == 201
        async with get_session_factory()() as session:
            await session.execute(update(RedemptionRequest).where(RedemptionRequest.request_key == key).values(response_ciphertext='damaged'))
            await session.commit()
        assert (await client.post(f'/offers/{offer}/redeem', headers=headers)).status_code == 503
        assert len((await client.get('/vouchers', headers=_auth(token))).json()) == 1
        async with get_session_factory()() as session:
            assert (await session.get(Offer, offer)).inventory == 1
    finally:
        await _cleanup(email, offer)
