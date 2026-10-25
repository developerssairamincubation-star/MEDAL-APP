// lib/modules/institution/features/institution/screens/student/student_pending_courses_screen.dart
// Pending Courses Screen matching Screenshot 5.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import '../../widgets/student_shell_scaffold.dart';
import '../../widgets/unesco_logo.dart';

class StudentPendingCoursesScreen extends StatefulWidget {
  const StudentPendingCoursesScreen({super.key});

  @override
  State<StudentPendingCoursesScreen> createState() => _StudentPendingCoursesScreenState();
}

class _StudentPendingCoursesScreenState extends State<StudentPendingCoursesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingCourses = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingCourses();
  }

  Future<void> _fetchPendingCourses() async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.get(
        Uri.parse('$baseUrl/student/pending-courses'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
        if (mounted) {
          setState(() {
            _pendingCourses = list;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Courses',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 18),

                  ..._pendingCourses.map((c) {
                    final id = c['id'] ?? 4;
                    final title = c['title'] ?? 'SEEK COURSE';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                            padding: const EdgeInsets.only(left: 10),
                            child: Row(
                              children: [
                                const UnescoLogoWidget(width: 86, height: 46),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 36,
                                  width: 82,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      context.push('/student/course-detail/$id');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0467B6),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Enroll',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
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
                  }),
                ],
              ),
            ),
    );
  }
}
