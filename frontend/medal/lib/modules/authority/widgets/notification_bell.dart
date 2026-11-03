// lib/modules/authority/widgets/notification_bell.dart
// Notification bell with an unread dot driven by AuthorityNotificationState.
// Only the Dashboard and Profile headers should show it.

import 'package:flutter/material.dart';
import '../state/authority_notification_state.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _state = AuthorityNotificationState.instance;

  @override
  void initState() {
    super.initState();
    _state.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('notification_bell'),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ListenableBuilder(
          listenable: _state,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications,
                color: Color(0xFF475569),
                size: 24,
              ),
              if (_state.hasUnread)
                Positioned(
                  top: 1,
                  right: 2,
                  child: Container(
                    key: const Key('notification_unread_dot'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
