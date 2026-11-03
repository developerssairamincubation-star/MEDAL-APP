// lib/modules/institution/features/institution/screens/student/student_academy_screen.dart
// Student Academy screen matching Screenshots 7 (My Courses) & 8 (My Certificates).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';
import '../../widgets/student_shell_scaffold.dart';
import '../../../../../../widgets/medal_logo.dart';

class StudentAcademyScreen extends StatefulWidget {
  final int initialTabIndex; // 0: My Courses, 1: My Certificates

  const StudentAcademyScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<StudentAcademyScreen> createState() => _StudentAcademyScreenState();
}

class _StudentAcademyScreenState extends State<StudentAcademyScreen> {
  late int _selectedTab; // 0 for My Courses, 1 for My Certificates
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _certificates = [];
  bool _isLoadingCourses = true;
  bool _isLoadingCerts = true;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _fetchCourses();
    _fetchCertificates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCourses([String? query]) async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;
      String url = '$baseUrl/student/courses';
      if (query != null && query.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(query)}';
      }

      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
        if (mounted) {
          setState(() {
            // There is one SEEK course; its chapters carry the content.
            _courses = list.take(1).toList();
            _isLoadingCourses = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _fetchCertificates() async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.get(
        Uri.parse('$baseUrl/student/certificates'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
        if (mounted) {
          setState(() {
            _certificates = list;
            _isLoadingCerts = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCerts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudentShellScaffold(
      currentTabIndex: 2,
      child: Column(
        children: [
          // Segmented Tabs: My Courses | My Certificates (Screenshots 7 & 8)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentButton(
                    title: 'My Courses',
                    isSelected: _selectedTab == 0,
                    onTap: () {
                      setState(() {
                        _selectedTab = 0;
                        _searchController.clear();
                      });
                      _fetchCourses();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSegmentButton(
                    title: 'My Certificates',
                    isSelected: _selectedTab == 1,
                    onTap: () {
                      setState(() {
                        _selectedTab = 1;
                        _searchController.clear();
                      });
                      _fetchCertificates();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E4EC)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  if (_selectedTab == 0) {
                    _fetchCourses(val);
                  } else {
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  hintText: _selectedTab == 0
                      ? 'Search courses, SDGs, or skills...'
                      : 'Search courses, badges...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: _selectedTab == 0 ? _buildMyCoursesTab() : _buildMyCertificatesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0467B6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ── Tab 1: My Courses (Screenshot 7) ──────────────────────────────────
  Widget _buildMyCoursesTab() {
    if (_isLoadingCourses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_courses.isEmpty) {
      return Center(
        child: Text(
          'No courses found.',
          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final c = _courses[index];
        final id = c['id'] ?? (index + 1);
        final title = c['title'] ?? 'SEEK Course';
        final duration = c['duration'] ?? '';
        final category = c['category'] ?? 'SEEK';
        final String? imgUrl = c['image_url'] as String?;
        final status = c['enrollment_status'] ?? 'not_enrolled';

        final isEnrolled = status == 'enrolled' || status == 'completed';
        final buttonText = isEnrolled ? 'Start Course' : 'Enroll';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with Category Tag Overlay (Screenshot 7)
              Stack(
                children: [
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: imgUrl == null || imgUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFCBD5E1),
                            child: const Icon(Icons.school, size: 40, color: Colors.white),
                          )
                        : Image.asset(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFCBD5E1),
                              child: const Icon(Icons.school, size: 40, color: Colors.white),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Course Meta & Button
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          duration,
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action Button ("Start Course" or "Enroll")
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () {
                          context.push('/student/course-detail/$id');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0467B6), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          buttonText,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0467B6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 2: My Certificates (Screenshot 8) ─────────────────────────────
  Widget _buildMyCertificatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 Achievement Badges in a Row (Screenshot 8)
          Row(
            children: [
              Expanded(
                child: _buildAchievementBadge(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFEA580C),
                  title: '21 Days',
                  gradient: const [Color(0xFF5B6BBF), Color(0xFF38437D)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAchievementBadge(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: const Color(0xFFFACC15),
                  title: 'Learning spree',
                  gradient: const [Color(0xFF5B6BBF), Color(0xFF38437D)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAchievementBadge(
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Active user',
                  gradient: const [Color(0xFF5B6BBF), Color(0xFF38437D)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Title: Earned Certifications + View All
          Row(
            children: [
              const MedalLogo(iconSize: 18),
              const SizedBox(width: 6),
              Text(
                'Earned Certifications',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0467B6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Certificate Cards (Screenshot 8)
          if (_isLoadingCerts)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_certificates.isNotEmpty)
            ..._certificates.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildCertificateCard(
                    completedText: (c['completed_date_str'] ?? c['completed_text'] ?? 'COMPLETED').toString().toUpperCase(),
                    title: c['title'] ?? 'SEEK Course Certificate',
                    certNo: (c['certificate_no'] ?? c['certificate_number'] ?? 'MED-CERT').toString(),
                    badgeIcon: Icons.verified_rounded,
                    badgeColor: const Color(0xFF0467B6),
                    badgeBgColor: const Color(0xFFE6F2FA),
                  ),
                ))
          else
            Container(
              key: const Key('no_certificates_state'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E4EC)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 40, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 10),
                  Text(
                    'No certificates yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete a course to earn your certificate. It will appear here as soon as the course is finished.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.4,
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

  Widget _buildAchievementBadge({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Color> gradient,
  }) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard({
    required String completedText,
    required String title,
    required String certNo,
    required IconData badgeIcon,
    required Color badgeColor,
    required Color badgeBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Stack(
        children: [
          // Left Blue Accent Pill
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFF0467B6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completedText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Certificate No.',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        certNo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    // Badge Icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(badgeIcon, color: badgeColor, size: 22),
                    ),
                    const SizedBox(height: 18),
                    // Download Icon Button
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Color(0xFF0467B6), size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloading Certificate $certNo...'),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
