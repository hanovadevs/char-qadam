"""Persist privately downloadable weekly/monthly merchant PDF snapshots."""
from alembic import op
import sqlalchemy as sa

revision = '0011'
down_revision = '0010'
branch_labels = depends_on = None


def upgrade():
    op.create_table('merchant_ledgers',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('partner_id', sa.String(36), sa.ForeignKey('partners.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('request_id', sa.String(36), nullable=False),
        sa.Column('period', sa.String(8), nullable=False),
        sa.Column('starts_on', sa.String(10), nullable=False),
        sa.Column('ends_on', sa.String(10), nullable=False),
        sa.Column('timezone', sa.String(64), nullable=False),
        sa.Column('row_count', sa.Integer(), nullable=False),
        sa.Column('fixed_discount_total', sa.Numeric(20, 2), nullable=False),
        sa.Column('sha256', sa.String(64), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('partner_id', 'request_id', name='uq_merchant_ledger_request'))
    op.create_index('ix_merchant_ledgers_partner_id', 'merchant_ledgers', ['partner_id'])
    op.create_index('ix_merchant_ledgers_history', 'merchant_ledgers', ['partner_id', 'created_at', 'id'])
    op.execute('ALTER TABLE public.merchant_ledgers ENABLE ROW LEVEL SECURITY')


def downgrade():
    raise RuntimeError('Do not erase generated ledger history; retain additive schema when rolling back code')
