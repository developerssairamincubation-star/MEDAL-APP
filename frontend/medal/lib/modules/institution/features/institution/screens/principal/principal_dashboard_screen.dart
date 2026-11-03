// lib/features/institution/screens/principal/principal_dashboard_screen.dart
// Place at: lib/features/institution/screens/principal/principal_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import 'package:medal/core/services/api_service.dart';
import '../../models/member.dart';
import '../../providers/institution_provider.dart';
import '../../widgets/async_body.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/overview_sections.dart';

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
    final overview = ref.watch(institutionOverviewProvider);
    final name = (ApiService().currentUser?['full_name'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(institutionOverviewProvider.future),
        child: AsyncBody<InstitutionOverview>(
          value: overview,
          onRetry: () => ref.invalidate(institutionOverviewProvider),
          builder: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
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
                name.isEmpty ? 'Welcome, Principal.' : 'Welcome, $name.',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              if (data.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'No staff added yet',
                        message: 'Add your first teacher to start tracking SEEK course progress.',
                      ),
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.principalAddStaff),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add staff'),
                      ),
                    ],
                  ),
                )
              else ...[
                OverviewStats(overview: data),
                const SizedBox(height: 28),
                RecentActivitySection(entries: data.recentActivity),
              ],
              const SizedBox(height: 16),
            ],
          ),
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
