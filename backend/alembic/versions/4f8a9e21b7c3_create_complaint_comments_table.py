"""create_complaint_comments_table

Revision ID: 4f8a9e21b7c3
Revises: 323179e097f0
Create Date: 2026-09-18 14:02:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4f8a9e21b7c3'
down_revision: Union[str, Sequence[str], None] = '323179e097f0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema to include complaint_comments table."""
    op.create_table(
        'complaint_comments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('complaint_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('comment', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['complaint_id'], ['complaints.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_complaint_comments_complaint_id'), 'complaint_comments', ['complaint_id'], unique=False)
    op.create_index(op.f('ix_complaint_comments_id'), 'complaint_comments', ['id'], unique=False)
    op.create_index(op.f('ix_complaint_comments_user_id'), 'complaint_comments', ['user_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_complaint_comments_user_id'), table_name='complaint_comments')
    op.drop_index(op.f('ix_complaint_comments_id'), table_name='complaint_comments')
    op.drop_index(op.f('ix_complaint_comments_complaint_id'), table_name='complaint_comments')
    op.drop_table('complaint_comments')
