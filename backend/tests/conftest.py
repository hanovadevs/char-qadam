"""Integration tests use an isolated, disposable schema on an explicit test URL.

Set TEST_DATABASE_URL and optional TEST_DB_SSL_CA_FILE. Never fall back to the
application's DATABASE_URL or create test records in the public schema.
"""
from __future__ import annotations
import asyncio
import os
import ssl
import uuid

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool
from app.db import postgres as _pg_module


@pytest.fixture(scope="session", autouse=True)
def _patch_engine_for_tests():
    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("Set TEST_DATABASE_URL to run isolated database integration tests")
    from app.config import get_settings
    from app.db.base import Base
    import app.db.models
    overrides = {"ENVIRONMENT": "test", "DEBUG": "false", "JWT_SECRET": "isolated-integration-test-secret-only", "DAILY_STEP_CAP": "20000", "STEPS_PER_POINT": "100"}
    old_env = {key: os.environ.get(key) for key in overrides}
    os.environ.update(overrides)
    get_settings.cache_clear()
    schema = "qadam_tests_" + uuid.uuid4().hex
    connect_args = {"server_settings": {"search_path": schema}, "command_timeout": 30}
    ca_file = os.environ.get("TEST_DB_SSL_CA_FILE")
    if ca_file:
        connect_args["ssl"] = ssl.create_default_context(cafile=ca_file)
    engine = create_async_engine(database_url, poolclass=NullPool, echo=False, connect_args=connect_args)
    async def bootstrap():
        async with engine.begin() as connection:
            await connection.execute(text(f'CREATE SCHEMA "{schema}"'))
            await connection.run_sync(Base.metadata.create_all)
    asyncio.run(bootstrap())
    _pg_module._engine = engine
    _pg_module._session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    try:
        yield
    finally:
        async def cleanup():
            async with engine.begin() as connection:
                await connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
            await engine.dispose()
        asyncio.run(cleanup())
        _pg_module._engine = None
        _pg_module._session_factory = None
        for key, value in old_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        get_settings.cache_clear()


@pytest_asyncio.fixture
async def client() -> AsyncClient:
    from app.main import app
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test", headers={"X-Bypass-Rate-Limit": "true"}) as ac:
        yield ac


@pytest.fixture
def admin_headers():
    from app.services.security import create_access_token
    return {"Authorization": "Bearer " + create_access_token(subject="admin_user_root", extra_claims={"role": "ADMIN"})}
