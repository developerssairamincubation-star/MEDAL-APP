// lib/features/institution/screens/staff/staff_dashboard_screen.dart
// Place at: lib/features/institution/screens/staff/staff_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../models/member.dart';
import '../../providers/institution_provider.dart';
import '../../widgets/async_body.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/overview_sections.dart';

/// Staff Dashboard — own SEEK progress plus live student stats.
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
        context.go(AppRoutes.studentAcademy);
        break;
      case 3:
        context.go(AppRoutes.staffProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(institutionOverviewProvider);
    final own = ref.watch(ownProgressProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(ownProgressProvider);
          return ref.refresh(institutionOverviewProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Text(
              'Dashboard',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // ── My SEEK course progress ───────────────────────
            own.when(
              loading: () => const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                describeError(e),
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              ),
              data: (o) => _MyCourseCard(
                progress: o,
                onTap: () => context.go(AppRoutes.studentAcademy),
              ),
            ),
            const SizedBox(height: 20),
            overview.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                describeError(e),
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              ),
              data: (o) => o.totalStudents == 0 && o.recentActivity.isEmpty
                  ? const EmptyState(
                      icon: Icons.school_outlined,
                      title: 'No students yet',
                      message: 'Students appear here once they register.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OverviewStats(overview: o, showStaff: false),
                        const SizedBox(height: 28),
                        RecentActivitySection(entries: o.recentActivity),
                      ],
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

class _MyCourseCard extends StatelessWidget {
  const _MyCourseCard({required this.progress, required this.onTap});

  final OwnProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.totalChapters == 0
        ? 0.0
        : progress.completedChapters / progress.totalChapters;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MY SEEK COURSE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${progress.percent}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${progress.completedChapters} of ${progress.totalChapters} chapters completed',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
