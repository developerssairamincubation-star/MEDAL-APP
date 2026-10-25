// lib/modules/institution/features/institution/screens/student/student_dashboard_screen.dart
// Student Dashboard Screen matching Screenshots 3 & 4.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
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
  String _welcomeName = 'Dilli Ganesh';
  int _streakDays = 21;
  int _overallCompletionPct = 32;

  int _certificationsReady = 2;
  int _enrolledCourses = 3;
  int _creditsEarned = 115;
  int _enrollmentPending = 2;

  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();

    if (widget.showInitialPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAcademyPromotionModal();
      });
    }
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
            _welcomeName = data['welcome_name'] ?? 'Dilli Ganesh';
            _streakDays = data['streak_days'] ?? 21;
            _overallCompletionPct = data['overall_completion_pct'] ?? 32;

            final stats = data['stats'] ?? {};
            _certificationsReady = stats['certifications_ready'] ?? 2;
            _enrolledCourses = stats['enrolled_courses'] ?? 3;
            _creditsEarned = stats['credits_earned'] ?? 115;
            _enrollmentPending = stats['enrollment_pending'] ?? 2;

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

  void _showAcademyPromotionModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue Header with Graduation Cap
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                color: const Color(0xFF0467B6),
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  children: [
                    Text(
                      'Level Up Your Impact',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Join our new Academy modules to learn how to create more effective reports and drive real community change.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: const Color(0xFF475569),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // "Explore Academy" Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.go(AppRoutes.studentAcademy);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0467B6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Explore Academy',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // "No thanks" Button
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'No thanks',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      number: _creditsEarned.toString(),
                      label: 'Credits Earned',
                      badge: 'POINTS',
                      accentColor: const Color(0xFF0467B6), // Blue
                      badgeBgColor: const Color(0xFFE6F2FA),
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
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.studentPendingCourses),
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

              // Recent Activity Cards (Screenshot 4)
              if (_recentActivity.isEmpty)
                ...[
                  _buildActivityCard(
                    title: 'SEEK COURSE 1',
                    startDate: '06 Oct 2026',
                    endDate: '26 Oct 2026',
                  ),
                  const SizedBox(height: 12),
                  _buildActivityCard(
                    title: 'SEEK COURSE 2',
                    startDate: '09 Oct 2026',
                    endDate: '30 Oct 2026',
                  ),
                ]
              else
                ..._recentActivity.map((act) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildActivityCard(
                      title: act['title'] ?? 'SEEK COURSE',
                      startDate: act['start_date'] ?? '06 Oct 2026',
                      endDate: act['end_date'] ?? '26 Oct 2026',
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
  }) {
    return Container(
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
    );
  }

  Widget _buildActivityCard({
    required String title,
    required String startDate,
    required String endDate,
  }) {
    return Container(
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
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start Date :   $startDate',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'End Date :    $endDate',
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
    );
  }
}
