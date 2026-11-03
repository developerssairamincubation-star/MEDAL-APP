// lib/modules/institution/features/institution/widgets/overview_sections.dart
// Stat cards and recent-activity feed shared by the Principal and Staff dashboards (live data).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../models/member.dart';
import 'activity_feed_item.dart';
import 'custom_stat_card.dart';

class OverviewStats extends StatelessWidget {
  const OverviewStats({super.key, required this.overview, this.showStaff = true});

  final InstitutionOverview overview;
  final bool showStaff;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (showStaff) ...[
              Expanded(
                child: CustomStatCard(
                  icon: Icons.groups_rounded,
                  label: 'Staff',
                  value: '${overview.totalStaff} Total',
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: CustomStatCard(
                icon: Icons.school_rounded,
                label: 'Students',
                value: '${overview.totalStudents} Total',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomMiniStatCard(
                count: overview.certificationReady,
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
                count: overview.activeStudents,
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
                count: overview.inactiveStudents,
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
                count: overview.enrollmentPending,
                label: 'Enrollment pending',
                badgeLabel: 'WAITLIST',
                accentColor: AppTheme.accentOrange,
                badgeBgColor: AppTheme.statusWaitlistLight,
                badgeTextColor: AppTheme.statusWaitlist,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key, required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Insights',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: AppTheme.primary),
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
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'No activity yet. Completed chapters will show up here.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
          )
        else
          ...entries.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ActivityFeedItem(
                name: a.name,
                time: a.timeAgo,
                action: a.action,
                badges: [a.role.toUpperCase()],
              ),
            ),
          ),
      ],
    );
  }
}
