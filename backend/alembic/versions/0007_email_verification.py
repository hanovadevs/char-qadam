"""Require mailbox ownership and bind Google accounts by stable subject.

Existing accounts deliberately remain unverified: there is no historical proof.
"""
from alembic import op
import sqlalchemy as sa

revision = '0007'
down_revision = '0006'
branch_labels = None
depends_on = None


def upgrade():
    connection = op.get_bind()
    if connection.execute(sa.text('SELECT 1 FROM users GROUP BY lower(email) HAVING count(*) > 1 LIMIT 1')).first():
        raise RuntimeError('Duplicate case-insensitive emails require manual review before migration')
    connection.execute(sa.text('UPDATE users SET email = lower(email) WHERE email <> lower(email)'))
    op.add_column('users', sa.Column('email_verified_at', sa.DateTime(timezone=True)))
    op.add_column('users', sa.Column('google_subject', sa.String(255)))
    op.create_unique_constraint('uq_users_google_subject', 'users', ['google_subject'])
    op.add_column('users', sa.Column('verification_code_hash', sa.String(64)))
    op.add_column('users', sa.Column('verification_expires_at', sa.DateTime(timezone=True)))
    op.add_column('users', sa.Column('verification_sent_at', sa.DateTime(timezone=True)))
    op.add_column('users', sa.Column('verification_attempts', sa.Integer(), nullable=False, server_default='0'))


def downgrade():
    raise RuntimeError('Email ownership records must not be erased by an automatic downgrade')
