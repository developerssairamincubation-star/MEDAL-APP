"""add_image_url_to_complaint_comments

Revision ID: c1f57b649d21
Revises: 2b21f00343b0
Create Date: 2026-10-24 16:55:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c1f57b649d21'
down_revision: Union[str, Sequence[str], None] = '2b21f00343b0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: add image_url column to complaint_comments."""
    op.add_column(
        'complaint_comments',
        sa.Column('image_url', sa.String(length=1024), nullable=True),
    )


def downgrade() -> None:
    """Downgrade schema: drop image_url column."""
    op.drop_column('complaint_comments', 'image_url')
