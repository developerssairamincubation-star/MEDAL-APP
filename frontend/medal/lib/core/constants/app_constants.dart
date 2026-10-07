// lib/core/constants/app_constants.dart
// App-wide constants for the MEDAL application.

import 'package:flutter/material.dart';

/// Centralized constants used across the MEDAL application.
abstract final class AppConstants {
  // ── App Identity ──────────────────────────────────────────────
  static const String appName = 'MEdAL';
  static const String appTagline = 'Empowering Citizens. Enabling Institutions.';

  // ── Timing ────────────────────────────────────────────────────
  static const Duration splashDuration = Duration(milliseconds: 2500);
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Duration staggerDelay = Duration(milliseconds: 200);

  // ── Spacing ───────────────────────────────────────────────────
  static const double cardBorderRadius = 20.0;
  static const double buttonBorderRadius = 16.0;
  static const double pagePadding = 24.0;

  // ── Brand Colors (quick-access for non-themed contexts) ──────
  static const Color brandPrimary = Color(0xFF2321BC);
  static const Color brandPrimaryLight = Color(0xFFEEF0FD);
  static const Color brandDark = Color(0xFF111C2D);
  static const Color brandSecondary = Color(0xFF5D6478);
  static const Color brandBorder = Color(0xFFC6C5D7);
  static const Color brandBackground = Color(0xFFF8FAFC);
}
