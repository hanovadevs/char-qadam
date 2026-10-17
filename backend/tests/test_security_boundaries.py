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
async def test_recovery_unavailable_without_delivery_and_no_tokens_leak(client, monkeypatch):
    from app.config import get_settings
    monkeypatch.setattr(get_settings(), 'smtp_host', '')
    response = await client.post('/auth/forgot-password', json={'email': 'anyone@example.com'})
    assert response.status_code == 503
    assert 'reset_token' not in response.json()


@pytest.mark.asyncio
async def test_rate_limit_bypass_header_ignored_outside_tests(client, monkeypatch):
    from app.config import get_settings
    monkeypatch.setattr(get_settings(), 'environment', 'development')
    statuses = [(await client.post('/admin/auth/login', json={'email': 'wrong', 'password': 'wrong'})).status_code for _ in range(11)]
    assert statuses[-1] == 429


@pytest.mark.asyncio
async def test_offer_terms_reject_negative_cost_and_invalid_percent(admin_client):
    base = {'partner_id': 'unused', 'title': 'Test reward', 'discount_type': 'PERCENT', 'discount_value': 10, 'points_cost': 10}
    for invalid in [{'points_cost': -100}, {'inventory': -1}, {'discount_value': 101}]:
        response = await admin_client.post('/admin/offers', json={**base, **invalid})
        assert response.status_code == 422, response.text


@pytest.mark.asyncio
async def test_admin_can_clear_inventory_limit(admin_client):
    from app.db.models import Partner, Offer, DiscountType
    from app.db.postgres import get_session_factory
    from sqlalchemy import delete
    import uuid
    partner_id, offer_id = str(uuid.uuid4()), str(uuid.uuid4())
    async with get_session_factory()() as session:
        session.add(Partner(id=partner_id, name='Inventory test'))
        session.add(Offer(id=offer_id, partner_id=partner_id, title='Limited reward', discount_type=DiscountType.PERCENT, discount_value=10, points_cost=10, inventory=5))
        await session.commit()
    try:
        zero = await admin_client.patch(f'/admin/offers/{offer_id}', json={'inventory': 0})
        assert zero.status_code == 200
        async with get_session_factory()() as session:
            assert (await session.get(Offer, offer_id)).inventory == 0
        unlimited = await admin_client.patch(f'/admin/offers/{offer_id}', json={'inventory': None})
        assert unlimited.status_code == 200
        async with get_session_factory()() as session:
            assert (await session.get(Offer, offer_id)).inventory is None
        negative = await admin_client.patch(f'/admin/offers/{offer_id}', json={'points_cost': -1})
        assert negative.status_code == 422
    finally:
        async with get_session_factory()() as session:
            await session.execute(delete(Offer).where(Offer.id == offer_id))
            await session.execute(delete(Partner).where(Partner.id == partner_id))
            await session.commit()
