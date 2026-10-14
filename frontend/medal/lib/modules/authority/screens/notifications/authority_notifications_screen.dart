// lib/modules/authority/screens/notifications/authority_notifications_screen.dart
// Dedicated Authority Notifications screen opened by the top bar bell icon.
// Preserves the existing Citizen notification behavior without conflict.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/authority_models.dart';
import '../complaints/authority_complaint_detail_screen.dart';

class AuthorityNotificationsScreen extends StatefulWidget {
  const AuthorityNotificationsScreen({super.key});

  @override
  State<AuthorityNotificationsScreen> createState() => _AuthorityNotificationsScreenState();
}

class _AuthorityNotificationsScreenState extends State<AuthorityNotificationsScreen> {
  String _selectedFilter = 'All';
  late List<AuthorityNotificationItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(MockAuthorityRepository.notifications);
  }

  void _markAllAsRead() {
    setState(() {
      _items = _items
          .map((item) => AuthorityNotificationItem(
                id: item.id,
                title: item.title,
                body: item.body,
                timestamp: item.timestamp,
                isRead: true,
                isUrgent: item.isUrgent,
                relatedComplaintId: item.relatedComplaintId,
              ))
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read.'),
        backgroundColor: MedalTheme.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<AuthorityNotificationItem> get _filteredItems {
    if (_selectedFilter == 'Urgent / SLA') {
      return _items.where((n) => n.isUrgent).toList();
    } else if (_selectedFilter == 'System') {
      return _items.where((n) => !n.isUrgent).toList();
    }
    return _items;
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: MedalTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: MedalTheme.darkNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              "Authority Alerts",
              style: TextStyle(
                color: MedalTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount NEW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              "Mark All Read",
              style: TextStyle(
                color: MedalTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: MedalTheme.lavenderBorder),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Urgent / SLA'),
                const SizedBox(width: 8),
                _buildFilterChip('System'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: MedalTheme.lavenderBorder),

          // Notifications List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 48, color: MedalTheme.slateBlue.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          "No notifications found",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MedalTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildNotificationCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MedalTheme.primary : MedalTheme.primaryTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MedalTheme.primary : MedalTheme.lavenderBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : MedalTheme.textSecondary,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AuthorityNotificationItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : MedalTheme.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isUrgent
              ? const Color(0xFFFECACA)
              : (item.isRead
                  ? MedalTheme.lavenderBorder
                  : MedalTheme.primaryLight.withValues(alpha: 0.4)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.isUrgent ? const Color(0xFFFEE2E2) : MedalTheme.primaryTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isUrgent ? Icons.warning_amber_rounded : Icons.notifications_active_outlined,
              color: item.isUrgent ? const Color(0xFFDC2626) : MedalTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                          color: MedalTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(item.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: MedalTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: MedalTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (item.relatedComplaintId != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      final complaint = MockAuthorityRepository.complaints.firstWhere(
                        (c) => c.id == item.relatedComplaintId,
                        orElse: () => MockAuthorityRepository.complaints.first,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AuthorityComplaintDetailScreen(
                            complaint: complaint,
                            onStatusChanged: () => setState(() {}),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MedalTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new, size: 14, color: MedalTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            "View Details (${item.relatedComplaintId})",
                            style: const TextStyle(
                              color: MedalTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
