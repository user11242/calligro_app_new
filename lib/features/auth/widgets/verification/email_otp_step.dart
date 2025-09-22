import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';
import 'otp_input_widget.dart';

class EmailOtpStep extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;

  const EmailOtpStep({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<EmailOtpStep> createState() => _EmailOtpStepState();
}

class _EmailOtpStepState extends State<EmailOtpStep> {
  final AuthService _authService = AuthService();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  String? _errorText;
  bool isLoading = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp(); // Sends OTP immediately when the step loads
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final ok = await _authService.sendEmailOtp(widget.email);
    if (ok) {
      _startCooldown();
    } else {
      setState(() => _errorText = "Failed to send OTP");
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorText = "Enter the 6-digit code");
      return;
    }

    setState(() {
      _errorText = null;
      isLoading = true;
    });

    final valid = await _authService.verifyEmailOtp(widget.email, otp);
    if (valid) {
      widget.onVerified(); // Calls the parent's callback to move to the next step
    } else {
      setState(() => _errorText = "Invalid OTP, try again.");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "Enter the code sent to ${widget.email}",
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        OtpInputWidget(controllers: _controllers, errorText: _errorText),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _resendCooldown == 0 ? _sendOtp : null,
          child: Text(
            _resendCooldown == 0
                ? "Resend Code"
                : "Resend in $_resendCooldown s",
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: isLoading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade400,
            foregroundColor: Colors.black,
          ),
          child: isLoading
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                )
              : const Text("Verify"),
        ),
      ],
    );
  }
}