// lib/screens/role_selection_screen.dart
// Premium responsive Role Selection Screen with staggered animations.

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../widgets/medal_logo.dart';
import '../widgets/role_card.dart';
import '../routes/app_routes.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _card1SlideAnimation;
  late Animation<double> _card1FadeAnimation;
  late Animation<Offset> _card2SlideAnimation;
  late Animation<double> _card2FadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Title animation (fast fade-in)
    _titleFadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    // Card 1 animation (slide up + fade)
    _card1SlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _card1FadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
    );

    // Card 2 animation (staggered delay, slide up + fade)
    _card2SlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _card2FadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    // Run animations
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width > 700;

    return Scaffold(
      backgroundColor: MedalTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: isDesktop ? 780 : 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title and Subtitle Section
                      FadeTransition(
                        opacity: _titleFadeAnimation,
                        child: Column(
                          children: [
                            const MedalLogo(iconSize: 34),
                            const SizedBox(height: 6),
                            const Text(
                              'Welcome to MEDAL',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: MedalTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Choose how you want to continue',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: MedalTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cards Section (Row on Desktop/Tablet, Column on Mobile)
                      if (isDesktop)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FadeTransition(
                                opacity: _card1FadeAnimation,
                                child: SlideTransition(
                                  position: _card1SlideAnimation,
                                  child: _buildCitizenCard(context, compact: false),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: FadeTransition(
                                opacity: _card2FadeAnimation,
                                child: SlideTransition(
                                  position: _card2SlideAnimation,
                                  child: _buildInstitutionCard(context, compact: false),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            FadeTransition(
                              opacity: _card1FadeAnimation,
                              child: SlideTransition(
                                position: _card1SlideAnimation,
                                child: _buildCitizenCard(context, compact: true),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FadeTransition(
                              opacity: _card2FadeAnimation,
                              child: SlideTransition(
                                position: _card2SlideAnimation,
                                child: _buildInstitutionCard(context, compact: true),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCitizenCard(BuildContext context, {bool compact = false}) {
    return RoleCard(
      title: 'Citizen',
      description: 'Access Citizen Services, report local issues, and study community-impact materials.',
      icon: Icon(
        Icons.person_rounded,
        color: MedalTheme.primary,
        size: compact ? 30 : 36,
      ),
      buttonText: 'Continue',
      compact: compact,
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.citizenLogin);
      },
    );
  }

  Widget _buildInstitutionCard(BuildContext context, {bool compact = false}) {
    return RoleCard(
      title: 'Institution',
      description: 'Access the Student Portal for SEEK learning & certifications, or sign in to your Principal/Staff account.',
      icon: Icon(
        Icons.school_rounded,
        color: MedalTheme.primary,
        size: compact ? 30 : 36,
      ),
      buttonText: 'Continue',
      compact: compact,
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.institution);
      },
    );
  }
}
