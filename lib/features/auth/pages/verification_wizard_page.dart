import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../auth/data/services/auth_service.dart';
import '../widgets/verification/phone_otp_step.dart';
import '../widgets/verification/email_otp_step.dart';
import '../widgets/verification/finish_verification_step.dart';

class VerificationWizardPage extends StatefulWidget {
  final String role;
  final String email;
  final String password;
  final String phone;
  final String name;
  final String portfolio;

  const VerificationWizardPage({
    super.key,
    required this.role,
    required this.email,
    required this.password,
    required this.phone,
    required this.name,
    required this.portfolio,
  });

  @override
  State<VerificationWizardPage> createState() => _VerificationWizardPageState();
}

class _VerificationWizardPageState extends State<VerificationWizardPage> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _step = 0;
  bool isLoading = false;

  bool get isTeacher => widget.role == "teacher";

  @override
  void initState() {
    super.initState();
    // 🔹 The fix: For students, we skip the phone step and start at step 1 (email).
    if (!isTeacher) {
      _step = 1;
    }
  }

  // ---------- FINISH REGISTRATION ----------
  Future<void> _finishRegistration() async {
    setState(() => isLoading = true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );
      final user = credential.user;
      if (user == null) throw Exception("User creation failed");

      final data = {
        "uid": user.uid,
        "name": widget.name,
        "email": widget.email,
        "role": widget.role,
        "status": isTeacher ? "pending" : "approved",
        "createdAt": FieldValue.serverTimestamp(),
      };
      if (isTeacher) {
        data["phone"] = widget.phone;
        data["portfolio"] = widget.portfolio;
      }

      await _firestore.collection("users").doc(user.uid).set(data);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/LoginPage");
    } catch (e) {
      _showMessage("Registration failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------- NAVIGATION ----------
  void _goToNextStep() {
    setState(() {
      _step++;
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // 🔹 A simple container for the dialog's content
  Widget _buildStepContent() {
    if (_step == 0) {
      return PhoneOtpStep(
        phone: widget.phone,
        onVerified: _goToNextStep,
      );
    } else if (_step == 1) {
      return EmailOtpStep(
        email: widget.email,
        onVerified: _goToNextStep,
      );
    } else {
      return FinishVerificationStep(
        onFinish: _finishRegistration,
        isLoading: isLoading,
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    const totalSteps = 3;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Dialog(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, "/RegisterPage");
                    },
                  ),
                ),
                if (isTeacher && _step < 2)
                  Text("Step ${_step + 1} of $totalSteps",
                      style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 250,
                  child: Center(
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
