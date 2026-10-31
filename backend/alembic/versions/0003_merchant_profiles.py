"""Version the merchant profile columns previously added by a manual script.

Revision ID: 0003
Revises: 0002
"""
from alembic import op
import sqlalchemy as sa

revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None


def upgrade():
    connection = op.get_bind()
    inspector = sa.inspect(connection)
    partners = {column['name'] for column in inspector.get_columns('partners')}
    for name, type_ in [
        ('email', sa.String(320)), ('password_hash', sa.String(255)),
        ('category', sa.String(64)), ('description', sa.Text()),
        ('location', sa.String(255)), ('google_maps_url', sa.Text()),
    ]:
        if name not in partners:
            op.add_column('partners', sa.Column(name, type_, nullable=True))
    users = {column['name'] for column in inspector.get_columns('users')}
    if 'role' not in users:
        op.add_column('users', sa.Column('role', sa.String(32), nullable=False, server_default='USER'))
    if 'partner_id' not in users:
        op.add_column('users', sa.Column('partner_id', sa.String(36), sa.ForeignKey('partners.id', ondelete='SET NULL'), nullable=True))
    if 'ix_users_partner_id' not in {index['name'] for index in sa.inspect(connection).get_indexes('users')}:
        op.create_index('ix_users_partner_id', 'users', ['partner_id'])


def downgrade():
    # Existing installations may already contain merchant identities and links.
    # A rollback must not silently discard these records or recreate passwords.
    raise RuntimeError('Merchant profile rollback requires a reviewed data-preservation plan')
