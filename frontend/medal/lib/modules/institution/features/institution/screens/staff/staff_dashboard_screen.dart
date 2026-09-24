// lib/features/institution/screens/staff/staff_dashboard_screen.dart
// Place at: lib/features/institution/screens/staff/staff_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/custom_stat_card.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/activity_feed_item.dart';

/// Staff Dashboard Screen — matches Staff_login_dashboard.png
class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        break; // Already here
      case 1:
        context.go(AppRoutes.staffMyClass);
        break;
      case 2:
        context.go(AppRoutes.staffInviteStudents);
        break;
      case 3:
        context.go(AppRoutes.staffProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(staffDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────
            Text(
              'Dashboard',
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
                    icon: Icons.school_rounded,
                    label: 'Total Students',
                    value: '${stats.totalStudents} Total',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomStatCard(
                    icon: Icons.groups_rounded,
                    label: 'My Classroom',
                    value: '${stats.myClassroom} Students',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Mini accent stat cards ────────────────────────
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
        items: staffNavItems,
        currentIndex: 0,
        onTap: (i) => _onNavTap(context, i),
      ),
    );
  }
}
