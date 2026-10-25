import sys
sys.path.insert(0, r"e:\MEDAL\MEDAL-APP-main\backend")

from sqlalchemy import text
from app.database.database import engine, SessionLocal, Base
from app.models.user import User
from app.models.student import StudentCourse, StudentEnrollment, StudentCertificate, StudentNotification
from app.utils.security import hash_password

def migrate_and_seed():
    print("1. Ensuring columns on users table...")
    with engine.connect() as conn:
        # Add columns if not exist
        conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS student_id VARCHAR(64);"))
        conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS registration_number VARCHAR(64);"))
        conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS preferences VARCHAR(512);"))
        conn.commit()
    print("Columns verified on users table.")

    print("2. Creating student tables if not exist...")
    Base.metadata.create_all(bind=engine)
    print("Tables created.")

    print("3. Seeding student data...")
    db = SessionLocal()
    try:
        # Seed or update student user: Kajol Misra
        student = db.query(User).filter(User.email == "kajolmisra@medal.gov").first()
        if not student:
            student = User(
                email="kajolmisra@medal.gov",
                password_hash=hash_password("Password123!"),
                full_name="Kajol Misra",
                phone="+91 93870 98213",
                role="student",
                department="Mathematics Department",
                student_id="med24cs123",
                registration_number="24123456789",
                preferences="Maths , Physics , Biology",
                approval_status="approved",
                is_active=True,
                is_verified=True,
            )
            db.add(student)
            db.commit()
            db.refresh(student)
            print(f"Created student Kajol Misra (ID: {student.id})")
        else:
            student.role = "student"
            student.full_name = "Kajol Misra"
            student.phone = "+91 93870 98213"
            student.department = "Mathematics Department"
            student.student_id = "med24cs123"
            student.registration_number = "24123456789"
            student.preferences = "Maths , Physics , Biology"
            db.commit()
            print(f"Updated student Kajol Misra (ID: {student.id})")

        # Also seed Dilli Ganesh (from Screenshot 4)
        student2 = db.query(User).filter(User.email == "dilli.ganesh@medal.gov").first()
        if not student2:
            student2 = User(
                email="dilli.ganesh@medal.gov",
                password_hash=hash_password("Password123!"),
                full_name="Dilli Ganesh",
                phone="+91 98401 23456",
                role="student",
                department="Computer Science",
                student_id="med24cs101",
                registration_number="24123456701",
                preferences="Computer Science , AI",
                approval_status="approved",
                is_active=True,
                is_verified=True,
            )
            db.add(student2)
            db.commit()
            db.refresh(student2)
            print(f"Created student Dilli Ganesh (ID: {student2.id})")

        # Seed Courses
        courses_data = [
            {
                "id": 1,
                "title": "SEEK COURSE 1",
                "provider": "UNESCO",
                "department": "Foundational Learning",
                "category": "SDG 15",
                "duration": "4h",
                "rating": 4.9,
                "description": "Foundational socio-emotional and environmental knowledge course covering biodiversity, ecosystem resilience, and sustainable community leadership.",
                "what_you_will_learn": "SEEK basics and key concepts\nEcosystem resilience models\nHands-on community reporting\nGlobal sustainability guidelines",
                "language": "English",
                "certificate_available": True,
                "enrollment_deadline": "26 October 2026",
                "deadline_remaining_text": "Completed",
                "image_url": "assets/images/sample_mountain.jpg",
                "total_modules": 5,
            },
            {
                "id": 2,
                "title": "SEEK COURSE 2",
                "provider": "UNESCO",
                "department": "Social Sciences",
                "category": "EMPATHY",
                "duration": "6h",
                "rating": 4.7,
                "description": "Empathy-driven social innovation and citizen action for municipal problem diagnosis and collaborative civic problem-solving.",
                "what_you_will_learn": "Empathy-driven problem discovery\nCommunity interview techniques\nStakeholder mapping\nEthics in civic participation",
                "language": "English",
                "certificate_available": True,
                "enrollment_deadline": "30 October 2026",
                "deadline_remaining_text": "In Progress",
                "image_url": "assets/images/sample_chart.jpg",
                "total_modules": 6,
            },
            {
                "id": 3,
                "title": "SEEK COURSE 3",
                "provider": "UNESCO",
                "department": "Public Policy",
                "category": "LEADERSHIP",
                "duration": "3h",
                "rating": 4.8,
                "description": "Strategic leadership in youth governance, evidence collation, and SDG-aligned public advocacy campaigns.",
                "what_you_will_learn": "Youth leadership strategies\nEvidence verification fundamentals\nPolicy alignment frameworks\nDigital public engagement",
                "language": "English",
                "certificate_available": True,
                "enrollment_deadline": "15 November 2026",
                "deadline_remaining_text": "Open",
                "image_url": "assets/images/sample_team.jpg",
                "total_modules": 4,
            },
            {
                "id": 4,
                "title": "SEEK COURSE 4",
                "provider": "UNESCO",
                "department": "Ethics & Civic Wellness",
                "category": "MINDFULNESS",
                "duration": "4 Weeks",
                "rating": 4.6,
                "description": "Learn the fundamentals of SEEK, from key concepts to real-world applications and best practices in public institutional welfare.",
                "what_you_will_learn": "SEEK basics and key concepts\nPopular SEEK service models\nHands-on labs with real-world tools\nSecurity and scalability best practices",
                "language": "English",
                "certificate_available": True,
                "enrollment_deadline": "25 October 2026",
                "deadline_remaining_text": "2 days left",
                "image_url": "assets/images/sample_building.jpg",
                "total_modules": 4,
            },
            {
                "id": 5,
                "title": "SEEK COURSE 5",
                "provider": "UNESCO",
                "department": "Urban Ecology",
                "category": "SDG 11",
                "duration": "3 Weeks",
                "rating": 4.8,
                "description": "Urban ecological interventions and smart municipal complaint monitoring frameworks for sustainable cities.",
                "what_you_will_learn": "Smart urban infrastructure\nWaste stream monitoring\nRenewable community grids\nPublic grievance management",
                "language": "English",
                "certificate_available": True,
                "enrollment_deadline": "05 November 2026",
                "deadline_remaining_text": "11 days left",
                "image_url": "assets/images/sample_mountain.jpg",
                "total_modules": 4,
            },
            {
                "id": 6,
                "title": "SEEK COURSE 6",
                "provider": "UNESCO",
                "department": "Data Science",
                "category": "ANALYTICS",
                "duration": "5 Weeks",
                "rating": 4.9,
                "description": "Advanced analytics and geospatial telemetry data interpretation for evidence-based governance.",
                "what_you_will_learn": "Geospatial data mapping\nEvidence verification pipelines\nPredictive maintenance alerts\nStatistical impact quantification",
                "language": "English",
                "certificate_available": True,
                "enrollment_deadline": "20 November 2026",
                "deadline_remaining_text": "26 days left",
                "image_url": "assets/images/sample_chart.jpg",
                "total_modules": 5,
            },
        ]

        for cd in courses_data:
            existing_c = db.query(StudentCourse).filter(StudentCourse.id == cd["id"]).first()
            if not existing_c:
                c = StudentCourse(**cd)
                db.add(c)
            else:
                for k, v in cd.items():
                    setattr(existing_c, k, v)
        db.commit()
        print("Courses seeded.")

        # Seed Enrollments for Kajol Misra and Dilli Ganesh
        for u in [student, student2]:
            # Enrollment 1: Course 1 (completed)
            if not db.query(StudentEnrollment).filter(StudentEnrollment.user_id == u.id, StudentEnrollment.course_id == 1).first():
                db.add(StudentEnrollment(
                    user_id=u.id,
                    course_id=1,
                    status="completed",
                    progress_pct=1.0,
                    completed_modules=5,
                    start_date="06 Oct 2026",
                    end_date="26 Oct 2026",
                    credits_earned=60,
                ))

            # Enrollment 2: Course 2 (in progress)
            if not db.query(StudentEnrollment).filter(StudentEnrollment.user_id == u.id, StudentEnrollment.course_id == 2).first():
                db.add(StudentEnrollment(
                    user_id=u.id,
                    course_id=2,
                    status="enrolled",
                    progress_pct=0.32,
                    completed_modules=2,
                    start_date="09 Oct 2026",
                    end_date="30 Oct 2026",
                    credits_earned=55,
                ))

            # Enrollment 3: Course 3 (enrolled)
            if not db.query(StudentEnrollment).filter(StudentEnrollment.user_id == u.id, StudentEnrollment.course_id == 3).first():
                db.add(StudentEnrollment(
                    user_id=u.id,
                    course_id=3,
                    status="enrolled",
                    progress_pct=0.10,
                    completed_modules=1,
                    start_date="12 Oct 2026",
                    end_date="15 Nov 2026",
                    credits_earned=0,
                ))

            # Pending Enrollment 4: Course 4
            if not db.query(StudentEnrollment).filter(StudentEnrollment.user_id == u.id, StudentEnrollment.course_id == 4).first():
                db.add(StudentEnrollment(
                    user_id=u.id,
                    course_id=4,
                    status="pending",
                    progress_pct=0.0,
                    completed_modules=0,
                    start_date=None,
                    end_date=None,
                    credits_earned=0,
                ))

            # Pending Enrollment 5: Course 5
            if not db.query(StudentEnrollment).filter(StudentEnrollment.user_id == u.id, StudentEnrollment.course_id == 5).first():
                db.add(StudentEnrollment(
                    user_id=u.id,
                    course_id=5,
                    status="pending",
                    progress_pct=0.0,
                    completed_modules=0,
                    start_date=None,
                    end_date=None,
                    credits_earned=0,
                ))

            # Seed Certificates (Screenshot 8)
            cert_no_1 = "MED-55219-X04" if u.id == student.id else "MED-55219-X05"
            cert_no_2 = "MED-1102-G12" if u.id == student.id else "MED-1102-G13"

            if not db.query(StudentCertificate).filter(StudentCertificate.user_id == u.id, StudentCertificate.certificate_no == cert_no_1).first():
                db.add(StudentCertificate(
                    user_id=u.id,
                    title="SEEK Foundation & Ecological Awareness",
                    certificate_no=cert_no_1,
                    completed_date_str="COMPLETED MAY 2024",
                    issuing_institution="Academic Excellence Academy",
                    badge_type="verified",
                ))

            if not db.query(StudentCertificate).filter(StudentCertificate.user_id == u.id, StudentCertificate.certificate_no == cert_no_2).first():
                db.add(StudentCertificate(
                    user_id=u.id,
                    title="Community Empathy & Civic Problem Discovery",
                    certificate_no=cert_no_2,
                    completed_date_str="COMPLETED FEB 2024",
                    issuing_institution="Academic Excellence Academy",
                    badge_type="star",
                ))

            # Seed Notifications (Screenshot 12)
            existing_notifs = db.query(StudentNotification).filter(StudentNotification.user_id == u.id).count()
            if existing_notifs == 0:
                db.add_all([
                    StudentNotification(
                        user_id=u.id,
                        category="Academy",
                        title="Course Progress Reminder",
                        description="Course 20% pending... we would love to see your progress",
                        period_group="last_7_days",
                    ),
                    StudentNotification(
                        user_id=u.id,
                        category="Certificate Issued",
                        title="Certificate Issued",
                        description="3 certificates have been issued",
                        period_group="last_7_days",
                    ),
                    StudentNotification(
                        user_id=u.id,
                        category="Academy",
                        title="Course Completion",
                        description="Course 1 successfully completed. View the certificate",
                        period_group="last_30_days",
                    ),
                    StudentNotification(
                        user_id=u.id,
                        category="Streak Maintenance",
                        title="Streak Maintenance",
                        description="Continuous 21 days of streaks maintained",
                        period_group="last_30_days",
                    ),
                    StudentNotification(
                        user_id=u.id,
                        category="Learning Spree",
                        title="Learning Spree",
                        description="Learning is being spontaneous",
                        period_group="last_30_days",
                    ),
                ])

        db.commit()
        print("Enrollments, Certificates, and Notifications seeded successfully.")

    finally:
        db.close()

if __name__ == "__main__":
    migrate_and_seed()
