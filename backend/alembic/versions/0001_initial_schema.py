"""Initial schema — creates all 9 Qadam MVP tables.

Tables created:
    users, devices, activity_daily, points_ledger,
    partners, offers, vouchers, redemptions, audit_log

Revision ID: 0001
Revises: (none)
Create Date: 2026-08-14
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision: str = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------ users
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column(
            "status",
            sa.Enum("ACTIVE", "SUSPENDED", "DELETED", name="user_status"),
            nullable=False,
            server_default="ACTIVE",
        ),
        sa.Column("country", sa.String(2), nullable=True),
        sa.Column("timezone", sa.String(64), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )

    # ----------------------------------------------------------------- devices
    op.create_table(
        "devices",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("platform", sa.String(16), nullable=False),
        sa.Column("app_version", sa.String(32), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # ------------------------------------------------------------- activity_daily
    op.create_table(
        "activity_daily",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("local_date", sa.String(10), nullable=False),
        sa.Column("eligible_steps", sa.BigInteger, nullable=False, server_default="0"),
        sa.Column("source", sa.String(32), nullable=False),
        sa.Column("sync_key", sa.String(128), nullable=False),
        sa.Column("sync_version", sa.Integer, nullable=False, server_default="1"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("user_id", "local_date", name="uq_activity_user_date"),
        sa.UniqueConstraint("sync_key", name="uq_activity_sync_key"),
    )
    op.create_index("ix_activity_user_date", "activity_daily", ["user_id", "local_date"])

    # ------------------------------------------------------------- points_ledger
    op.create_table(
        "points_ledger",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("delta", sa.Integer, nullable=False),
        sa.Column(
            "reason",
            sa.Enum("STEP_EARN", "OFFER_SPEND", "ADJUST", name="ledger_reason"),
            nullable=False,
        ),
        sa.Column("ref_type", sa.String(64), nullable=True),
        sa.Column("ref_id", sa.String(36), nullable=True),
        sa.Column("campaign_id", sa.String(64), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_ledger_user_id", "points_ledger", ["user_id"])

    # ----------------------------------------------------------------- partners
    op.create_table(
        "partners",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(128), nullable=False),
        sa.Column(
            "status",
            sa.Enum("ACTIVE", "INACTIVE", name="partner_status"),
            nullable=False,
            server_default="ACTIVE",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # ------------------------------------------------------------------ offers
    op.create_table(
        "offers",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "partner_id",
            sa.String(36),
            sa.ForeignKey("partners.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(256), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column(
            "discount_type",
            sa.Enum("PERCENT", "FIXED", "FREE_ITEM", name="discount_type"),
            nullable=False,
        ),
        sa.Column("discount_value", sa.Numeric(10, 2), nullable=False),
        sa.Column("points_cost", sa.Integer, nullable=False),
        sa.Column("min_basket", sa.Numeric(10, 2), nullable=True),
        sa.Column("inventory", sa.Integer, nullable=True),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "status",
            sa.Enum("ACTIVE", "INACTIVE", "EXPIRED", name="offer_status"),
            nullable=False,
            server_default="ACTIVE",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_offers_status_dates",
        "offers",
        ["status", "starts_at", "ends_at"],
    )

    # ----------------------------------------------------------------- vouchers
    op.create_table(
        "vouchers",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "offer_id",
            sa.String(36),
            sa.ForeignKey("offers.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("short_code", sa.String(32), nullable=False),
        sa.Column("token_hash", sa.String(255), nullable=False),
        sa.Column(
            "status",
            sa.Enum("ISSUED", "REDEEMED", "EXPIRED", "CANCELLED", name="voucher_status"),
            nullable=False,
            server_default="ISSUED",
        ),
        sa.Column("issued_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("short_code", name="uq_vouchers_short_code"),
    )
    op.create_index("ix_vouchers_token_hash", "vouchers", ["token_hash"])
    op.create_index("ix_vouchers_user_status", "vouchers", ["user_id", "status"])

    # --------------------------------------------------------------- redemptions
    op.create_table(
        "redemptions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "voucher_id",
            sa.String(36),
            sa.ForeignKey("vouchers.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "partner_id",
            sa.String(36),
            sa.ForeignKey("partners.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("store_id", sa.String(128), nullable=True),
        sa.Column("order_reference", sa.String(256), nullable=True),
        sa.Column("discount_value", sa.Numeric(10, 2), nullable=False),
        sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("voucher_id", name="uq_redemptions_voucher_id"),
    )

    # --------------------------------------------------------------- audit_log
    op.create_table(
        "audit_log",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("actor", sa.String(36), nullable=False),
        sa.Column("action", sa.String(128), nullable=False),
        sa.Column("object_type", sa.String(64), nullable=False),
        sa.Column("object_id", sa.String(36), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("audit_log")
    op.drop_table("redemptions")
    op.drop_index("ix_vouchers_user_status", table_name="vouchers")
    op.drop_index("ix_vouchers_token_hash", table_name="vouchers")
    op.drop_table("vouchers")
    op.drop_index("ix_offers_status_dates", table_name="offers")
    op.drop_table("offers")
    op.drop_table("partners")
    op.drop_index("ix_ledger_user_id", table_name="points_ledger")
    op.drop_table("points_ledger")
    op.drop_index("ix_activity_user_date", table_name="activity_daily")
    op.drop_table("activity_daily")
    op.drop_table("devices")
    op.drop_table("users")

    # Drop enum types (Postgres doesn't auto-drop them)
    op.execute("DROP TYPE IF EXISTS user_status")
    op.execute("DROP TYPE IF EXISTS ledger_reason")
    op.execute("DROP TYPE IF EXISTS discount_type")
    op.execute("DROP TYPE IF EXISTS offer_status")
    op.execute("DROP TYPE IF EXISTS partner_status")
    op.execute("DROP TYPE IF EXISTS voucher_status")
