import asyncio
from datetime import datetime, timedelta, timezone
import uuid

import pytest
from sqlalchemy import select, update

from app.config import get_settings
from app.db.models import User
from app.db.postgres import get_session_factory
from app.services.security import create_access_token


async def register(client):
    email = f'verify_{uuid.uuid4().hex}@example.com'
    response = await client.post('/auth/register', json={'email': email, 'password': 'strong-password-123'})
    assert response.status_code == 201, response.text
    return email, response.json()['verification_token']


async def verify(client, token, code):
    return await client.post('/auth/verify-email', json={'verification_token': token, 'code': code})


@pytest.mark.asyncio
async def test_registration_requires_mailbox_and_single_use_code(client):
    email, ticket = await register(client)
    code = client.verification_emails[email]
    async with get_session_factory()() as session:
        user = await session.scalar(select(User).where(User.email == email))
        assert user.email_verified_at is None
        assert user.verification_code_hash != code
        legacy_token = create_access_token(user.id)
    for token in [ticket, legacy_token]:
        assert (await client.get('/auth/me', headers={'Authorization': f'Bearer {token}'})).status_code == 401
        assert (await client.get('/points/balance', headers={'Authorization': f'Bearer {token}'})).status_code == 401
    login = await client.post('/auth/login', json={'email': email, 'password': 'strong-password-123'})
    assert login.json()['verification_required'] is True
    assert 'access_token' not in login.json()
    assert client.verification_emails[email] == code  # repeated login doesn't flood the inbox
    accepted = await verify(client, ticket, code)
    assert accepted.status_code == 200, accepted.text
    me = await client.get('/auth/me', headers={'Authorization': f"Bearer {accepted.json()['access_token']}"})
    assert me.json()['email_verified'] is True
    assert (await verify(client, ticket, code)).status_code == 400
    assert (await client.post('/auth/login', json={'email': email, 'password': 'strong-password-123'})).json()['access_token']


@pytest.mark.asyncio
async def test_codes_have_durable_attempt_limits_and_resend_cooldown(client):
    email, ticket = await register(client)
    code = client.verification_emails[email]
    wrong = '000000' if code != '000000' else '111111'
    for _ in range(5):
        assert (await verify(client, ticket, wrong)).status_code == 400
    assert (await verify(client, ticket, code)).status_code == 429
    assert (await client.post('/auth/resend-verification', json={'verification_token': ticket})).status_code == 429
    async with get_session_factory()() as session:
        await session.execute(update(User).where(User.email == email).values(verification_sent_at=datetime.now(timezone.utc) - timedelta(seconds=61)))
        await session.commit()
    resent = await client.post('/auth/resend-verification', json={'verification_token': ticket})
    assert resent.status_code == 200
    assert (await verify(client, resent.json()['verification_token'], client.verification_emails[email])).status_code == 200


@pytest.mark.asyncio
async def test_expired_code_and_wrong_purpose_token_rejected(client):
    email, ticket = await register(client)
    async with get_session_factory()() as session:
        user = await session.scalar(select(User).where(User.email == email))
        user.verification_expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        token = create_access_token(user.id)
        await session.commit()
    assert (await verify(client, ticket, client.verification_emails[email])).status_code == 400
    assert (await verify(client, token, client.verification_emails[email])).status_code == 400


@pytest.mark.asyncio
async def test_concurrent_verification_issues_one_session(client):
    email, ticket = await register(client)
    responses = await asyncio.gather(*[verify(client, ticket, client.verification_emails[email]) for _ in range(3)])
    assert sorted(r.status_code for r in responses) == [200, 400, 400]


@pytest.mark.asyncio
@pytest.mark.parametrize('delivery_failure', [False, True])
async def test_unavailable_email_never_creates_usable_account(client, monkeypatch, delivery_failure):
    email = f'undelivered_{uuid.uuid4().hex}@example.com'
    if delivery_failure:
        def fail(*args):
            raise RuntimeError('Private provider diagnostic')
        monkeypatch.setattr('app.services.email_verification.send_verification_email', fail)
    else:
        monkeypatch.setattr(get_settings(), 'smtp_host', '')
    response = await client.post('/auth/register', json={'email': email, 'password': 'strong-password-123'})
    assert response.status_code == 503
    assert 'Private provider' not in response.text
    async with get_session_factory()() as session:
        assert await session.scalar(select(User).where(User.email == email)) is None


@pytest.mark.asyncio
async def test_google_mailbox_proof_removes_unverified_planted_password(client, monkeypatch):
    email, _ = await register(client)
    async def google(*args, **kwargs):
        return {'email': email, 'sub': 'subject-' + email, 'authoritative_email': True}
    monkeypatch.setattr('app.routers.auth.verify_google_id_token', google)
    google_login = await client.post('/auth/google', json={'id_token': 'valid-google-token'})
    assert google_login.status_code == 200
    assert google_login.json()['access_token']
    planted = await client.post('/auth/login', json={'email': email, 'password': 'strong-password-123'})
    assert planted.status_code == 401


@pytest.mark.asyncio
async def test_google_third_party_email_needs_code_before_binding(client, monkeypatch):
    email, _ = await register(client)
    async def google(*args, **kwargs):
        return {'email': email, 'sub': 'third-party-' + email, 'authoritative_email': False}
    monkeypatch.setattr('app.routers.auth.verify_google_id_token', google)
    response = await client.post('/auth/google', json={'id_token': 'valid-google-token'})
    assert 'access_token' not in response.json()
    async with get_session_factory()() as session:
        assert (await session.scalar(select(User).where(User.email == email))).google_subject is None
    accepted = await verify(client, response.json()['verification_token'], client.verification_emails[email])
    assert accepted.status_code == 200
    again = await client.post('/auth/google', json={'id_token': 'valid-google-token'})
    assert again.json()['access_token']
    assert (await client.post('/auth/login', json={'email': email, 'password': 'strong-password-123'})).status_code == 401


@pytest.mark.asyncio
async def test_google_identity_survives_email_change(client, monkeypatch):
    email = f'google_{uuid.uuid4().hex}@gmail.com'
    identity = {'email': email, 'sub': 'stable-' + email, 'authoritative_email': True}
    async def google(*args, **kwargs):
        return identity
    monkeypatch.setattr('app.routers.auth.verify_google_id_token', google)
    first = await client.post('/auth/google', json={'id_token': 'valid-google-token'})
    identity['email'] = f'changed_{uuid.uuid4().hex}@gmail.com'
    second = await client.post('/auth/google', json={'id_token': 'valid-google-token'})
    profiles = [(await client.get('/auth/me', headers={'Authorization': f"Bearer {r.json()['access_token']}"})).json() for r in [first, second]]
    assert profiles[0]['id'] == profiles[1]['id']


@pytest.mark.asyncio
@pytest.mark.parametrize('merchant', [False, True])
async def test_admin_email_change_revokes_old_proof_and_sessions(admin_client, merchant):
    from app.db.models import Partner
    from app.services.security import create_password_reset_token
    from tests.auth_helpers import register_verified
    email = f'old_{uuid.uuid4().hex}@example.com'
    new_email = f'new_{uuid.uuid4().hex}@example.com'
    registered = await register_verified(admin_client, json={'email': email, 'password': 'strong-password-123'})
    token = registered.json()['access_token']
    async with get_session_factory()() as session:
        user = await session.scalar(select(User).where(User.email == email))
        user.google_subject = 'binding-' + email
        previous_reset = create_password_reset_token(user.id, user.password_hash, email=email, auth_version=user.auth_version)
        if merchant:
            partner = Partner(id=str(uuid.uuid4()), name='Verification merchant', email=email)
            session.add(partner)
            await session.flush()
            user.partner_id = partner.id
            user.role = 'MERCHANT'
        path = f'/admin/partners/{user.partner_id}' if merchant else f'/admin/users/{user.id}'
        user_id = user.id
        await session.commit()
    changed = await admin_client.patch(path, json={'email': new_email})
    assert changed.status_code == 200, changed.text
    assert (await admin_client.post('/auth/reset-password', json={
        'reset_token': previous_reset, 'new_password': 'another-password-123',
    })).status_code == 400
    assert (await admin_client.get('/auth/me', headers={'Authorization': f'Bearer {token}'})).status_code == 401
    async with get_session_factory()() as session:
        user = await session.get(User, user_id)
        assert user.email_verified_at is None
        assert user.google_subject is None
        assert user.verification_code_hash is None
    login = await admin_client.post('/auth/login', json={'email': new_email, 'password': 'strong-password-123'})
    assert login.json()['verification_required'] is True


@pytest.mark.parametrize('use_ssl', [False, True])
def test_verification_mail_uses_authenticated_encrypted_transport(monkeypatch, use_ssl):
    from unittest.mock import MagicMock
    from app.services.email import send_verification_email
    settings = get_settings().model_copy(update={
        'smtp_host': 'smtp.test', 'smtp_from': 'Stepsy <team@example.com>',
        'smtp_port': 465 if use_ssl else 587, 'smtp_use_ssl': use_ssl,
        'smtp_username': 'team@example.com', 'smtp_password': 'private-test-password',
    })
    transport = MagicMock()
    server = transport.return_value
    monkeypatch.setattr('app.services.email.smtplib.' + ('SMTP_SSL' if use_ssl else 'SMTP'), transport)
    send_verification_email('runner@example.com', '123456', settings)
    server.login.assert_called_once_with('team@example.com', 'private-test-password')
    if not use_ssl:
        server.starttls.assert_called_once()
    message = server.send_message.call_args.args[0]
    assert message['To'] == 'runner@example.com'
    assert '123456' in message.get_content()
    assert 'private-test-password' not in message.as_string()
