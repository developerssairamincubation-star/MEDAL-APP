// lib/features/institution/widgets/student_list_card.dart
// Place at: lib/features/institution/widgets/student_list_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../models/student.dart';

/// Card used in the My Class screen.
/// Shows: avatar + status label + name + percentage + progress bar + View Details / Nudge.
class StudentListCard extends StatelessWidget {
  const StudentListCard({
    super.key,
    required this.student,
    this.onViewDetails,
    this.onNudge,
  });

  final Student student;
  final VoidCallback? onViewDetails;
  final VoidCallback? onNudge;

  Color _statusColor(StudentStatus s) {
    switch (s) {
      case StudentStatus.activeLearning:
        return AppTheme.statusOnTrack;
      case StudentStatus.needsSupport:
        return AppTheme.statusNeedsSupport;
      case StudentStatus.inactive:
        return AppTheme.statusInactive;
    }
  }

  Color _progressColor(StudentStatus s) {
    switch (s) {
      case StudentStatus.activeLearning:
        return AppTheme.primary;
      case StudentStatus.needsSupport:
        return AppTheme.statusNeedsSupport;
      case StudentStatus.inactive:
        return AppTheme.statusInactive;
    }
  }

  String _progressLabel(StudentStatus s) {
    switch (s) {
      case StudentStatus.activeLearning:
        return 'ON TRACK';
      case StudentStatus.needsSupport:
        return 'INACTIVE';
      case StudentStatus.inactive:
        return 'INACTIVE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(student.status);
    final progressColor = _progressColor(student.status);
    final pct = (student.completionPct * 100).toInt();
    final isNeedsSupport = student.status == StudentStatus.needsSupport;

    return Container(
      padding: const EdgeInsets.all(14),
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
          GestureDetector(
            onTap: onViewDetails,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.10),
                child: Text(
                  student.name.substring(0, 1),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.status.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      student.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pct%',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    _progressLabel(student.status),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: student.completionPct,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          // Last active (for needs support)
          if (isNeedsSupport) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  student.lastActive,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isNeedsSupport)
                GestureDetector(
                  onTap: onNudge,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_none_rounded,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Nudge',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onViewDetails,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppTheme.primary),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
