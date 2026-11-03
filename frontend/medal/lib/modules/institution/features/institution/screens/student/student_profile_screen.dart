// lib/modules/institution/features/institution/screens/student/student_profile_screen.dart
// Student Profile screen matching Screenshot 9.

import 'package:medal/widgets/medal_dialog.dart';
import 'package:medal/widgets/profile_ui.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';
import '../../widgets/student_shell_scaffold.dart';
import '../../widgets/logout_dialog.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String _name = '';
  String _email = '';
  String _phone = '';
  String _preferences = '';
  String? _avatarUrl;
  int _certificatesCount = 0;
  double _studyHours = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final certResp = await http.get(Uri.parse('$baseUrl/student/certificates'), headers: headers);
      if (certResp.statusCode == 200 && mounted) {
        setState(() => _certificatesCount = (jsonDecode(certResp.body) as List).length);
      }
      final dashResp = await http.get(Uri.parse('$baseUrl/student/dashboard'), headers: headers);
      if (dashResp.statusCode == 200 && mounted) {
        setState(() => _studyHours = ((jsonDecode(dashResp.body)['study_hours'] ?? 0) as num).toDouble());
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _name = data['full_name'] ?? '';
            _email = data['email'] ?? '';
            _phone = data['phone'] ?? '';
            _preferences = data['preferences'] ?? '';
            _avatarUrl = data['profile_image_url'];
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

  void _showManagePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => MedalAlertDialog(
        title: Text(
          'Manage Password',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_reset, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock_reset, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final baseUrl = ApiService().baseUrl;
                final token = ApiService().token;

                final resp = await http.post(
                  Uri.parse('$baseUrl/student/manage-password'),
                  headers: {
                    'Content-Type': 'application/json',
                    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'current_password': currentPassController.text,
                    'new_password': newPassController.text,
                  }),
                );

                nav.pop();

                if (resp.statusCode == 200) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully!'),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                } else {
                  final data = jsonDecode(resp.body);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(data['detail'] ?? 'Failed to update password'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0467B6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showClassPreferencesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => MedalAlertDialog(
        title: Text(
          'Class Preferences',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferred Subjects & Streams:',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_preferences.trim().isEmpty)
              Text(
                'No preferences added yet. Add them from Edit Profile.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pref in _preferences.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty))
                    _buildChip(pref),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              'Academic Delivery Mode: Hybrid / SEEK Modules',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0467B6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0467B6).withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0467B6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentShellScaffold(
      currentTabIndex: 3,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Profile hero (shared layout, same as every login)
            ProfileHeroCard(
              roleLabel: 'Student',
              name: _name,
              email: _email,
              phone: _phone,
              photoUrl: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? ApiService().resolveImageUrl(_avatarUrl)
                  : null,
              badgeBackground: const Color(0xFFE8F4FD),
              badgeForeground: const Color(0xFF0467B6),
              onEdit: () async {
                await context.push(AppRoutes.studentEditProfile);
                _fetchProfile();
              },
            ),
            const SizedBox(height: 16),

            // Two Stat Cards: My Certificates (left) & Study Hours (right) (Screenshot 9)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E4EC)),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MY CERTIFICATES',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _certificatesCount.toString().padLeft(2, '0'),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0467B6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => context.go('${AppRoutes.studentAcademy}?tab=certificates'),
                                child: Text(
                                  'View certificates',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0467B6),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E4EC)),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STUDY HOURS',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _studyHours == _studyHours.roundToDouble() ? '${_studyHours.round()}' : _studyHours.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0467B6),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Section: Account Management (shared tiles)
            const ProfileSectionTitle('Account Management'),
            const SizedBox(height: 10),
            ProfileAccountTile(
              icon: Icons.sync_lock_rounded,
              title: 'Manage Password',
              subtitle: 'Update your security credentials',
              onTap: _showManagePasswordDialog,
            ),
            const SizedBox(height: 8),
            ProfileAccountTile(
              icon: Icons.account_balance_outlined,
              iconColor: const Color(0xFF6D28D9),
              iconBgColor: const Color(0xFFEDE9FE),
              title: 'Class preferences',
              subtitle: 'Profile and academic records',
              onTap: _showClassPreferencesDialog,
            ),
            const SizedBox(height: 8),
            ProfileLogoutTile(
              onTap: () => confirmAndLogout(context),
            ),
            const SizedBox(height: 20),

            // Institutional Admin Info Banner (Screenshot 9)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your profile is managed by the Institutional Admin. For changes to your department or name, please contact the Registrar Office.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
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
}
