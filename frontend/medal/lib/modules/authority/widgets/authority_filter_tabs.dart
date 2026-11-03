// lib/modules/authority/widgets/authority_filter_tabs.dart
// Horizontal pill tabs shared by Dashboard, Complaints and Academy so every page
// uses the same look. [AuthorityTabSize.compact] is slightly smaller (Dashboard),
// [AuthorityTabSize.regular] slightly larger (Complaints, Academy).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AuthorityTabSize {
  compact(fontSize: 12, hPad: 15, vPad: 6, height: 32),
  regular(fontSize: 13, hPad: 18, vPad: 8, height: 38);

  const AuthorityTabSize({
    required this.fontSize,
    required this.hPad,
    required this.vPad,
    required this.height,
  });

  final double fontSize;
  final double hPad;
  final double vPad;
  final double height;
}

class AuthorityFilterTabs extends StatelessWidget {
  const AuthorityFilterTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.size = AuthorityTabSize.regular,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AuthorityTabSize size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: size.hPad, vertical: size.vPad),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0467B6) : const Color(0xFFE2EDF9),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[index],
                maxLines: 1,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontSize: size.fontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
