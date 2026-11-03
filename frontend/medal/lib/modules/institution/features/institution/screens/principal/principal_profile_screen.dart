// lib/features/institution/screens/principal/principal_profile_screen.dart
// Place at: lib/features/institution/screens/principal/principal_profile_screen.dart

import 'package:medal/widgets/profile_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import 'package:medal/core/services/api_service.dart';
import '../../providers/institution_provider.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/password_dialogs.dart';

/// Principal Profile Screen — matches Principal_login_Profile.png
class PrincipalProfileScreen extends ConsumerWidget {
  const PrincipalProfileScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.principalDashboard);
        break;
      case 1:
        context.go(AppRoutes.principalStaffList);
        break;
      case 2:
        context.go(AppRoutes.principalAddStaff);
        break;
      case 3:
        break; // Already here
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ApiService().currentUser ?? const <String, dynamic>{};
    final overview = ref.watch(institutionOverviewProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile hero (shared layout, same as every login) ──
            ProfileHeroCard(
              roleLabel: 'Principal',
              name: (user['full_name'] ?? '').toString(),
              email: (user['email'] ?? '').toString(),
              phone: (user['phone'] ?? '').toString(),
              badgeBackground: const Color(0xFFE8F4FD),
              badgeForeground: const Color(0xFF0467B6),
            ),
            const SizedBox(height: 16),
            // ── Institution Overview card ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INSTITUTION OVERVIEW',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 14),
                  overview.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => Text(
                      describeError(e),
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    data: (o) => o.isEmpty
                        ? Text(
                            'No staff added yet.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                          )
                        : Row(
                            children: [
                              _StatColumn(label: 'Students', value: '${o.totalStudents}'),
                              const SizedBox(width: 32),
                              _StatColumn(label: 'Staff', value: '${o.totalStaff}'),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Account Management (shared tiles) ──
            const ProfileSectionTitle('Account Management'),
            const SizedBox(height: 10),
            ProfileAccountTile(
              icon: Icons.sync_lock_rounded,
              title: 'Manage Password',
              subtitle: 'Update your security credentials',
              onTap: () => showManagePasswordDialog(context),
            ),
            const SizedBox(height: 8),
            ProfileAccountTile(
              icon: Icons.account_balance_outlined,
              iconColor: const Color(0xFF6D28D9),
              iconBgColor: const Color(0xFFEDE9FE),
              title: 'Institution Details',
              subtitle: 'Profile and academic records',
              onTap: () {},
            ),
            const SizedBox(height: 8),
            ProfileLogoutTile(onTap: () => confirmAndLogout(context)),
            const SizedBox(height: 24),
            // ── Footer ────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    'MEdAL v2.4.0 Institutional Core',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        items: principalNavItems,
        currentIndex: 3,
        onTap: (i) => _onNavTap(context, i),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
