// lib/modules/institution/features/institution/screens/student/student_course_progress_screen.dart
// Course Progress Screen (Bottom Nav Tab 2).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import '../../widgets/student_shell_scaffold.dart';

class StudentCourseProgressScreen extends StatefulWidget {
  const StudentCourseProgressScreen({super.key});

  @override
  State<StudentCourseProgressScreen> createState() => _StudentCourseProgressScreenState();
}

class _StudentCourseProgressScreenState extends State<StudentCourseProgressScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _progressList = [];

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.get(
        Uri.parse('$baseUrl/student/progress'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
        if (mounted) {
          setState(() {
            _progressList = list;
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
      currentTabIndex: 1,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Course Progress',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track your ongoing learning modules, credits, and certificate eligibility.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_progressList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No courses currently in progress.',
                          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else
                    ..._progressList.map((item) {
                      final title = item['title'] ?? 'SEEK Course';
                      final category = item['category'] ?? 'SEEK';
                      final double progressPct = (item['progress_pct'] as num?)?.toDouble() ?? 0.0;
                      final int completedM = item['completed_modules'] ?? 0;
                      final int totalM = item['total_modules'] ?? 5;
                      final status = item['status'] ?? 'In Progress';
                      final isCompleted = progressPct >= 1.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F2FA),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    category,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0467B6),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isCompleted ? const Color(0xFFE8F8F0) : const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isCompleted ? const Color(0xFF2ECC71) : const Color(0xFF9B59B6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressPct,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFECEFF5),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted ? const Color(0xFF2ECC71) : const Color(0xFF0467B6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$completedM of $totalM modules completed',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${(progressPct * 100).toInt()}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
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
