// lib/features/institution/models/classroom.dart
// Place at: lib/features/institution/models/classroom.dart

class Classroom {
  final String id;
  final String courseId;
  final String courseTitle;
  final String staffId;
  final int studentCount;
  final double completionPct;

  const Classroom({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.staffId,
    required this.studentCount,
    required this.completionPct,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) => Classroom(
        id: json['id'] as String,
        courseId: json['courseId'] as String,
        courseTitle: json['courseTitle'] as String,
        staffId: json['staffId'] as String,
        studentCount: json['studentCount'] as int,
        completionPct: (json['completionPct'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'staffId': staffId,
        'studentCount': studentCount,
        'completionPct': completionPct,
      };

  Classroom copyWith({
    String? id,
    String? courseId,
    String? courseTitle,
    String? staffId,
    int? studentCount,
    double? completionPct,
  }) =>
      Classroom(
        id: id ?? this.id,
        courseId: courseId ?? this.courseId,
        courseTitle: courseTitle ?? this.courseTitle,
        staffId: staffId ?? this.staffId,
        studentCount: studentCount ?? this.studentCount,
        completionPct: completionPct ?? this.completionPct,
      );
}
