"""A purchase is once per offer/account, independently of voucher lifecycle."""
import asyncio
import uuid

import pytest
from sqlalchemy import delete, update

from app.db.models import Offer, PointsLedger, Voucher, VoucherStatus
from app.db.postgres import get_session_factory
from tests.test_offers import _auth, _cleanup, _create_offer, _email, _register, _sync_steps


@pytest.mark.asyncio
@pytest.mark.parametrize('voucher_state', ['ISSUED', 'REDEEMED', 'EXPIRED', 'CANCELLED', 'DELETED'])
async def test_claim_cannot_be_repeated_after_voucher_lifecycle_changes(client, voucher_state):
    email = _email()
    offer = await _create_offer(points_cost=10, inventory=5)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        headers = {**_auth(token), 'Idempotency-Key': str(uuid.uuid4())}
        first = await client.post(f'/offers/{offer}/redeem', headers=headers)
        assert first.status_code == 201, first.text
        voucher_id = first.json()['voucher_id']
        async with get_session_factory()() as session:
            if voucher_state == 'DELETED':
                await session.execute(delete(Voucher).where(Voucher.id == voucher_id))
            else:
                await session.execute(update(Voucher).where(Voucher.id == voucher_id).values(status=VoucherStatus(voucher_state)))
            await session.commit()
        # An old client without a request key must obey the policy too.
        for retry_headers in [_auth(token), {**_auth(token), 'Idempotency-Key': str(uuid.uuid4())}]:
            second = await client.post(f'/offers/{offer}/redeem', headers=retry_headers)
            assert second.status_code == 409, second.text
            assert 'already claimed' in second.json()['detail']
        catalog = (await client.get('/offers', headers=_auth(token))).json()
        assert next(item for item in catalog if item['id'] == offer)['already_redeemed'] is True
        balance = (await client.get('/points/balance', headers=_auth(token))).json()
        assert balance['balance'] == 90
        assert balance['total_spent'] == 10
        async with get_session_factory()() as session:
            assert (await session.get(Offer, offer)).inventory == 4
        # Retry recovery still returns the original purchase, never a second one.
        replay = await client.post(f'/offers/{offer}/redeem', headers=headers)
        assert replay.status_code == 201
        assert replay.json()['voucher_id'] == voucher_id
        assert replay.json()['is_replay'] is True
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_simultaneous_distinct_purchase_ids_cannot_buy_same_reward_twice(client):
    email = _email()
    offer = await _create_offer(points_cost=10, inventory=10)
    try:
        token = await _register(client, email)
        await _sync_steps(client, token, 10000)
        responses = await asyncio.gather(*[
            client.post(f'/offers/{offer}/redeem', headers={**_auth(token), 'Idempotency-Key': str(uuid.uuid4())})
            for _ in range(5)
        ])
        assert sorted(response.status_code for response in responses) == [201, 409, 409, 409, 409]
        assert len((await client.get('/vouchers', headers=_auth(token))).json()) == 1
        assert (await client.get('/points/balance', headers=_auth(token))).json()['balance'] == 90
        async with get_session_factory()() as session:
            assert (await session.get(Offer, offer)).inventory == 9
    finally:
        await _cleanup(email, offer)


@pytest.mark.asyncio
async def test_claim_status_is_account_scoped_and_other_rewards_remain_available(client):
    emails = [_email(), _email()]
    offer, other_offer = await _create_offer(points_cost=0), await _create_offer(points_cost=0)
    try:
        first, second = [await _register(client, email) for email in emails]
        assert (await client.post(f'/offers/{offer}/redeem', headers=_auth(first))).status_code == 201
        for token, claimed in [(first, True), (second, False)]:
            catalog = (await client.get('/offers', headers=_auth(token))).json()
            assert next(item for item in catalog if item['id'] == offer)['already_redeemed'] is claimed
            assert next(item for item in catalog if item['id'] == other_offer)['already_redeemed'] is False
        assert (await client.post(f'/offers/{offer}/redeem', headers=_auth(second))).status_code == 201
        assert (await client.post(f'/offers/{other_offer}/redeem', headers=_auth(first))).status_code == 201
    finally:
        await _cleanup(emails[0])
        await _cleanup(emails[1], offer, other_offer)


@pytest.mark.asyncio
async def test_existing_voucher_without_purchase_ledger_also_blocks_repeat(client):
    email = _email()
    offer = await _create_offer(points_cost=0)
    try:
        token = await _register(client, email)
        assert (await client.post(f'/offers/{offer}/redeem', headers=_auth(token))).status_code == 201
        async with get_session_factory()() as session:
            await session.execute(delete(PointsLedger).where(PointsLedger.ref_id == offer))
            await session.commit()
        assert (await client.post(f'/offers/{offer}/redeem', headers=_auth(token))).status_code == 409
        catalog = (await client.get('/offers', headers=_auth(token))).json()
        assert next(item for item in catalog if item['id'] == offer)['already_redeemed'] is True
    finally:
        await _cleanup(email, offer)
