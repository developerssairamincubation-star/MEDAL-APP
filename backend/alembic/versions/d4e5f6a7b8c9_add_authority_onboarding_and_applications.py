"""add_authority_onboarding_and_applications

Revision ID: d4e5f6a7b8c9
Revises: c1f57b649d21
Create Date: 2026-10-24 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4e5f6a7b8c9'
down_revision: Union[str, Sequence[str], None] = 'c1f57b649d21'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add authority profile and approval columns to users
    op.add_column(
        'users',
        sa.Column('approval_status', sa.String(length=32), nullable=False, server_default='approved'),
    )
    op.create_index('ix_users_approval_status', 'users', ['approval_status'])
    op.add_column(
        'users',
        sa.Column('designation', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'users',
        sa.Column('department', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'users',
        sa.Column('jurisdiction', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'users',
        sa.Column('clearance_level', sa.String(length=128), nullable=True),
    )

    # 2. Create authority_applications table
    op.create_table(
        'authority_applications',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('official_email', sa.String(length=255), nullable=False),
        sa.Column('official_phone', sa.String(length=64), nullable=True),
        sa.Column('designation', sa.String(length=255), nullable=False),
        sa.Column('department', sa.String(length=255), nullable=False),
        sa.Column('jurisdiction', sa.String(length=255), nullable=False),
        sa.Column('identity_number', sa.String(length=64), nullable=True),
        sa.Column(
            'clearance_level',
            sa.String(length=128),
            nullable=False,
            server_default='Level 2 (Inspection & Resolution Lead)',
        ),
        sa.Column('aadhaar_document_url', sa.String(length=1024), nullable=False),
        sa.Column('employment_document_url', sa.String(length=1024), nullable=False),
        sa.Column('status', sa.String(length=32), nullable=False, server_default='pending'),
        sa.Column('rejection_reason', sa.Text(), nullable=True),
        sa.Column('reviewed_by_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_authority_applications_user_id', 'authority_applications', ['user_id'])
    op.create_index('ix_authority_applications_official_email', 'authority_applications', ['official_email'])
    op.create_index('ix_authority_applications_status', 'authority_applications', ['status'])


def downgrade() -> None:
    op.drop_index('ix_authority_applications_status', table_name='authority_applications')
    op.drop_index('ix_authority_applications_official_email', table_name='authority_applications')
    op.drop_index('ix_authority_applications_user_id', table_name='authority_applications')
    op.drop_table('authority_applications')

    op.drop_column('users', 'clearance_level')
    op.drop_column('users', 'jurisdiction')
    op.drop_column('users', 'department')
    op.drop_column('users', 'designation')
    op.drop_index('ix_users_approval_status', table_name='users')
    op.drop_column('users', 'approval_status')
