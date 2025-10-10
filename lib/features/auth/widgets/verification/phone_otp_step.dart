import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_input_widget.dart'; 

class PhoneOtpStep extends StatefulWidget {
  final String phone;
  final VoidCallback onVerified;
  final bool showNextButton;

  const PhoneOtpStep({
    super.key,
    required this.phone,
    required this.onVerified,
    this.showNextButton = true,
  });

  @override
  // Public State class to allow parent access
  State<PhoneOtpStep> createState() => PhoneOtpStepState();
}

// Public State class to allow parent access to validation methods
class PhoneOtpStepState extends State<PhoneOtpStep> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());

  String? _verificationId;
  String? _errorText;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp(); 
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
        // 🔹 Check mounted inside periodic timer callback
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _errorText = null);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          widget.onVerified();
        },
        verificationFailed: (e) {
          // 🔹 Check mounted
          if (!mounted) return;
          setState(() => _errorText = e.message);
        },
        codeSent: (verificationId, _) {
          // 🔹 Check mounted
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
          _startCooldown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // 🔹 Check mounted
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      // 🔹 Check mounted
      if (!mounted) return;
      setState(() => _errorText = "Failed to send OTP: $e");
    }
  }

  // Public method callable by the parent widget (GoogleRegisterWizard)
  Future<bool> verifyAndSubmit() async {
    final smsCode = _controllers.map((c) => c.text).join();
    
    if (_verificationId == null) {
      setState(() => _errorText = "Please wait for the verification code to be sent.");
      return false;
    }

    if (smsCode.length != 6) {
      setState(() => _errorText = "Enter the full 6-digit code");
      return false;
    }

    setState(() => _errorText = null);
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      // await call
      await _auth.signInWithCredential(credential);
      
      // If sign-in is successful, widget.onVerified() is called, 
      // which moves the step and disposes this widget.
      widget.onVerified(); 
      return true;
    } on FirebaseAuthException catch (e) {
      // 🔹 FIX: Check mounted before calling setState() on error
      if (!mounted) return false;
      setState(() => _errorText = e.message);
      return false;
    } catch (_) {
      // 🔹 FIX: Check mounted before calling setState() on error
      if (!mounted) return false;
      setState(() => _errorText = "Invalid OTP, try again.");
      return false;
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
          // Using OtpInputWidget as per your last provided code
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
        ],
      ),
    );
  }
}