// lib/main.dart
// Unified application entry point for the MEdAL project.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep system UI status bar styles matching our lavender-grey background aesthetics
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MedalRootApp());
}

class MedalRootApp extends StatelessWidget {
  const MedalRootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEdAL',
      debugShowCheckedModeBanner: false,
      theme: MedalTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}