import secrets
import uuid
import pytest

from sqlalchemy import select
from app.db.models import DeviceBinding
from app.db.postgres import get_session_factory
from tests.auth_helpers import auth_headers, register_verified
from app.services.local_date import local_today


async def merchant(client):
    email = f'slot-{uuid.uuid4().hex}@stepsyapp.com'
    response = await client.post('/admin/partners', json={'name': 'Device slot store', 'email': email, 'password': 'merchant-slot-password'})
    assert response.status_code == 201, response.text
    return email


async def login_merchant(client, email, device):
    return await client.post('/auth/login', headers={'X-Device-ID': device}, json={'email': email, 'password': 'merchant-slot-password'})


@pytest.mark.asyncio
async def test_one_customer_and_one_merchant_can_share_phone_without_either_session_being_replaced(admin_client):
    customer = await register_verified(admin_client, json={'email': f'personal-{uuid.uuid4().hex}@example.com', 'password': 'personal-password'})
    customer_token = customer.json()['access_token']
    device = admin_client.headers['X-Device-ID']
    first = await login_merchant(admin_client, await merchant(admin_client), device)
    assert first.status_code == 200, first.text
    merchant_token = first.json()['access_token']
    assert (await admin_client.get('/auth/me', headers=auth_headers(customer_token))).status_code == 200
    assert (await admin_client.get('/partner/v1/info', headers=auth_headers(merchant_token))).status_code == 200
    assert (await admin_client.get('/partner/v1/info', headers=auth_headers(customer_token))).status_code == 403
    blocked = await login_merchant(admin_client, await merchant(admin_client), device)
    assert blocked.status_code == 409 and 'merchant account' in blocked.json()['detail']
    second_customer = await register_verified(admin_client, json={'email': f'other-{uuid.uuid4().hex}@example.com', 'password': 'personal-password'})
    assert (await admin_client.post('/auth/login', headers={'X-Device-ID': device}, json={
        'email': second_customer.json()['user']['email'], 'password': 'personal-password'})).status_code == 409
    # A merchant cannot create a second source of walking credits on the phone.
    sync = await admin_client.post('/activity/sync', headers=auth_headers(merchant_token), json={
        'local_date': local_today().isoformat(), 'eligible_steps': 1000, 'source': 'test', 'sync_key': str(uuid.uuid4())})
    assert sync.status_code == 403
    assert (await admin_client.get('/auth/me', headers=auth_headers(merchant_token))).status_code == 200


@pytest.mark.asyncio
async def test_deactivation_releases_only_its_own_slot(admin_client):
    device = secrets.token_hex(32)
    merchant_login = await login_merchant(admin_client, await merchant(admin_client), device)
    assert merchant_login.status_code == 200
    merchant_token = merchant_login.json()['access_token']
    admin_client.headers['X-Device-ID'] = device
    response = await admin_client.post('/auth/register', json={'email': f'share-{uuid.uuid4().hex}@example.com', 'password': 'personal-password'})
    assert response.status_code == 201, response.text
    verified = await admin_client.post('/auth/verify-email', json={'verification_token': response.json()['verification_token'], 'code': admin_client.verification_emails[response.json()['email']]})
    customer_token = verified.json()['access_token']
    assert (await admin_client.delete('/users/me', headers=auth_headers(merchant_token))).status_code == 204
    assert (await admin_client.get('/auth/me', headers=auth_headers(customer_token))).status_code == 200
    async with get_session_factory()() as session:
        binding = await session.get(DeviceBinding, device)
        assert binding.user_id == verified.json()['user']['id'] and binding.merchant_user_id is None
    new_merchant = await login_merchant(admin_client, await merchant(admin_client), device)
    assert new_merchant.status_code == 200
    assert (await admin_client.delete('/users/me', headers=auth_headers(customer_token))).status_code == 204
    assert (await admin_client.get('/partner/v1/info', headers=auth_headers(new_merchant.json()['access_token']))).status_code == 200
