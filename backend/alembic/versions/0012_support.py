"""Support tickets and shared AI cost controls. AI starts disabled.
Revision ID: 0012
Revises: 0011
"""
from alembic import op
from app.db.models import SupportTicket, SupportMessage, SupportAISettings, SupportAIUsage
revision = '0012'
down_revision = '0011'
branch_labels = None
depends_on = None
MODELS = [SupportTicket, SupportMessage, SupportAISettings, SupportAIUsage]
def upgrade():
    for model in MODELS:
        model.__table__.create(op.get_bind(), checkfirst=True)
        name = model.__tablename__
        op.execute(f'ALTER TABLE {name} ENABLE ROW LEVEL SECURITY')
        op.execute(f'''DO $$ BEGIN
            IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN REVOKE ALL ON {name} FROM anon; END IF;
            IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN REVOKE ALL ON {name} FROM authenticated; END IF;
        END $$''')
def downgrade():
    for model in reversed(MODELS):
        model.__table__.drop(op.get_bind(), checkfirst=True)
