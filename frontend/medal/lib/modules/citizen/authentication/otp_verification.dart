import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/citizen/authentication/reset_password.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  // 60-second resend cooldown timer
  Timer? _cooldownTimer;
  int _cooldownSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerifyOtp() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the verification code.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await ApiService().verifyOtp(
        email: widget.email,
        otp: code,
      );

      final resetToken = response['reset_token'] as String?;
      if (resetToken == null || resetToken.isEmpty) {
        throw Exception('Verification completed but no reset token was returned.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code confirmed! Please choose your new password.'),
          backgroundColor: Color(0xFF0467B6),
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to Reset Password Screen with the verified reset token
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(
            prefilledToken: resetToken,
            email: widget.email,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verification error: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await ApiService().resendOtp(email: widget.email);
      final msg = response['message'] as String? ?? 'A new verification code has been sent.';

      if (!mounted) return;

      setState(() {
        _successMessage = msg;
      });
      _startCooldownTimer();

      // Clear entered digits
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not resend code: $e';
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste of multiple characters
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < digits.length && (index + i) < 6; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
      if (_otpCode.length == 6) {
        _handleVerifyOtp();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otpCode.length == 6) {
          _handleVerifyOtp();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111C2D), size: 20),
          tooltip: "Back",
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC6C5D7).withValues(alpha: 0.5)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000), // 5% black shadow
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Shield Icon Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F4FD),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFF0467B6),
                          size: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Center(
                      child: Text(
                        "Enter Verification Code",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111C2D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      "We have sent a 6-digit code to",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5D6478),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            widget.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0467B6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF5D6478)),
                          tooltip: "Change Email",
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Success Banner
                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF065F46),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 6 Pin Input Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 44,
                          height: 52,
                          child: KeyboardListener(
                            focusNode: FocusNode(),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey == LogicalKeyboardKey.backspace &&
                                  _controllers[index].text.isEmpty &&
                                  index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                            },
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111C2D),
                              ),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFC6C5D7)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0467B6),
                                    width: 2.0,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFC6C5D7)),
                                ),
                              ),
                              onChanged: (val) => _onDigitChanged(index, val),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Expiry Indicator
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: Color(0xFF6B7280)),
                        SizedBox(width: 6),
                        Text(
                          "Code expires in 10 minutes",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0467B6),
                          disabledBackgroundColor: const Color(0xFF0467B6).withValues(alpha: 0.6),
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
                                "Verify & Continue",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Resend Code Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't receive the code? ",
                          style: TextStyle(
                            color: Color(0xFF5D6478),
                            fontSize: 13,
                          ),
                        ),
                        if (_cooldownSeconds > 0)
                          Text(
                            "Resend in ${_cooldownSeconds}s",
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          )
                        else
                          TextButton(
                            onPressed: _isResending ? null : _handleResendOtp,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: _isResending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0467B6),
                                    ),
                                  )
                                : const Text(
                                    "Resend Code",
                                    style: TextStyle(
                                      color: Color(0xFF0467B6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                      ],
                    ),

                    const Divider(height: 28, color: Color(0xFFC6C5D7)),

                    // Return to Login
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: const Text(
                          "Back to Sign In",
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }
}
