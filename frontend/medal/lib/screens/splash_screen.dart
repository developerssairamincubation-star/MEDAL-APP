// lib/screens/splash_screen.dart
// Premium animated splash screen for the MEDAL application.

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';
import '../widgets/medal_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: AppConstants.animationDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Start animation
    _animationController.forward();

    // Start session check in parallel with splash animation
    _startStartupFlow();
  }

  void _startStartupFlow() {
    final sessionFuture = ApiService().tryRestoreSession();
    _splashTimer = Timer(AppConstants.splashDuration, () async {
      final sessionResult = await sessionFuture;
      if (!mounted) return;

      if (sessionResult.isValid) {
        if (sessionResult.role == 'institution' ||
            sessionResult.role == 'principal' ||
            sessionResult.role == 'staff') {
          Navigator.of(context).pushReplacementNamed(AppRoutes.institution);
        } else if (sessionResult.role == 'admin') {
          Navigator.of(context).pushReplacementNamed(AppRoutes.adminApplicationsList);
        } else if (sessionResult.role == 'official') {
          Navigator.of(context).pushReplacementNamed(AppRoutes.authorityMain);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.citizenMain);
        }
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: MedalTheme.splashGradient,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // MEdAL Logo Icon (styled premium badge/medal)
                  const MedalLogo(onGradient: true),
                  const SizedBox(height: 24),
                  // App Name
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tagline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      AppConstants.appTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
