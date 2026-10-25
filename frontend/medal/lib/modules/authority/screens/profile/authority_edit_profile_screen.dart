// lib/modules/authority/screens/profile/authority_edit_profile_screen.dart
// Authority Edit Profile screen visually matching reference Screenshot 4.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/authority_models.dart';

class AuthorityEditProfileScreen extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const AuthorityEditProfileScreen({
    super.key,
    required this.onProfileUpdated,
  });

  @override
  State<AuthorityEditProfileScreen> createState() =>
      _AuthorityEditProfileScreenState();
}

class _AuthorityEditProfileScreenState extends State<AuthorityEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _positionsController;
  late TextEditingController _phoneController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _jurisdictionController;
  late TextEditingController _securePhoneController;

  bool _isAchievementsExpanded = false;
  bool _isWorksExpanded = false;

  @override
  void initState() {
    super.initState();
    final officer = MockAuthorityRepository.currentOfficer;
    _nameController = TextEditingController(text: officer.legalName);
    _emailController = TextEditingController(text: officer.officialEmail);
    _positionsController = TextEditingController(text: officer.position);
    _phoneController = TextEditingController(text: officer.phone);
    _designationController = TextEditingController(text: officer.designation);
    _departmentController = TextEditingController(text: officer.department);
    _jurisdictionController = TextEditingController(text: officer.jurisdiction);
    _securePhoneController = TextEditingController(text: officer.secureContactPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _positionsController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _jurisdictionController.dispose();
    _securePhoneController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final officer = MockAuthorityRepository.currentOfficer;
    officer.legalName = _nameController.text.trim();
    officer.officialEmail = _emailController.text.trim();
    officer.position = _positionsController.text.trim();
    officer.phone = _phoneController.text.trim();
    officer.designation = _designationController.text.trim();
    officer.department = _departmentController.text.trim();
    officer.jurisdiction = _jurisdictionController.text.trim();
    officer.secureContactPhone = _securePhoneController.text.trim();

    widget.onProfileUpdated();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile changes saved successfully.'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  void _editProfilePicture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select a new profile image from gallery or camera.'),
        backgroundColor: Color(0xFF0467B6),
      ),
    );
  }

  void _showAddLinkDialog(String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Add $type",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter $type title...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  if (type == 'Achievement') {
                    MockAuthorityRepository.currentOfficer.achievements = [
                      ...MockAuthorityRepository.currentOfficer.achievements,
                      controller.text.trim(),
                    ];
                  } else {
                    MockAuthorityRepository.currentOfficer.works = [
                      ...MockAuthorityRepository.currentOfficer.works,
                      controller.text.trim(),
                    ];
                  }
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0467B6)),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar with MEDAL branding
            _buildTopHeader(),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Title: Edit profile
                      Text(
                        "Edit profile",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111C2D),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Avatar & Edit profile picture action
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 82,
                              height: 82,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 54,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _editProfilePicture,
                              child: Text(
                                "Edit profile picture",
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0467B6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 1. Name Field
                      _buildInputField(
                        label: "Name",
                        controller: _nameController,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? "Name is required" : null,
                      ),
                      const SizedBox(height: 10),

                      // 2. Email Field
                      _buildInputField(
                        label: "Email",
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? "Email is required" : null,
                      ),
                      const SizedBox(height: 10),

                      // 3. Positions Field
                      _buildInputField(
                        label: "Positions",
                        controller: _positionsController,
                      ),
                      const SizedBox(height: 10),

                      // 4. Phone Field
                      _buildInputField(
                        label: "Phone",
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 10),

                      // 5. Designation Field
                      _buildInputField(
                        label: "Designation",
                        controller: _designationController,
                      ),
                      const SizedBox(height: 10),

                      // 6. Department Field
                      _buildInputField(
                        label: "Department",
                        controller: _departmentController,
                      ),
                      const SizedBox(height: 10),

                      // 7. Jurisdiction Boundary Field (Multi-line)
                      _buildInputField(
                        label: "Jurisdiction Boundary",
                        controller: _jurisdictionController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),

                      // 8. Secure Contact Number Field
                      _buildInputField(
                        label: "Secure Contact Number",
                        controller: _securePhoneController,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 16),

                      // Links Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Links",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111C2D),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showAddLinkDialog('Achievement'),
                            child: Text(
                              "Add links",
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Dropdown Box 1: Add achievements
                      _buildDropdownTile(
                        title: "Add achievements",
                        isExpanded: _isAchievementsExpanded,
                        onTap: () {
                          setState(() {
                            _isAchievementsExpanded = !_isAchievementsExpanded;
                          });
                        },
                        items: MockAuthorityRepository.currentOfficer.achievements,
                        onAddItem: () => _showAddLinkDialog('Achievement'),
                      ),

                      const SizedBox(height: 8),

                      // Dropdown Box 2: Add works
                      _buildDropdownTile(
                        title: "Add works",
                        isExpanded: _isWorksExpanded,
                        onTap: () {
                          setState(() {
                            _isWorksExpanded = !_isWorksExpanded;
                          });
                        },
                        items: MockAuthorityRepository.currentOfficer.works,
                        onAddItem: () => _showAddLinkDialog('Work'),
                      ),

                      const SizedBox(height: 20),

                      // Save Changes Button
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0467B6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            "Save changes",
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
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  /// Bottom Navigation Bar matching Screenshot 4
  Widget _buildBottomNavigation() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildNavItem(
              index: 0,
              icon: Icons.grid_view_rounded,
              label: "Dashboard",
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 1,
              icon: Icons.article_outlined,
              label: "My Complaint",
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 2,
              icon: Icons.groups_outlined,
              label: "Academy",
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 3,
              icon: Icons.person_rounded,
              label: "Profile",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = index == 3;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF0467B6) : const Color(0xFF94A3B8),
            size: 19,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF0467B6) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  /// Top Header Bar matching Reference
  Widget _buildTopHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.military_tech_rounded, color: Color(0xFF0467B6), size: 22),
          const SizedBox(width: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "M",
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111C2D),
                  ),
                ),
                TextSpan(
                  text: "E",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111C2D),
                  ),
                ),
                TextSpan(
                  text: "dAL",
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111C2D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stacked Label Input Field matching Screenshot 4
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator: validator,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111C2D),
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.only(top: 2, bottom: 2),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown Tile for achievements / works matching Screenshot 4
  Widget _buildDropdownTile({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<String> items,
    required VoidCallback onAddItem,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.0),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111C2D),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 6),
                  if (items.isEmpty)
                    Text(
                      "No entries yet.",
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF0467B6)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onAddItem,
                      icon: const Icon(Icons.add, size: 14),
                      label: Text("Add item", style: GoogleFonts.inter(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0467B6),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
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
}
