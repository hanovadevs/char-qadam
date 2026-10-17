"""Shared pytest fixtures for the Qadam backend test suite.

Uses httpx.AsyncClient with the FastAPI ASGI transport — no real server
needed. TEST_DATABASE_URL must point at an isolated loopback test database.

Event loop / connection pool
-----------------------------
asyncpg connections cannot be shared across event loops.  We override the
engine factory with ``NullPool`` for the test session so each test gets a
fresh connection (no pool) and there are no "event loop closed" errors.
"""
from __future__ import annotations

import os
from sqlalchemy.engine import make_url

# Never load DATABASE_URL from a developer's .env or exercise a shared database.
test_url = os.environ.get('TEST_DATABASE_URL', 'postgresql+asyncpg://stepsy_test:local-audit-only@127.0.0.1:55432/stepsy_test')
parsed = make_url(test_url)
if parsed.host not in ('127.0.0.1', 'localhost', '::1') or not (parsed.database or '').endswith('_test'):
    raise RuntimeError('TEST_DATABASE_URL must target a loopback database ending in _test')
os.environ.update(DATABASE_URL=test_url, ENVIRONMENT='test', DEBUG='false', JWT_SECRET='stepsy-isolated-test-secret-only-32-characters', SMTP_HOST='')
os.environ['REDEMPTION_RECEIPT_KEYS'] = 'MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA='

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.pool import NullPool

from app.db import postgres as _pg_module


@pytest.fixture(scope="session", autouse=True)
def _patch_engine_for_tests():
    """Replace the shared engine with a NullPool engine for test isolation."""
    from app.config import get_settings
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine, AsyncSession

    settings = get_settings()
    test_engine = create_async_engine(
        settings.database_url,
        poolclass=NullPool,
        echo=False,
    )
    test_factory = async_sessionmaker(test_engine, expire_on_commit=False, class_=AsyncSession)

    # Monkeypatch the module-level engine and factory
    _pg_module._engine = test_engine
    _pg_module._session_factory = test_factory

    import asyncio
    from alembic import command
    from alembic.config import Config
    from pathlib import Path
    command.upgrade(Config(str(Path(__file__).resolve().parents[1] / 'alembic.ini')), 'head')
    yield
    asyncio.run(test_engine.dispose())


@pytest_asyncio.fixture
async def client() -> AsyncClient:
    """Async HTTPX client wired to the FastAPI app (no real server)."""
    from app.main import app
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"X-Bypass-Rate-Limit": "true"},
    ) as ac:
        yield ac


@pytest_asyncio.fixture
async def admin_client(client):
    from app.services.security import create_access_token
    token = create_access_token(subject='admin_user_root', extra_claims={'role': 'ADMIN'})
    client.headers['Authorization'] = f'Bearer {token}'
    return client
