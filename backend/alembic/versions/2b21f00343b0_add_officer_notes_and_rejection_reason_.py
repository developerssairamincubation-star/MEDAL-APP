"""add_officer_notes_and_rejection_reason_to_complaints

Revision ID: 2b21f00343b0
Revises: 99515bf2a89e
Create Date: 2026-10-20 09:26:40.869365

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '2b21f00343b0'
down_revision: Union[str, Sequence[str], None] = '99515bf2a89e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('complaints', sa.Column('officer_notes', sa.Text(), nullable=True))
    op.add_column('complaints', sa.Column('rejection_reason', sa.Text(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('complaints', 'rejection_reason')
    op.drop_column('complaints', 'officer_notes')
