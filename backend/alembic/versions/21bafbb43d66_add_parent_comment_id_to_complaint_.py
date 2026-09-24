"""add_parent_comment_id_to_complaint_comments

Revision ID: 21bafbb43d66
Revises: 7aa2f13f42ee
Create Date: 2026-09-21 11:49:22.491139

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '21bafbb43d66'
down_revision: Union[str, Sequence[str], None] = '7aa2f13f42ee'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: add parent_comment_id with self-referencing FK and index."""
    op.add_column(
        'complaint_comments',
        sa.Column('parent_comment_id', sa.Integer(), sa.ForeignKey('complaint_comments.id', ondelete='CASCADE'), nullable=True),
    )
    op.create_index(
        op.f('ix_complaint_comments_parent_comment_id'),
        'complaint_comments',
        ['parent_comment_id'],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema: remove parent_comment_id column and index."""
    op.drop_index(op.f('ix_complaint_comments_parent_comment_id'), table_name='complaint_comments')
    op.drop_column('complaint_comments', 'parent_comment_id')
