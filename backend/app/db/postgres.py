"""Async PostgreSQL engine, session factory, and FastAPI dependency.

Usage in routers:
    from app.db.postgres import get_session
    from sqlalchemy.ext.asyncio import AsyncSession

    async def my_route(session: AsyncSession = Depends(get_session)):
        ...
"""
from __future__ import annotations

from collections.abc import AsyncGenerator
import asyncio
from sqlalchemy import select

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.config import get_settings

# Module-level engine (created once at import time; disposed in lifespan).
_engine = None
_session_factory: async_sessionmaker[AsyncSession] | None = None
_read_engine = None
_read_session_factory: async_sessionmaker[AsyncSession] | None = None
POOL_SIZE = 5


def get_engine():
    """Return (and lazily create) the async engine."""
    global _engine
    if _engine is None:
        settings = get_settings()
        _engine = create_async_engine(
            settings.database_url,
            echo=settings.debug,        # SQL logging in dev
            pool_pre_ping=True,         # detect stale connections
            pool_size=settings.db_pool_size,
            max_overflow=settings.db_max_overflow,
            pool_timeout=6,
            pool_recycle=900,
            connect_args={'timeout': 10, 'command_timeout': 20},
        )
    return _engine


def get_read_engine():
    """Dedicated autocommit pool for reviewed SELECT-only admin/readiness routes.

    Avoid BEGIN/ROLLBACK network round trips over the remote database link.
    Never use this pool for account, points, voucher, support or admin writes.
    """
    global _read_engine
    if _read_engine is None:
        settings = get_settings()
        _read_engine = create_async_engine(
            settings.database_url, isolation_level='AUTOCOMMIT',
            echo=settings.debug, pool_pre_ping=True,
            pool_size=settings.db_read_pool_size, max_overflow=0,
            pool_timeout=6, pool_recycle=900,
            connect_args={'timeout': 10, 'command_timeout': 20},
        )
    return _read_engine


async def warm_pool(engine=None, connections=None) -> None:
    """Initialize the bounded pool and enum codecs before accepting traffic.

    Engine construction alone does not establish connections. These zero-row
    reads incur connection/type setup at startup, without accessing user rows.
    """
    from app.db.models import Offer, Partner, PointsLedger, User, Voucher
    engine = engine if engine is not None else get_engine()

    async def warm_connection():
        async with engine.connect() as connection:
            for model in (User, Partner, Offer, Voucher, PointsLedger):
                await connection.execute(select(model).limit(0))

    async with asyncio.TaskGroup() as tasks:
        for _ in range(connections or get_settings().db_pool_size):
            tasks.create_task(warm_connection())


async def warm_read_pool() -> None:
    await warm_pool(get_read_engine(), get_settings().db_read_pool_size)


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
    global _engine, _session_factory, _read_engine, _read_session_factory
    if _engine is not None:
        await _engine.dispose()
        _engine = None
        _session_factory = None
    if _read_engine is not None:
        await _read_engine.dispose()
        _read_engine = None
        _read_session_factory = None


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency that yields a per-request AsyncSession."""
    factory = get_session_factory()
    async with factory() as session:
        yield session


def get_read_session_factory() -> async_sessionmaker[AsyncSession]:
    global _read_session_factory
    if _read_session_factory is None:
        _read_session_factory = async_sessionmaker(
            get_read_engine(), expire_on_commit=False, autoflush=False,
        )
    return _read_session_factory


async def get_read_session() -> AsyncGenerator[AsyncSession, None]:
    """SELECT-only dependency. Mutating routes must keep get_session()."""
    async with get_read_session_factory()() as session:
        yield session
