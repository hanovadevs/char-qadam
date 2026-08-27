"""Alembic migration environment configuration for Qadam backend.

Key points:
- Uses the async engine from app.db.postgres (asyncpg driver).
- Imports ALL models via app.db.models so autogenerate can diff them.
- DATABASE_URL is read from the same Settings object the app uses.
"""
from __future__ import annotations

import asyncio
from logging.config import fileConfig

from alembic import context
# pyrefly: ignore [missing-import]
from sqlalchemy.ext.asyncio import create_async_engine

# Make sure all models are imported so their tables appear in metadata.
import app.db.models  # noqa: F401  (side-effect import)
from app.db.base import Base
from app.config import get_settings

# Alembic Config object — gives access to values in alembic.ini.
config = context.config

# Interpret the [loggers] section of alembic.ini if present.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# The metadata object for 'autogenerate' support.
target_metadata = Base.metadata


def get_url() -> str:
    return get_settings().database_url


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (no DB connection required)."""
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    """Run migrations in 'online' mode with an async engine."""
    engine = create_async_engine(get_url(), echo=False)
    async with engine.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
