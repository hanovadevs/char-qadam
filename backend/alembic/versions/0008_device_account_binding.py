"""One active account per device, with non-resetting reward consumption."""
from alembic import op
import sqlalchemy as sa

revision = '0008'
down_revision = '0007'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('device_bindings',
        sa.Column('id', sa.String(64), primary_key=True),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('generation', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()))
    op.create_index('ix_device_bindings_user_id', 'device_bindings', ['user_id'])
    op.create_table('device_activity_daily',
        sa.Column('device_id', sa.String(64), sa.ForeignKey('device_bindings.id', ondelete='RESTRICT'), primary_key=True),
        sa.Column('local_date', sa.String(10), primary_key=True),
        sa.Column('eligible_steps', sa.BigInteger(), nullable=False, server_default='0'))
    op.execute('ALTER TABLE public.device_bindings ENABLE ROW LEVEL SECURITY')
    op.execute('ALTER TABLE public.device_activity_daily ENABLE ROW LEVEL SECURITY')


def downgrade():
    raise RuntimeError('Do not erase device ownership or consumed reward history')
