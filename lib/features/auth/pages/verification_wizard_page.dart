// File: lib/features/auth/presentation/pages/verification_wizard_page.dart

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
    if (!isTeacher) {
      _step = 1;
    }
  }

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
      // Close the wizard and return to the previous page.
      // The previous page should then handle the navigation to the login page.
      Navigator.pop(context);

    } catch (e) {
      _showMessage("Registration failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    const totalSteps = 3;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
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
                          // This will now correctly pop the dialog off the stack
                          Navigator.of(context).pop();
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
        ),
      ),
    );
  }
}