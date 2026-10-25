// lib/modules/institution/features/institution/screens/student/student_profile_screen.dart
// Student Profile screen matching Screenshot 9.

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
  String _name = 'Kajol Misra';
  String _email = 'kajolmisra@medal.gov';
  String _phone = '+91 93870 98213';
  String? _avatarUrl;
  final int _certificatesCount = 2;
  final int _studyHours = 7;
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

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _name = data['full_name'] ?? 'Kajol Misra';
            _email = data['email'] ?? 'kajolmisra@medal.gov';
            _phone = data['phone'] ?? '+91 93870 98213';
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip('Mathematics'),
                _buildChip('Physics'),
                _buildChip('Biology'),
                _buildChip('SEEK Leadership'),
                _buildChip('Ecology'),
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
            // Profile Card (Screenshot 9)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                children: [
                  // Avatar with Edit Pencil Badge (Screenshot 9)
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE2E8F0),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? Image.network(
                                ApiService().resolveImageUrl(_avatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF64748B),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            await context.push(AppRoutes.studentEditProfile);
                            _fetchProfile();
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0467B6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name
                  Text(
                    _name,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Email
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email_outlined, size: 16, color: Color(0xFF0467B6)),
                      const SizedBox(width: 8),
                      Text(
                        _email,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Phone
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF0467B6)),
                      const SizedBox(width: 8),
                      Text(
                        _phone,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                                onTap: () => context.go(AppRoutes.studentAcademy),
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
                                '$_studyHours',
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

            // Section: Account Management
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Account Management',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Item 1: Manage Password
            _buildActionTile(
              icon: Icons.sync_lock_rounded,
              iconBgColor: const Color(0xFFE6F2FA),
              iconColor: const Color(0xFF0467B6),
              title: 'Manage Password',
              subtitle: 'Update your security credentials',
              onTap: _showManagePasswordDialog,
            ),
            const SizedBox(height: 10),

            // Item 2: Class preferences
            _buildActionTile(
              icon: Icons.account_balance_outlined,
              iconBgColor: const Color(0xFFE6F2FA),
              iconColor: const Color(0xFF0467B6),
              title: 'Class preferences',
              subtitle: 'Profile and academic records',
              onTap: _showClassPreferencesDialog,
            ),
            const SizedBox(height: 14),

            // Log Out Button (Red text, as in Screenshot 9)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const LogoutDialog(),
                  );
                },
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
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

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E4EC)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
          size: 20,
        ),
      ),
    );
  }
}
