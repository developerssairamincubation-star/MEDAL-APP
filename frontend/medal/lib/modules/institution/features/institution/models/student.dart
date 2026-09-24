// lib/features/institution/models/student.dart
// Place at: lib/features/institution/models/student.dart

enum StudentStatus { activeLearning, needsSupport, inactive }

extension StudentStatusExtension on StudentStatus {
  String get label {
    switch (this) {
      case StudentStatus.activeLearning:
        return 'ACTIVE LEARNING';
      case StudentStatus.needsSupport:
        return 'NEEDS SUPPORT';
      case StudentStatus.inactive:
        return 'INACTIVE';
    }
  }
}

enum ChapterStatus { completed, inProgress, locked }

class ChapterProgress {
  final String id;
  final int number;
  final String title;
  final ChapterStatus status;
  final String? grade;
  final String? completedOn;
  final double? progressPct;

  const ChapterProgress({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    this.grade,
    this.completedOn,
    this.progressPct,
  });

  factory ChapterProgress.fromJson(Map<String, dynamic> json) => ChapterProgress(
        id: json['id'] as String,
        number: json['number'] as int,
        title: json['title'] as String,
        status: ChapterStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ChapterStatus.locked,
        ),
        grade: json['grade'] as String?,
        completedOn: json['completedOn'] as String?,
        progressPct: (json['progressPct'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'title': title,
        'status': status.name,
        'grade': grade,
        'completedOn': completedOn,
        'progressPct': progressPct,
      };
}

class Student {
  final String id;
  final String name;
  final String grade;
  final String subject;
  final double completionPct;
  final double avgQuizScore;
  final String lastActive;
  final StudentStatus status;
  final String? avatarUrl;
  final List<ChapterProgress> chapters;
  final String classroomId;

  const Student({
    required this.id,
    required this.name,
    required this.grade,
    required this.subject,
    required this.completionPct,
    required this.avgQuizScore,
    required this.lastActive,
    required this.status,
    this.avatarUrl,
    required this.chapters,
    required this.classroomId,
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        name: json['name'] as String,
        grade: json['grade'] as String,
        subject: json['subject'] as String,
        completionPct: (json['completionPct'] as num).toDouble(),
        avgQuizScore: (json['avgQuizScore'] as num).toDouble(),
        lastActive: json['lastActive'] as String,
        status: StudentStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => StudentStatus.activeLearning,
        ),
        avatarUrl: json['avatarUrl'] as String?,
        chapters: (json['chapters'] as List<dynamic>)
            .map((c) => ChapterProgress.fromJson(c as Map<String, dynamic>))
            .toList(),
        classroomId: json['classroomId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'grade': grade,
        'subject': subject,
        'completionPct': completionPct,
        'avgQuizScore': avgQuizScore,
        'lastActive': lastActive,
        'status': status.name,
        'avatarUrl': avatarUrl,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'classroomId': classroomId,
      };

  Student copyWith({
    String? id,
    String? name,
    String? grade,
    String? subject,
    double? completionPct,
    double? avgQuizScore,
    String? lastActive,
    StudentStatus? status,
    String? avatarUrl,
    List<ChapterProgress>? chapters,
    String? classroomId,
  }) =>
      Student(
        id: id ?? this.id,
        name: name ?? this.name,
        grade: grade ?? this.grade,
        subject: subject ?? this.subject,
        completionPct: completionPct ?? this.completionPct,
        avgQuizScore: avgQuizScore ?? this.avgQuizScore,
        lastActive: lastActive ?? this.lastActive,
        status: status ?? this.status,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        chapters: chapters ?? this.chapters,
        classroomId: classroomId ?? this.classroomId,
      );
}
