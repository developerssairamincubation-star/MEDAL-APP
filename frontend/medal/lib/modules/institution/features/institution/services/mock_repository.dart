// lib/features/institution/services/mock_repository.dart
// Place at: lib/features/institution/services/mock_repository.dart

import '../models/institution.dart';
import '../models/principal.dart';
import '../models/staff.dart';
import '../models/course.dart';
import '../models/classroom.dart';
import '../models/student.dart';

/// Central mock data store.
/// Replace with real API calls in production.
abstract final class MockRepository {
  // ── Institution ────────────────────────────────────────────────
  static const Institution institution = Institution(
    id: 'inst_001',
    name: 'Academic Excellence Academy',
    activeStudents: 1248,
    totalFaculty: 86,
  );

  // ── Principal ─────────────────────────────────────────────────
  static const Principal principal = Principal(
    id: 'usr_001',
    name: 'Steve Rogers',
    email: 'steverogers@medal.gov',
    phone: '+91 93870 98213',
    institutionId: 'inst_001',
    institution: institution,
    role: 'principal',
  );

  // ── Staff ─────────────────────────────────────────────────────
  static const List<Staff> staffList = [
    Staff(
      id: 'usr_002',
      name: 'Sarah Jenkins',
      email: 'kajolmisra@medal.gov',
      phone: '+91 93870 98213',
      department: 'Mathematics Department',
      jobTitle: 'Mathematics Department',
      studentCount: 45,
      completionPct: 0.75,
      certificates: 2,
      status: StaffStatus.active,
      institutionId: 'inst_001',
      role: 'staff',
    ),
    Staff(
      id: 'usr_003',
      name: 'Michael Chen',
      email: 'michael.chen@medal.gov',
      phone: '+91 93870 55421',
      department: 'Science',
      jobTitle: 'Senior Science Lead',
      studentCount: 32,
      completionPct: 0.42,
      certificates: 1,
      status: StaffStatus.inProgress,
      institutionId: 'inst_001',
      role: 'staff',
    ),
    Staff(
      id: 'usr_004',
      name: 'Elena Rodriguez',
      email: 'elena.rodriguez@medal.gov',
      phone: '+91 93870 77893',
      department: 'Arts',
      jobTitle: 'Literature & Arts',
      studentCount: 28,
      completionPct: 0.90,
      certificates: 3,
      status: StaffStatus.active,
      institutionId: 'inst_001',
      role: 'staff',
    ),
  ];

  // Current logged-in staff (first in list for mock)
  static Staff get currentStaff => staffList.first;

  // ── Courses ───────────────────────────────────────────────────
  static const List<Course> courses = [
    Course(
      id: 'crs_001',
      title: 'SEEK Foundation',
      department: 'Mathematics Department',
      completionPct: 0.75,
      description: 'Core mathematical foundations for SEEK certification.',
      staffId: 'usr_002',
    ),
    Course(
      id: 'crs_002',
      title: 'Science Essentials',
      department: 'Science',
      completionPct: 0.42,
      staffId: 'usr_003',
    ),
    Course(
      id: 'crs_003',
      title: 'Literature & Arts',
      department: 'Arts',
      completionPct: 0.90,
      staffId: 'usr_004',
    ),
  ];

  // ── Classrooms ────────────────────────────────────────────────
  static const List<Classroom> classrooms = [
    Classroom(
      id: 'cls_001',
      courseId: 'crs_001',
      courseTitle: 'SEEK Foundation',
      staffId: 'usr_002',
      studentCount: 30,
      completionPct: 0.75,
    ),
  ];

  // ── Students ──────────────────────────────────────────────────
  static const List<Student> students = [
    Student(
      id: 'stu_001',
      name: 'Alex Johnson',
      grade: 'Grade 11',
      subject: 'Computer Science',
      completionPct: 0.82,
      avgQuizScore: 91.0,
      lastActive: 'Today',
      status: StudentStatus.activeLearning,
      classroomId: 'cls_001',
      chapters: [
        ChapterProgress(
          id: 'ch_001',
          number: 1,
          title: 'Course Introduction',
          status: ChapterStatus.completed,
          grade: 'Grade: A',
          completedOn: 'Oct 12, 2023',
        ),
        ChapterProgress(
          id: 'ch_002',
          number: 2,
          title: 'Pre-Course Survey',
          status: ChapterStatus.completed,
          grade: 'Grade: B+',
          completedOn: 'Oct 28, 2023',
        ),
        ChapterProgress(
          id: 'ch_003',
          number: 3,
          title: 'Foundational Concepts',
          status: ChapterStatus.inProgress,
          progressPct: 0.33,
        ),
      ],
    ),
    Student(
      id: 'stu_002',
      name: 'Samantha Reed',
      grade: 'Grade 11',
      subject: 'Computer Science',
      completionPct: 0.24,
      avgQuizScore: 82.5,
      lastActive: 'Active 3 days ago',
      status: StudentStatus.needsSupport,
      classroomId: 'cls_001',
      chapters: [
        ChapterProgress(
          id: 'ch_004',
          number: 1,
          title: 'Course Introduction',
          status: ChapterStatus.completed,
          grade: 'Grade: A',
          completedOn: 'Oct 12, 2023',
        ),
        ChapterProgress(
          id: 'ch_005',
          number: 2,
          title: 'Pre-Course Survey',
          status: ChapterStatus.completed,
          grade: 'Grade: B+',
          completedOn: 'Oct 28, 2023',
        ),
        ChapterProgress(
          id: 'ch_006',
          number: 3,
          title: 'Foundational Concepts',
          status: ChapterStatus.inProgress,
          progressPct: 0.33,
        ),
      ],
    ),
    Student(
      id: 'stu_003',
      name: 'Marcus Lane',
      grade: 'Grade 10',
      subject: 'Mathematics',
      completionPct: 0.68,
      avgQuizScore: 78.0,
      lastActive: 'Today',
      status: StudentStatus.activeLearning,
      classroomId: 'cls_001',
      chapters: [
        ChapterProgress(
          id: 'ch_007',
          number: 1,
          title: 'Course Introduction',
          status: ChapterStatus.completed,
          grade: 'Grade: A-',
          completedOn: 'Oct 10, 2023',
        ),
        ChapterProgress(
          id: 'ch_008',
          number: 2,
          title: 'Pre-Course Survey',
          status: ChapterStatus.inProgress,
          progressPct: 0.60,
        ),
      ],
    ),
  ];

  // ── Dashboard Stats ───────────────────────────────────────────
  static const Map<String, dynamic> principalStats = {
    'totalStaff': 24,
    'totalStudents': 850,
    'certificationReady': 12,
    'activeStudents': 16,
    'inactiveStudents': 9,
    'enrollmentPending': 5,
  };

  static const Map<String, dynamic> staffStats = {
    'totalStudents': 850,
    'myClassroom': 30,
    'certificationReady': 12,
    'activeStudents': 16,
    'inactiveStudents': 9,
    'enrollmentPending': 5,
  };

  // ── Activity Feed ─────────────────────────────────────────────
  static const List<Map<String, dynamic>> recentActivity = [
    {
      'name': 'Ms. Elena Rivers',
      'time': '2m ago',
      'action': 'Completed SEEK course with 98% score.',
      'badges': ['CERTIFIED', 'BADGE: LEADER'],
    },
    {
      'name': 'Mr. John Doe',
      'time': '15m ago',
      'action': 'Started SEEK course.',
      'badges': ['IN PROGRESS'],
    },
  ];

  // ── Pending Invites ───────────────────────────────────────────
  static List<Map<String, dynamic>> pendingStudentInvites = [
    {
      'email': 'k.thompson@edu.com',
      'sentAt': 'Sent 2 hours ago',
    },
  ];

  // ── Credentials (for mock login) ──────────────────────────────
  static const Map<String, String> credentials = {
    'steverogers@medal.gov': 'principal',
    'kajolmisra@medal.gov': 'staff',
    'principal@medal.gov': 'principal',
    'staff@medal.gov': 'staff',
  };
}
