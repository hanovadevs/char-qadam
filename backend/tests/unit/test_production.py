"""Regression checks that do not connect to any database."""
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from jwt import InvalidTokenError as JWTError
from pydantic import ValidationError

from app.config import Settings, get_settings
from app.deps import get_current_admin
from app.middleware.rate_limiter import RateLimiterMiddleware
from app.routers import admin
from app.services.security import (
    create_access_token, create_password_reset_token, decode_access_token,
    decode_password_reset_token, verify_google_id_token,
)


@pytest.fixture(autouse=True)
def settings(monkeypatch):
    monkeypatch.setenv('ENVIRONMENT', 'test')
    monkeypatch.setenv('JWT_SECRET', 'unit-test-secret-with-at-least-32-characters')
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_production_rejects_default_admin_and_wildcard():
    kwargs = dict(_env_file=None, environment='production', jwt_secret='x' * 64)
    with pytest.raises(ValidationError, match='ADMIN_PASSWORD'):
        Settings(**kwargs, cors_origins=['https://example.com'])
    with pytest.raises(ValidationError, match='CORS_ORIGINS'):
        Settings(**kwargs, admin_password='unique-password-with-32-characters')
    assert not Settings(**kwargs, admin_password='unique-password-with-32-characters', cors_origins=['https://example.com']).debug


def test_reset_token_cannot_authenticate():
    reset = create_password_reset_token('user-id', 'password-hash')
    assert decode_password_reset_token(reset, 'password-hash') == 'user-id'
    with pytest.raises(JWTError):
        decode_access_token(reset)
    assert decode_access_token(create_access_token('user-id')) == 'user-id'


@pytest.mark.asyncio
async def test_admin_routes_require_admin_role():
    app = FastAPI()
    app.include_router(admin.public_router)
    app.include_router(admin.router)
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
        assert (await client.get('/admin/auth/me')).status_code == 401
        user_token = create_access_token('normal-user', extra_claims={'role': 'USER'})
        assert (await client.get('/admin/auth/me', headers={'Authorization': f'Bearer {user_token}'})).status_code == 403
        token = create_access_token(subject='admin_user_root', extra_claims={'role': 'ADMIN'})
        assert (await client.get('/admin/auth/me', headers={'Authorization': f'Bearer {token}'})).status_code == 200
        assert (await client.post('/admin/auth/login', json={'email': 'bad', 'password': 'wrong-password'})).status_code == 401


@pytest.mark.asyncio
async def test_mock_google_tokens_fail_outside_tests(monkeypatch):
    monkeypatch.setenv('ENVIRONMENT', 'development')
    get_settings.cache_clear()
    with pytest.raises(ValueError):
        await verify_google_id_token('mock_google_token:someone@example.com')


@pytest.mark.asyncio
async def test_rate_limit_cannot_be_bypassed_in_development(monkeypatch):
    monkeypatch.setenv('ENVIRONMENT', 'development')
    get_settings.cache_clear()
    app = FastAPI()
    app.add_middleware(RateLimiterMiddleware)
    @app.post('/admin/auth/login')
    async def login():
        return {'ok': True}
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
        responses = [await client.post('/admin/auth/login', headers={'X-Bypass-Rate-Limit': 'true'}) for _ in range(11)]
    assert responses[9].status_code == 200
    assert responses[10].status_code == 429
    assert int(responses[10].headers['Retry-After']) > 0








def test_adjustments_require_a_nonzero_delta_and_a_reason():
    with pytest.raises(ValidationError):
        admin.AdminAdjustPointsIn(delta=0, reason_note="support")
    with pytest.raises(ValidationError):
        admin.AdminAdjustPointsIn(delta=10, reason_note="   ")
