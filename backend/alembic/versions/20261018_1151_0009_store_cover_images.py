"""Store cover images and non-destructive store/offer archival.

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-18 11:51:44.407622+00:00

"""
from __future__ import annotations
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0009'
down_revision: Union[str, None] = '0008'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('partners', sa.Column('cover_image_url', sa.Text(), nullable=True))
    op.add_column('partners', sa.Column('archived_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('offers', sa.Column('archived_at', sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    raise RuntimeError('Preserve stored covers and archive state; roll back application code without dropping these additive columns')
