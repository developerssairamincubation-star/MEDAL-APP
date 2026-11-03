// lib/modules/institution/features/institution/screens/student/student_dashboard_screen.dart
// Student Dashboard Screen matching Screenshots 3 & 4.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import 'package:medal/widgets/medal_dialog.dart';
import '../../state/student_session_state.dart';
import '../../widgets/student_shell_scaffold.dart';
import '../../widgets/unesco_logo.dart';

class StudentDashboardScreen extends StatefulWidget {
  final bool showInitialPopup;

  const StudentDashboardScreen({
    super.key,
    this.showInitialPopup = true,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _isLoading = true;
  String _welcomeName = '';
  int _streakDays = 0;
  int _overallCompletionPct = 0;
  int _chaptersDone = 0;
  int _chaptersTotal = 0;

  int _certificationsReady = 0;
  int _enrolledCourses = 0;
  int _enrollmentPending = 0;

  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData().then((_) => _maybeShowImpactCard());
  }

  /// Shows the impact-progress card once per login session (students only).
  void _maybeShowImpactCard() {
    if (!mounted || !widget.showInitialPopup) return;
    if (StudentSessionState.impactCardShown) return;
    StudentSessionState.impactCardShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showImpactCard();
    });
  }

  Future<void> _fetchDashboardData() async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;
      final uri = Uri.parse('$baseUrl/student/dashboard');

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _welcomeName = data['welcome_name'] ?? '';
            _streakDays = data['streak_days'] ?? 0;
            _overallCompletionPct = data['overall_completion_pct'] ?? 0;
            _chaptersDone = (data['chapters']?['completed'] ?? 0) as int;
            _chaptersTotal = (data['chapters']?['total'] ?? 0) as int;

            final stats = data['stats'] ?? {};
            _certificationsReady = stats['certifications_ready'] ?? 0;
            _enrolledCourses = stats['enrolled_courses'] ?? 0;
            _enrollmentPending = stats['enrollment_pending'] ?? 0;

            _recentActivity = List<Map<String, dynamic>>.from(data['recent_activity'] ?? []);
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

  String get _impactLevel {
    if (_overallCompletionPct >= 100) return 'SEEK Graduate';
    if (_overallCompletionPct >= 75) return 'Champion';
    if (_overallCompletionPct >= 50) return 'Achiever';
    if (_overallCompletionPct >= 25) return 'Explorer';
    return 'Starter';
  }

  /// Single card showing the student's impact level; tapping it opens Course Progress.
  void _showImpactCard() {
    showDialog(
      context: context,
      builder: (ctx) {
        void openProgress() {
          Navigator.pop(ctx);
          context.go(AppRoutes.studentCourseProgress);
        }

        return MedalAlertDialog(
          icon: Icons.school_rounded,
          title: const Text('Level Up Your Impact'),
          content: InkWell(
            key: const Key('impact_progress_card'),
            onTap: openProgress,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F7FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6E6F5)),
              ),
              child: Column(
                children: [
                  Text(
                    'Level: $_impactLevel',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0467B6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _overallCompletionPct / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFD6DFE8),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0467B6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _chaptersTotal > 0
                        ? '$_chaptersDone of $_chaptersTotal chapters completed'
                        : '$_overallCompletionPct% completed',
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Not now',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: openProgress,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0467B6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'View Progress',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return '';
    final local = d.isUtc ? d.toLocal() : d;
    return '${local.day.toString().padLeft(2, '0')} ${_months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StudentShellScaffold(
      currentTabIndex: 0,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WELCOME BACK Header
              Text(
                'WELCOME BACK , ${_welcomeName.toUpperCase()}',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),

              // Overall Performance Card (Screenshot 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E4EC)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall Performance',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFEA580C),
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Streak: $_streakDays Days',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0467B6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Circular Progress Indicator (Screenshot 4)
                    SizedBox(
                      width: 74,
                      height: 74,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 74,
                            height: 74,
                            child: CircularProgressIndicator(
                              value: _overallCompletionPct / 100,
                              strokeWidth: 3.5,
                              backgroundColor: const Color(0xFFD6DFE8),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0467B6)),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_overallCompletionPct%',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'COMPLETED',
                                style: GoogleFonts.inter(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.4,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 Stat Cards in 2x2 Grid (Screenshot 4)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      number: _certificationsReady.toString().padLeft(2, '0'),
                      label: 'Certification Ready',
                      badge: 'COMPLETED',
                      accentColor: const Color(0xFF0D9488), // Teal
                      badgeBgColor: const Color(0xFFE6FFFA),
                      onTap: () => context.go('${AppRoutes.studentAcademy}?tab=certificates'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      number: _enrolledCourses.toString().padLeft(2, '0'),
                      label: 'Enrolled Courses',
                      badge: 'ACTIVE',
                      accentColor: const Color(0xFF7C3AED), // Purple
                      badgeBgColor: const Color(0xFFF3E8FF),
                      onTap: () => context.go(AppRoutes.studentCourseProgress),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      number: _chaptersDone.toString(),
                      label: 'Chapters Completed',
                      badge: 'PROGRESS',
                      accentColor: const Color(0xFF0467B6), // Blue
                      badgeBgColor: const Color(0xFFE6F2FA),
                      onTap: () => context.go(AppRoutes.studentCourseProgress),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      number: _enrollmentPending.toString().padLeft(2, '0'),
                      label: 'Enrollment Pending',
                      badge: 'PENDING',
                      accentColor: const Color(0xFF0284C7), // Sky Blue
                      badgeBgColor: const Color(0xFFE0F2FE),
                      onTap: () => context.push(AppRoutes.studentPendingCourses),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Daily Insights Section
              Text(
                'Daily Insights',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              // Recent Activity Subtitle Row + View All
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF0467B6),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Recent Activity',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  if (_recentActivity.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        final rawId = _recentActivity.first['course_id'] ?? 1;
                        final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 1;
                        context.push('/student/course-detail/$id');
                      },
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0467B6),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Recent activity: chapters the student has completed
              if (_recentActivity.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E4EC)),
                  ),
                  child: Text(
                    'No chapters completed yet. Finish a chapter in your SEEK course and it will show up here.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                )
              else
                ..._recentActivity.map((act) {
                  final rawId = act['course_id'] ?? 1;
                  final courseId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildActivityCard(
                      courseId: courseId,
                      title: (act['title'] ?? 'Chapter').toString(),
                      module: (act['module_title'] ?? '').toString(),
                      completedOn: _formatDate(act['completed_at']),
                    ),
                  );
                }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String number,
    required String label,
    required String badge,
    required Color accentColor,
    required Color badgeBgColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E4EC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Left vertical accent line
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          number,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
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
      ),
    );
  }

  Widget _buildActivityCard({
    required int courseId,
    required String title,
    required String module,
    required String completedOn,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/student/course-detail/$courseId');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E4EC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Left accent pill
              Positioned(
                left: 0,
                top: 2,
                bottom: 2,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0467B6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // UNESCO Logo
                    const UnescoLogoWidget(width: 88),
                    const SizedBox(width: 14),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F2FA),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0467B6),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 9,
                                      color: Color(0xFF0467B6),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            module,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Completed :   $completedOn',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
