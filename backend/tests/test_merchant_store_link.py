"""A merchant role alone cannot create a usable POS session."""
import uuid

import pytest
from sqlalchemy import select

from app.db.models import User
from app.db.postgres import get_session_factory
from app.services.local_date import local_today
from tests.auth_helpers import auth_headers, register_verified

PASSWORD = 'preserve-store-password-123'


async def account(client):
    email = f'link-{uuid.uuid4().hex}@example.com'
    response = await register_verified(client, json={'email': email, 'password': PASSWORD})
    return email, response.json()['user']['id'], response.json()['access_token']


@pytest.mark.asyncio
async def test_unlinked_merchant_has_clear_store_error_instead_of_expired_session(admin_client):
    email, user_id, token = await account(admin_client)
    async with get_session_factory()() as session:
        user = await session.get(User, user_id)
        user.role = 'MERCHANT'  # Reproduce an older admin-created invalid role.
        await session.commit()
    login = await admin_client.post('/auth/login', json={'email': email, 'password': PASSWORD})
    assert login.status_code == 403 and 'No store is linked' in login.json()['detail']
    assert 'access_token' not in login.json()
    for path in ['/partner/v1/info', '/partner/v1/redemptions']:
        denied = await admin_client.get(path, headers=auth_headers(token))
        assert denied.status_code == 403 and 'No store is linked' in denied.json()['detail']
    assert (await admin_client.get('/auth/me', headers=auth_headers(token))).status_code == 200


@pytest.mark.asyncio
async def test_create_store_links_existing_identity_without_resetting_credentials_or_history(admin_client):
    email, user_id, token = await account(admin_client)
    earned = await admin_client.post('/activity/sync', headers=auth_headers(token), json={
        'local_date': local_today().isoformat(), 'eligible_steps': 1000,
        'source': 'test', 'sync_key': str(uuid.uuid4()),
    })
    assert earned.status_code == 200 and earned.json()['balance'] == 10
    async with get_session_factory()() as session:
        user = await session.get(User, user_id)
        before = (user.password_hash, user.email_verified_at, user.auth_version)
        user.google_subject = 'stable-' + user_id
        await session.commit()
    # Existing customer access cannot operate the POS even with a valid session.
    assert (await admin_client.get('/partner/v1/info', headers=auth_headers(token))).status_code == 403
    body = {'name': 'Linked store', 'email': email, 'use_existing_account': True}
    response = await admin_client.post('/admin/partners', json=body)
    assert response.status_code == 201, response.text
    partner_id = response.json()['id']
    async with get_session_factory()() as session:
        user = await session.get(User, user_id)
        assert user.role == 'MERCHANT' and user.partner_id == partner_id
        assert (user.password_hash, user.email_verified_at, user.auth_version) == (*before[:2], before[2] + 1)
        assert user.google_subject == 'stable-' + user_id
        assert len((await session.scalars(select(User).where(User.email == email))).all()) == 1
    assert (await admin_client.get('/auth/me', headers=auth_headers(token))).status_code == 401
    login = await admin_client.post('/auth/login', json={'email': email, 'password': PASSWORD})
    assert login.status_code == 200, login.text
    assert login.json()['user']['id'] == user_id
    headers = auth_headers(login.json()['access_token'])
    info = await admin_client.get('/partner/v1/info', headers=headers)
    assert info.status_code == 200 and info.json()['partner_id'] == partner_id
    assert (await admin_client.get('/points/balance', headers=headers)).json()['balance'] == 10
    directory = await admin_client.get('/admin/users', params={'search': email})
    assert directory.json()[0]['partner_id'] == partner_id
    # Relinking a managed account must never silently take it from its store.
    assert (await admin_client.post('/admin/partners', json=body)).status_code == 409


@pytest.mark.asyncio
async def test_link_is_explicit_and_never_overwrites_an_existing_password(admin_client):
    email, user_id, _ = await account(admin_client)
    body = {'name': 'Explicit link', 'email': email}
    assert (await admin_client.post('/admin/partners', json={**body, 'password': PASSWORD})).status_code == 409
    assert (await admin_client.post('/admin/partners', json={**body, 'use_existing_account': True, 'password': 'replacement-password'})).status_code == 422
    assert (await admin_client.post('/admin/partners', json={**body, 'email': f'missing-{uuid.uuid4().hex}@example.com', 'use_existing_account': True})).status_code == 404
    assert (await admin_client.patch(f'/admin/users/{user_id}/status', json={'status': 'SUSPENDED'})).status_code == 200
    assert (await admin_client.post('/admin/partners', json={**body, 'use_existing_account': True})).status_code == 409


@pytest.mark.asyncio
async def test_admin_cannot_assign_a_merchant_role_without_a_store(admin_client):
    email, user_id, token = await account(admin_client)
    changed = await admin_client.patch(f'/admin/users/{user_id}', json={'role': 'MERCHANT'})
    assert changed.status_code == 409 and 'linked store' in changed.json()['detail']
    profile = await admin_client.get('/auth/me', headers=auth_headers(token))
    assert profile.status_code == 200 and profile.json()['role'] == 'USER'
