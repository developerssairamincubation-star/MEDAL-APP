// lib/modules/authority/screens/profile/authority_edit_profile_screen.dart
// Edit Profile screen for Authority Officers.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
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
  late TextEditingController _phoneController;
  late TextEditingController _jurisdictionController;
  late String _selectedDepartment;
  late String _selectedDesignation;

  final List<String> _departments = [
    'Water Supply & Public Works',
    'Solid Waste Management',
    'Roads & Infrastructure',
    'Electrical & Street Lighting',
    'Public Health & Sanitation',
    'Town Planning & Revenue',
  ];

  final List<String> _designations = [
    'Assistant Executive Engineer',
    'Ward Engineer',
    'Sanitary Inspector',
    'Zonal Officer',
    'Junior Engineer (Electrical)',
    'Health Inspector',
  ];

  @override
  void initState() {
    super.initState();
    final officer = MockAuthorityRepository.currentOfficer;
    _nameController = TextEditingController(text: officer.legalName);
    _phoneController = TextEditingController(text: officer.phone);
    _jurisdictionController = TextEditingController(text: officer.jurisdiction);

    _selectedDepartment = _departments.contains(officer.department)
        ? officer.department
        : _departments.first;
    _selectedDesignation = _designations.contains(officer.designation)
        ? officer.designation
        : _designations.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _jurisdictionController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final officer = MockAuthorityRepository.currentOfficer;
    officer.legalName = _nameController.text.trim();
    officer.phone = _phoneController.text.trim();
    officer.jurisdiction = _jurisdictionController.text.trim();
    officer.department = _selectedDepartment;
    officer.designation = _selectedDesignation;

    widget.onProfileUpdated();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Authority profile updated successfully.'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedalTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: MedalTheme.darkNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Official Profile",
          style: TextStyle(
            color: MedalTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: MedalTheme.lavenderBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MedalTheme.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MedalTheme.lavenderBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: MedalTheme.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Changes to official jurisdiction or designation will be logged in the municipal audit trail.",
                        style: TextStyle(fontSize: 12.5, color: MedalTheme.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Legal Name
              const Text("Legal Full Name",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(Icons.person_outline),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Name is required" : null,
              ),
              const SizedBox(height: 16),

              // Designation
              const Text("Designation",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedDesignation,
                decoration: _inputDecoration(Icons.work_outline),
                items: _designations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedDesignation = v);
                },
              ),
              const SizedBox(height: 16),

              // Department
              const Text("Department",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedDepartment,
                decoration: _inputDecoration(Icons.account_balance_outlined),
                items: _departments
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedDepartment = v);
                },
              ),
              const SizedBox(height: 16),

              // Jurisdiction
              const Text("Assigned Jurisdiction / Ward",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _jurisdictionController,
                decoration: _inputDecoration(Icons.location_city_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Jurisdiction is required" : null,
              ),
              const SizedBox(height: 16),

              // Phone
              const Text("Contact Phone",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                decoration: _inputDecoration(Icons.phone_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Phone is required" : null,
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MedalTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: MedalTheme.slateBlue, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MedalTheme.primary, width: 1.5),
      ),
    );
  }
}
