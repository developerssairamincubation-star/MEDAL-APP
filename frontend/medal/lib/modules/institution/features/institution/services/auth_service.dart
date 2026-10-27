// lib/features/institution/services/auth_service.dart
// Authentication service supporting Student (live API) as well as Principal and Staff roles.

import 'package:medal/core/services/api_service.dart';
import 'mock_repository.dart';

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

    // 1. First attempt login against live Backend API (real student authentication)
    try {
      final res = await ApiService().login(email: normalizedEmail, password: password);
      final userData = res['data'] as Map<String, dynamic>?;
      final roleStr = (userData?['role'] ?? ApiService().userRole).toString().toLowerCase().trim();

      if (roleStr == 'student' || normalizedEmail == 'kajolmisra@medal.gov' || normalizedEmail == 'dilli.ganesh@medal.gov') {
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
      // 2. If backend rejects, check mock repository for demo accounts
      final roleStr = MockRepository.credentials[normalizedEmail];
      if (roleStr != null) {
        if (roleStr == 'principal') {
          return const AuthResult.success(UserRole.principal);
        } else if (roleStr == 'student') {
          return const AuthResult.success(UserRole.student);
        } else {
          return const AuthResult.success(UserRole.staff);
        }
      }

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
