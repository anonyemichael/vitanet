"""add user biological sex

Revision ID: c1d4e2a9b1f0
Revises: add788e9c59c
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c1d4e2a9b1f0"
down_revision: Union[str, Sequence[str], None] = "add788e9c59c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("biological_sex", sa.String(length=32), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "biological_sex")
