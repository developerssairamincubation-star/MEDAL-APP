"""add schools, users.school_id and users.token_version

Revision ID: b8c9d0e1f2a3
Revises: a7b8c9d0e1f2
Create Date: 2026-11-03 12:00:00.000000

Multi-school tenancy + server-side session revocation.

Existing rows: every existing principal / staff / student is attached to ONE school,
code 'DEFAULT' (created here only if such users exist). Citizens, authorities and admins
keep school_id NULL. To split existing data across real schools afterwards, create the
schools and UPDATE users SET school_id = ... for the right users. token_version starts
at 0 for everybody.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b8c9d0e1f2a3'
down_revision: Union[str, Sequence[str], None] = 'a7b8c9d0e1f2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

INSTITUTION_ROLES = ('principal', 'staff', 'student')


def upgrade() -> None:
    op.create_table(
        'schools',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('code', sa.String(length=32), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('ix_schools_code', 'schools', ['code'], unique=True)

    with op.batch_alter_table('users') as batch:
        batch.add_column(sa.Column('school_id', sa.Integer(), nullable=True))
        batch.add_column(sa.Column('token_version', sa.Integer(), server_default='0', nullable=False))
        batch.create_index('ix_users_school_id', ['school_id'])
        batch.create_foreign_key('fk_users_school_id', 'schools', ['school_id'], ['id'], ondelete='RESTRICT')

    # Backfill: all existing institution users -> one 'DEFAULT' school.
    bind = op.get_bind()
    roles = ", ".join(f"'{r}'" for r in INSTITUTION_ROLES)
    existing = bind.execute(sa.text(f"SELECT COUNT(*) FROM users WHERE role IN ({roles})")).scalar()
    if existing:
        bind.execute(sa.text("INSERT INTO schools (code, name) VALUES ('DEFAULT', 'Default School')"))
        school_id = bind.execute(sa.text("SELECT id FROM schools WHERE code = 'DEFAULT'")).scalar()
        bind.execute(
            sa.text(f"UPDATE users SET school_id = :sid WHERE role IN ({roles}) AND school_id IS NULL"),
            {"sid": school_id},
        )


def downgrade() -> None:
    with op.batch_alter_table('users') as batch:
        batch.drop_constraint('fk_users_school_id', type_='foreignkey')
        batch.drop_index('ix_users_school_id')
        batch.drop_column('token_version')
        batch.drop_column('school_id')
    op.drop_index('ix_schools_code', table_name='schools')
    op.drop_table('schools')
