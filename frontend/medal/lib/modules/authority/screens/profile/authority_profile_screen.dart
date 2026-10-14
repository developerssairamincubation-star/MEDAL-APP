// lib/modules/authority/screens/profile/authority_profile_screen.dart
// Authority Profile screen with Authority Details, Password Management,
// and Logout Confirmation dialog.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../citizen/authentication/login.dart';
import '../../models/authority_models.dart';
import 'authority_edit_profile_screen.dart';

class AuthorityProfileScreen extends StatefulWidget {
  const AuthorityProfileScreen({super.key});

  @override
  State<AuthorityProfileScreen> createState() => _AuthorityProfileScreenState();
}

class _AuthorityProfileScreenState extends State<AuthorityProfileScreen> {
  final officer = MockAuthorityRepository.currentOfficer;

  void _showPasswordManagementDialog() {
    final formKey = GlobalKey<FormState>();
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: MedalTheme.primary),
              SizedBox(width: 8),
              Text("Password Management",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Update your official portal password. Must be at least 8 characters.",
                    style: TextStyle(fontSize: 12.5, color: MedalTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Current Password
                  const Text("Current Password",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: currentPassController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureCurrent ? Icons.visibility_off : Icons.visibility,
                            size: 18),
                        onPressed: () =>
                            setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                    ),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? "Current password is required" : null,
                  ),
                  const SizedBox(height: 12),

                  // New Password
                  const Text("New Password",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: newPassController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureNew ? Icons.visibility_off : Icons.visibility,
                            size: 18),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "New password is required";
                      if (val.length < 8) return "Password must be at least 8 characters";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Confirm New Password
                  const Text("Confirm New Password",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: confirmPassController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            size: 18),
                        onPressed: () =>
                            setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                    ),
                    validator: (val) {
                      if (val != newPassController.text) {
                        return "Passwords do not match";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Official portal password updated successfully."),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MedalTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text("Sign Out of Authority",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Are you sure you want to end your official session? You will need to sign in again with your official credentials.",
          style: TextStyle(fontSize: 13.5, color: MedalTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  void _showGuidelinesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Municipal SLA & SOP Guidelines",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• Critical / Red SLA:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
              Text("Requires on-site inspection within 4 hours; resolution within 24 hours.",
                  style: TextStyle(fontSize: 12.5)),
              SizedBox(height: 10),
              Text("• High Priority:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
              Text("Triage within 12 hours; resolution within 48 hours.",
                  style: TextStyle(fontSize: 12.5)),
              SizedBox(height: 10),
              Text("• Rejection Protocol:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("Must record specific factual and jurisdictional reasons.",
                  style: TextStyle(fontSize: 12.5)),
              SizedBox(height: 10),
              Text("• Redirection Protocol:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("Identify the exact nodal authority and attach reason.",
                  style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: MedalTheme.primary),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedalTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Officer Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: MedalTheme.primaryTint,
                    child: Icon(Icons.person, color: MedalTheme.primary, size: 44),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    officer.legalName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MedalTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${officer.designation} • ${officer.department}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MedalTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          "VERIFIED DEPARTMENT OFFICIAL",
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Authority Details Section
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MedalTheme.lavenderBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 8,
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
                      const Row(
                        children: [
                          Icon(Icons.account_balance_outlined,
                              size: 18, color: MedalTheme.primary),
                          SizedBox(width: 8),
                          Text(
                            "Authority Details",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: MedalTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AuthorityEditProfileScreen(
                                onProfileUpdated: () => setState(() {}),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text("Edit", style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: MedalTheme.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: MedalTheme.lavenderBorder),
                  _buildDetailRow(
                      Icons.badge_outlined, "Employee Badge ID", officer.employeeId),
                  _buildDetailRow(Icons.fingerprint, "Identity Number (Masked)",
                      officer.maskedIdentityNumber),
                  _buildDetailRow(Icons.location_city_outlined, "Assigned Jurisdiction",
                      officer.jurisdiction),
                  _buildDetailRow(Icons.email_outlined, "Official Email",
                      officer.officialEmail),
                  _buildDetailRow(
                      Icons.phone_outlined, "Official Contact Phone", officer.phone),
                  _buildDetailRow(
                      Icons.verified_user_outlined, "Document Status", "Verified by Municipal Admin",
                      valueColor: const Color(0xFF16A34A)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Settings & Actions
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MedalTheme.lavenderBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildActionTile(
                    icon: Icons.lock_outline,
                    title: "Password Management",
                    subtitle: "Change portal login credentials",
                    onTap: _showPasswordManagementDialog,
                  ),
                  const Divider(height: 14, color: MedalTheme.lavenderBorder),
                  _buildActionTile(
                    icon: Icons.rule_folder_outlined,
                    title: "Department SLA Guidelines",
                    subtitle: "Civic escalation standards and protocols",
                    onTap: _showGuidelinesDialog,
                  ),
                  const Divider(height: 14, color: MedalTheme.lavenderBorder),
                  _buildActionTile(
                    icon: Icons.logout_rounded,
                    title: "Sign Out",
                    subtitle: "Exit Authority Portal",
                    iconColor: const Color(0xFFDC2626),
                    onTap: _showLogoutConfirmationDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: MedalTheme.slateBlue),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: MedalTheme.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? MedalTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? MedalTheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? MedalTheme.primary, size: 20),
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
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: MedalTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: MedalTheme.slateBlue),
          ],
        ),
      ),
    );
  }
}
