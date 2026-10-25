// lib/features/institution/screens/splash_screen.dart
// Place at: lib/features/institution/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/medal_app_bar.dart';

/// Splash Screen that displays the MEdAL logo for 3 seconds before routing.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Navigate after 3 seconds
    _timer = Timer(const Duration(seconds: 3), _navigate);
  }

  void _navigate() {
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      if (authState.role == UserRole.principal) {
        context.go(AppRoutes.principalDashboard);
      } else if (authState.role == UserRole.staff) {
        context.go(AppRoutes.staffDashboard);
      } else {
        context.go(AppRoutes.studentDashboard);
      }
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: const MedalLogoLarge()
            .animate()
            .fade(duration: 800.ms, curve: Curves.easeOut)
            .slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.easeOut),
      ),
    );
  }
}
