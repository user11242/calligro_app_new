import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../../core/theme/colors.dart';
import '../../auth/data/services/auth_service.dart';
import '../widgets/verification/universal_otp_step.dart';
import '../widgets/verification/finish_verification_step.dart';

class VerificationWizardPage extends StatefulWidget {
  final String role, email, password, phone, name, portfolio;
  final bool acceptedTerms;
  final String? language;
  final String? fcmToken;

  const VerificationWizardPage({
    super.key,
    required this.role,
    required this.email,
    required this.password,
    required this.phone,
    required this.name,
    required this.portfolio,
    required this.acceptedTerms,
    this.language,
    this.fcmToken,
  });

  @override
  State<VerificationWizardPage> createState() => _VerificationWizardPageState();
}

class _VerificationWizardPageState extends State<VerificationWizardPage> {
  final AuthService _authService = AuthService();
  GlobalKey<UniversalOtpStepState> _otpKey = GlobalKey<UniversalOtpStepState>();

  int _step = 0;
  bool isLoading = false;

  bool get isTeacher => widget.role == "teacher";
  int get currentStepIndex => isTeacher ? _step + 1 : _step;
  int get totalStepsCount => isTeacher ? 3 : 2;

  @override
  void initState() {
    super.initState();
    if (!isTeacher) _step = 1;
  }

  void _goToNextStep() {
    setState(() {
      _otpKey = GlobalKey<UniversalOtpStepState>();
      _step++;
    });
  }

  void _prevStep() {
    if (_step > 0) {
      if (isTeacher && _step == 1) {
        // Teachers start at step 0 (phone). If they are at step 1 (email) and go back, go to phone.
        // Also unlink the phone so they can change it if they want.
        _authService.unlinkPhone();
        setState(() {
          _otpKey = GlobalKey<UniversalOtpStepState>();
          _step = 0;
        });
      } else if (!isTeacher && _step == 1) {
        // Students start at step 1 (email). If they go back from here, exit/cancel.
        // (This condition should be redundant if button is hidden, but good for safety)
        _handleCancel();
      } else {
        setState(() {
          _otpKey = GlobalKey<UniversalOtpStepState>();
          _step--;
        });
      }
    } else {
      _handleCancel();
    }
  }

  Future<void> _handleCancel() async {
    // Cleanup any ghost account (Auth record without Firestore doc)
    setState(() => isLoading = true);
    await _authService.cleanupGhostAccount();
    if (mounted) {
      setState(() => isLoading = false);
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_step < 2) {
      await _otpKey.currentState?.verifyAndSubmit();
    } else {
      await _finishRegistration();
    }
  }

  Future<void> _finishRegistration() async {
    debugPrint("DEBUG: _finishRegistration started for role: ${widget.role}");
    final navigator = Navigator.of(context);
    setState(() => isLoading = true);

    try {
    final error = await _authService.registerWithEmail(
      name: widget.name,
      email: widget.email,
      password: widget.password,
      confirmPassword: widget.password,
      role: widget.role,
      phone: widget.phone,
      portfolio: widget.portfolio,
      acceptedTerms: widget.acceptedTerms,
      language: widget.language,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (error == null) {
      // ✅ Save FCM Token immediately after successful registration
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // If we already pre-fetched the token, save it directly
        if (widget.fcmToken != null) {
           await FirebaseFirestore.instance.collection("users").doc(currentUser.uid).update({
             "fcmToken": widget.fcmToken,
             "lastTokenUpdate": FieldValue.serverTimestamp(),
           });
        } else {
           await _authService.saveUserFcmToken(currentUser.uid);
        }
      }

      if (widget.role == 'teacher') {
        navigator.pop('SUCCESS_CLOSE_TEACHER');
      } else {
        navigator.pop(widget.role);
      }
    } else {
      _showDetailedErrorDialog("Registration Error", error);
    }
    } catch (e, stack) {
      if (mounted) setState(() => isLoading = false);
      _showDetailedErrorDialog("Crash in Registration", "$e\n$stack");
    }
  }

  void _showDetailedErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: SingleChildScrollView(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12))),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.amber)))
        ]
      )
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
      case 1:
        return UniversalOtpStep(
          key: _otpKey,
          destination: _step == 0 ? widget.phone : widget.email,
          onVerified: _goToNextStep,
        );
      case 2:
        return const FinishVerificationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: !isLoading, // Prevent pop if we are currently cleaning up
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // If already popped by something else
        
        // 👻 Cleanup if system back or swipe exits the wizard
        await _authService.cleanupGhostAccount();
        
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85 - bottomInset,
                ),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                child: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Align(
                              alignment: AlignmentDirectional.topEnd,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white70),
                                onPressed: _handleCancel,
                              ),
                            ),
                          ],
                        ),
                        if (currentStepIndex <= totalStepsCount)
                          Text(
                            l10n.stepOf(currentStepIndex, totalStepsCount),
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                          ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Container(key: ValueKey<int>(_step), child: _buildStepContent()),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Spacer(),
                            if (_step == 2)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentGold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isLoading ? null : _handlePrimaryAction,
                                child: isLoading
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                          ),
                                          SizedBox(width: 10),
                                          Text(l10n.finalizing, style: const TextStyle(color: Colors.black, fontSize: 13)),
                                        ],
                                      )
                                    : Text(l10n.finishAndRegister, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
