import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_input_widget.dart';

class PhoneOtpStep extends StatefulWidget {
  final String phone;
  final VoidCallback onVerified;

  const PhoneOtpStep({
    super.key,
    required this.phone,
    required this.onVerified,
  });

  @override
  State<PhoneOtpStep> createState() => _PhoneOtpStepState();
}

class _PhoneOtpStepState extends State<PhoneOtpStep> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());

  String? _verificationId;
  String? _errorText;
  bool isLoading = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp(); // 🔹 send OTP immediately when step opens
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
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // 🔹 This is only triggered on Android for instant verification.
          await _auth.signInWithCredential(credential);
          widget.onVerified();
        },
        verificationFailed: (e) {
          setState(() => _errorText = e.message);
        },
        codeSent: (verificationId, _) {
          setState(() => _verificationId = verificationId);
          _startCooldown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      setState(() => _errorText = "Failed to send OTP: $e");
    }
  }

  Future<void> _verifyOtpAndProceed() async {
    final smsCode = _controllers.map((c) => c.text).join();
    if (_verificationId == null || smsCode.length != 6) {
      setState(() => _errorText = "Enter the 6-digit code");
      return;
    }

    setState(() {
      _errorText = null;
      isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      widget.onVerified(); // 🔹 Trigger the parent's callback on success
    } catch (_) {
      setState(() => _errorText = "Invalid OTP, try again.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Enter the code sent to ${widget.phone}",
              style: const TextStyle(color: Colors.white)),
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
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isLoading ? null : _verifyOtpAndProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade400,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: isLoading
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  )
                : const Text("Next"),
          ),
        ],
      ),
    );
  }
}