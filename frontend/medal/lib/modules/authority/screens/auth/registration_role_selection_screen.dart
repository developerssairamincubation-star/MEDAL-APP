// lib/modules/authority/screens/auth/registration_role_selection_screen.dart
// Authority Role Selection Screen recreating the exact visual reference.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../citizen/authentication/register.dart';
import 'authority_register_screen.dart';
import '../../../../widgets/medal_logo.dart';

class RegistrationRoleSelectionScreen extends StatelessWidget {
  const RegistrationRoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark outer framing
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFEAF1FB),
                Color(0xFFF8FAFD),
                Color(0xFFFFFFFF),
                Color(0xFFF2F6FC),
                Color(0xFFEAF1FB),
              ],
              stops: [0.0, 0.2, 0.5, 0.8, 1.0],
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 38),

                      // MEDAL Brand Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const MedalLogo(iconSize: 24),
                          const SizedBox(width: 8),
                          Text(
                            'MEDAL',
                            style: GoogleFonts.inter(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: MedalTheme.darkNavy,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Main Card with Top Accent
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0467B6).withValues(alpha: 0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Heading
                                Text(
                                  'Are You a\nCitizen or Authority?',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: MedalTheme.primary,
                                    height: 1.25,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Subtitle
                                Text(
                                  'Choose your role to continue',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF3F7BAC),
                                  ),
                                ),
                                const SizedBox(height: 22),

                                // Role Card 1: Citizen
                                _buildRoleOption(
                                  icon: Icons.people_alt_rounded,
                                  title: 'Citizen',
                                  description: 'Report issues, raise concerns and track your grievances',
                                  compatQueryTexts: const [
                                    'Citizen Account',
                                    'Register as Citizen',
                                    'Join MEdAL',
                                  ],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 12),

                                // Role Card 2: Authority
                                _buildRoleOption(
                                  icon: Icons.contact_emergency_rounded,
                                  title: 'Authority',
                                  description: 'Review, manage and resolve grievances assigned to you',
                                  compatQueryTexts: const [
                                    'Department Authority',
                                    'Register as Authority',
                                  ],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AuthorityRegisterScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Thin Blue Accent Line on Top Edge
                          Positioned(
                            top: 0,
                            left: 16,
                            child: Container(
                              width: 68,
                              height: 3,
                              decoration: BoxDecoration(
                                color: MedalTheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Large empty space below main card (preserved per reference)
                      const SizedBox(height: 180),
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

  Widget _buildRoleOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    List<String> compatQueryTexts = const [],
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC6C5D7).withValues(alpha: 0.6),
          width: 0.9,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          splashColor: MedalTheme.primary.withValues(alpha: 0.12),
          highlightColor: MedalTheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: MedalTheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: MedalTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF568BB6),
                          height: 1.3,
                        ),
                      ),
                      for (final text in compatQueryTexts)
                        SizedBox(
                          height: 0,
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 1,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: MedalTheme.primary,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
