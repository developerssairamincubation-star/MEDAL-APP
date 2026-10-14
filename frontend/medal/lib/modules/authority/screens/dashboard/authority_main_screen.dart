// lib/modules/authority/screens/dashboard/authority_main_screen.dart
// Authority Module Shell with bottom navigation and official header.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/authority_models.dart';
import '../notifications/authority_notifications_screen.dart';
import 'authority_dashboard_screen.dart';
import '../complaints/authority_complaints_screen.dart';
import '../academy/authority_academy_screen.dart';
import '../profile/authority_profile_screen.dart';

class AuthorityMainScreen extends StatefulWidget {
  final int initialIndex;

  const AuthorityMainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AuthorityMainScreen> createState() => _AuthorityMainScreenState();
}

class _AuthorityMainScreenState extends State<AuthorityMainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _navigateToComplaints() {
    setState(() => _currentIndex = 1);
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return AuthorityDashboardScreen(
          onNavigateToComplaints: _navigateToComplaints,
        );
      case 1:
        return const AuthorityComplaintsScreen();
      case 2:
        return const AuthorityAcademyScreen();
      case 3:
        return const AuthorityProfileScreen();
      default:
        return AuthorityDashboardScreen(
          onNavigateToComplaints: _navigateToComplaints,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadAlerts =
        MockAuthorityRepository.notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: MedalTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16.0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.military_tech_rounded,
              color: MedalTheme.primary,
              size: 26,
            ),
            const SizedBox(width: 8),
            const Text(
              "MEdAL",
              style: TextStyle(
                color: MedalTheme.darkNavy,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: MedalTheme.primaryTint,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: MedalTheme.primaryLight.withValues(alpha: 0.4)),
              ),
              child: const Text(
                "AUTHORITY",
                style: TextStyle(
                  color: MedalTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications,
                    color: MedalTheme.slateBlue,
                    size: 24,
                  ),
                  tooltip: "Authority Notifications",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthorityNotificationsScreen(),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
                if (unreadAlerts > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: MedalTheme.lavenderBorder,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: MedalTheme.lavenderBorder, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: "DASHBOARD",
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: "COMPLAINTS",
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.school_outlined,
                activeIcon: Icons.school_rounded,
                label: "ACADEMY",
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: "PROFILE",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    const activeColor = MedalTheme.primary;
    const inactiveColor = MedalTheme.slateBlue;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 16,
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
