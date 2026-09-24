// lib/features/institution/widgets/custom_profile_tile.dart
// Place at: lib/features/institution/widgets/custom_profile_tile.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

/// Account Management row tile.
/// Icon container + title + subtitle + trailing arrow (or custom widget).
class CustomProfileTile extends StatelessWidget {
  const CustomProfileTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconBgColor,
    this.iconColor,
    this.trailingColor,
    this.onTap,
    this.trailing,
    this.titleColor,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconBgColor;
  final Color? iconColor;
  final Color? trailingColor;
  final Color? titleColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final effectiveIconBg = iconBgColor ??
        (isDestructive
            ? AppTheme.statusInactiveLight
            : const Color(0xFFEEEEFF));
    final effectiveIconColor =
        iconColor ?? (isDestructive ? AppTheme.statusInactive : AppTheme.primary);
    final effectiveTitleColor =
        titleColor ?? (isDestructive ? AppTheme.statusInactive : AppTheme.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isDestructive
              ? Border.all(
                  color: AppTheme.statusInactive.withValues(alpha: 0.15),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: effectiveIconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: effectiveIconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: effectiveTitleColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: trailingColor ??
                      (isDestructive
                          ? AppTheme.statusInactive
                          : AppTheme.textMuted),
                ),
          ],
        ),
      ),
    );
  }
}
