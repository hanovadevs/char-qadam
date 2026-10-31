import asyncio
from datetime import datetime, timedelta, timezone
import secrets
import uuid

import pytest
import pytest_asyncio
from sqlalchemy import delete, select, func

from app.db.models import (ActivityDaily, DeviceActivityDaily, DeviceBinding,
    LedgerReason, Offer, Partner, PointsLedger, Redemption, RedemptionRequest, User, UserStatus, Voucher)
from app.db.postgres import get_session_factory
from app.services.local_date import local_today
from app.services.security import create_access_token, decode_access_claims, hash_password
from tests.auth_helpers import auth_headers, register_verified
from tests.test_offers import _create_offer


@pytest_asyncio.fixture
async def accounts(monkeypatch):
    context = {'emails': [], 'offers': [], 'ids': []}
    async def google(token, client_id=None):
        if not token.startswith('device-google:'):
            raise ValueError('Invalid token')
        address = token.split(':', 1)[1]
        return {'email': address, 'sub': 'google-sub:' + address, 'authoritative_email': True}
    monkeypatch.setattr('app.routers.auth.verify_google_id_token', google)
    yield context
    async with get_session_factory()() as s:
        ids = list((await s.scalars(select(User.id).where(User.email.in_(context['emails'])))).all())
        ids.extend(context['ids'])
        voucher_ids = select(Voucher.id).where(Voucher.user_id.in_(ids))
        await s.execute(delete(Redemption).where(Redemption.voucher_id.in_(voucher_ids)))
        await s.execute(delete(RedemptionRequest).where(RedemptionRequest.user_id.in_(ids)))
        await s.execute(delete(Voucher).where(Voucher.user_id.in_(ids)))
        await s.execute(delete(PointsLedger).where(PointsLedger.user_id.in_(ids)))
        await s.execute(delete(ActivityDaily).where(ActivityDaily.user_id.in_(ids)))
        await s.execute(delete(User).where(User.id.in_(ids)))
        if context['offers']:
            partners = list((await s.scalars(select(Offer.partner_id).where(Offer.id.in_(context['offers'])))).all())
            await s.execute(delete(Offer).where(Offer.id.in_(context['offers'])))
            await s.execute(delete(Partner).where(Partner.id.in_(partners)))
        await s.commit()


def address(accounts):
    email = f'device_{uuid.uuid4().hex}@example.com'
    accounts['emails'].append(email)
    return email


async def google(client, email, device):
    return await client.post('/auth/google', headers={'X-Device-ID': device}, json={'id_token': 'device-google:' + email})


async def signed_in(client, accounts, device):
    response = await google(client, address(accounts), device)
    assert response.status_code == 200, response.text
    token = response.json()['access_token']
    accounts['ids'].append(decode_access_claims(token)['sub'])
    return token


async def sync(client, token, steps, date=None):
    return await client.post('/activity/sync', headers=auth_headers(token), json={
        'local_date': date or local_today().isoformat(), 'eligible_steps': steps,
        'source': 'test-sensor', 'sync_key': str(uuid.uuid4()),
    })


@pytest.mark.asyncio
async def test_other_account_cannot_register_or_login_on_owned_device(client, accounts):
    first = await signed_in(client, accounts, 'a' * 64)
    other_email = address(accounts)
    second = await register_verified(client, json={'email': other_email, 'password': 'device-password-123'})
    other = second.json()['access_token']
    attempt = await client.post('/auth/login', headers={'X-Device-ID': 'a' * 64}, json={'email': other_email, 'password': 'device-password-123'})
    assert attempt.status_code == 409 and 'linked to another active account' in attempt.json()['detail']
    assert (await google(client, other_email, 'a' * 64)).status_code == 409
    third_email = address(accounts)
    registration = await client.post('/auth/register', headers={'X-Device-ID': 'a' * 64}, json={'email': third_email, 'password': 'device-password-123'})
    assert registration.status_code == 409
    assert (await client.get('/auth/me', headers=auth_headers(first))).status_code == 200
    assert (await client.get('/auth/me', headers=auth_headers(other))).status_code == 200
    assert (await client.get('/points/balance', headers={'Authorization': f'Bearer {other}', 'X-Device-ID': 'a' * 64})).status_code == 401
    async with get_session_factory()() as s:
        assert await s.scalar(select(User.id).where(User.email == third_email)) is None


@pytest.mark.asyncio
async def test_deactivation_releases_phone_without_repeating_steps_or_sharing_wallet(client, accounts):
    key = secrets.token_hex(32)
    first = await signed_in(client, accounts, key)
    assert (await sync(client, first, 1000)).json()['points_awarded'] == 10
    offer = await _create_offer(points_cost=5)
    accounts['offers'].append(offer)
    voucher = await client.post(f'/offers/{offer}/redeem', headers=auth_headers(first))
    assert voucher.status_code == 201
    assert (await client.delete('/users/me', headers=auth_headers(first))).status_code == 204
    second = await signed_in(client, accounts, key)
    assert (await client.get('/vouchers', headers=auth_headers(second))).json() == []
    assert (await sync(client, second, 1000)).json()['points_awarded'] == 0
    assert (await sync(client, second, 1099)).json()['points_awarded'] == 0
    assert (await sync(client, second, 1100)).json()['points_awarded'] == 1
    assert (await client.get('/auth/me', headers=auth_headers(first))).status_code == 401
    first_id = decode_access_claims(first)['sub']
    async with get_session_factory()() as s:
        assert (await s.get(User, first_id)).status == UserStatus.DELETED
        assert (await s.get(User, first_id)).email == f'deleted-{first_id}@deleted.invalid'
        assert (await s.scalar(select(Voucher).where(Voucher.user_id == first_id))).status.value == 'CANCELLED'
        assert await s.scalar(select(func.count(Voucher.id)).where(Voucher.user_id == first_id)) == 1
        assert await s.scalar(select(func.sum(PointsLedger.delta)).where(PointsLedger.user_id == first_id)) == 5
    await client.delete('/users/me', headers=auth_headers(second))
    third = await signed_in(client, accounts, key)
    assert (await sync(client, third, 1100)).json()['points_awarded'] == 0
    assert (await sync(client, third, 1200)).json()['points_awarded'] == 1
    async with get_session_factory()() as s:
        day = await s.get(DeviceActivityDaily, (key, local_today().isoformat()))
        assert day.eligible_steps == 1200


@pytest.mark.asyncio
async def test_simultaneous_first_logins_bind_exactly_one_account(client, accounts):
    emails = [address(accounts), address(accounts)]
    key = secrets.token_hex(32)
    results = await asyncio.gather(*[google(client, email, key) for email in emails])
    assert sorted(r.status_code for r in results) == [200, 409]
    async with get_session_factory()() as s:
        assert await s.scalar(select(func.count(User.id)).where(User.email.in_(emails))) == 1


@pytest.mark.asyncio
async def test_simultaneous_email_verifications_cannot_claim_two_accounts(client, accounts):
    tickets = []
    for _ in range(2):
        email = address(accounts)
        response = await client.post('/auth/register', json={'email': email, 'password': 'device-password-123'})
        assert response.status_code == 201
        tickets.append({'verification_token': response.json()['verification_token'], 'code': client.verification_emails[email]})
    results = await asyncio.gather(*[client.post('/auth/verify-email', json=body) for body in tickets])
    assert sorted(r.status_code for r in results) == [200, 409]
    async with get_session_factory()() as s:
        assert await s.scalar(select(func.count(User.id)).where(User.email.in_(accounts['emails']), User.email_verified_at.is_not(None))) == 1


@pytest.mark.asyncio
async def test_missing_device_old_tokens_and_changed_device_cannot_bypass_gate(client, accounts):
    token = await signed_in(client, accounts, secrets.token_hex(32))
    claims = decode_access_claims(token)
    legacy = create_access_token(claims['sub'], extra_claims={'ver': claims['ver']})
    assert (await client.get('/points/balance', headers={**auth_headers(token), 'Authorization': f'Bearer {legacy}'})).status_code == 401
    client.headers.pop('X-Device-ID')
    assert (await client.get('/points/balance', headers={'Authorization': f'Bearer {token}'})).status_code == 426
    assert (await google(client, address(accounts), 'invalid')).status_code == 400
    assert (await client.post('/auth/google', json={'id_token': 'device-google:' + address(accounts)})).status_code == 426


@pytest.mark.asyncio
async def test_verification_ticket_is_bound_to_its_phone(client, accounts):
    email = address(accounts)
    registration = await client.post('/auth/register', json={'email': email, 'password': 'device-password-123'})
    wrong_phone = await client.post('/auth/verify-email', headers={'X-Device-ID': secrets.token_hex(32)}, json={
        'verification_token': registration.json()['verification_token'], 'code': client.verification_emails[email],
    })
    assert wrong_phone.status_code == 400


@pytest.mark.asyncio
async def test_legacy_credits_seed_consumption_before_first_device_login(client, accounts):
    email = address(accounts)
    async with get_session_factory()() as s:
        user = User(id=str(uuid.uuid4()), email=email, password_hash=hash_password('legacy-password-123'), email_verified_at=datetime.now(timezone.utc))
        s.add(user)
        day = ActivityDaily(id=str(uuid.uuid4()), user_id=user.id, local_date=local_today().isoformat(), eligible_steps=1000, source='legacy', sync_key=str(uuid.uuid4()))
        s.add(day)
        s.add(PointsLedger(id=str(uuid.uuid4()), user_id=user.id, delta=10, reason=LedgerReason.STEP_EARN, ref_type='activity_daily', ref_id=day.id))
        await s.commit()
    key = secrets.token_hex(32)
    login = await client.post('/auth/login', headers={'X-Device-ID': key}, json={'email': email, 'password': 'legacy-password-123'})
    assert login.status_code == 200
    token = login.json()['access_token']
    result = (await sync(client, token, 1000)).json()
    assert result['points_awarded'] == 0 and result['balance'] == 10
    await client.delete('/users/me', headers=auth_headers(token))
    replacement = await signed_in(client, accounts, key)
    assert (await sync(client, replacement, 1000)).json()['points_awarded'] == 0


@pytest.mark.asyncio
async def test_suspended_account_keeps_device_reservation(client, accounts):
    key = secrets.token_hex(32)
    first = await signed_in(client, accounts, key)
    async with get_session_factory()() as s:
        user = await s.get(User, decode_access_claims(first)['sub'])
        user.status = UserStatus.SUSPENDED
        await s.commit()
    assert (await google(client, address(accounts), key)).status_code == 409


@pytest.mark.asyncio
async def test_deactivation_race_cannot_double_award_the_same_walk(client, accounts):
    key = secrets.token_hex(32)
    first = await signed_in(client, accounts, key)
    first_id = decode_access_claims(first)['sub']
    synced, deactivated = await asyncio.gather(sync(client, first, 1000), client.delete('/users/me', headers=auth_headers(first)))
    assert deactivated.status_code == 204
    assert synced.status_code in (200, 401), synced.text
    second = await signed_in(client, accounts, key)
    assert (await sync(client, second, 1000)).status_code == 200
    ids = [first_id, decode_access_claims(second)['sub']]
    async with get_session_factory()() as s:
        assert await s.scalar(select(func.sum(PointsLedger.delta)).where(PointsLedger.user_id.in_(ids), PointsLedger.reason == LedgerReason.STEP_EARN)) == 10


@pytest.mark.asyncio
async def test_device_daily_cap_survives_transfer_but_days_are_independent(client, accounts):
    key = secrets.token_hex(32)
    first = await signed_in(client, accounts, key)
    yesterday = (local_today() - timedelta(days=1)).isoformat()
    assert (await sync(client, first, 25000, yesterday)).json()['points_awarded'] == 200
    await client.delete('/users/me', headers=auth_headers(first))
    second = await signed_in(client, accounts, key)
    assert (await sync(client, second, 25000, yesterday)).json()['points_awarded'] == 0
    assert (await sync(client, second, 1000)).json()['points_awarded'] == 10
