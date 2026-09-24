// lib/features/institution/screens/principal/principal_dashboard_screen.dart
// Place at: lib/features/institution/screens/principal/principal_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../providers/principal_provider.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/custom_stat_card.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/activity_feed_item.dart';

/// Principal Dashboard — matches Principal_login_dashboard.png
class PrincipalDashboardScreen extends ConsumerWidget {
  const PrincipalDashboardScreen({super.key});

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
        context.go(AppRoutes.principalProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(principalDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Academic Overview ─────────────────────────────
            Text(
              'ACADEMIC OVERVIEW',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Good Morning, Principal.',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            // ── Top stat cards (2-col) ────────────────────────
            Row(
              children: [
                Expanded(
                  child: CustomStatCard(
                    icon: Icons.groups_rounded,
                    label: 'Staff',
                    value: '${stats.totalStaff} Total',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomStatCard(
                    icon: Icons.school_rounded,
                    label: 'Students',
                    value: '${stats.totalStudents} Total',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Mini accent stat cards (2x2 grid) ────────────
            Row(
              children: [
                Expanded(
                  child: CustomMiniStatCard(
                    count: stats.certificationReady,
                    label: 'Certification Ready',
                    badgeLabel: 'COMPLETED',
                    accentColor: AppTheme.accentGreen,
                    badgeBgColor: AppTheme.statusCompletedLight,
                    badgeTextColor: AppTheme.statusCompleted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomMiniStatCard(
                    count: stats.activeStudents,
                    label: 'Active students',
                    badgeLabel: 'ACTIVE',
                    accentColor: AppTheme.accentPurple,
                    badgeBgColor: AppTheme.statusInProgressLight,
                    badgeTextColor: AppTheme.statusInProgress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomMiniStatCard(
                    count: stats.inactiveStudents,
                    label: 'Inactive students',
                    badgeLabel: 'INACTIVE',
                    accentColor: AppTheme.accentRed,
                    badgeBgColor: AppTheme.statusInactiveLight,
                    badgeTextColor: AppTheme.statusInactive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomMiniStatCard(
                    count: stats.enrollmentPending,
                    label: 'Enrollment pending',
                    badgeLabel: 'WAITLIST',
                    accentColor: AppTheme.accentOrange,
                    badgeBgColor: AppTheme.statusWaitlistLight,
                    badgeTextColor: AppTheme.statusWaitlist,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // ── Daily Insights ────────────────────────────────
            Text(
              'Daily Insights',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // ── Recent Activity ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Recent Activity',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...stats.recentActivity.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActivityFeedItem(
                  name: activity['name'] as String,
                  time: activity['time'] as String,
                  action: activity['action'] as String,
                  badges: List<String>.from(activity['badges'] as List),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        items: principalNavItems,
        currentIndex: 0,
        onTap: (i) => _onNavTap(context, i),
      ),
    );
  }
}
