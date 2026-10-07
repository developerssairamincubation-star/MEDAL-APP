import 'package:flutter/material.dart';

import 'feed.dart';
import 'tracker.dart';
import 'report.dart';
import 'academy.dart';
import 'profile.dart';
import 'home.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final bool showAcademyPopup;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.showAcademyPopup = false,
  });

  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState
    extends State<MainScreen> {

  late int currentIndex;
  bool _popupChecked = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_popupChecked) {
      _popupChecked = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      final shouldShow = widget.showAcademyPopup ||
          (args is Map && args['showAcademyPopup'] == true);
      if (shouldShow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showAcademyModalPopup(context);
          }
        });
      }
    }
  }

  final List<Widget> pages = const [
    FeedScreen(),
    TrackerScreen(),
    ReportScreen(),
    AcademyScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFF1F5F9),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1. FEED TAB
                  _buildNavItem(
                    index: 0,
                    icon: Icons.feed_outlined,
                    label: "FEED",
                    hasActivePill: true,
                  ),

                  // 2. TRACKER TAB
                  _buildNavItem(
                    index: 1,
                    icon: Icons.military_tech_outlined,
                    label: "TRACKER",
                  ),

                  // Center Spacer for Floating Button
                  const SizedBox(width: 56),

                  // 3. ACADEMY TAB
                  _buildNavItem(
                    index: 3,
                    icon: Icons.school_outlined,
                    label: "ACADEMY",
                  ),

                  // 4. PROFILE TAB
                  _buildNavItem(
                    index: 4,
                    icon: Icons.person_outline_rounded,
                    label: "PROFILE",
                  ),
                ],
              ),

              // Floating Center Action Button (+ or ✕)
              Positioned(
                top: -18,
                child: GestureDetector(
                  onTap: () {
                    if (currentIndex == 2) {
                      setState(() {
                        currentIndex = 0;
                      });
                    } else {
                      setState(() {
                        currentIndex = 2;
                      });
                    }
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: currentIndex == 2 ? const Color(0xFFF8FAFC) : const Color(0xFF2321BC),
                      shape: BoxShape.circle,
                      border: currentIndex == 2
                          ? Border.all(color: const Color(0xFF2321BC), width: 3.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2321BC).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      currentIndex == 2 ? Icons.close : Icons.add,
                      color: currentIndex == 2 ? const Color(0xFF2321BC) : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    bool hasActivePill = false,
    bool isTwoLine = false,
  }) {
    final isSelected = currentIndex == index;
    const activeColor = Color(0xFF2321BC);
    const inactiveColor = Color(0xFF5D6478);

    return InkWell(
      onTap: () {
        setState(() {
          currentIndex = index;
        });
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFEEF0FD),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: isTwoLine ? 8.5 : 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.3,
                height: isTwoLine ? 1.05 : 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}