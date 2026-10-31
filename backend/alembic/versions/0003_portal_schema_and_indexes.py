"""Reconcile portal fields and add indexes for history, rankings and admin lists.

Revision ID: 0003
Revises: 0002
"""
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None

INDEXES = {
    "ix_users_created_id": ("users", "created_at DESC, id"),
    "ix_users_partner_id": ("users", "partner_id"),
    "ix_activity_date_user": ("activity_daily", "local_date, user_id"),
    "ix_ledger_user_created": ("points_ledger", "user_id, created_at DESC"),
    "ix_ledger_created": ("points_ledger", "created_at DESC"),
    "ix_offers_partner": ("offers", "partner_id"),
    "ix_vouchers_created": ("vouchers", "created_at DESC"),
    "ix_vouchers_status_expiry": ("vouchers", "status, expires_at"),
    "ix_redemptions_partner_time": ("redemptions", "partner_id, redeemed_at DESC"),
    "ix_redemptions_time": ("redemptions", "redeemed_at DESC"),
    "ix_audit_created": ("audit_log", "created_at DESC"),
}


def upgrade():
    # Earlier deployments used a manual schema script; tolerate existing fields.
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(32) NOT NULL DEFAULT 'USER'")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS partner_id VARCHAR(36) REFERENCES partners(id) ON DELETE SET NULL")
    for column, kind in [("email", "VARCHAR(320)"), ("password_hash", "VARCHAR(255)"),
                         ("category", "VARCHAR(64)"), ("description", "TEXT"), ("location", "VARCHAR(255)")]:
        op.execute(f"ALTER TABLE partners ADD COLUMN IF NOT EXISTS {column} {kind}")
    for name, (table, columns) in INDEXES.items():
        op.execute(f"CREATE INDEX IF NOT EXISTS {name} ON {table} ({columns})")


def downgrade():
    for name in reversed(INDEXES):
        op.execute(f"DROP INDEX IF EXISTS {name}")
    # Keep portal columns: they may predate this migration and contain user data.
