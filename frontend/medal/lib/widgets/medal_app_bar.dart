import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Common application header shell matching the Figma reference design.
/// Features a pure white background, the indigo MEDAL medal logo and stylized
/// typography on the left, and a notification bell icon on the right.
class MedalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onNotificationPressed;
  final bool showNotification;
  final double elevation;

  const MedalAppBar({
    super.key,
    this.leading,
    this.trailing,
    this.onNotificationPressed,
    this.showNotification = true,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: elevation,
      automaticallyImplyLeading: false,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleSpacing: 16.0,
      title: leading ??
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.military_tech_rounded,
                color: Color(0xFF0467B6),
                size: 26,
              ),
              SizedBox(width: 8),
              Text(
                "MEdAL",
                style: TextStyle(
                  color: Color(0xFF111C2D),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
      actions: [
        if (trailing != null)
          trailing!
        else if (showNotification)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(
                Icons.notifications,
                color: Color(0xFF5D6478),
                size: 24,
              ),
              tooltip: "Notifications",
              onPressed: onNotificationPressed ?? () {},
            ),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1.0),
        child: Divider(
          height: 1.0,
          thickness: 1.0,
          color: Color(0xFFF1F5F9),
        ),
      ),
    );
  }
}
