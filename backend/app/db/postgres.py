"""Async PostgreSQL engine, session factory, and FastAPI dependency.

Usage in routers:
    from app.db.postgres import get_session
    from sqlalchemy.ext.asyncio import AsyncSession

    async def my_route(session: AsyncSession = Depends(get_session)):
        ...
"""
from __future__ import annotations

from collections.abc import AsyncGenerator
import ssl

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.config import get_settings

# Module-level engine (created once at import time; disposed in lifespan).
_engine = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def get_engine():
    """Return (and lazily create) the async engine."""
    global _engine
    if _engine is None:
        settings = get_settings()
        connect_args = {"command_timeout": settings.db_command_timeout}
        if settings.environment.lower() == "production" or settings.db_ssl_ca_file:
            connect_args["ssl"] = ssl.create_default_context(cafile=settings.db_ssl_ca_file)
        _engine = create_async_engine(
            settings.database_url,
            echo=settings.debug,        # SQL logging in dev
            pool_pre_ping=True,         # detect stale connections
            pool_size=settings.db_pool_size,
            max_overflow=settings.db_max_overflow,
            pool_timeout=settings.db_pool_timeout,
            pool_recycle=1800,
            connect_args=connect_args,
        )
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    """Return (and lazily create) the session factory."""
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(
            get_engine(),
            expire_on_commit=False,
            class_=AsyncSession,
        )
    return _session_factory


async def dispose_engine() -> None:
    """Dispose the engine connection pool. Call on application shutdown."""
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
        _engine = None
        _session_factory = None


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency that yields a per-request AsyncSession."""
    factory = get_session_factory()
    async with factory() as session:
        yield session
