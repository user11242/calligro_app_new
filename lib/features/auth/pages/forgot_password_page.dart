import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../../../core/theme/colors.dart';
import '../../../core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../data/services/auth_service.dart';
import '../widgets/verification/universal_otp_step.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  bool isLoading = false;
  int _currentStep = 0; // 0: Email, 1: OTP, 2: New Password
  String? _userEmail;

  // Placeholder for GlobalKey

  final GlobalKey<UniversalOtpStepState> _otpStepKey =
      GlobalKey<UniversalOtpStepState>();

  @override
  void dispose() {
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(
    BuildContext context,
    String title,
    String message,
    MessengerType type,
  ) {
    AppMessenger.showSnackBar(
      context,
      title: title,
      message: message,
      type: type,
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    return emailRegex.hasMatch(email);
  }

  void _showGoogleSignAlert(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentGold.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.g_mobiledata_rounded,
                  size: 48,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.googleAccountAlertTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.googleAccountAlertMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext); // Close dialog
                    Navigator.pop(context); // Go back to Login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.gotIt,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _handleEmailSubmit() async {
    final email = emailController.text.trim().toLowerCase();
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) return; // Prevent double trigger

    if (email.isEmpty) {
      _showMessage(context, l10n.error, l10n.enterEmail, MessengerType.error);
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(context, l10n.error, l10n.invalidEmail, MessengerType.error);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Check if user exists in Firestore
      final query = await _firestore
          .collection("users")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showMessage(
          context,
          l10n.error,
          l10n.noAccountFound,
          MessengerType.error,
        );
        setState(() => isLoading = false);
        return;
      }

      final userData = query.docs.first.data();
      final status = userData["status"] ?? "pending";

      if (status != "approved" && status != "active") {
        _showMessage(
          context,
          l10n.unavailable,
          l10n.teacherUnderReview,
          MessengerType.info,
        );
        setState(() => isLoading = false);
        return;
      }

      // Check sign-in methods
      final signInMethods = await _authService.getUserSignInMethods(email);
      print("DEBUG: Sign-in methods for $email: $signInMethods"); // Debug log

      bool isGoogle = false;

      if (signInMethods.isEmpty) {
        // Fallback: Check Firestore `authProvider` field
        print(
          "DEBUG: Cloud Function returned empty. Checking Firestore fallback.",
        );
        final String? authProvider = userData["authProvider"];
        if (authProvider == 'google') {
          isGoogle = true;
        } else if (authProvider == 'email') {
          isGoogle = false;
        } else {
          // No provider info in Firestore either (Legacy user?)
          // Warning: Falling back to email might send OTP to Google user if they are legacy.
          // Ideally we ask them to contact support or try logging in.
          // For now, let's allow flow to proceed if we can't definitively say it's Google.
          print(
            "DEBUG: No authProvider in Firestore. Proceeding as Email (Legacy).",
          );
        }
        // Block ONLY if they have google.com AND DO NOT have a password.
        isGoogle = signInMethods.contains('google.com') && !signInMethods.contains('password');
      }

      if (isGoogle) {
        if (!mounted) return;
        setState(() => isLoading = false);
        _showGoogleSignAlert(context);
        return;
      }

      // Proceed to OTP step
      setState(() {
        _userEmail = email;
        _currentStep = 1;
        isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      print("DEBUG: FirebaseFunctionsException: ${e.code} - ${e.message}");
      if (e.code == 'permission-denied') {
        _showMessage(
          context,
          l10n.error,
          "Developer Action Required: Cloud Function permissions not set. Check implementation plan.",
          MessengerType.error,
        );
      } else {
        _showMessage(
          context,
          l10n.error,
          e.message ?? l10n.pleaseTryAgain,
          MessengerType.error,
        );
      }
      setState(() => isLoading = false);
    } on FirebaseAuthException catch (e) {
      print("DEBUG: FirebaseAuthException: $e");
      _showMessage(
        context,
        l10n.error,
        e.message ?? l10n.error,
        MessengerType.error,
      );
      setState(() => isLoading = false);
    } catch (e) {
      print("DEBUG: General Exception: $e");
      _showMessage(
        context,
        l10n.error,
        l10n.pleaseTryAgain,
        MessengerType.error,
      );
      setState(() => isLoading = false);
    }
  }

  // State variables for password fields
  String? _passwordError;
  String? _confirmError;
  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  void _validatePassword(String value) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      if (value.isEmpty) {
        _passwordError = l10n.enterPassword;
      } else if (value.length < 6) {
        _passwordError = l10n.passwordTooShort;
      } else if (!RegExp(
        r'^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,}$',
      ).hasMatch(value)) {
        _passwordError = l10n.passwordComplexity;
      } else {
        _passwordError = null;
      }

      if (confirmPasswordController.text.isNotEmpty) {
        _validateConfirmPassword(confirmPasswordController.text);
      }
    });
  }

  void _validateConfirmPassword(String value) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      if (value != newPasswordController.text) {
        _confirmError = l10n.passwordsDoNotMatch;
      } else {
        _confirmError = null;
      }
    });
  }

  Future<void> _handlePasswordReset() async {
    final l10n = AppLocalizations.of(context)!;
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    _validatePassword(newPassword);
    _validateConfirmPassword(confirmPassword);

    if (_passwordError != null || _confirmError != null) {
      _showMessage(context, l10n.error, l10n.fixErrors, MessengerType.error);
      return;
    }

    // Validation passed via the checks above

    setState(() => isLoading = true);

    try {
      // Call Cloud Function to reset password
      final callable = FirebaseFunctions.instance.httpsCallable(
        'resetPasswordWithOtp',
      );
      final result = await callable.call({
        'email': _userEmail,
        'newPassword': newPassword,
      });

      if (result.data['success'] == true) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accentGold.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.success,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.passwordResetSuccess,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close dialog
                        Navigator.pop(context); // Go back to Login
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.login,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      } else {
        _showMessage(
          context,
          l10n.error,
          l10n.pleaseTryAgain,
          MessengerType.error,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      print("DEBUG: FirebaseFunctionsException: ${e.code} - ${e.message}");
      if (e.code == 'permission-denied') {
        _showMessage(
          context,
          l10n.error,
          "Developer Action Required: Cloud Function permissions not set. Check implementation plan.",
          MessengerType.error,
        );
      } else {
        _showMessage(
          context,
          l10n.error,
          e.message ?? l10n.pleaseTryAgain,
          MessengerType.error,
        );
      }
    } catch (e) {
      _showMessage(
        context,
        l10n.error,
        l10n.pleaseTryAgain,
        MessengerType.error,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildStepContent() {
    final l10n = AppLocalizations.of(context)!;

    switch (_currentStep) {
      case 0:
        return _buildEmailStep();
      case 1:
        return _buildOtpStep();
      case 2:
        return _buildPasswordStep();
      default:
        return _buildEmailStep();
    }
  }

  Widget _buildEmailStep() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        AuthTextField(
          controller: emailController,
          hint: l10n.emailAddress,
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 25),
        isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : AuthButton(
                text: l10n.sendResetEmail,
                onPressed: _handleEmailSubmit,
              ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),

        UniversalOtpStep(
          key: _otpStepKey,
          destination: _userEmail!,
          onVerified: () {
            setState(() => _currentStep = 2);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPasswordStep() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        AuthTextField(
          controller: newPasswordController,
          hint: l10n.newPassword,
          icon: Icons.lock,
          obscure: true,
          showToggle: true,
          isObscured: _isNewPasswordObscured,
          onToggle: () =>
              setState(() => _isNewPasswordObscured = !_isNewPasswordObscured),
          onChanged: _validatePassword,
          errorText: _passwordError,
          isSuccess:
              _passwordError == null && newPasswordController.text.isNotEmpty,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: confirmPasswordController,
          hint: l10n.confirmNewPassword,
          icon: Icons.lock_outline,
          obscure: true,
          showToggle: true,
          isObscured: _isConfirmPasswordObscured,
          onToggle: () => setState(
            () => _isConfirmPasswordObscured = !_isConfirmPasswordObscured,
          ),
          onChanged: _validateConfirmPassword,
          errorText: _confirmError,
          isSuccess:
              _confirmError == null &&
              confirmPasswordController.text.isNotEmpty,
        ),
        const SizedBox(height: 25),
        isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : AuthButton(
                text: l10n.setNewPasswordTitle,
                onPressed: _handlePasswordReset,
              ),
      ],
    );
  }

  String _getTitle() {
    final l10n = AppLocalizations.of(context)!;
    switch (_currentStep) {
      case 0:
        return l10n.forgotPasswordTitle;
      case 1:
        return l10n.verifyOtpTitle;
      case 2:
        return l10n.setNewPasswordTitle;
      default:
        return l10n.forgotPasswordTitle;
    }
  }

  String _getSubtitle() {
    final l10n = AppLocalizations.of(context)!;
    switch (_currentStep) {
      case 0:
        return l10n.forgotPasswordSubtitle;
      case 1:
        return ''; // Handled by UniversalOtpStep
      case 2:
        return l10n.setNewPasswordTitle;
      default:
        return l10n.forgotPasswordSubtitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Prevents background image from resizing
      body: Stack(
        children: [
          // 1. Fixed Background Image
          Positioned.fill(
            child: Image.asset(
              "assets/backgrounds/main_background.jpg",
              fit: BoxFit.cover,
            ),
          ),
          // 2. Overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          // 3. Back Button (Safe Area, Top Left, Styled like Login Page)
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 10,
            start: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ColorFilter.mode(
                  Colors.black.withOpacity(0.1),
                  BlendMode.darken,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep--);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),

          // 4. Bottom Sheet Content (Half Screen, Bottom Aligned)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, -bottomPadding, 0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height:
                    MediaQuery.of(context).size.height *
                    0.55, // 55% of screen height
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 32,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E), // Dark container background
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  // Use SingleChildScrollView to allow scrolling if content overflows or keyboard appears
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Center horizontally
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Icon Header for a better look
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _currentStep == 1
                              ? Icons.security_rounded
                              : Icons.lock_reset_rounded,
                          size: 40,
                          color: AppColors.accentGold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title & Subtitle (Now inside the container)
                      Text(
                        _getTitle(),
                        textAlign: TextAlign.center, // Center text
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getSubtitle(),
                        textAlign: TextAlign.center, // Center text
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // The Form Content
                      _buildStepContent(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
