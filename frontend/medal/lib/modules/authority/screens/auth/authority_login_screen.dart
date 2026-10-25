// lib/modules/authority/screens/auth/authority_login_screen.dart
// Dedicated login screen for Municipal & Public Department Authorities.

import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../admin/admin_authority_applications_list_screen.dart';
import '../dashboard/authority_main_screen.dart';
import 'authority_register_screen.dart';

class AuthorityLoginScreen extends StatefulWidget {
  const AuthorityLoginScreen({super.key});

  @override
  State<AuthorityLoginScreen> createState() => _AuthorityLoginScreenState();
}

class _AuthorityLoginScreenState extends State<AuthorityLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your official email/badge ID and password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService().login(email: email, password: password);
      final user = res['data'] as Map<String, dynamic>?;
      final role = (user?['role'] ?? ApiService().userRole).toString().trim().toLowerCase();

      // Enforce backend role: only official or admin may access Authority Dashboard
      if (role != 'official' && role != 'admin') {
        // Clear saved session immediately so unauthorized role is not retained
        await ApiService().logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: This portal is restricted to Municipal Authorities and Officials.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;

      final officerName = user?['full_name']?.toString() ?? 'Officer';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, $officerName! Authority session verified.'),
          backgroundColor: MedalTheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      if (role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminAuthorityApplicationsListScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthorityMainScreen()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.statusCode) {
        case 0:
          msg = e.message.isNotEmpty
              ? e.message
              : 'Cannot connect to MEDAL server. Please check your network connection.';
          break;
        case 401:
          msg = 'Invalid official email or password. Please try again.';
          break;
        case 403:
          msg = e.message.isNotEmpty
              ? e.message
              : 'Access denied: Your account does not have Authority access.';
          break;
        case 400:
          msg = e.message.isNotEmpty ? e.message : 'Invalid request. Please check your credentials.';
          break;
        case 500:
        case 502:
        case 503:
          msg = 'Server error (${e.statusCode}). Please try again later.';
          break;
        default:
          msg = e.message.isNotEmpty ? e.message : 'Login failed. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDemoLogin() {
    _emailController.text = 'rajesh.varma@corporation.gov.in';
    _passwordController.text = 'Officer@2026';
    _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedalTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  // Seal / Icon
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      color: MedalTheme.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: MedalTheme.primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Authority Portal",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: MedalTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Municipal Officer & Department Grievance Redressal Desk",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: MedalTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MedalTheme.lavenderBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Officer Sign In",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: MedalTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Official Email / Badge ID
                        const Text(
                          "Official Email or Badge ID",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MedalTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.badge_outlined,
                                color: MedalTheme.slateBlue, size: 20),
                            hintText: "officer@corporation.gov.in",
                            hintStyle: const TextStyle(color: MedalTheme.gray, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                              borderSide:
                                  const BorderSide(color: MedalTheme.primary, width: 1.5),
                            ),
                          ),
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
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: MedalTheme.slateBlue, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: MedalTheme.slateBlue,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            hintText: "••••••••",
                            hintStyle: const TextStyle(color: MedalTheme.gray, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                              borderSide:
                                  const BorderSide(color: MedalTheme.primary, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MedalTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Sign In as Authority",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Demo Quick Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleDemoLogin,
                            icon: const Icon(Icons.play_circle_outline, size: 18),
                            label: const Text(
                              "Quick Demo Officer Login (Review Mode)",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MedalTheme.primaryDark,
                              side: const BorderSide(color: MedalTheme.primaryLight),
                              backgroundColor: MedalTheme.primaryTint,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Divider(color: MedalTheme.lavenderBorder),
                        const SizedBox(height: 12),

                        // Apply for Access
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                "New Department Personnel?",
                                style: TextStyle(
                                  color: MedalTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AuthorityRegisterScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Apply for Official Verification & Access",
                                  style: TextStyle(
                                    color: MedalTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
