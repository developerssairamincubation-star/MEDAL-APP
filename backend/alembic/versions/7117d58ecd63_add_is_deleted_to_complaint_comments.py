"""add_is_deleted_to_complaint_comments

Revision ID: 7117d58ecd63
Revises: 21bafbb43d66
Create Date: 2026-09-21 12:12:23.450959

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7117d58ecd63'
down_revision: Union[str, Sequence[str], None] = '21bafbb43d66'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: add is_deleted boolean column to complaint_comments."""
    op.add_column(
        'complaint_comments',
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('false')),
    )


def downgrade() -> None:
    """Downgrade schema: drop is_deleted column."""
    op.drop_column('complaint_comments', 'is_deleted')
