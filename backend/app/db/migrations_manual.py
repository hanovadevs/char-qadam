"""Deprecated one-off migration entry point. Use versioned Alembic migrations.

No credentials or guessed merchant identities/passwords belong in source.
"""
if __name__ == '__main__':
    raise SystemExit('Run: python -m alembic upgrade head (from backend/)')
