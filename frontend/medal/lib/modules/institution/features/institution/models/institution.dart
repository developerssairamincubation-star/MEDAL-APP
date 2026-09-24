// lib/features/institution/models/institution.dart
// Place at: lib/features/institution/models/institution.dart

class Institution {
  final String id;
  final String name;
  final int activeStudents;
  final int totalFaculty;
  final String? logoUrl;

  const Institution({
    required this.id,
    required this.name,
    required this.activeStudents,
    required this.totalFaculty,
    this.logoUrl,
  });

  factory Institution.fromJson(Map<String, dynamic> json) => Institution(
        id: json['id'] as String,
        name: json['name'] as String,
        activeStudents: json['activeStudents'] as int,
        totalFaculty: json['totalFaculty'] as int,
        logoUrl: json['logoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'activeStudents': activeStudents,
        'totalFaculty': totalFaculty,
        'logoUrl': logoUrl,
      };

  Institution copyWith({
    String? id,
    String? name,
    int? activeStudents,
    int? totalFaculty,
    String? logoUrl,
  }) =>
      Institution(
        id: id ?? this.id,
        name: name ?? this.name,
        activeStudents: activeStudents ?? this.activeStudents,
        totalFaculty: totalFaculty ?? this.totalFaculty,
        logoUrl: logoUrl ?? this.logoUrl,
      );
}
