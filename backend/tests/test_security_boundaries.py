from unittest.mock import AsyncMock, patch

import pytest
from jose import JWTError

from app.services.security import (
    create_access_token, create_password_reset_token,
    decode_access_token, verify_google_id_token,
)


@pytest.mark.asyncio
async def test_admin_routes_reject_missing_customer_and_reset_tokens(client):
    tokens = [None, create_access_token('customer'), create_password_reset_token('admin_user_root', 'hash')]
    for token in tokens:
        headers = {'Authorization': f'Bearer {token}'} if token else {}
        for method, path in [('GET', '/admin/auth/me'), ('GET', '/admin/users'), ('POST', '/admin/partners'), ('DELETE', '/admin/users/any')]:
            response = await client.request(method, path, headers=headers)
            assert response.status_code in (401, 403), (path, response.text)


@pytest.mark.asyncio
async def test_admin_login_and_profile(client):
    from app.config import get_settings
    settings = get_settings()
    login = await client.post('/admin/auth/login', json={'email': settings.admin_email, 'password': settings.admin_password})
    assert login.status_code == 200
    profile = await client.get('/admin/auth/me', headers={'Authorization': f"Bearer {login.json()['access_token']}"})
    assert profile.status_code == 200
    assert profile.json()['role'] == 'ADMIN'


def test_reset_token_cannot_authenticate_as_access_token():
    with pytest.raises(JWTError):
        decode_access_token(create_password_reset_token('customer', 'hash'))


@pytest.mark.asyncio
async def test_fabricated_google_token_rejected():
    with pytest.raises(ValueError):
        await verify_google_id_token('mock_google_token:someone@example.com', client_id='app-id')


@pytest.mark.asyncio
async def test_google_requires_configured_audience():
    with pytest.raises(ValueError):
        await verify_google_id_token('anything')


@pytest.mark.asyncio
@pytest.mark.parametrize('invalid', [{'aud': 'other'}, {'email_verified': 'false'}, {'iss': 'attacker'}])
async def test_google_rejects_invalid_claims(invalid):
    data = {'aud': 'app-id', 'email': 'user@example.com', 'email_verified': 'true', 'iss': 'https://accounts.google.com', 'sub': '123', **invalid}
    response = type('Response', (), {'status_code': 200, 'json': lambda self: data})()
    with patch('app.services.security.httpx.AsyncClient') as factory:
        factory.return_value.__aenter__.return_value.get = AsyncMock(return_value=response)
        with pytest.raises(ValueError):
            await verify_google_id_token('signed-token', client_id='app-id')


@pytest.mark.asyncio
async def test_recovery_unavailable_without_delivery_and_no_tokens_leak(client):
    response = await client.post('/auth/forgot-password', json={'email': 'anyone@example.com'})
    assert response.status_code == 503
    assert 'reset_token' not in response.json()


@pytest.mark.asyncio
async def test_rate_limit_bypass_header_ignored_outside_tests(client, monkeypatch):
    from app.config import get_settings
    monkeypatch.setattr(get_settings(), 'environment', 'development')
    statuses = [(await client.post('/admin/auth/login', json={'email': 'wrong', 'password': 'wrong'})).status_code for _ in range(11)]
    assert statuses[-1] == 429
