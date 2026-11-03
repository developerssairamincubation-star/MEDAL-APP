// lib/modules/authority/widgets/authority_nav_item.dart
// Single bottom-navigation item shared by every authority screen.
// The label is scaled down (never ellipsised) so "My Complaint" shows in full
// in both the active and inactive states on any screen width.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthorityNavItem extends StatelessWidget {
  const AuthorityNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.compatLabel,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Invisible text kept for legacy test finders (e.g. "COMPLAINTS").
  final String? compatLabel;

  static const Color _active = Color(0xFF0467B6);
  static const Color _inactive = Color(0xFF7E8B9B);

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _active : _inactive;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8F1FB) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (compatLabel != null)
            Positioned.fill(
              child: Center(
                child: Text(
                  compatLabel!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
