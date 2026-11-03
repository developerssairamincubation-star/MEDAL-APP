// lib/modules/institution/routes/app_routes.dart
// Centralized GoRouter routing configuration for the Institution & Student Portal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/institution/providers/auth_provider.dart';
import '../features/institution/screens/splash_screen.dart';
import '../features/institution/screens/auth/institution_login_screen.dart';
import '../features/institution/screens/auth/student_register_screen.dart';

import '../features/institution/screens/student/student_dashboard_screen.dart';
import '../features/institution/screens/student/student_course_progress_screen.dart';
import '../features/institution/screens/student/student_academy_screen.dart';
import '../features/institution/screens/student/student_course_detail_screen.dart';
import '../features/institution/screens/student/student_pending_courses_screen.dart';
import '../features/institution/screens/student/student_profile_screen.dart';
import '../features/institution/screens/student/student_edit_profile_screen.dart';
import '../features/institution/screens/student/student_notifications_screen.dart';

import '../features/institution/screens/principal/principal_dashboard_screen.dart';
import '../features/institution/screens/principal/staff_list_screen.dart';
import '../features/institution/screens/principal/add_staff_screen.dart';
import '../features/institution/screens/principal/principal_profile_screen.dart';
import '../features/institution/screens/staff/staff_dashboard_screen.dart';
import '../features/institution/screens/staff/my_class_screen.dart';
import '../features/institution/screens/shared/member_detail_screen.dart';
import '../features/institution/screens/staff/staff_profile_screen.dart';
import '../features/institution/services/auth_service.dart';

// ── Route Names ─────────────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';

  // Student Portal
  static const String studentRegister = '/student/register';
  static const String studentDashboard = '/student/dashboard';
  static const String studentCourseProgress = '/student/course-progress';
  static const String studentAcademy = '/student/academy';
  static const String studentProfile = '/student/profile';
  static const String studentEditProfile = '/student/edit-profile';
  static const String studentPendingCourses = '/student/pending-courses';
  static const String studentNotifications = '/student/notifications';
  static const String studentCourseDetail = '/student/course-detail/:courseId';

  // Principal
  static const String principalDashboard = '/principal/dashboard';
  static const String principalStaffList = '/principal/staff-list';
  static const String principalAddStaff = '/principal/add-staff';
  static const String principalProfile = '/principal/profile';
  static const String principalMemberDetail = '/principal/member/:memberId';

  // Staff
  static const String staffDashboard = '/staff/dashboard';
  static const String staffMyClass = '/staff/my-class';
  static const String staffStudentDetail = '/staff/student/:memberId';
  static const String staffProfile = '/staff/profile';
}

// ── Router Provider ─────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  // The router is created once. Auth changes re-run `redirect` through
  // `refreshListenable` instead of rebuilding the router, which used to reset
  // the app to the splash screen (and clear the login form) on every change.
  final authChanged = ValueNotifier<int>(0);
  ref.listen<AuthState>(authProvider, (_, __) => authChanged.value++);
  ref.onDispose(authChanged.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: authChanged,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isSplashRoute = state.matchedLocation == AppRoutes.splash;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      final isRegisterRoute = state.matchedLocation == AppRoutes.studentRegister;

      // Allow splash and registration without authentication
      if (isSplashRoute || isRegisterRoute) return null;

      // If not authenticated and not on login → go to login
      if (!isAuthenticated && !isLoginRoute) return AppRoutes.login;

      // If authenticated and on login → redirect to appropriate role dashboard
      if (isAuthenticated && isLoginRoute) {
        if (authState.role == UserRole.principal) {
          return AppRoutes.principalDashboard;
        } else if (authState.role == UserRole.staff) {
          return AppRoutes.staffDashboard;
        } else {
          return AppRoutes.studentDashboard;
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
      GoRoute(
        path: AppRoutes.studentRegister,
        name: 'studentRegister',
        builder: (context, state) => const StudentRegisterScreen(),
      ),

      // ── Student Portal Routes ───────────────────────────────────
      GoRoute(
        path: AppRoutes.studentDashboard,
        name: 'studentDashboard',
        builder: (context, state) => const StudentDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentCourseProgress,
        name: 'studentCourseProgress',
        builder: (context, state) => const StudentCourseProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentAcademy,
        name: 'studentAcademy',
        builder: (context, state) => StudentAcademyScreen(
          initialTabIndex:
              state.uri.queryParameters['tab'] == 'certificates' ? 1 : 0,
        ),
      ),
      GoRoute(
        path: AppRoutes.studentProfile,
        name: 'studentProfile',
        builder: (context, state) => const StudentProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentEditProfile,
        name: 'studentEditProfile',
        builder: (context, state) => const StudentEditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentPendingCourses,
        name: 'studentPendingCourses',
        builder: (context, state) => const StudentPendingCoursesScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentNotifications,
        name: 'studentNotifications',
        builder: (context, state) => const StudentNotificationsScreen(),
      ),
      GoRoute(
        path: '/student/course-detail/:courseId',
        name: 'studentCourseDetail',
        builder: (context, state) {
          final idStr = state.pathParameters['courseId'] ?? '1';
          final id = int.tryParse(idStr) ?? 1;
          return StudentCourseDetailScreen(courseId: id);
        },
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
      GoRoute(
        path: AppRoutes.principalMemberDetail,
        name: 'principalMemberDetail',
        builder: (context, state) => MemberDetailScreen(
          memberId: int.tryParse(state.pathParameters['memberId'] ?? '') ?? 0,
        ),
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
        path: AppRoutes.staffStudentDetail,
        name: 'staffStudentDetail',
        builder: (context, state) => MemberDetailScreen(
          memberId: int.tryParse(state.pathParameters['memberId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: AppRoutes.staffProfile,
        name: 'staffProfile',
        builder: (context, state) => const StaffProfileScreen(),
      ),
    ],
  );
});
