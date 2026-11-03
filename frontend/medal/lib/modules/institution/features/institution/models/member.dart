// lib/modules/institution/features/institution/models/member.dart
// Staff / student rows and the institution overview, exactly as the API returns them.

enum MemberStatus { completed, inProgress, notStarted }

extension MemberStatusLabel on MemberStatus {
  String get label {
    switch (this) {
      case MemberStatus.completed:
        return 'COMPLETED';
      case MemberStatus.inProgress:
        return 'IN PROGRESS';
      case MemberStatus.notStarted:
        return 'NOT STARTED';
    }
  }
}

class InstitutionMember {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? department;
  final String? designation;
  final String? studentId;
  final int completedChapters;
  final int totalChapters;
  final double progressPct;
  final MemberStatus status;
  final DateTime? lastActive;

  const InstitutionMember({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.department,
    this.designation,
    this.studentId,
    required this.completedChapters,
    required this.totalChapters,
    required this.progressPct,
    required this.status,
    this.lastActive,
  });

  factory InstitutionMember.fromJson(Map<String, dynamic> json) =>
      InstitutionMember(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        phone: json['phone'] as String?,
        role: (json['role'] ?? '') as String,
        department: json['department'] as String?,
        designation: json['designation'] as String?,
        studentId: json['student_id'] as String?,
        completedChapters: (json['completed_chapters'] ?? 0) as int,
        totalChapters: (json['total_chapters'] ?? 0) as int,
        progressPct: ((json['progress_pct'] ?? 0) as num).toDouble(),
        status: switch (json['status']) {
          'completed' => MemberStatus.completed,
          'in_progress' => MemberStatus.inProgress,
          _ => MemberStatus.notStarted,
        },
        lastActive: json['last_active'] == null
            ? null
            : DateTime.tryParse(json['last_active'] as String),
      );

  /// "Mathematics" / "Senior Lead" style subtitle, whichever the account has.
  String get subtitle {
    final parts = [designation, department, studentId]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? email : parts.join(' • ');
  }
}

class ActivityEntry {
  final String name;
  final String role;
  final String action;
  final String timeAgo;

  const ActivityEntry({
    required this.name,
    required this.role,
    required this.action,
    required this.timeAgo,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        name: (json['name'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        action: (json['action'] ?? '') as String,
        timeAgo: (json['time_ago'] ?? '') as String,
      );
}

class InstitutionOverview {
  final int totalStaff;
  final int totalStudents;
  final int certificationReady;
  final int activeStudents;
  final int inactiveStudents;
  final int enrollmentPending;
  final List<ActivityEntry> recentActivity;

  const InstitutionOverview({
    required this.totalStaff,
    required this.totalStudents,
    required this.certificationReady,
    required this.activeStudents,
    required this.inactiveStudents,
    required this.enrollmentPending,
    required this.recentActivity,
  });

  factory InstitutionOverview.fromJson(Map<String, dynamic> json) =>
      InstitutionOverview(
        totalStaff: (json['total_staff'] ?? 0) as int,
        totalStudents: (json['total_students'] ?? 0) as int,
        certificationReady: (json['certification_ready'] ?? 0) as int,
        activeStudents: (json['active_students'] ?? 0) as int,
        inactiveStudents: (json['inactive_students'] ?? 0) as int,
        enrollmentPending: (json['enrollment_pending'] ?? 0) as int,
        recentActivity: ((json['recent_activity'] ?? []) as List)
            .map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isEmpty => totalStaff == 0 && totalStudents == 0;
}

/// One member plus their per-chapter SEEK progress.
class MemberProgress {
  final InstitutionMember member;
  final List<Map<String, dynamic>> modules;

  const MemberProgress({required this.member, required this.modules});

  factory MemberProgress.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>?;
    return MemberProgress(
      member: InstitutionMember.fromJson(json['member'] as Map<String, dynamic>),
      modules: List<Map<String, dynamic>>.from(
        ((course?['modules'] ?? []) as List)
            .map((m) => Map<String, dynamic>.from(m as Map)),
      ),
    );
  }
}

class NewStaffResult {
  final InstitutionMember staff;
  final String temporaryPassword;

  const NewStaffResult({required this.staff, required this.temporaryPassword});
}

/// Result of adding one student by e-mail (POST /institution/students/invite).
class StudentInviteResult {
  final InstitutionMember student;
  final bool emailSent;

  /// Only present when the invite e-mail could not be sent, so the teacher can pass it on.
  final String? temporaryPassword;
  final String message;
  final String? error;

  const StudentInviteResult({
    required this.student,
    required this.emailSent,
    required this.message,
    this.temporaryPassword,
    this.error,
  });

  factory StudentInviteResult.fromJson(Map<String, dynamic> json) => StudentInviteResult(
        student: InstitutionMember.fromJson(json['student'] as Map<String, dynamic>),
        emailSent: json['email_sent'] == true,
        temporaryPassword: json['temporary_password'] as String?,
        message: (json['message'] ?? '') as String,
        error: json['error'] as String?,
      );
}

class CsvRowError {
  final int row;
  final String email;
  final String error;

  const CsvRowError({required this.row, required this.email, required this.error});
}

/// Result of a CSV upload (POST /institution/students/bulk).
class BulkInviteResult {
  final int totalRows;
  final int created;
  final int failed;
  final int invitesQueued;
  final List<CsvRowError> errors;

  /// Dev only: when the server has no e-mail provider it returns the passwords instead.
  final List<Map<String, String>> credentials;

  const BulkInviteResult({
    required this.totalRows,
    required this.created,
    required this.failed,
    required this.invitesQueued,
    required this.errors,
    required this.credentials,
  });

  factory BulkInviteResult.fromJson(Map<String, dynamic> json) => BulkInviteResult(
        totalRows: (json['total_rows'] ?? 0) as int,
        created: (json['created'] ?? 0) as int,
        failed: (json['failed'] ?? 0) as int,
        invitesQueued: (json['invites_queued'] ?? 0) as int,
        errors: [
          for (final e in (json['errors'] as List? ?? const []))
            CsvRowError(
              row: (e['row'] ?? 0) as int,
              email: (e['email'] ?? '').toString(),
              error: (e['error'] ?? '').toString(),
            ),
        ],
        credentials: [
          for (final c in (json['credentials'] as List? ?? const []))
            {'email': '${c['email']}', 'temporary_password': '${c['temporary_password']}'},
        ],
      );
}

/// The signed-in user's own SEEK progress (same data the student screens show).
class OwnProgress {
  final int completedChapters;
  final int totalChapters;
  final int percent;
  final int certificates;
  final List<String> recentChapters;

  const OwnProgress({
    required this.completedChapters,
    required this.totalChapters,
    required this.percent,
    required this.certificates,
    required this.recentChapters,
  });
}
