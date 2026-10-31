"""Regression checks that do not connect to any database."""
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from jwt import InvalidTokenError as JWTError
from pydantic import ValidationError

from app.config import Settings, get_settings
from app.deps import require_admin
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
        Settings(**kwargs)
    with pytest.raises(ValidationError, match='CORS_ORIGINS'):
        Settings(**kwargs, admin_password='unique-password-with-32-characters')
    assert not Settings(**kwargs, admin_password='unique-password-with-32-characters', cors_origins=['https://example.com']).debug


def test_reset_token_cannot_authenticate():
    reset = create_password_reset_token('user-id')
    assert decode_password_reset_token(reset) == 'user-id'
    with pytest.raises(JWTError):
        decode_access_token(reset)
    assert decode_access_token(create_access_token('user-id')) == 'user-id'


@pytest.mark.asyncio
async def test_admin_routes_require_admin_role():
    app = FastAPI()
    app.include_router(admin.auth_router)
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
    with pytest.raises(ValueError, match='only allowed'):
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


@pytest.mark.asyncio
async def test_user_directory_query_count_does_not_grow_with_users():
    # 51 users should require two queries, rather than 52 queries.
    from datetime import datetime, timezone
    from app.db.models import UserStatus
    users = [(SimpleNamespace(id=str(i), email=f'{i}@example.com', status=UserStatus.ACTIVE,
               country='PK', created_at=datetime.now(timezone.utc)), i * 100) for i in range(51)]
    session = SimpleNamespace(execute=AsyncMock(side_effect=[
        SimpleNamespace(all=lambda: users),
        SimpleNamespace(all=lambda: [(str(i), i) for i in range(51)]),
    ]))
    result = await admin.list_users(status=None, limit=51, offset=0, session=session)
    assert session.execute.await_count == 2
    assert len(result) == 51
    assert result[50]['points_balance'] == 50


def test_password_change_revokes_issued_user_token():
    from app.services.security import create_user_access_token, validate_user_token
    user = SimpleNamespace(id="user-id", role="USER", partner_id=None, password_hash="old-hash")
    token = create_user_access_token(user)
    validate_user_token(token, user)
    user.password_hash = "new-hash"
    with pytest.raises(JWTError):
        validate_user_token(token, user)


def test_password_length_is_validated_in_utf8_bytes():
    from app.schemas.auth import RegisterIn
    with pytest.raises(ValidationError, match="72 UTF-8 bytes"):
        RegisterIn(email="person@example.com", password="界" * 30)


def test_adjustments_require_a_nonzero_delta_and_a_reason():
    with pytest.raises(ValidationError):
        admin.AdminAdjustPointsIn(delta=0, reason_note="support")
    with pytest.raises(ValidationError):
        admin.AdminAdjustPointsIn(delta=10, reason_note="   ")
