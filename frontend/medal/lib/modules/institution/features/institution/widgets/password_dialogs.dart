// lib/modules/institution/features/institution/widgets/password_dialogs.dart
// Password flows for Principal / Staff:
//  * showForgotPasswordFlow  - e-mail a 6-digit code, verify it, set a new password (login screen)
//  * showManagePasswordDialog - change the password while signed in (profile screen)
//
// Dialogs open on the host app's root Navigator, above this module's ProviderScope, so nothing
// inside them uses `ref`; the sign-out after a password change reads the container from the
// screen's own context (same approach as logout_dialog.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import 'package:medal/widgets/medal_dialog.dart';

import '../../../theme/app_theme.dart';
import '../providers/auth_provider.dart';

const int kMinPasswordLength = 6; // the server rejects anything shorter

InputDecoration _field(String label, {IconData? icon}) => InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

Widget _errorText(String? message) => message == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(message,
            key: const Key('password_dialog_error'),
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFDC2626))),
      );

String _message(Object e) => e is ApiException ? e.message : 'Could not reach the server. Check your connection.';

// ── Forgot password (login screen) ─────────────────────────────────────────

Future<void> showForgotPasswordFlow(BuildContext context, {String initialEmail = ''}) async {
  final messenger = ScaffoldMessenger.of(context);
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
  if (done == true) {
    messenger.showSnackBar(SnackBar(
      content: const Text('Password reset. Sign in with your new password.'),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 0; // 0 e-mail, 1 code, 2 new password
  bool _busy = false;
  String? _error;
  String? _info;
  String? _resetToken;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        final email = _email.text.trim();
        if (!email.contains('@') || email.length < 5) {
          throw ApiException(0, 'Please enter a valid email address.');
        }
        final res = await ApiService().forgotPassword(email: email);
        if (!mounted) return;
        setState(() {
          _step = 1;
          _info = (res['message'] ?? 'If this email is registered, a 6-digit code has been sent.').toString();
        });
      });

  Future<void> _resend() => _run(() async {
        final res = await ApiService().resendOtp(email: _email.text);
        if (mounted) setState(() => _info = (res['message'] ?? 'A new code has been sent.').toString());
      });

  Future<void> _verify() => _run(() async {
        final code = _code.text.trim();
        if (code.length != 6 || int.tryParse(code) == null) {
          throw ApiException(0, 'Enter the 6-digit code from the email.');
        }
        final res = await ApiService().verifyOtp(email: _email.text, otp: code);
        if (!mounted) return;
        setState(() {
          _resetToken = res['reset_token'] as String?;
          _step = 2;
          _info = null;
        });
      });

  Future<void> _reset() => _run(() async {
        if (_password.text.length < kMinPasswordLength) {
          throw ApiException(0, 'Password must be at least $kMinPasswordLength characters.');
        }
        if (_password.text != _confirm.text) throw ApiException(0, 'Passwords do not match.');
        await ApiService().resetPassword(token: _resetToken ?? '', newPassword: _password.text);
        if (mounted) Navigator.of(context).pop(true);
      });

  @override
  Widget build(BuildContext context) {
    final titles = ['Reset Password', 'Enter the code', 'Choose a new password'];
    final primaryLabel = ['Send Code', 'Verify', 'Reset Password'][_step];
    final primaryAction = [_sendCode, _verify, _reset][_step];

    return MedalAlertDialog(
      icon: Icons.lock_reset_rounded,
      title: Text(titles[_step], style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_step == 0) ...[
            Text('Enter your registered email address. We will email you a 6-digit code.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(
              key: const Key('forgot_email_field'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _field('Email', icon: Icons.email_outlined),
            ),
          ] else if (_step == 1) ...[
            Text(_info ?? 'We sent a 6-digit code to ${_email.text.trim()}.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(
              key: const Key('forgot_code_field'),
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: _field('6-digit code', icon: Icons.pin_outlined).copyWith(counterText: ''),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('forgot_resend'),
                onPressed: _busy ? null : _resend,
                child: const Text('Resend code'),
              ),
            ),
          ] else ...[
            TextField(
              key: const Key('forgot_new_password'),
              controller: _password,
              obscureText: true,
              decoration: _field('New password', icon: Icons.lock_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('forgot_confirm_password'),
              controller: _confirm,
              obscureText: true,
              decoration: _field('Confirm new password', icon: Icons.lock_outline_rounded),
            ),
          ],
          _errorText(_error),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('forgot_cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('forgot_primary'),
          onPressed: _busy ? null : primaryAction,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(primaryLabel),
        ),
      ],
    );
  }
}

// ── Manage password (profile screen) ───────────────────────────────────────

/// Changes the signed-in user's password. The server revokes every session afterwards, so on
/// success the user is signed out and sent to the login screen.
Future<void> showManagePasswordDialog(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ManagePasswordDialog(),
  );
  if (changed != true) return;
  await container.read(authProvider.notifier).logout();
  messenger.showSnackBar(SnackBar(
    content: const Text('Password updated. Please sign in again with your new password.'),
    backgroundColor: AppTheme.primary,
    behavior: SnackBarBehavior.floating,
  ));
  router.go(AppRoutes.login);
}

class _ManagePasswordDialog extends StatefulWidget {
  const _ManagePasswordDialog();

  @override
  State<_ManagePasswordDialog> createState() => _ManagePasswordDialogState();
}

class _ManagePasswordDialogState extends State<_ManagePasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (_new.text.length < kMinPasswordLength) {
      setState(() => _error = 'New password must be at least $kMinPasswordLength characters.');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService().changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MedalAlertDialog(
      icon: Icons.sync_lock_rounded,
      title: Text('Manage Password', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('manage_current_password'),
            controller: _current,
            obscureText: true,
            decoration: _field('Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('manage_new_password'),
            controller: _new,
            obscureText: true,
            decoration: _field('New password'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('manage_confirm_password'),
            controller: _confirm,
            obscureText: true,
            decoration: _field('Confirm new password'),
          ),
          _errorText(_error),
          const SizedBox(height: 8),
          Text('You will be signed out and need to sign in again with the new password.',
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('manage_cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('manage_submit'),
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Update'),
        ),
      ],
    );
  }
}
