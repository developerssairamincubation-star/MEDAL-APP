// lib/modules/institution/features/institution/screens/student/student_course_detail_screen.dart
// Course Details screen matching Screenshot 6.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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

  // Chapters come from the API (data source: student_course_chapters).
  List<Map<String, dynamic>> _chapterModules = [];
  int _chaptersDone = 0;
  int _chaptersTotal = 0;

  double get _progress =>
      _chaptersTotal == 0 ? 0.0 : _chaptersDone / _chaptersTotal;

  Map<String, String> get _authHeaders {
    final token = ApiService().token;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _fetchCourseDetail();
    _fetchChapters();
  }

  void _applyChapters(dynamic data) {
    final modules = List<Map<String, dynamic>>.from(
      (data['modules'] as List? ?? const []).map((m) => Map<String, dynamic>.from(m as Map)),
    );
    _chapterModules = modules;
    _chaptersDone = (data['completed_chapters'] ?? 0) as int;
    _chaptersTotal = (data['total_chapters'] ?? 0) as int;
  }

  Future<void> _fetchChapters() async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiService().baseUrl}/student/courses/${widget.courseId}/chapters'),
        headers: _authHeaders,
      );
      if (resp.statusCode == 200 && mounted) {
        setState(() => _applyChapters(jsonDecode(resp.body)));
      }
    } catch (_) {}
  }

  Future<void> _setChapterCompleted(Map<String, dynamic> chapter, bool done) async {
    final previous = chapter['completed'] == true;
    setState(() => chapter['completed'] = done);
    try {
      final resp = await http.put(
        Uri.parse('${ApiService().baseUrl}/student/chapters/${chapter['id']}/completion'),
        headers: _authHeaders,
        body: jsonEncode({'completed': done}),
      );
      if (resp.statusCode == 200) {
        if (mounted) {
          setState(() {
            _applyChapters(jsonDecode(resp.body));
            if (_enrollmentStatus == 'not_enrolled') _enrollmentStatus = 'enrolled';
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => chapter['completed'] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your progress. Please try again.')),
      );
    }
  }

  Future<void> _openChapterLink(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this chapter link.')),
      );
    }
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

  int _minutes(String? d) =>
      int.tryParse(RegExp(r'\d+').firstMatch(d ?? '')?.group(0) ?? '') ?? 0;

  /// Modules for the list, with status derived from the live completions.
  List<Map<String, dynamic>> get _courseModules {
    var activeAssigned = false;
    return _chapterModules.map((m) {
      final chapters = List<Map<String, dynamic>>.from(m['chapters'] as List);
      final done = chapters.where((c) => c['completed'] == true).length;
      String status;
      if (chapters.isNotEmpty && done == chapters.length) {
        status = 'Completed';
      } else if (!activeAssigned) {
        status = 'In Progress';
        activeAssigned = true;
      } else {
        status = 'Upcoming';
      }
      final minutes = chapters.fold<int>(0, (t, c) => t + _minutes(c['duration']?.toString()));
      return {
        'number': m['number'],
        'title': m['title'],
        'duration': '$minutes mins',
        'lessons_count': chapters.length,
        'status': status,
        'lessons': chapters,
      };
    }).toList();
  }

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
                        final lTitle = '${lesson['key'] ?? ''} ${lesson['title'] ?? 'Chapter'}'.trim();
                        final lUrl = (lesson['url'] ?? '').toString();
                        final lType = lesson['type'] ?? 'reading';
                        final lDur = lesson['duration'] ?? '';
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
                              onTap: () async {
                                // A chapter with a link opens it; one without toggles completion.
                                if (lUrl.isNotEmpty) {
                                  _openChapterLink(lUrl);
                                } else {
                                  await _setChapterCompleted(lesson, !isDone);
                                  setSheetState(() {});
                                }
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
                                    InkWell(
                                      key: Key('chapter_toggle_${lesson['id']}'),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () async {
                                        await _setChapterCompleted(lesson, !isDone);
                                        setSheetState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDone ? const Color(0xFFE8F8F0) : const Color(0xFF0467B6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isDone ? 'Done' : 'Mark done',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDone ? const Color(0xFF2ECC71) : Colors.white,
                                          ),
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

    final title = _courseData?['title'] ?? 'SEEK Course';
    final provider = _courseData?['provider'] ?? 'UNESCO';
    final desc = _courseData?['description'] ?? '';
    final duration = _courseData?['duration'] ?? '';
    final language = _courseData?['language'] ?? 'English';
    final deadline = _courseData?['enrollment_deadline'] as String?;
    final deadlineDays = _courseData?['deadline_remaining_text'] as String?;
    final hasDeadline = deadline != null && deadline.isNotEmpty;

    final List<dynamic> whatYoullLearn = _courseData?['what_you_will_learn'] ?? const [];

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
            const SizedBox(height: 16),

            // Progress from the chapters the student has completed
            Container(
              key: const Key('course_progress_bar'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E4EC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Progress',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0467B6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFECEFF5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progress >= 1.0 ? const Color(0xFF2ECC71) : const Color(0xFF0467B6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_chaptersDone of $_chaptersTotal chapters completed',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
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

            // Enrollment deadline (only when the course has one)
            if (hasDeadline)
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
                      deadlineDays ?? '',
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
                  '${_chapterModules.length} Modules • $_chaptersTotal Chapters',
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
                                      '$lessonsCount chapters  •  $modDuration',
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
                          final modules = _courseModules;
                          if (modules.isNotEmpty) {
                            _openModuleContentSheet(
                              context,
                              modules.firstWhere(
                                (m) => m['status'] != 'Completed',
                                orElse: () => modules.first,
                              ),
                            );
                          }
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
