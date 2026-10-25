// lib/modules/institution/features/institution/screens/student/student_edit_profile_screen.dart
// Edit Profile screen matching Screenshot 11.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';
import '../../widgets/student_shell_scaffold.dart';

class StudentEditProfileScreen extends StatefulWidget {
  const StudentEditProfileScreen({super.key});

  @override
  State<StudentEditProfileScreen> createState() => _StudentEditProfileScreenState();
}

class _StudentEditProfileScreenState extends State<StudentEditProfileScreen> {
  final _nameController = TextEditingController(text: 'Kajol Misra');
  final _emailController = TextEditingController(text: 'kajolmisra@medal.gov');
  final _deptController = TextEditingController(text: 'Maths , Physics , Biology');
  final _phoneController = TextEditingController(text: '9123456789');

  String? _avatarUrl;
  bool _isSaving = false;

  String? _selectedAchievement;
  String? _selectedCertificate;

  final List<String> _achievementOptions = [
    '21 Days Learning Streak',
    'Active Community Reporter',
    'Fast Track Completion',
  ];

  final List<String> _certificateOptions = [
    'SEEK Foundation (MED-55219-X04)',
    'Community Empathy (MED-1102-G12)',
    'Ecological Resilience (MED-7714-E01)',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _deptController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
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
            _nameController.text = data['full_name'] ?? 'Kajol Misra';
            _emailController.text = data['email'] ?? 'kajolmisra@medal.gov';
            _phoneController.text = (data['phone'] ?? '9123456789').replaceAll('+91 ', '');
            _deptController.text = data['preferences'] ?? data['department'] ?? 'Maths , Physics , Biology';
            _avatarUrl = data['profile_image_url'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final res = await ApiService().updateProfilePhoto(
        fileBytes: bytes,
        filename: picked.name,
      );

      if (mounted) {
        setState(() {
          _avatarUrl = res['profile_image_url'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final baseUrl = ApiService().baseUrl;
      final token = ApiService().token;

      final resp = await http.patch(
        Uri.parse('$baseUrl/student/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'preferences': _deptController.text.trim(),
        }),
      );

      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile changes saved successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
        context.pop();
      } else {
        final data = jsonDecode(resp.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Failed to save changes'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudentShellScaffold(
      showBackButton: true,
      onBack: () => context.pop(),
      currentTabIndex: 3,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit profile',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Card Container (Screenshot 11)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                  // Avatar
                  Container(
                    width: 86,
                    height: 86,
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
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 48, color: Color(0xFF64748B)),
                          )
                        : const Icon(Icons.person, size: 48, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),

                  // "Edit profile picture" link
                  GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: Text(
                      'Edit profile picture',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0467B6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Field 1: Name
                  _buildFloatingLabelField(
                    label: 'Name',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 14),

                  // Field 2: Email (read only for official student email)
                  _buildFloatingLabelField(
                    label: 'Email',
                    controller: _emailController,
                    readOnly: true,
                  ),
                  const SizedBox(height: 14),

                  // Field 3: Preferred departments
                  _buildFloatingLabelField(
                    label: 'Preferred departments',
                    controller: _deptController,
                  ),
                  const SizedBox(height: 14),

                  // Field 4: Phone
                  _buildFloatingLabelField(
                    label: 'Phone',
                    controller: _phoneController,
                  ),
                  const SizedBox(height: 20),

                  // Links section: "Links" + "Add links"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Links',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link manager opened')),
                          );
                        },
                        child: Text(
                          'Add links',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dropdown 1: Add achievements
                  _buildDropdownField(
                    hint: 'Add achievements',
                    value: _selectedAchievement,
                    items: _achievementOptions,
                    onChanged: (val) => setState(() => _selectedAchievement = val),
                  ),
                  const SizedBox(height: 12),

                  // Dropdown 2: Add certificates
                  _buildDropdownField(
                    hint: 'Add cerificates', // Note spelling matches screenshot 11
                    value: _selectedCertificate,
                    items: _certificateOptions,
                    onChanged: (val) => setState(() => _selectedCertificate = val),
                  ),
                  const SizedBox(height: 28),

                  // Save changes button (Screenshot 11)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0467B6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Save changes',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Footer info (Screenshot 11)
            Center(
              child: Column(
                children: [
                  Text(
                    'MEdAL v2.4.0 Institutional Core',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Last login: Today at 08:42 AM',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingLabelField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E4EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            readOnly: readOnly,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E4EC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
