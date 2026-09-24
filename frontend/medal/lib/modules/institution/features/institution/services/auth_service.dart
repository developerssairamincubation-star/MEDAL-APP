// lib/features/institution/services/auth_service.dart
// Place at: lib/features/institution/services/auth_service.dart

import 'mock_repository.dart';

enum UserRole { principal, staff }

class AuthResult {
  final bool success;
  final UserRole? role;
  final String? error;

  const AuthResult({
    required this.success,
    this.role,
    this.error,
  });

  const AuthResult.failure(this.error)
      : success = false,
        role = null;

  const AuthResult.success(this.role)
      : success = true,
        error = null;
}

/// Handles authentication logic.
/// Currently uses mock credentials — replace with API call in production.
class AuthService {
  const AuthService();

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1200));

    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const AuthResult.failure('Email and password are required.');
    }

    if (password.length < 4) {
      return const AuthResult.failure('Invalid credentials.');
    }

    final roleStr = MockRepository.credentials[normalizedEmail];
    if (roleStr == null) {
      return const AuthResult.failure(
        'No account found with this email address.',
      );
    }

    final role = roleStr == 'principal' ? UserRole.principal : UserRole.staff;
    return AuthResult.success(role);
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
