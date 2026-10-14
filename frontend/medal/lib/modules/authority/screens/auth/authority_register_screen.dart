// lib/modules/authority/screens/auth/authority_register_screen.dart
// Authority Registration screen with document verification and admin review notice.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../citizen/authentication/login.dart';

class AuthorityRegisterScreen extends StatefulWidget {
  const AuthorityRegisterScreen({super.key});

  @override
  State<AuthorityRegisterScreen> createState() => _AuthorityRegisterScreenState();
}

class _AuthorityRegisterScreenState extends State<AuthorityRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _legalNameController = TextEditingController();
  final TextEditingController _identityNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _jurisdictionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Dropdown values
  String _selectedDesignation = 'Ward Engineer';
  String _selectedDepartment = 'Water Supply & Drainage';

  final List<String> _designations = [
    'Ward Engineer',
    'Assistant Executive Engineer',
    'Sanitary Inspector',
    'Zonal Officer',
    'Junior Engineer (Electrical)',
    'Health Inspector',
    'Town Planning Officer',
    'Superintending Officer',
  ];

  final List<String> _departments = [
    'Water Supply & Drainage',
    'Solid Waste Management',
    'Roads & Infrastructure',
    'Electrical & Street Lighting',
    'Public Health & Sanitation',
    'Town Planning & Revenue',
  ];

  // Document upload state
  String? _identityProofFileName;
  String? _identityProofFileSize;
  bool _isIdentityProofUploaded = false;

  String? _employmentIdFileName;
  String? _employmentIdFileSize;
  bool _isEmploymentIdUploaded = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _legalNameController.dispose();
    _identityNumberController.dispose();
    _emailController.dispose();
    _jurisdictionController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _simulateUploadIdentityProof() {
    setState(() {
      _identityProofFileName = 'Govt_ID_Proof_Rajesh.pdf';
      _identityProofFileSize = '1.8 MB';
      _isIdentityProofUploaded = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Identity proof uploaded and prepared for verification.'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  void _simulateUploadEmploymentId() {
    setState(() {
      _employmentIdFileName = 'Dept_Badge_Ward62_Rajesh.png';
      _employmentIdFileSize = '2.4 MB';
      _isEmploymentIdUploaded = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Official employment ID uploaded and prepared for verification.'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  void _removeIdentityProof() {
    setState(() {
      _identityProofFileName = null;
      _identityProofFileSize = null;
      _isIdentityProofUploaded = false;
    });
  }

  void _removeEmploymentId() {
    setState(() {
      _employmentIdFileName = null;
      _employmentIdFileSize = null;
      _isEmploymentIdUploaded = false;
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isIdentityProofUploaded || !_isEmploymentIdUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both Identity Proof and Official Employment ID before submitting.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSubmissionSuccessDialog();
    });
  }

  void _showSubmissionSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  color: Color(0xFFD97706),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Application Submitted for Review",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: MedalTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "STATUS: PENDING ADMIN REVIEW",
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Reference ID: AUTH-REV-2026-9812",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: MedalTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Your application and documents have been sent to the Municipal E-Governance Admin. Note: Submission does not immediately grant login access. You will receive an official activation update once your credentials are confirmed.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: MedalTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MedalTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Return to Sign In",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
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
          "Authority Registration",
          style: TextStyle(
            color: MedalTheme.darkNavy,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: MedalTheme.lavenderBorder),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin Review Explanation Banner
                  _buildReviewNoticeBanner(),
                  const SizedBox(height: 20),

                  // Section 1: Official Profile Information
                  _buildSectionHeader("Official Profile Details", Icons.badge_outlined),
                  const SizedBox(height: 14),
                  _buildCardWrapper(
                    children: [
                      // Legal Name
                      _buildTextField(
                        controller: _legalNameController,
                        label: "Legal Full Name",
                        hint: "Er. Rajesh Varma",
                        icon: Icons.person_outline,
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? "Legal name is required" : null,
                      ),
                      const SizedBox(height: 16),

                      // Masked Identity Number
                      _buildTextField(
                        controller: _identityNumberController,
                        label: "Identity Proof Number (Masked)",
                        hint: "XXXX-XXXX-8921",
                        icon: Icons.fingerprint,
                        helperText: "Format: 12-digit Aadhaar / Gov ID. Stored securely and masked.",
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Identity number is required";
                          }
                          if (val.trim().length < 8) {
                            return "Please enter a valid identity number";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Designation Dropdown
                      const Text(
                        "Designation",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MedalTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDesignation,
                        decoration: _inputDecoration(prefixIcon: Icons.work_outline),
                        items: _designations
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDesignation = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Department Dropdown
                      const Text(
                        "Department",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MedalTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDepartment,
                        decoration: _inputDecoration(prefixIcon: Icons.account_balance_outlined),
                        items: _departments
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDepartment = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Official Email
                      _buildTextField(
                        controller: _emailController,
                        label: "Official Email Address",
                        hint: "rajesh.varma@corporation.gov.in",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Official email is required";
                          if (!val.contains('@') || !val.contains('.')) {
                            return "Enter a valid email address";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Jurisdiction
                      _buildTextField(
                        controller: _jurisdictionController,
                        label: "Jurisdiction / Assigned Ward",
                        hint: "Zone 5 - Ward 62, Greater Municipal Corp",
                        icon: Icons.location_city_outlined,
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? "Jurisdiction is required" : null,
                      ),
                      const SizedBox(height: 16),

                      // Contact Phone
                      _buildTextField(
                        controller: _phoneController,
                        label: "Official Contact Phone",
                        hint: "+91 98401 23456",
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? "Contact phone is required" : null,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      const Text(
                        "Password",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MedalTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          prefixIcon: Icons.lock_outline,
                          hintText: "••••••••",
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: MedalTheme.slateBlue,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Password is required";
                          if (val.length < 6) return "Password must be at least 6 characters";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      const Text(
                        "Confirm Password",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MedalTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: _inputDecoration(
                          prefixIcon: Icons.lock_reset_outlined,
                          hintText: "••••••••",
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: MedalTheme.slateBlue,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (val) {
                          if (val != _passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Document Verification Section
                  _buildSectionHeader("Document Verification", Icons.document_scanner_outlined),
                  const SizedBox(height: 6),
                  const Text(
                    "Upload authentic identity credentials for official departmental verification.",
                    style: TextStyle(fontSize: 13, color: MedalTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Identity Proof Upload
                  _buildDocumentUploadTile(
                    title: "Identity Proof (Aadhaar / National ID)",
                    subtitle: "PDF, JPG or PNG up to 5MB",
                    isUploaded: _isIdentityProofUploaded,
                    fileName: _identityProofFileName,
                    fileSize: _identityProofFileSize,
                    onUpload: _simulateUploadIdentityProof,
                    onRemove: _removeIdentityProof,
                  ),
                  const SizedBox(height: 14),

                  // Official Employment ID / Department Badge
                  _buildDocumentUploadTile(
                    title: "Official Employment ID / Department Badge",
                    subtitle: "Government ID Card, Appointment Order or Department Badge",
                    isUploaded: _isEmploymentIdUploaded,
                    fileName: _employmentIdFileName,
                    fileSize: _employmentIdFileSize,
                    onUpload: _simulateUploadEmploymentId,
                    onRemove: _removeEmploymentId,
                  ),
                  const SizedBox(height: 28),

                  // Submit for Admin Review Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MedalTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Submit for Admin Review",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Submission Pending Administrative Review",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Submitting your official details does not immediately grant login access. Your identity documents and departmental badge will be verified by the Municipal Admin Desk before your account is activated.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFB45309),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MedalTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: MedalTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCardWrapper({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MedalTheme.lavenderBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MedalTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: _inputDecoration(
            prefixIcon: icon,
            hintText: hint,
            helperText: helperText,
          ),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      prefixIcon: Icon(prefixIcon, color: MedalTheme.slateBlue, size: 20),
      suffixIcon: suffixIcon,
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      hintStyle: const TextStyle(color: MedalTheme.gray, fontSize: 13),
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

  Widget _buildDocumentUploadTile({
    required String title,
    required String subtitle,
    required bool isUploaded,
    required String? fileName,
    required String? fileSize,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? const Color(0xFF86EFAC) : MedalTheme.lavenderBorder,
          width: isUploaded ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? const Color(0xFFDCFCE7)
                      : MedalTheme.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                  color: isUploaded ? const Color(0xFF16A34A) : MedalTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MedalTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: MedalTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isUploaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName ?? '',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF14532D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$fileSize • Status: Ready for Admin Verification',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                    tooltip: 'Remove document',
                    onPressed: onRemove,
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text("Select & Upload Document"),
              style: OutlinedButton.styleFrom(
                foregroundColor: MedalTheme.primary,
                side: const BorderSide(color: MedalTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
        ],
      ),
    );
  }
}
