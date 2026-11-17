"""App profile fields on health_profiles (conditions, medications, family history, blood type, age) and the
SMS line's tables (sms_messages, sms_contacts).

Revision ID: f4c2a8e1d7b3
Revises: e7a1c9d4f2b6
Create Date: 2026-11-16
"""
from typing import Sequence, Union

from alembic import op

from app.database.schema_sync import sync_schema

revision: str = "f4c2a8e1d7b3"
down_revision: Union[str, Sequence[str], None] = "e7a1c9d4f2b6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # additive and guarded: creates the SMS tables and adds the new nullable columns only where missing
    sync_schema(op.get_bind())


def downgrade() -> None:
    op.drop_table("sms_contacts")
    op.drop_table("sms_messages")
    for col in ("age_years", "blood_type", "family_history", "medications", "conditions"):
        op.drop_column("health_profiles", col)
