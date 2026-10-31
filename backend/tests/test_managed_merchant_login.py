"""Admin-issued store IDs work without a mailbox; customer proof is preserved."""
import secrets
import uuid

import pytest
from sqlalchemy import select

from app.config import get_settings
from app.db.models import User, UserStatus
from app.db.postgres import get_session_factory
from app.services.email_verification import requires_email_verification
from tests.auth_helpers import auth_headers


PASSWORD = 'store-test-password-123'


async def create_store(client, domain='stepsyapp.com'):
    email = f'store-{uuid.uuid4().hex}@{domain}'
    response = await client.post('/admin/partners', json={
        'name': 'Managed login test store', 'email': email, 'password': PASSWORD,
    })
    assert response.status_code == 201, response.text
    return email, response.json()['id']


@pytest.mark.asyncio
async def test_managed_merchant_login_and_protected_pos_without_smtp(admin_client, monkeypatch):
    email, partner_id = await create_store(admin_client)
    monkeypatch.setattr(get_settings(), 'smtp_host', '')
    wrong = await admin_client.post('/auth/login', json={'email': email, 'password': 'wrong'})
    assert wrong.status_code == 401
    response = await admin_client.post('/auth/login', json={'email': email.upper(), 'password': PASSWORD})
    assert response.status_code == 200, response.text
    assert response.json()['role'] == 'MERCHANT'
    assert 'verification_token' not in response.json()
    headers = auth_headers(response.json()['access_token'])
    me = await admin_client.get('/auth/me', headers=headers)
    assert me.status_code == 200, me.text
    assert me.json()['email_verified'] is False  # No fabricated mailbox proof.
    info = await admin_client.get('/partner/v1/info', headers=headers)
    assert info.status_code == 200, info.text
    assert info.json()['partner_id'] == partner_id
    assert (await admin_client.get('/partner/v1/redemptions', headers=headers)).status_code == 200
    assert not admin_client.verification_emails

    # An inactive store still cannot operate; suspended users cannot log in.
    assert (await admin_client.patch(f'/admin/partners/{partner_id}', json={'status': 'INACTIVE'})).status_code == 200
    assert (await admin_client.get('/partner/v1/info', headers=headers)).status_code == 403
    async with get_session_factory()() as session:
        user = await session.scalar(select(User).where(User.email == email))
        user.status = UserStatus.SUSPENDED
        await session.commit()
    assert (await admin_client.post('/auth/login', json={'email': email, 'password': PASSWORD})).status_code == 403


@pytest.mark.asyncio
async def test_admin_reset_and_email_changes_apply_managed_login_policy(admin_client):
    email, partner_id = await create_store(admin_client)
    response = await admin_client.post('/auth/login', json={'email': email, 'password': PASSWORD})
    old_headers = auth_headers(response.json()['access_token'])
    password = 'replacement-store-password-123'
    reset = await admin_client.post(f'/admin/partners/{partner_id}/reset-password', json={'password': password})
    assert reset.status_code == 200, reset.text
    assert (await admin_client.get('/partner/v1/info', headers=old_headers)).status_code == 401
    assert (await admin_client.post('/auth/login', json={'email': email, 'password': PASSWORD})).status_code == 401
    assert (await admin_client.post('/auth/login', json={'email': email, 'password': password})).json()['access_token']

    # Real merchant mailboxes still require proof after the admin edits an ID.
    external = f'merchant-{uuid.uuid4().hex}@example.com'
    assert (await admin_client.patch(f'/admin/partners/{partner_id}', json={'email': external})).status_code == 200
    challenge = await admin_client.post('/auth/login', json={'email': external, 'password': password})
    assert challenge.json()['verification_required'] is True
    assert 'access_token' not in challenge.json()
    assert external in admin_client.verification_emails

    # Existing stores and edits back to the managed domain work without migrations.
    assert (await admin_client.patch(f'/admin/partners/{partner_id}', json={'email': email})).status_code == 200
    assert (await admin_client.post('/auth/login', json={'email': email, 'password': password})).json()['access_token']


@pytest.mark.asyncio
async def test_public_signup_cannot_bypass_verification_using_managed_domain(client):
    email = f'customer-{uuid.uuid4().hex}@stepsyapp.com'
    registered = await client.post('/auth/register', json={'email': email, 'password': PASSWORD})
    assert registered.status_code == 201, registered.text
    assert registered.json()['verification_required'] is True
    login = await client.post('/auth/login', json={'email': email, 'password': PASSWORD})
    assert login.json()['verification_required'] is True
    assert 'access_token' not in login.json()


@pytest.mark.parametrize('role,partner_id,email,needs_code', [
    ('MERCHANT', 'store-id', 'broadway@stepsyapp.com', False),
    ('MERCHANT', 'store-id', 'broadway@STEPSYAPP.COM', False),
    ('USER', 'store-id', 'broadway@stepsyapp.com', True),
    ('MERCHANT', None, 'broadway@stepsyapp.com', True),
    ('MERCHANT', 'store-id', 'broadway@branch.stepsyapp.com', True),
    ('MERCHANT', 'store-id', 'broadway@stepsyapp.com.example.com', True),
    ('MERCHANT', 'store-id', 'broadway@otherstepsyapp.com', True),
])
def test_only_exact_domain_store_linked_merchants_are_exempt(role, partner_id, email, needs_code):
    assert requires_email_verification(User(role=role, partner_id=partner_id, email=email)) is needs_code


@pytest.mark.asyncio
async def test_managed_merchant_still_honors_device_binding(admin_client):
    email, _ = await create_store(admin_client)
    # Bind this phone to a different store first, then reject cross-account login.
    other_email, _ = await create_store(admin_client)
    assert (await admin_client.post('/auth/login', json={'email': other_email, 'password': PASSWORD})).status_code == 200
    assert (await admin_client.post('/auth/login', json={'email': email, 'password': PASSWORD})).status_code == 409
    admin_client.headers['X-Device-ID'] = secrets.token_hex(32)
    assert (await admin_client.post('/auth/login', json={'email': email, 'password': PASSWORD})).json()['access_token']
