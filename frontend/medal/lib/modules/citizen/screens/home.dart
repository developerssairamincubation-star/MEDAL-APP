import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:medal/modules/citizen/screens/academy.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/widgets/medal_app_bar.dart';

/// Shows the "Level Up Your Impact" Academy modal popup overlay on top of the current screen (Feed).
/// The background Feed is dimmed and subtly blurred while preserving full visibility and widget tree state.
Future<void> showAcademyModalPopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: LevelUpImpactPopup(
                onExploreAcademy: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AcademyScreen(),
                    ),
                  );
                },
                onNoThanks: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The approved Level Up Your Impact popup UI component.
class LevelUpImpactPopup extends StatelessWidget {
  final VoidCallback onExploreAcademy;
  final VoidCallback onNoThanks;

  const LevelUpImpactPopup({
    super.key,
    required this.onExploreAcademy,
    required this.onNoThanks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF4F46E5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.school,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Level Up Your Impact",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              "Join our new Academy module to learn how to create more effective reports and drive real community change.",
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                ),
                onPressed: onExploreAcademy,
                child: const Text(
                  "Explore Academy",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onNoThanks,
            child: const Text(
              "No Thanks",
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Kept for backwards compatibility and direct route testing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: const MedalAppBar(),
      body: Center(
        child: LevelUpImpactPopup(
          onExploreAcademy: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const AcademyScreen(),
              ),
              (route) => false,
            );
          },
          onNoThanks: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const MainScreen(),
              ),
              (route) => false,
            );
          },
        ),
      ),
    );
  }
}