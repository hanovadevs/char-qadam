"""Persist encrypted issuance receipts for retry-safe reward purchases."""
from alembic import op
import sqlalchemy as sa

revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'redemption_requests',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('request_key', sa.String(128), nullable=False),
        sa.Column('offer_id', sa.String(36), sa.ForeignKey('offers.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('response_ciphertext', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint('user_id', 'request_key', name='uq_redemption_user_key'),
    )
    # FastAPI uses the owning DB role; Supabase Data API roles get no policies.
    op.execute('ALTER TABLE redemption_requests ENABLE ROW LEVEL SECURITY')


def downgrade():
    raise RuntimeError('Keep issuance receipts when rolling back code; deleting them can permit duplicate purchases')
