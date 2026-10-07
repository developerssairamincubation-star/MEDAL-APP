"""add_latitude_longitude_location_address_to_complaints

Revision ID: 32deec9ad842
Revises: 72428e792eb8
Create Date: 2026-10-06 14:59:38.423702

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '32deec9ad842'
down_revision: Union[str, Sequence[str], None] = '72428e792eb8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('complaints', sa.Column('latitude', sa.Float(), nullable=True))
    op.add_column('complaints', sa.Column('longitude', sa.Float(), nullable=True))
    op.add_column('complaints', sa.Column('location_address', sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('complaints', 'location_address')
    op.drop_column('complaints', 'longitude')
    op.drop_column('complaints', 'latitude')
