// lib/features/institution/providers/auth_provider.dart
// Place at: lib/features/institution/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../state/student_notification_state.dart';
import '../state/student_session_state.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AuthState {
  final bool isAuthenticated;
  final UserRole? role;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.role,
    this.isLoading = false,
    this.error,
  });

  const AuthState.initial()
      : isAuthenticated = false,
        role = null,
        isLoading = false,
        error = null;

  AuthState copyWith({
    bool? isAuthenticated,
    UserRole? role,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearRole = false,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        role: clearRole ? null : (role ?? this.role),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(const AuthState.initial());

  final AuthService _authService;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result.success) {
        StudentSessionState.reset();
        StudentNotificationState.instance.reset();
        state = state.copyWith(
          isAuthenticated: true,
          role: result.role,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    StudentSessionState.reset();
    StudentNotificationState.instance.reset();
    state = const AuthState.initial();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>(
  (ref) => const AuthService(),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);

/// Convenient selector: is the current user a principal?
final isPrincipalProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).role == UserRole.principal,
);

/// Convenient selector: is the current user a staff member?
final isStaffProvider = Provider<bool>(
  (ref) => ref.watch(authProvider).role == UserRole.staff,
);
