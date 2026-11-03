// lib/modules/institution/institution_app.dart
// Wrapper widget that hosts the entire Institution module.
// It initializes a separate ProviderScope for Riverpod state management
// and runs the GoRouter configuration defined within the module.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

/// Exposes the host (root app) navigator to the Institution module, whose own
/// MaterialApp.router has a separate Navigator that cannot pop back to the
/// role-selection screen.
class InstitutionHostScope extends InheritedWidget {
  const InstitutionHostScope({
    super.key,
    required this.navigator,
    required super.child,
  });

  final NavigatorState navigator;

  static NavigatorState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InstitutionHostScope>()?.navigator;

  @override
  bool updateShouldNotify(InstitutionHostScope oldWidget) => navigator != oldWidget.navigator;
}

class InstitutionAppWrapper extends StatelessWidget {
  const InstitutionAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return InstitutionHostScope(
      navigator: Navigator.of(context),
      child: const ProviderScope(
        child: InstitutionApp(),
      ),
    );
  }
}

class InstitutionApp extends ConsumerWidget {
  const InstitutionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Using PopScope to allow the user to return to the Role Selection Screen
    // if they press the system back button on the initial/login screen of the Institution module.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // If the GoRouter can pop internally, let it pop.
        // Otherwise, pop the wrapper itself from the root navigator.
        if (router.canPop()) {
          router.pop();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: MaterialApp.router(
        title: 'MEdAL – Institution',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
