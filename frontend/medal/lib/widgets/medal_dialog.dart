// lib/widgets/medal_dialog.dart
// Single dialog look for every login (citizen, institution, authority, admin),
// copied from the Authority "Log Out" popup: white card, blue border, blue
// header with a white icon disc. Action buttons are always centred.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _medalBlue = Color(0xFF0467B6);

/// Blue-header card shared by every popup. [child] is the body under the header.
class MedalDialogFrame extends StatelessWidget {
  const MedalDialogFrame({
    super.key,
    required this.child,
    this.icon = Icons.close_rounded,
    this.onClose,
    this.headerHeight = 84,
  });

  final Widget child;
  final IconData icon;

  /// Tapping the header disc calls this. When null the disc is decorative.
  final VoidCallback? onClose;
  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = min(340.0, screen.width - 48.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: screen.height * 0.88),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _medalBlue, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: headerHeight,
              color: _medalBlue,
              alignment: Alignment.center,
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _medalBlue, size: 26),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// Drop-in replacement for [AlertDialog] (title / content / actions) that uses
/// the shared look. Actions are centred, wrapping onto a new line if needed.
class MedalAlertDialog extends StatelessWidget {
  const MedalAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon = Icons.info_outline_rounded,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MedalDialogFrame(
      icon: icon,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _medalBlue,
                ),
                child: Center(child: IntrinsicWidth(child: title!)),
              ),
            if (title != null && content != null) const SizedBox(height: 10),
            if (content != null)
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.35,
                  color: const Color(0xFF1E293B),
                ),
                child: content!,
              ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Two-button confirmation (e.g. Cancel + Delete). Resolves to true when the
/// confirm button is pressed, false on cancel, null if dismissed.
Future<bool?> showMedalConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => MedalAlertDialog(
      icon: icon,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelLabel,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                destructive ? const Color(0xFFDC2626) : _medalBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            confirmLabel,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
