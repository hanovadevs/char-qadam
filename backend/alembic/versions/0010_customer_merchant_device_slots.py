"""One customer and one merchant reservation per physical phone."""
from alembic import op
import sqlalchemy as sa

revision = '0010'
down_revision = '0009'
branch_labels = depends_on = None


def upgrade():
    op.add_column('device_bindings', sa.Column('merchant_user_id', sa.String(36),
                  sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True))
    op.add_column('device_bindings', sa.Column('merchant_generation', sa.Integer(), nullable=False, server_default='0'))
    op.create_index('ix_device_bindings_merchant_user_id', 'device_bindings', ['merchant_user_id'])
    # Preserve old merchant sessions and all physical-device consumption rows.
    op.execute("""UPDATE device_bindings AS d SET merchant_user_id=d.user_id,
        merchant_generation=d.generation, user_id=NULL, generation=d.generation+1
        FROM users AS u WHERE u.id=d.user_id AND u.role='MERCHANT'""")


def downgrade():
    raise RuntimeError('Preserve both account reservations and consumed reward history; do not downgrade device slots')
