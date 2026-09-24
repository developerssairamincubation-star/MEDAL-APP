// lib/features/institution/models/course.dart
// Place at: lib/features/institution/models/course.dart

class Course {
  final String id;
  final String title;
  final String department;
  final double completionPct;
  final String? description;
  final String staffId;

  const Course({
    required this.id,
    required this.title,
    required this.department,
    required this.completionPct,
    this.description,
    required this.staffId,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        title: json['title'] as String,
        department: json['department'] as String,
        completionPct: (json['completionPct'] as num).toDouble(),
        description: json['description'] as String?,
        staffId: json['staffId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'department': department,
        'completionPct': completionPct,
        'description': description,
        'staffId': staffId,
      };

  Course copyWith({
    String? id,
    String? title,
    String? department,
    double? completionPct,
    String? description,
    String? staffId,
  }) =>
      Course(
        id: id ?? this.id,
        title: title ?? this.title,
        department: department ?? this.department,
        completionPct: completionPct ?? this.completionPct,
        description: description ?? this.description,
        staffId: staffId ?? this.staffId,
      );
}
