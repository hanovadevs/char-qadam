"""Deny direct Data API access to tables managed by FastAPI's own auth."""
from alembic import op

revision = '0006'
down_revision = '0005'
branch_labels = None
depends_on = None

TABLES = (
    'users', 'devices', 'activity_daily', 'points_ledger', 'partners', 'offers',
    'vouchers', 'redemptions', 'audit_log', 'alembic_version', 'redemption_requests',
)


def upgrade():
    # The owning backend role retains access. Supabase anon/authenticated roles
    # have no policies: the app authenticates through FastAPI, not Supabase Auth.
    for table in TABLES:
        op.execute(f'ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY')


def downgrade():
    raise RuntimeError('Review the access model before removing database API protection')
