"""add respiratory-rate vital type

Revision ID: d2e5f3a8c4b1
Revises: c1d4e2a9b1f0
"""

from typing import Sequence, Union

from alembic import op

revision: str = "d2e5f3a8c4b1"
down_revision: Union[str, Sequence[str], None] = "c1d4e2a9b1f0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE vitaltype ADD VALUE IF NOT EXISTS 'RESPIRATORY_RATE'")


def downgrade() -> None:
    # PostgreSQL cannot safely remove an enum value without rebuilding the type.
    pass
