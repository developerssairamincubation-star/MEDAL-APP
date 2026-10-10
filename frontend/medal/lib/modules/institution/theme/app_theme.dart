// lib/theme/app_theme.dart
// Place at: lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MEDAL Design System — Material 3 Theme
/// Unified Design System Material 3 Theme for MEDAL Institution
abstract final class AppTheme {
  // ── Palette from Design System Specification ─────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkNavy = Color(0xFF111C2D);
  static const Color brandBlue = Color(0xFF0467B6);
  static const Color slateBlue = Color(0xFF5D6478);
  static const Color black = Color(0xFF000000);
  static const Color black05 = Color(0x0D000000); // 000000 5%
  static const Color charcoal = Color(0xFF464555);
  static const Color slate = Color(0xFF575E72);
  static const Color gray = Color(0xFF6B7280);
  static const Color gray64 = Color(0xA36B7280); // 6B7280 64%
  static const Color gray46 = Color(0x756B7280); // 6B7280 46%
  static const Color lavenderBorder = Color(0xFFC6C5D7); // C6C5D7 100%

  // ── Brand Colors ──────────────────────────────────────────────
  static const Color primary = brandBlue; // #0467B6
  static const Color primaryDark = Color(0xFF035293);
  static const Color primaryLight = Color(0xFF1A82D2);

  static const Color background = Color(0xFFF0F0FA); // lavender-grey
  static const Color surface = white;
  static const Color cardSurface = white;

  static const Color textPrimary = darkNavy; // #111C2D
  static const Color textSecondary = slateBlue; // #5D6478
  static const Color textMuted = gray64; // #6B7280 64%
  static const Color border = lavenderBorder; // #C6C5D7

  // Status badge colors
  static const Color statusActive = Color(0xFF2ECC71);
  static const Color statusActiveLight = Color(0xFFE8F8F0);
  static const Color statusCompleted = Color(0xFF2ECC71);
  static const Color statusCompletedLight = Color(0xFFE8F8F0);
  static const Color statusInProgress = Color(0xFF9B59B6);
  static const Color statusInProgressLight = Color(0xFFF3E8FF);
  static const Color statusInactive = Color(0xFFE74C3C);
  static const Color statusInactiveLight = Color(0xFFFFECEB);
  static const Color statusWaitlist = Color(0xFFF39C12);
  static const Color statusWaitlistLight = Color(0xFFFFF3E0);
  static const Color statusOnTrack = Color(0xFF2ECC71);
  static const Color statusNeedsSupport = Color(0xFFE74C3C);

  // Accent card left-border colors
  static const Color accentGreen = Color(0xFF2ECC71);
  static const Color accentPurple = Color(0xFF9B59B6);
  static const Color accentRed = Color(0xFFE74C3C);
  static const Color accentOrange = Color(0xFFF39C12);

  // ── Light Theme ───────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surface,
        onSurface: textPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F8FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: statusInactive),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primary,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9CA3AF),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: primary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade100,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFE5E7EB),
        linearMinHeight: 6,
      ),
    );
  }
}
