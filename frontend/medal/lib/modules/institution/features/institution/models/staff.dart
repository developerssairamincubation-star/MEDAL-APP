// lib/features/institution/models/staff.dart
// Place at: lib/features/institution/models/staff.dart

enum StaffStatus { active, inProgress, inactive }

extension StaffStatusExtension on StaffStatus {
  String get label {
    switch (this) {
      case StaffStatus.active:
        return 'ACTIVE';
      case StaffStatus.inProgress:
        return 'IN PROGRESS';
      case StaffStatus.inactive:
        return 'INACTIVE';
    }
  }
}

class Staff {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String department;
  final String jobTitle;
  final int studentCount;
  final double completionPct;
  final int certificates;
  final StaffStatus status;
  final String institutionId;
  final String role;

  const Staff({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.department,
    required this.jobTitle,
    required this.studentCount,
    required this.completionPct,
    this.certificates = 0,
    this.status = StaffStatus.active,
    required this.institutionId,
    this.role = 'staff',
  });

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        department: json['department'] as String,
        jobTitle: json['jobTitle'] as String,
        studentCount: json['studentCount'] as int,
        completionPct: (json['completionPct'] as num).toDouble(),
        certificates: json['certificates'] as int? ?? 0,
        status: StaffStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => StaffStatus.active,
        ),
        institutionId: json['institutionId'] as String,
        role: json['role'] as String? ?? 'staff',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'department': department,
        'jobTitle': jobTitle,
        'studentCount': studentCount,
        'completionPct': completionPct,
        'certificates': certificates,
        'status': status.name,
        'institutionId': institutionId,
        'role': role,
      };

  Staff copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? department,
    String? jobTitle,
    int? studentCount,
    double? completionPct,
    int? certificates,
    StaffStatus? status,
    String? institutionId,
    String? role,
  }) =>
      Staff(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        department: department ?? this.department,
        jobTitle: jobTitle ?? this.jobTitle,
        studentCount: studentCount ?? this.studentCount,
        completionPct: completionPct ?? this.completionPct,
        certificates: certificates ?? this.certificates,
        status: status ?? this.status,
        institutionId: institutionId ?? this.institutionId,
        role: role ?? this.role,
      );
}
