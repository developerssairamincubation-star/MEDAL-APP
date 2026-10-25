// lib/modules/authority/screens/academy/authority_academy_screen.dart
// Authority Academy screen featuring My Courses and My Certificates tabs matching Figma reference screenshots.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/authority_models.dart';

class AuthorityAcademyScreen extends StatefulWidget {
  final int initialTab;
  const AuthorityAcademyScreen({super.key, this.initialTab = 0});

  @override
  State<AuthorityAcademyScreen> createState() => _AuthorityAcademyScreenState();
}

class _AuthorityAcademyScreenState extends State<AuthorityAcademyScreen> {
  late int _selectedTab; // 0 = My Courses, 1 = My Certificates
  String _selectedCourseTopic = 'All Topics';
  String _selectedCertFilter = 'All Topics';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _courseTopics = [
    'All Topics',
    'Mindfulness',
    'Leadership',
    'Empathy',
    'Digital Skills',
  ];

  final List<String> _certFilters = [
    'All Topics',
    'Goal oriented',
    'Top badges',
    'Recent',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCertificateDialog(AuthorityCertificate cert) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF16A34A),
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Certificate of Completion",
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111C2D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cert.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0467B6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6E4F0)),
                ),
                child: Column(
                  children: [
                    _buildCertRow("Recipient", MockAuthorityRepository.currentOfficer.legalName),
                    const SizedBox(height: 5),
                    _buildCertRow("Certificate No.", cert.certificateNo),
                    const SizedBox(height: 5),
                    _buildCertRow("Issued By", cert.issuedBy),
                    const SizedBox(height: 5),
                    _buildCertRow("Issue Date", cert.issueDate),
                    const SizedBox(height: 5),
                    _buildCertRow("Grade", cert.grade),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Certificate ${cert.certificateNo} downloaded successfully."),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    "Download PDF Certificate",
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0467B6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildCertRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111C2D),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFD),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tab Switcher (My Courses | My Certificates)
            _buildTabSwitcher(),

            const SizedBox(height: 12),

            // 2. Search Field
            _buildSearchBar(),

            const SizedBox(height: 10),

            // 3. Horizontal Category Filter Pills
            _buildFilterPills(),

            const SizedBox(height: 12),

            // 4. Tab Specific Content
            if (_selectedTab == 0) _buildMyCoursesContent() else _buildMyCertificatesContent(),
          ],
        ),
      ),
    );
  }

  /// Tab Switcher matching reference pill container
  Widget _buildTabSwitcher() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF0467B6) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "My Courses",
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 0 ? Colors.white : const Color(0xFF5A6E85),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF0467B6) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "My Certificates",
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 1 ? Colors.white : const Color(0xFF5A6E85),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rounded Search Bar
  Widget _buildSearchBar() {
    final hint = _selectedTab == 0
        ? "Search courses, SDGs, or skills..."
        : "Search courses, badges...";

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.0),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B9CB2)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF7B8C9E)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// Horizontal scrollable category filter pills
  Widget _buildFilterPills() {
    final pills = _selectedTab == 0 ? _courseTopics : _certFilters;
    final active = _selectedTab == 0 ? _selectedCourseTopic : _selectedCertFilter;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: pills.map((topic) {
          final isSelected = topic == active;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedTab == 0) {
                    _selectedCourseTopic = topic;
                  } else {
                    _selectedCertFilter = topic;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0467B6) : const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  topic,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334E68),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // TAB 1: MY COURSES CONTENT (Screenshot 1)
  // ==========================================
  Widget _buildMyCoursesContent() {
    final featured = MockAuthorityRepository.featuredCourse;
    final courses = MockAuthorityRepository.courses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. In-Progress Featured Course Card
        _buildFeaturedCourseCard(featured),

        const SizedBox(height: 12),

        // 2. Course Cards Feed
        ...courses.map((course) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildCourseCard(course),
            )),
      ],
    );
  }

  Widget _buildFeaturedCourseCard(AuthorityCourse course) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red In Progress Flame Tag
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFDC2626)),
              const SizedBox(width: 4),
              Text(
                "IN PROGRESS",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFDC2626),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Course Title
          Text(
            course.title,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111C2D),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // Progress Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Course Completion",
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
              Text(
                "${(course.progress * 100).toInt()}%",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0467B6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: course.progress,
              backgroundColor: const Color(0xFFE2EDF8),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0467B6)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          // Continue Learning Button
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Resuming ${course.title}..."),
                    backgroundColor: const Color(0xFF0467B6),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0467B6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                course.buttonActionText ?? "Continue Learning",
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(AuthorityCourse course) {
    final imageAsset = course.imageAsset ?? 'assets/images/sample_mountain.jpg';
    final isWhiteBadge = course.badgeText != 'SDG 15';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Thumbnail Image with Badge Overlay
          Stack(
            children: [
              Image.asset(
                imageAsset,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 130,
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: Icon(Icons.school_outlined, size: 36, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              if (course.badgeText != null)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isWhiteBadge ? Colors.white : Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      course.badgeText!,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isWhiteBadge ? const Color(0xFF111C2D) : Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Course Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111C2D),
                  ),
                ),
                const SizedBox(height: 6),

                // Meta Row: Duration and Rating
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      course.duration,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text(
                      course.rating?.toString() ?? "4.8",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Outlined Action Button
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Enrolling in ${course.title}..."),
                          backgroundColor: const Color(0xFF0467B6),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0467B6),
                      side: const BorderSide(color: Color(0xFF0467B6), width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      course.buttonActionText ?? "Start Course",
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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
  }

  // ===============================================
  // TAB 2: MY CERTIFICATES CONTENT (Screenshot 2)
  // ===============================================
  Widget _buildMyCertificatesContent() {
    final certs = MockAuthorityRepository.certificates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Stats / Streaks 3-Card Row
        _buildStatsCardsRow(),

        const SizedBox(height: 14),

        // 2. Section Header: Earned Certifications
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.military_tech_rounded, size: 20, color: Color(0xFF0467B6)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "Earned Certifications",
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111C2D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Showing all official earned certifications."),
                    backgroundColor: Color(0xFF0467B6),
                  ),
                );
              },
              child: Text(
                "View All",
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0467B6),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 3. Certificate Cards
        ...certs.map((cert) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildCertificateCard(cert),
            )),
      ],
    );
  }

  /// 3 purple gradient stat cards in a horizontal row
  Widget _buildStatsCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            topText: "31 Days",
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF6D00),
            bottomText: "Daily streaks",
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            topText: "Learning spree",
            icon: Icons.workspace_premium_rounded,
            iconColor: const Color(0xFFFFD54F),
            bottomText: "5 Courses\ncompleted",
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            topText: "",
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF22C55E),
            bottomText: "Active user",
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String topText,
    required IconData icon,
    required Color iconColor,
    required String bottomText,
  }) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6B7280),
            Color(0xFF4B5563),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            topText,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          Icon(icon, size: 28, color: iconColor),
          Text(
            bottomText,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(AuthorityCertificate cert) {
    final isCheckBadge = cert.badgeType == 'check';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Blue Left Accent Bar matching Screenshot 2
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3.5,
            child: Container(color: const Color(0xFF0467B6)),
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Completed Date & Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cert.completionDateText,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Lorem ipsum dolor",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111C2D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCheckBadge ? const Color(0xFFE0E7FF) : const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCheckBadge ? Icons.verified_rounded : Icons.star_rounded,
                        size: 18,
                        color: isCheckBadge ? const Color(0xFF0467B6) : const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Bottom Row: Certificate No. and Download Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Certificate No.",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cert.certificateNo,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111C2D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Download / View Credential Action
                    InkWell(
                      onTap: () => _showCertificateDialog(cert),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FD),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.download_rounded,
                              size: 16,
                              color: Color(0xFF0467B6),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  "View Credential",
                                  style: const TextStyle(
                                    fontSize: 1,
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
