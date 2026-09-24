// lib/features/institution/models/principal.dart
// Place at: lib/features/institution/models/principal.dart

import 'institution.dart';

class Principal {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String institutionId;
  final Institution institution;
  final String role;

  const Principal({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.institutionId,
    required this.institution,
    this.role = 'principal',
  });

  factory Principal.fromJson(Map<String, dynamic> json) => Principal(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        institutionId: json['institutionId'] as String,
        institution: Institution.fromJson(
          json['institution'] as Map<String, dynamic>,
        ),
        role: json['role'] as String? ?? 'principal',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'institutionId': institutionId,
        'institution': institution.toJson(),
        'role': role,
      };

  Principal copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? institutionId,
    Institution? institution,
    String? role,
  }) =>
      Principal(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        institutionId: institutionId ?? this.institutionId,
        institution: institution ?? this.institution,
        role: role ?? this.role,
      );
}
