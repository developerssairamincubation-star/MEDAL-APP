// lib/modules/institution/features/institution/widgets/student_shell_scaffold.dart
// Shell layout for Student Portal featuring the Top Bar with MEdAL branding + unread notifications
// and the persistent 4-tab bottom navigation bar.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';

class StudentShellScaffold extends StatelessWidget {
  final Widget child;
  final int currentTabIndex;
  final bool showBackButton;
  final VoidCallback? onBack;

  const StudentShellScaffold({
    super.key,
    required this.child,
    this.currentTabIndex = 0,
    this.showBackButton = false,
    this.onBack,
  });

  void _onTabTapped(BuildContext context, int index) {
    if (index == currentTabIndex) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.studentDashboard);
        break;
      case 1:
        context.go(AppRoutes.studentCourseProgress);
        break;
      case 2:
        context.go(AppRoutes.studentAcademy);
        break;
      case 3:
        context.go(AppRoutes.studentProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFECEFF5), width: 1),
              ),
            ),
            child: Row(
              children: [
                if (showBackButton)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                    onPressed: onBack ?? () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.studentDashboard);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (showBackButton) const SizedBox(width: 8),

                // MEdAL Logo Brand
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.military_tech_rounded,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'MEd',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'AL',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Notification Bell with Badge "2"
                GestureDetector(
                  onTap: () => context.push(AppRoutes.studentNotifications),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications,
                          color: Color(0xFF475569),
                          size: 24,
                        ),
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '2',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFECEFF5), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: Icons.article_outlined,
                label: 'Course Progress',
              ),
              _buildNavItem(
                context,
                index: 2,
                icon: Icons.groups_outlined,
                label: 'Academy',
              ),
              _buildNavItem(
                context,
                index: 3,
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    IconData? selectedIcon,
    required String label,
  }) {
    final isSelected = currentTabIndex == index;
    final color = isSelected ? AppTheme.primary : const Color(0xFF64748B);

    return InkWell(
      onTap: () => _onTabTapped(context, index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: isSelected
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE6F2FA) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? (selectedIcon ?? icon) : icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
