"""Shared pytest fixtures for the Qadam backend test suite.

Uses httpx.AsyncClient with the FastAPI ASGI transport — no real server
needed.  DATABASE_URL is read from .env so tests hit the Supabase dev DB.

Event loop / connection pool
-----------------------------
asyncpg connections cannot be shared across event loops.  We override the
engine factory with ``NullPool`` for the test session so each test gets a
fresh connection (no pool) and there are no "event loop closed" errors.
"""
from __future__ import annotations

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

    yield

    import asyncio
    asyncio.get_event_loop().run_until_complete(test_engine.dispose())


@pytest_asyncio.fixture
async def client() -> AsyncClient:
    """Async HTTPX client wired to the FastAPI app (no real server)."""
    from app.main import app
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac
