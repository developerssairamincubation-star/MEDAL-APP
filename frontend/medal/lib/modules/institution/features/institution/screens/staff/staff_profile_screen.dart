// lib/features/institution/screens/staff/staff_profile_screen.dart
// Place at: lib/features/institution/screens/staff/staff_profile_screen.dart

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

/// Staff Profile Screen — matches Staff_login_Profile.png
class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.staffDashboard);
        break;
      case 1:
        context.go(AppRoutes.staffMyClass);
        break;
      case 2:
        context.go(AppRoutes.studentAcademy);
        break;
      case 3:
        break; // Already here
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ApiService().currentUser ?? const <String, dynamic>{};
    final fullName = (user['full_name'] ?? '').toString();
    final own = ref.watch(ownProgressProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: MedalAppBar(
        actions: [
          // Notification bell + avatar (matches staff profile header)
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppTheme.textPrimary),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(
                fullName.isEmpty ? '?' : fullName.substring(0, 1).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile hero (shared layout, same as every login) ──
            ProfileHeroCard(
              roleLabel: 'Staff',
              name: fullName,
              email: (user['email'] ?? '').toString(),
              phone: (user['phone'] ?? '').toString(),
              badgeBackground: const Color(0xFFE8F4FD),
              badgeForeground: const Color(0xFF0467B6),
            ),
            const SizedBox(height: 14),
            // ── Certificates stat card ────────────────────────
            _LeftBorderStatCard(
              label: 'MY CERTIFICATES',
              value: own.maybeWhen(
                data: (o) => o.certificates.toString().padLeft(2, '0'),
                orElse: () => '–',
              ),
              trailing: TextButton(
                onPressed: () => context.go('${AppRoutes.studentAcademy}?tab=certificates'),
                child: Text(
                  'View certificates',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ── Students stat card ────────────────────────────
            _LeftBorderStatCard(
              label: 'SEEK COURSE PROGRESS',
              value: own.maybeWhen(
                data: (o) => '${o.completedChapters} / ${o.totalChapters} chapters',
                orElse: () => '–',
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
              onTap: () {},
            ),
            const SizedBox(height: 8),
            ProfileAccountTile(
              icon: Icons.account_balance_outlined,
              iconColor: const Color(0xFF6D28D9),
              iconBgColor: const Color(0xFFEDE9FE),
              title: 'Course & certificates',
              subtitle: 'Your SEEK course progress and certificates',
              onTap: () => context.go(AppRoutes.studentAcademy),
            ),
            const SizedBox(height: 8),
            ProfileLogoutTile(onTap: () => confirmAndLogout(context)),
            const SizedBox(height: 20),
            // ── Admin note ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your profile is managed by the Institutional Admin. For changes to your department or name, please contact the Registrar Office.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        items: staffNavItems,
        currentIndex: 3,
        onTap: (i) => _onNavTap(context, i),
      ),
    );
  }
}

class _LeftBorderStatCard extends StatelessWidget {
  const _LeftBorderStatCard({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: AppTheme.primary, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
