// lib/features/institution/services/auth_service.dart
// Authentication service: live backend login for Student, Staff and Principal roles.

import 'package:medal/core/services/api_service.dart';

enum UserRole { principal, staff, student }

class AuthResult {
  final bool success;
  final UserRole? role;
  final String? error;
  final Map<String, dynamic>? user;

  const AuthResult({
    required this.success,
    this.role,
    this.error,
    this.user,
  });

  const AuthResult.failure(this.error)
      : success = false,
        role = null,
        user = null;

  const AuthResult.success(this.role, [this.user])
      : success = true,
        error = null;
}

class AuthService {
  const AuthService();

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const AuthResult.failure('Email and password are required.');
    }

    if (password.length < 4) {
      return const AuthResult.failure('Password must be at least 4 characters.');
    }

    // Sign in against the live backend; the account's role decides the portal.
    try {
      final res = await ApiService().login(email: normalizedEmail, password: password);
      final userData = res['data'] as Map<String, dynamic>?;
      final roleStr = (userData?['role'] ?? ApiService().userRole).toString().toLowerCase().trim();

      if (roleStr == 'student') {
        return AuthResult.success(UserRole.student, userData);
      } else if (roleStr == 'principal') {
        return AuthResult.success(UserRole.principal, userData);
      } else if (roleStr == 'staff' || roleStr == 'faculty' || roleStr == 'teacher') {
        return AuthResult.success(UserRole.staff, userData);
      } else if (roleStr == 'citizen') {
        await ApiService().logout();
        return const AuthResult.failure(
          'Access denied: Citizen accounts cannot log in to the Institution Portal. Please use the Citizen Login.',
        );
      } else if (roleStr == 'official' || roleStr == 'admin') {
        await ApiService().logout();
        return const AuthResult.failure(
          'Access denied: Municipal Authority accounts cannot log in to the Institution Portal.',
        );
      } else {
        await ApiService().logout();
        return AuthResult.failure(
          'Access denied: Your account role ($roleStr) is not authorized for the Institution Portal.',
        );
      }
    } catch (e) {
      final errorMsg = e is ApiException ? e.message : 'Invalid credentials. Please verify your email and password.';
      return AuthResult.failure(errorMsg);
    }
  }

  Future<void> logout() async {
    try {
      await ApiService().logout();
    } catch (_) {}
  }
}
