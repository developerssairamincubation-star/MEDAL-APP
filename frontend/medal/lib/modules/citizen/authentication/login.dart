import 'package:flutter/material.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/modules/citizen/authentication/register.dart';
import 'package:medal/modules/citizen/authentication/forgot_password.dart';
import 'package:medal/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = usernameController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('[MEDAL] LOGIN STARTED — email=$email');

    try {
      await ApiService().login(email: email, password: password);
      debugPrint('[MEDAL] LOGIN SUCCESS');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${ApiService().currentUser?['full_name'] ?? 'Citizen'}!'),
          backgroundColor: const Color(0xFF4F46E5),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainScreen(showAcademyPopup: true),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      debugPrint('[MEDAL] LOGIN API EXCEPTION: statusCode=${e.statusCode} message=${e.message}');
      if (!mounted) return;
      String msg;
      switch (e.statusCode) {
        case 0:
          // Network error or timeout — message already set by ApiService
          msg = e.message;
          break;
        case 401:
          msg = 'Invalid email or password. Please try again.';
          break;
        case 403:
          msg = 'Your account is not authorized to log in.';
          break;
        case 404:
          msg = 'Login endpoint not found. Check backend configuration.';
          break;
        case 500:
        case 502:
        case 503:
          msg = 'Server error (${e.statusCode}). Please try again later.';
          break;
        default:
          msg = e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      debugPrint('[MEDAL] LOGIN UNEXPECTED ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: ${e.runtimeType}. Check debug logs.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      debugPrint('[MEDAL] LOGIN FLOW COMPLETE — resetting spinner');
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          tooltip: "Back to Role Selection",
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Icon(
                Icons.workspace_premium,
                color: Color(0xFF4F46E5),
                size: 50,
              ),
              const SizedBox(height: 10),
              const Text(
                "MEdAL",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0567B6),
                      ),
                    ),
                    const SizedBox(height: 25),

                    /// Email / Username
                    TextField(
                      controller: usernameController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        hintText: "user@example.com",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// Password
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 8),

                    /// Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Sign In",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Create an account",
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.institution);
                      },
                      icon: const Icon(Icons.account_balance, size: 18, color: Color(0xFF4338CA)),
                      label: const Text(
                        "Institution / Official Portal",
                        style: TextStyle(
                          color: Color(0xFF4338CA),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0E7FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}