// lib/modules/institution/features/institution/screens/student/student_course_detail_screen.dart
// Course Details screen matching Screenshot 6.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';
import '../../widgets/student_shell_scaffold.dart';
import '../../widgets/unesco_logo.dart';

class StudentCourseDetailScreen extends StatefulWidget {
  final int courseId;

  const StudentCourseDetailScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<StudentCourseDetailScreen> createState() => _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
  bool _isLoading = true;
  bool _isEnrolling = false;

  Map<String, dynamic>? _courseData;
  String _enrollmentStatus = 'not_enrolled';

  @override
  void initState() {
    super.initState();
    _fetchCourseDetail();
  }

  Future<void> _fetchCourseDetail() async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.get(
        Uri.parse('$baseUrl/student/courses/${widget.courseId}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _courseData = data;
            _enrollmentStatus = data['enrollment_status'] ?? 'not_enrolled';
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

  Future<void> _handleEnroll() async {
    setState(() => _isEnrolling = true);

    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.post(
        Uri.parse('$baseUrl/student/courses/${widget.courseId}/enroll'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _enrollmentStatus = 'enrolled';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Successfully enrolled!'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enrollment error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const StudentShellScaffold(
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final title = _courseData?['title'] ?? 'SEEK COURSE 4';
    final provider = _courseData?['provider'] ?? 'UNESCO';
    final desc = _courseData?['description'] ??
        'Learn the fundamentals of SEEK, from key concepts to real-world applications and best practices';
    final duration = _courseData?['duration'] ?? '4 Weeks';
    final language = _courseData?['language'] ?? 'English';
    final deadline = _courseData?['enrollment_deadline'] ?? '25 October 2026';
    final deadlineDays = _courseData?['deadline_remaining_text'] ?? '2 days left';

    final List<dynamic> whatYoullLearn = _courseData?['what_you_will_learn'] ?? [
      'SEEK basics and key concepts',
      'Popular SEEK service models',
      'Hands-on labs with real-world tools',
      'Security and scalability best practices',
    ];

    final isAlreadyEnrolled = _enrollmentStatus == 'enrolled' || _enrollmentStatus == 'completed';

    return StudentShellScaffold(
      showBackButton: true,
      onBack: () => context.pop(),
      currentTabIndex: 2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card with UNESCO Logo & Badge (Screenshot 6)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E4EC)),
              ),
              child: Row(
                children: [
                  const UnescoLogoWidget(width: 95, height: 50),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAlreadyEnrolled ? 'Enrolled' : 'Pending Enrollment',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // About the Course
            Text(
              'About the Course',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF475569),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            // What You'll Learn
            Row(
              children: [
                const Icon(Icons.track_changes_rounded, size: 20, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                Text(
                  "What You'll Learn",
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            ...whatYoullLearn.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2E4EC)),
            const SizedBox(height: 14),

            // Stats Row: Duration | Language | Certificate (Screenshot 6)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetaColumn(
                      icon: Icons.calendar_month_outlined,
                      label: 'Duration',
                      value: duration,
                    ),
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFFE2E4EC)),
                  Expanded(
                    child: _buildMetaColumn(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      value: language,
                    ),
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFFE2E4EC)),
                  Expanded(
                    child: _buildMetaColumn(
                      icon: Icons.card_membership_rounded,
                      label: 'Certificate',
                      value: 'Yes',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Enrollment Deadline Banner (Screenshot 6)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E4EC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled, size: 22, color: Color(0xFF0F172A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enrollment Deadline',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          deadline,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      deadlineDays,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Enroll Now Button (Screenshot 6)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isEnrolling || isAlreadyEnrolled ? null : _handleEnroll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0467B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                ),
                child: _isEnrolling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isAlreadyEnrolled ? 'Already Enrolled' : 'Enroll Now',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF475569)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
