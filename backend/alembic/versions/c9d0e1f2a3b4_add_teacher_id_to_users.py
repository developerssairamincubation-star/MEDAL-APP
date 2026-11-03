"""add users.teacher_id (students added under a teacher)

Revision ID: c9d0e1f2a3b4
Revises: b8c9d0e1f2a3
Create Date: 2026-11-03 18:00:00.000000

A student added by a teacher (staff user) points at that teacher. Existing rows get NULL
(nobody owns them yet); the principal still sees every student in the school.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c9d0e1f2a3b4'
down_revision: Union[str, Sequence[str], None] = 'b8c9d0e1f2a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('users') as batch:
        batch.add_column(sa.Column('teacher_id', sa.Integer(), nullable=True))
        batch.create_index('ix_users_teacher_id', ['teacher_id'])
        batch.create_foreign_key('fk_users_teacher_id', 'users', ['teacher_id'], ['id'], ondelete='SET NULL')


def downgrade() -> None:
    with op.batch_alter_table('users') as batch:
        batch.drop_constraint('fk_users_teacher_id', type_='foreignkey')
        batch.drop_index('ix_users_teacher_id')
        batch.drop_column('teacher_id')
