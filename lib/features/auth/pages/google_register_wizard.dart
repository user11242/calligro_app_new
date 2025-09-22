import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';

// Step widgets
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_role.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_welcome.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_student_finish.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_teacher_phone.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_teacher_portfolio.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_teacher_finish.dart';

// Verification widgets
import 'package:calligro_app/features/auth/widgets/verification/phone_otp_step.dart';

class GoogleRegisterWizard extends StatefulWidget {
  const GoogleRegisterWizard({super.key});

  @override
  State<GoogleRegisterWizard> createState() => _GoogleRegisterWizardState();
}

class _GoogleRegisterWizardState extends State<GoogleRegisterWizard> {
  int _step = 0;
  String selectedRole = "student";

  final phoneController = TextEditingController();
  final portfolioController = TextEditingController();

  bool isLoading = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  /// ✅ Steps builder
  late List<Widget> steps;

  @override
  void initState() {
    super.initState();
    _buildSteps();
  }

  void _buildSteps() {
    steps = [
      StepWelcome(user: _auth.currentUser),
      StepRole(
        selectedRole: selectedRole,
        onRoleChanged: (r) => setState(() {
          selectedRole = r;
          _buildSteps(); // rebuild steps when role changes
        }),
      ),
      if (selectedRole == "student") const StepStudentFinish(),
      if (selectedRole == "teacher")
        StepTeacherPhone(controller: phoneController),
      if (selectedRole == "teacher")
        PhoneOtpStep(
          phone: phoneController.text.trim(),
          onVerified: _nextStep, // automatically go next when verified
        ),
      if (selectedRole == "teacher")
        StepTeacherPortfolio(controller: portfolioController),
      if (selectedRole == "teacher") const StepTeacherFinish(),
    ];
  }

  /// ---------- STEP VALIDATION ----------
  Future<bool> _validateStep(int step) async {
    if (selectedRole == "teacher") {
      // step 2 → phone required
      if (step == 2 && phoneController.text.trim().isEmpty) {
        _showError("Phone number required");
        return false;
      }

      // step 3 → phone OTP must be correct
      if (step == 3) {
        final otpStep = steps[step] as PhoneOtpStep;
        final state = otpStep.createState() as dynamic;
        final ok = await state.verifyOtp();
        if (!ok) return false;
      }

      // step 4 → portfolio URL valid
      if (step == 4 && !_isValidUrl(portfolioController.text.trim())) {
        _showError("Enter a valid portfolio link");
        return false;
      }
    }
    return true;
  }

  bool _isValidUrl(String url) {
    final regex = RegExp(r"^https?:\/\/[\w\-]+(\.[\w\-]+)+");
    return regex.hasMatch(url);
  }

  /// ---------- NAVIGATION ----------
  Future<void> _nextStep() async {
    final ok = await _validateStep(_step);
    if (!ok) return;
    setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  /// ---------- ERROR DISPLAY ----------
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  /// ---------- FINISH ----------
  Future<void> _finish() async {
    setState(() => isLoading = true);
    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      "uid": user.uid,
      "name": user.displayName ?? "",
      "email": user.email ?? "",
      "photoUrl": user.photoURL ?? "",
      "role": selectedRole,
      "status": selectedRole == "teacher" ? "pending" : "approved",
      "createdAt": FieldValue.serverTimestamp(),
      if (selectedRole == "teacher") ...{
        "phone": phoneController.text.trim(),
        "portfolio": portfolioController.text.trim(),
      },
    };

    await _firestore.collection("users").doc(user.uid).set(data);

    if (!mounted) return;
    setState(() => isLoading = false);
    Navigator.pop(context, selectedRole);
  }

  /// ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    _buildSteps(); // refresh steps when UI rebuilds

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Dialog(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 200,
                    maxHeight: 350,
                  ),
                  child: steps[_step],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _prevStep,
                        child: const Text(
                          "Back",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : (_isFinalStep() ? _finish : _nextStep),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade400,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            )
                          : Text(_isFinalStep() ? "Finish" : "Next"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ---------- FINAL STEP ----------
  bool _isFinalStep() {
    if (selectedRole == "student") return _step == 2;
    if (selectedRole == "teacher") return _step == 5;
    return false;
  }
}