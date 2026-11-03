// lib/features/institution/widgets/medal_app_bar.dart
// Place at: lib/features/institution/widgets/medal_app_bar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../widgets/medal_logo.dart';
import '../../../theme/app_theme.dart';

/// Reusable MEdAL top app bar.
/// Matches the screenshots: medal icon + "MEdAL" bold text in indigo.
class MedalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MedalAppBar({
    super.key,
    this.actions,
    this.showBackButton = false,
  });

  final List<Widget>? actions;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: const _MedalLogo(),
      titleSpacing: showBackButton ? 0 : NavigationToolbar.kMiddleSpacing,
      actions: actions,
    );
  }
}

/// Inline logo widget — medal icon + "MEdAL" text.
class _MedalLogo extends StatelessWidget {
  const _MedalLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MedalLogo(iconSize: 18),
        const SizedBox(width: 6),
        Text(
          'MEdAL',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Standalone logo widget used on the login screen (larger).
class MedalLogoLarge extends StatelessWidget {
  const MedalLogoLarge({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MedalLogo(iconSize: 34),
        const SizedBox(height: 12),
        Text(
          'MEdAL',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
