// lib/core/theme/app_theme.dart
// Unified Material 3 theme for the MEDAL application.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MEDAL Design System — Unified Material 3 Theme.
/// Brand color: Indigo #4F46E5.
abstract final class MedalTheme {
  // ── Palette from Design System Specification ─────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkNavy = Color(0xFF111C2D);
  static const Color brandBlue = Color(0xFF2321BC);
  static const Color slateBlue = Color(0xFF5D6478);
  static const Color black = Color(0xFF000000);
  static const Color black05 = Color(0x0D000000); // 000000 5%
  static const Color charcoal = Color(0xFF464555);
  static const Color slate = Color(0xFF575E72);
  static const Color gray64 = Color(0xA36B7280); // 6B7280 64%
  static const Color gray46 = Color(0x756B7280); // 6B7280 46%
  static const Color lavenderBorder = Color(0xFFC6C5D7); // C6C5D7 100%

  // ── Brand Colors ──────────────────────────────────────────────
  static const Color primary = brandBlue; // #2321BC
  static const Color primaryDark = Color(0xFF1A18A0);
  static const Color primaryLight = Color(0xFF4340E0);
  static const Color primaryTint = Color(0xFFEEF0FD);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = white;

  static const Color textPrimary = darkNavy; // #111C2D
  static const Color textSecondary = slateBlue; // #5D6478
  static const Color textMuted = gray64; // #6B7280 64%
  static const Color border = lavenderBorder; // #C6C5D7

  // ── Gradient (used in Splash Screen) ──────────────────────────
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2321BC),
      Color(0xFF1A18A0),
      Color(0xFF111C2D),
    ],
  );

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
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
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
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
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
    );
  }
}
