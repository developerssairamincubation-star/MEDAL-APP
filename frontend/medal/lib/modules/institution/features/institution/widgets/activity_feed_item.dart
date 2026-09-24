// lib/features/institution/widgets/activity_feed_item.dart
// Place at: lib/features/institution/widgets/activity_feed_item.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

/// Single item in the "Recent Activity" feed on dashboards.
/// Shows: avatar placeholder + name + time + action text + badge chips.
class ActivityFeedItem extends StatelessWidget {
  const ActivityFeedItem({
    super.key,
    required this.name,
    required this.time,
    required this.action,
    required this.badges,
    this.avatarUrl,
  });

  final String name;
  final String time;
  final String action;
  final List<String> badges;
  final String? avatarUrl;

  Color _badgeColor(String badge) {
    if (badge.contains('CERTIFIED') || badge.contains('LEADER')) {
      return AppTheme.statusActive;
    }
    if (badge.contains('IN PROGRESS')) {
      return AppTheme.statusInProgress;
    }
    if (badge.contains('BADGE')) {
      return AppTheme.statusActive;
    }
    return AppTheme.primary;
  }

  Color _badgeBg(String badge) {
    if (badge.contains('CERTIFIED') || badge.contains('LEADER')) {
      return AppTheme.statusActiveLight;
    }
    if (badge.contains('IN PROGRESS')) {
      return AppTheme.statusInProgressLight;
    }
    return AppTheme.primary.withValues(alpha: 0.08);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: badges.map((b) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeBg(b),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _badgeColor(b),
                          letterSpacing: 0.3,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
