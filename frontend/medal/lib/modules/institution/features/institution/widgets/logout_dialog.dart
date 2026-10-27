// lib/modules/institution/features/institution/widgets/logout_dialog.dart
// Logout Confirmation Dialog matching Screenshot 10.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medal/modules/institution/features/institution/providers/auth_provider.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';

class LogoutDialog extends ConsumerWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Blue Banner with White Circular Close/X Icon (Screenshot 10)
            Container(
              width: double.infinity,
              height: 100,
              color: const Color(0xFF0467B6),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF0467B6),
                    size: 26,
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0467B6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Are you sure\nyou want to log out?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // "No" Button (Solid Blue, as in Screenshot 10)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0467B6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'No',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // "Yes" Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go(AppRoutes.login);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Yes, Log Out',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
