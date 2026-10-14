// lib/routes/app_routes.dart
// Centralized named routing configuration for the MEDAL application.

import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/role_selection_screen.dart';
import '../modules/citizen/authentication/login.dart' as citizen;
import '../modules/citizen/authentication/forgot_password.dart' as citizen;
import '../modules/citizen/authentication/reset_password.dart' as citizen;
import '../modules/citizen/screens/components.dart' as citizen;
import '../modules/institution/institution_app.dart';
import '../modules/authority/screens/auth/registration_role_selection_screen.dart';
import '../modules/authority/screens/auth/authority_login_screen.dart';
import '../modules/authority/screens/auth/authority_register_screen.dart';
import '../modules/authority/screens/dashboard/authority_main_screen.dart';
import '../modules/authority/screens/notifications/authority_notifications_screen.dart';

/// AppRoutes defines the central routing table for the root MaterialApp.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String citizenLogin = '/citizen/login';
  static const String citizenForgotPassword = '/citizen/forgot-password';
  static const String citizenResetPassword = '/citizen/reset-password';
  static const String citizenDashboard = '/citizen/dashboard';
  static const String citizenMain = '/citizen/main';
  static const String institution = '/institution';
  static const String registrationRoleSelection = '/auth/registration-role-selection';
  static const String authorityLogin = '/authority/login';
  static const String authorityRegister = '/authority/register';
  static const String authorityMain = '/authority/main';
  static const String authorityNotifications = '/authority/notifications';

  /// Returns the route map to be registered in the root MaterialApp.
  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        roleSelection: (context) => const RoleSelectionScreen(),
        citizenLogin: (context) => const citizen.LoginScreen(),
        citizenForgotPassword: (context) => const citizen.ForgotPasswordScreen(),
        citizenResetPassword: (context) => const citizen.ResetPasswordScreen(),
        citizenDashboard: (context) => const citizen.MainScreen(showAcademyPopup: true),
        citizenMain: (context) => const citizen.MainScreen(),
        institution: (context) => const InstitutionAppWrapper(),
        registrationRoleSelection: (context) => const RegistrationRoleSelectionScreen(),
        authorityLogin: (context) => const AuthorityLoginScreen(),
        authorityRegister: (context) => const AuthorityRegisterScreen(),
        authorityMain: (context) => const AuthorityMainScreen(),
        authorityNotifications: (context) => const AuthorityNotificationsScreen(),
      };
}


