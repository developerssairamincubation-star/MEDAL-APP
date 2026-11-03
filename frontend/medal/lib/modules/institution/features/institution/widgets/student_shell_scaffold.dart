// lib/modules/institution/features/institution/widgets/student_shell_scaffold.dart
// Shell layout for Student Portal featuring the Top Bar with MEdAL branding + unread notifications
// and the persistent 4-tab bottom navigation bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../state/student_notification_state.dart';
import '../../../../../widgets/medal_logo.dart';

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

  /// Staff take the same SEEK course through these screens, so the shell
  /// follows the signed-in role: staff keep their own Dashboard / Students /
  /// Profile tabs and reach the course through "My course".
  bool _isStaff(BuildContext context) {
    try {
      return ProviderScope.containerOf(context, listen: false)
              .read(authProvider)
              .role ==
          UserRole.staff;
    } on StateError {
      return false; // no provider scope: plain student shell
    }
  }

  void _onTabTapped(BuildContext context, int index) {
    final staff = _isStaff(context);
    final current = staff ? _staffTab(currentTabIndex) : currentTabIndex;
    if (index == current) return;
    switch (index) {
      case 0:
        context.go(staff ? AppRoutes.staffDashboard : AppRoutes.studentDashboard);
        break;
      case 1:
        context.go(staff ? AppRoutes.staffMyClass : AppRoutes.studentCourseProgress);
        break;
      case 2:
        context.go(AppRoutes.studentAcademy);
        break;
      case 3:
        context.go(staff ? AppRoutes.staffProfile : AppRoutes.studentProfile);
        break;
    }
  }

  // Student tab positions -> staff tab positions (course progress and academy are both "My course").
  static int _staffTab(int studentTab) => studentTab == 1 ? 2 : studentTab;

  @override
  Widget build(BuildContext context) {
    final staff = _isStaff(context);
    final selectedTab = staff ? _staffTab(currentTabIndex) : currentTabIndex;
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
                        context.go(staff ? AppRoutes.staffDashboard : AppRoutes.studentDashboard);
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
                    const MedalLogo(iconSize: 18),
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

                // Notification bell; the red dot shows only for unseen notifications.
                GestureDetector(
                  onTap: () => context.push(AppRoutes.studentNotifications),
                  behavior: HitTestBehavior.opaque,
                  child: const _NotificationBell(),
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
                selectedTab: selectedTab,
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
              ),
              _buildNavItem(
                context,
                index: 1,
                selectedTab: selectedTab,
                icon: staff ? Icons.groups_outlined : Icons.article_outlined,
                label: staff ? 'Students' : 'Course Progress',
              ),
              _buildNavItem(
                context,
                index: 2,
                selectedTab: selectedTab,
                icon: staff ? Icons.menu_book_rounded : Icons.groups_outlined,
                label: staff ? 'My course' : 'Academy',
              ),
              _buildNavItem(
                context,
                index: 3,
                selectedTab: selectedTab,
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
    required int selectedTab,
    required IconData icon,
    IconData? selectedIcon,
    required String label,
  }) {
    final isSelected = selectedTab == index;
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


class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  final _state = StudentNotificationState.instance;

  @override
  void initState() {
    super.initState();
    _state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('student_notification_bell'),
      padding: const EdgeInsets.all(8),
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications, color: Color(0xFF475569), size: 24),
            if (_state.hasUnread)
              Positioned(
                top: 1,
                right: 2,
                child: Container(
                  key: const Key('student_notification_unread_dot'),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
