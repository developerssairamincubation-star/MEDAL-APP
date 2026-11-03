// lib/modules/institution/features/institution/widgets/logout_dialog.dart
// One logout flow for Student, Teacher and Principal, built on the shared
// MedalAlertDialog (centred buttons).
//
// The dialog opens on the host app's root Navigator, which sits above this
// module's ProviderScope, so nothing inside the dialog may use `ref`. The
// provider container is read from the screen's own context instead.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import 'package:medal/widgets/medal_dialog.dart';
import '../providers/auth_provider.dart';

Future<void> confirmAndLogout(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final confirmed = await showMedalConfirmDialog(
    context,
    title: 'Log Out',
    message: 'Are you sure you want to log out?',
    confirmLabel: 'Log Out',
    icon: Icons.logout_rounded,
    destructive: true,
  );
  if (confirmed != true) return;
  await container.read(authProvider.notifier).logout();
  if (context.mounted) context.go(AppRoutes.login);
}
