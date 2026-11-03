// lib/modules/institution/features/institution/screens/student/student_notifications_screen.dart
// Student Notifications screen matching Screenshot 12.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import '../../state/student_notification_state.dart';
import '../../widgets/student_shell_scaffold.dart';

class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() => _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _last7Days = [];
  List<Map<String, dynamic>> _last30Days = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.get(
        Uri.parse('$baseUrl/student/notifications'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        // Opening this page marks everything listed as seen (per user).
        StudentNotificationState.instance.markSeen(data);
        if (mounted) {
          setState(() {
            _last7Days = List<Map<String, dynamic>>.from(data['last_7_days'] ?? []);
            _last30Days = List<Map<String, dynamic>>.from(data['last_30_days'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _iconForCategory(String category) {
    if (category.toLowerCase().contains('academy')) return Icons.groups_outlined;
    if (category.toLowerCase().contains('streak')) return Icons.article_outlined;
    return Icons.grid_view_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return StudentShellScaffold(
      showBackButton: true,
      onBack: () => context.pop(),
      currentTabIndex: 0,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Last 7 days (Screenshot 12)
                  Text(
                    'Last 7 days',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_last7Days.isNotEmpty)
                    ..._last7Days.map((n) {
                      final cat = (n['category'] ?? '').toString();
                      final isAcad = cat.toLowerCase() == 'academy';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildNotificationTile(
                          icon: _iconForCategory(cat),
                          category: isAcad ? 'Academy' : '',
                          boldTitle: !isAcad ? (n['title'] ?? cat) : null,
                          description: n['description'] ?? '',
                          showViewButton: n['show_view'] == true,
                          onView: () {
                            final route = n['action_route']?.toString();
                            if (route != null && route.isNotEmpty) {
                              context.go(route);
                            } else {
                              context.go(AppRoutes.studentCourseProgress);
                            }
                          },
                        ),
                      );
                    })
                  else
                    _emptyNote(),
                  const SizedBox(height: 20),

                  // Section 2: Last 30 days (Screenshot 12)
                  Text(
                    'Last 30 days',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_last30Days.isNotEmpty)
                    ..._last30Days.map((n) {
                      final cat = (n['category'] ?? '').toString();
                      final isAcad = cat.toLowerCase() == 'academy';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildNotificationTile(
                          icon: _iconForCategory(cat),
                          category: isAcad ? 'Academy' : '',
                          boldTitle: !isAcad ? (n['title'] ?? cat) : null,
                          description: n['description'] ?? '',
                          showViewButton: n['show_view'] == true,
                          onView: () {
                            final route = n['action_route']?.toString();
                            if (route != null && route.isNotEmpty) {
                              context.go(route);
                            } else {
                              context.go(AppRoutes.studentAcademy);
                            }
                          },
                        ),
                      );
                    })
                  else
                    _emptyNote(),
                  const SizedBox(height: 36),

                  // Footer (Screenshot 12)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'MEdAL v2.4.0',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _emptyNote() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No notifications yet.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
      );

  Widget _buildNotificationTile({
    required IconData icon,
    required String category,
    required String description,
    String? boldTitle,
    required bool showViewButton,
    VoidCallback? onView,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Leading Icon with circular light blue background (Screenshot 12)
        Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFDCEAF7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF0467B6), size: 22),
            ),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 14),

        // Body Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (boldTitle != null && boldTitle.isNotEmpty)
                Text(
                  boldTitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        // Action button ("view")
        if (showViewButton) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: onView ?? () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDCEAF7),
                foregroundColor: const Color(0xFF0467B6),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'view',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
