"""add student / institution tables and student columns on users

Revision ID: a7b8c9d0e1f2
Revises: f6a7b8c9d0e1
Create Date: 2026-11-03 00:00:00.000000

These tables were previously created by a one-off seed script. They are now part
of the migration chain so a fresh database only needs `alembic upgrade head`.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a7b8c9d0e1f2'
down_revision: Union[str, Sequence[str], None] = 'f6a7b8c9d0e1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('student_id', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('registration_number', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('preferences', sa.String(length=512), nullable=True))

    now = sa.text('now()')

    op.create_table(
        'student_courses',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('provider', sa.String(length=128), nullable=False),
        sa.Column('department', sa.String(length=128), nullable=False),
        sa.Column('category', sa.String(length=64), nullable=False),
        sa.Column('duration', sa.String(length=64), nullable=False),
        sa.Column('rating', sa.Float(), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('what_you_will_learn', sa.Text(), nullable=True),
        sa.Column('language', sa.String(length=64), nullable=False),
        sa.Column('certificate_available', sa.Boolean(), nullable=False),
        sa.Column('enrollment_deadline', sa.String(length=64), nullable=True),
        sa.Column('deadline_remaining_text', sa.String(length=64), nullable=True),
        sa.Column('image_url', sa.String(length=512), nullable=True),
        sa.Column('total_modules', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=now, nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_student_courses_id', 'student_courses', ['id'])

    op.create_table(
        'student_enrollments',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('course_id', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=32), nullable=False),
        sa.Column('progress_pct', sa.Float(), nullable=False),
        sa.Column('completed_modules', sa.Integer(), nullable=False),
        sa.Column('start_date', sa.String(length=64), nullable=True),
        sa.Column('end_date', sa.String(length=64), nullable=True),
        sa.Column('credits_earned', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=now, nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['course_id'], ['student_courses.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_student_enrollments_id', 'student_enrollments', ['id'])
    op.create_index('ix_student_enrollments_user_id', 'student_enrollments', ['user_id'])
    op.create_index('ix_student_enrollments_course_id', 'student_enrollments', ['course_id'])

    op.create_table(
        'student_certificates',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('certificate_no', sa.String(length=128), nullable=False),
        sa.Column('completed_date_str', sa.String(length=64), nullable=False),
        sa.Column('issuing_institution', sa.String(length=128), nullable=False),
        sa.Column('badge_type', sa.String(length=64), nullable=False),
        sa.Column('download_url', sa.String(length=512), nullable=True),
        sa.Column('certificate_public_id', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=now, nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('certificate_no'),
    )
    op.create_index('ix_student_certificates_id', 'student_certificates', ['id'])
    op.create_index('ix_student_certificates_user_id', 'student_certificates', ['user_id'])

    op.create_table(
        'student_notifications',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('category', sa.String(length=64), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('period_group', sa.String(length=32), nullable=False),
        sa.Column('is_read', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=now, nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_student_notifications_id', 'student_notifications', ['id'])
    op.create_index('ix_student_notifications_user_id', 'student_notifications', ['user_id'])

    op.create_table(
        'student_course_chapters',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('course_id', sa.Integer(), nullable=False),
        sa.Column('chapter_key', sa.String(length=64), nullable=False),
        sa.Column('position', sa.Integer(), nullable=False),
        sa.Column('module_number', sa.Integer(), nullable=False),
        sa.Column('module_title', sa.String(length=255), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('chapter_type', sa.String(length=32), nullable=False),
        sa.Column('duration', sa.String(length=32), nullable=False),
        sa.Column('content_url', sa.String(length=1024), nullable=True),
        sa.ForeignKeyConstraint(['course_id'], ['student_courses.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('course_id', 'chapter_key', name='uq_course_chapter_key'),
    )
    op.create_index('ix_student_course_chapters_id', 'student_course_chapters', ['id'])
    op.create_index('ix_student_course_chapters_course_id', 'student_course_chapters', ['course_id'])

    op.create_table(
        'student_chapter_completions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('chapter_id', sa.Integer(), nullable=False),
        sa.Column('completed_at', sa.DateTime(timezone=True), server_default=now, nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['chapter_id'], ['student_course_chapters.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'chapter_id', name='uq_user_chapter_completion'),
    )
    op.create_index('ix_student_chapter_completions_id', 'student_chapter_completions', ['id'])
    op.create_index('ix_student_chapter_completions_user_id', 'student_chapter_completions', ['user_id'])
    op.create_index('ix_student_chapter_completions_chapter_id', 'student_chapter_completions', ['chapter_id'])


def downgrade() -> None:
    op.drop_table('student_chapter_completions')
    op.drop_table('student_course_chapters')
    op.drop_table('student_notifications')
    op.drop_table('student_certificates')
    op.drop_table('student_enrollments')
    op.drop_table('student_courses')
    op.drop_column('users', 'preferences')
    op.drop_column('users', 'registration_number')
    op.drop_column('users', 'student_id')
