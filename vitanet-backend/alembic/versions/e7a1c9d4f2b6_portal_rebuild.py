"""Portal rebuild: staff and portal tables, arrival/outcome columns,
structured vitals, alert acknowledgements; drop the old demo hospital_* tables.

Revision ID: e7a1c9d4f2b6
Revises: d2e5f3a8c4b1
Create Date: 2026-11-09
"""
from typing import Sequence, Union

from alembic import op

from app.database.schema_sync import sync_schema

revision: str = "e7a1c9d4f2b6"
down_revision: Union[str, Sequence[str], None] = "d2e5f3a8c4b1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Guarded: these tables were created by create_all on most databases.
    sync_schema(op.get_bind(), drop_legacy=True)


def downgrade() -> None:
    op.drop_table("portal_alert_acks")
    op.drop_table("portal_case_vitals")
