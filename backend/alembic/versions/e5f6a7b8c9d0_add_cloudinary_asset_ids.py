"""add_cloudinary_asset_ids

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-10-26 23:05:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e5f6a7b8c9d0'
down_revision: Union[str, Sequence[str], None] = 'd4e5f6a7b8c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add image_public_id to complaints
    op.add_column(
        'complaints',
        sa.Column('image_public_id', sa.String(length=255), nullable=True),
    )

    # 2. Add image_public_id to complaint_comments
    op.add_column(
        'complaint_comments',
        sa.Column('image_public_id', sa.String(length=255), nullable=True),
    )

    # 3. Add profile_image_public_id to users
    op.add_column(
        'users',
        sa.Column('profile_image_public_id', sa.String(length=255), nullable=True),
    )

    # 4. Add document public IDs to authority_applications
    op.add_column(
        'authority_applications',
        sa.Column('aadhaar_public_id', sa.String(length=255), nullable=True),
    )
    op.add_column(
        'authority_applications',
        sa.Column('employment_public_id', sa.String(length=255), nullable=True),
    )

    # 5. Add certificate_public_id to student_certificates if table exists
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()
    if 'student_certificates' in tables:
        op.add_column(
            'student_certificates',
            sa.Column('certificate_public_id', sa.String(length=255), nullable=True),
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'student_certificates' in tables:
        op.drop_column('student_certificates', 'certificate_public_id')
    op.drop_column('authority_applications', 'employment_public_id')
    op.drop_column('authority_applications', 'aadhaar_public_id')
    op.drop_column('users', 'profile_image_public_id')
    op.drop_column('complaint_comments', 'image_public_id')
    op.drop_column('complaints', 'image_public_id')
