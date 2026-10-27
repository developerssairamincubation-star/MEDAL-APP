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

  final List<Map<String, dynamic>> _courseModules = [
    {
      'number': 1,
      'title': 'Introduction & Civic Foundations',
      'duration': '35 mins',
      'lessons_count': 3,
      'status': 'Completed',
      'lessons': [
        {'title': '1.1 Welcome to the SEEK Curriculum', 'type': 'video', 'duration': '8 mins', 'completed': true},
        {'title': '1.2 Principles of Civic Grievance Reporting', 'type': 'reading', 'duration': '12 mins', 'completed': true},
        {'title': '1.3 Foundational Quiz: Ethics & Privacy', 'type': 'quiz', 'duration': '15 mins', 'completed': true},
      ],
    },
    {
      'number': 2,
      'title': 'SDG Alignment & Frameworks',
      'duration': '45 mins',
      'lessons_count': 4,
      'status': 'In Progress',
      'lessons': [
        {'title': '2.1 Mapping Local Issues to UN SDG Targets', 'type': 'video', 'duration': '14 mins', 'completed': true},
        {'title': '2.2 Sanitation, Clean Water & Infrastructure (SDG 6 & 9)', 'type': 'reading', 'duration': '10 mins', 'completed': false},
        {'title': '2.3 Sustainable Communities (SDG 11) in Action', 'type': 'reading', 'duration': '11 mins', 'completed': false},
        {'title': '2.4 Assessment: Identifying SDG Indicators', 'type': 'quiz', 'duration': '10 mins', 'completed': false},
      ],
    },
    {
      'number': 3,
      'title': 'Field Verification & Evidence Gathering',
      'duration': '40 mins',
      'lessons_count': 3,
      'status': 'Upcoming',
      'lessons': [
        {'title': '3.1 Accurate Geolocation & GPS Coordinate Tagging', 'type': 'video', 'duration': '10 mins', 'completed': false},
        {'title': '3.2 High-Fidelity Photo Documentation Protocols', 'type': 'reading', 'duration': '15 mins', 'completed': false},
        {'title': '3.3 Verification Lab Exercise', 'type': 'practice', 'duration': '15 mins', 'completed': false},
      ],
    },
    {
      'number': 4,
      'title': 'Institutional Response & Public Accountability',
      'duration': '50 mins',
      'lessons_count': 3,
      'status': 'Upcoming',
      'lessons': [
        {'title': '4.1 Municipal Authority Escalation Paths', 'type': 'video', 'duration': '15 mins', 'completed': false},
        {'title': '4.2 Collaborative Public Commenting & Moderation', 'type': 'reading', 'duration': '15 mins', 'completed': false},
        {'title': '4.3 Case Analysis: Resolution from Submission to Sign-Off', 'type': 'case_study', 'duration': '20 mins', 'completed': false},
      ],
    },
  ];

  void _openModuleContentSheet(BuildContext context, Map<String, dynamic> module) {
    final moduleNum = module['number'];
    final moduleTitle = module['title'];
    final lessons = List<Map<String, dynamic>>.from(module['lessons'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),

                      // Module Badge & Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F2FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'MODULE $moduleNum',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0467B6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text(
                        moduleTitle,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select a lesson below to view syllabus content, study materials, and track module completion.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFFE2E4EC)),
                      const SizedBox(height: 14),

                      // Lessons List
                      ...lessons.map((lesson) {
                        final lTitle = lesson['title'] ?? 'Lesson';
                        final lType = lesson['type'] ?? 'reading';
                        final lDur = lesson['duration'] ?? '10 mins';
                        final isDone = lesson['completed'] == true;

                        IconData typeIcon = Icons.menu_book_rounded;
                        if (lType == 'video') typeIcon = Icons.play_circle_outline_rounded;
                        if (lType == 'quiz') typeIcon = Icons.quiz_outlined;
                        if (lType == 'practice') typeIcon = Icons.handyman_outlined;
                        if (lType == 'case_study') typeIcon = Icons.analytics_outlined;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDone ? const Color(0xFFF8FAFC) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDone ? const Color(0xFFE2E8F0) : const Color(0xFF0467B6).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setSheetState(() {
                                  lesson['completed'] = !isDone;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Selected: $lTitle (${lesson['completed'] ? "Completed" : "In Progress"})'),
                                    backgroundColor: const Color(0xFF0467B6),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? const Color(0xFFE8F8F0)
                                            : const Color(0xFFE6F2FA),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isDone ? Icons.check_circle_rounded : typeIcon,
                                        size: 20,
                                        color: isDone ? const Color(0xFF2ECC71) : const Color(0xFF0467B6),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lTitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                              decoration: isDone ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$lDur  •  ${lType.toString().toUpperCase()}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDone ? const Color(0xFFE8F8F0) : const Color(0xFF0467B6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isDone ? 'Done' : 'Open',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDone ? const Color(0xFF2ECC71) : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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

            // Course Content & Syllabus Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF0F172A)),
                    const SizedBox(width: 8),
                    Text(
                      'Course Content',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  '4 Modules • 13 Lessons',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0467B6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selectable Course Content Modules
            ..._courseModules.map((mod) {
              final number = mod['number'] as int;
              final modTitle = mod['title'] as String;
              final modDuration = mod['duration'] as String;
              final lessonsCount = mod['lessons_count'] as int;
              final modStatus = mod['status'] as String;
              final isModCompleted = modStatus == 'Completed';
              final isModActive = modStatus == 'In Progress';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isModActive ? const Color(0xFF0467B6) : const Color(0xFFE2E4EC),
                    width: isModActive ? 1.5 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openModuleContentSheet(context, mod),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isModCompleted
                                  ? const Color(0xFFE8F8F0)
                                  : isModActive
                                      ? const Color(0xFFE6F2FA)
                                      : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isModCompleted
                                  ? const Icon(Icons.check_rounded, color: Color(0xFF2ECC71), size: 20)
                                  : Text(
                                      '$number',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isModActive ? const Color(0xFF0467B6) : const Color(0xFF64748B),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  modTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '$lessonsCount lessons  •  $modDuration',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isModCompleted
                                  ? const Color(0xFFE8F8F0)
                                  : isModActive
                                      ? const Color(0xFFE6F2FA)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              modStatus,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isModCompleted
                                    ? const Color(0xFF2ECC71)
                                    : isModActive
                                        ? const Color(0xFF0467B6)
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 18),

            // Enroll / Resume Course Content Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isEnrolling
                    ? null
                    : () {
                        if (isAlreadyEnrolled) {
                          _openModuleContentSheet(context, _courseModules[1]);
                        } else {
                          _handleEnroll();
                        }
                      },
                icon: isAlreadyEnrolled
                    ? const Icon(Icons.play_circle_filled_rounded, size: 20)
                    : const Icon(Icons.school_rounded, size: 18),
                label: _isEnrolling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isAlreadyEnrolled ? 'Resume Course Content' : 'Enroll Now',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0467B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
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
