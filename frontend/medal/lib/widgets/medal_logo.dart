// lib/widgets/medal_logo.dart
// Single source of truth for the MEdAL logo badge. This is the badge shown on
// the splash screen, reused on every entry/login screen and app bar.

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class MedalLogo extends StatelessWidget {
  const MedalLogo({
    super.key,
    this.iconSize = 72,
    this.onGradient = false,
  });

  /// Size of the medal glyph. Padding and ring scale proportionally
  /// (the splash screen uses 72).
  final double iconSize;

  /// True when drawn over [MedalTheme.splashGradient] (the splash screen).
  /// Otherwise a gradient disc is painted behind the badge so it looks
  /// identical on light backgrounds.
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final scale = iconSize / 72;
    final badge = Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: (2 * scale).clamp(1.0, 2.0),
        ),
      ),
      child: Icon(
        Icons.military_tech_rounded,
        color: Colors.white,
        size: iconSize,
      ),
    );
    if (onGradient) return badge;
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: MedalTheme.splashGradient,
      ),
      child: badge,
    );
  }
}

/// Logo badge + "MEdAL" wordmark used in headers of light screens.
class MedalLogoWithName extends StatelessWidget {
  const MedalLogoWithName({super.key, this.iconSize = 40, this.fontSize = 28});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MedalLogo(iconSize: iconSize),
        const SizedBox(height: 8),
        Text(
          'MEdAL',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: MedalTheme.darkNavy,
          ),
        ),
      ],
    );
  }
}
