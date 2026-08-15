"""Add api_key_hash column to partners table.

Revision ID: 0002
Revises: 0001
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "partners",
        sa.Column("api_key_hash", sa.String(64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_partners_api_key_hash", "partners", ["api_key_hash"]
    )


def downgrade() -> None:
    op.drop_constraint("uq_partners_api_key_hash", "partners", type_="unique")
    op.drop_column("partners", "api_key_hash")
