// lib/features/institution/widgets/custom_bottom_nav.dart
// Place at: lib/features/institution/widgets/custom_bottom_nav.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class BottomNavItem {
  final IconData icon;
  final String label;

  const BottomNavItem({required this.icon, required this.label});
}

/// Shared bottom navigation bar for both Principal and Staff.
/// Active tab shows filled icon + indigo background pill.
class CustomBottomNav extends StatelessWidget {
  const CustomBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: isActive
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isActive
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Principal Nav Items ───────────────────────────────────────────────────────

const principalNavItems = [
  BottomNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
  BottomNavItem(icon: Icons.list_alt_rounded, label: 'Staff list'),
  BottomNavItem(icon: Icons.person_add_alt_1_rounded, label: 'Add staffs'),
  BottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
];

// ── Staff Nav Items ───────────────────────────────────────────────────────────

const staffNavItems = [
  BottomNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
  BottomNavItem(icon: Icons.menu_book_rounded, label: 'My class'),
  BottomNavItem(icon: Icons.group_add_rounded, label: 'Invite students'),
  BottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
];
