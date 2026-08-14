"""DEPRECATED — removed in Phase B0 (2026-08-14).

MongoDB/Motor has been replaced by PostgreSQL + SQLAlchemy (asyncpg).
See app/db/postgres.py for the new database layer.

This file is kept temporarily to avoid breaking any imports that haven't
been migrated yet. It will be deleted once no references remain.
"""
raise ImportError(
    "app.db.mongo is removed. Use app.db.postgres (get_session) instead."
)
