// lib/routes/app_routes.dart
// Place at: lib/routes/app_routes.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/institution/providers/auth_provider.dart';
import '../features/institution/screens/splash_screen.dart';
import '../features/institution/screens/auth/institution_login_screen.dart';
import '../features/institution/screens/principal/principal_dashboard_screen.dart';
import '../features/institution/screens/principal/staff_list_screen.dart';
import '../features/institution/screens/principal/add_staff_screen.dart';
import '../features/institution/screens/principal/principal_profile_screen.dart';
import '../features/institution/screens/staff/staff_dashboard_screen.dart';
import '../features/institution/screens/staff/my_class_screen.dart';
import '../features/institution/screens/staff/class_detail_screen.dart';
import '../features/institution/screens/staff/invite_students_screen.dart';
import '../features/institution/screens/staff/staff_profile_screen.dart';
import '../features/institution/services/auth_service.dart';

// ── Route Names (named constants to avoid typos) ──────────────────────────────

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';

  // Principal
  static const String principalDashboard = '/principal/dashboard';
  static const String principalStaffList = '/principal/staff-list';
  static const String principalAddStaff = '/principal/add-staff';
  static const String principalProfile = '/principal/profile';

  // Staff
  static const String staffDashboard = '/staff/dashboard';
  static const String staffMyClass = '/staff/my-class';
  static const String staffClassDetail = '/staff/class-detail/:studentId';
  static const String staffInviteStudents = '/staff/invite-students';
  static const String staffProfile = '/staff/profile';
}

// ── Router Provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authState.isAuthenticated;
      final isSplashRoute = state.matchedLocation == AppRoutes.splash;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      // If on splash route, don't redirect yet (splash screen handles navigation after timer)
      if (isSplashRoute) return null;

      // If not authenticated and not on login → go to login
      if (!isAuthenticated && !isLoginRoute) return AppRoutes.login;

      // If authenticated and on login → redirect to correct dashboard
      if (isAuthenticated && isLoginRoute) {
        if (authState.role == UserRole.principal) {
          return AppRoutes.principalDashboard;
        } else {
          return AppRoutes.staffDashboard;
        }
      }

      // If authenticated and on wrong role's route, redirect
      if (isAuthenticated && authState.role == UserRole.principal) {
        if (state.matchedLocation.startsWith('/staff')) {
          return AppRoutes.principalDashboard;
        }
      }
      if (isAuthenticated && authState.role == UserRole.staff) {
        if (state.matchedLocation.startsWith('/principal')) {
          return AppRoutes.staffDashboard;
        }
      }

      return null;
    },
    routes: [
      // ── Splash ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth ───────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const InstitutionLoginScreen(),
      ),

      // ── Principal ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.principalDashboard,
        name: 'principalDashboard',
        builder: (context, state) => const PrincipalDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.principalStaffList,
        name: 'principalStaffList',
        builder: (context, state) => const StaffListScreen(),
      ),
      GoRoute(
        path: AppRoutes.principalAddStaff,
        name: 'principalAddStaff',
        builder: (context, state) => const AddStaffScreen(),
      ),
      GoRoute(
        path: AppRoutes.principalProfile,
        name: 'principalProfile',
        builder: (context, state) => const PrincipalProfileScreen(),
      ),

      // ── Staff ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.staffDashboard,
        name: 'staffDashboard',
        builder: (context, state) => const StaffDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffMyClass,
        name: 'staffMyClass',
        builder: (context, state) => const MyClassScreen(),
      ),
      GoRoute(
        path: '/staff/class-detail/:studentId',
        name: 'staffClassDetail',
        builder: (context, state) {
          final studentId = state.pathParameters['studentId'] ?? '';
          return ClassDetailScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: AppRoutes.staffInviteStudents,
        name: 'staffInviteStudents',
        builder: (context, state) => const InviteStudentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffProfile,
        name: 'staffProfile',
        builder: (context, state) => const StaffProfileScreen(),
      ),
    ],
  );
});
