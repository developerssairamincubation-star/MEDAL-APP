// lib/widgets/post_subject.dart
// Subject (title) line shown above a post's description on every feed card and
// detail page, for every role. Hidden only when it would just repeat the body.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PostSubject extends StatelessWidget {
  const PostSubject({
    super.key,
    required this.title,
    this.description = '',
    this.fontSize = 14,
    this.bottomSpacing = 4,
  });

  final String title;
  final String description;
  final double fontSize;
  final double bottomSpacing;

  /// True when there is a subject worth showing above [description].
  static bool shouldShow(String title, String description) {
    final t = title.trim();
    return t.isNotEmpty && t != description.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow(title, description)) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Text(
        title.trim(),
        key: const Key('post_subject'),
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111C2D),
          height: 1.3,
        ),
      ),
    );
  }
}
