import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../../core/theme/colors.dart';
import 'package:calligro_app/features/auth/data/services/auth_service.dart';
import '../../../core/message/app_messenger.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:device_region/device_region.dart';
import 'package:calligro_app/features/auth/pages/terms_and_conditions_page.dart';
import 'package:phone_number/phone_number.dart' as lib_phone;
import '../../../core/utils/numeric_utils.dart';

// Steps
import '../widgets/google_register_widgets/step_role.dart';
import '../widgets/google_register_widgets/step_welcome.dart';
import '../widgets/google_register_widgets/step_student_finish.dart';
import '../widgets/google_register_widgets/step_teacher_portfolio.dart';
import '../widgets/google_register_widgets/../verification/universal_otp_step.dart';
import '../widgets/google_register_widgets/step_teacher_finish.dart';

class GoogleRegisterWizard extends StatefulWidget {
  const GoogleRegisterWizard({super.key});

  @override
  State<GoogleRegisterWizard> createState() => _GoogleRegisterWizardState();
}

class _GoogleRegisterWizardState extends State<GoogleRegisterWizard> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final phoneController = TextEditingController();
  final portfolioController = TextEditingController();
  final _phoneUtil = lib_phone.PhoneNumberUtil();

  GlobalKey<UniversalOtpStepState> _otpKey = GlobalKey<UniversalOtpStepState>();

  int _step = 0;
  String selectedRole = "student";
  bool isLoading = false;
  bool _acceptedTerms = false;
  String fullPhoneNumber = "";
  String _initialCountryCode = "JO";
  bool _isStepsInitialized = false;
  final List<String> _selectedLanguages = [];

  String? _portfolioError;

  void _validatePortfolio(String value) {
    final l10n = AppLocalizations.of(context)!;
    if (value.isEmpty) {
      setState(() => _portfolioError = l10n.enterPortfolio);
      return;
    }

    final urlRegex = RegExp(
      r'^(http|https):\/\/(([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})(/[a-zA-Z0-9-._~:/?#\[\]@!$&' "'" r'()*+,;=%]*)?$',
      caseSensitive: false,
    );

    if (!urlRegex.hasMatch(value.trim())) {
      setState(() => _portfolioError = l10n.invalidPortfolio);
    } else {
      setState(() => _portfolioError = null);
    }
  }

  Future<void> _pastePortfolio() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      portfolioController.text = data!.text!;
      _validatePortfolio(data.text!);
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeWizard();
  }

  @override
  void dispose() {
    phoneController.dispose();
    portfolioController.dispose();
    super.dispose();
  }

  Future<void> _initializeWizard() async {
    try {
      // 1. Try SIM Card (Best)
      String? countryCode = await DeviceRegion.getSIMCountryCode();

      // 2. Fallback: Device System Region
      if (countryCode == null || countryCode.isEmpty) {
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        countryCode = locale.countryCode;
      }

      if (countryCode != null && countryCode.isNotEmpty) {
        _initialCountryCode = countryCode.toUpperCase();
      }
    } catch (_) {}
    if (mounted) setState(() => _isStepsInitialized = true);
  }

  void _onRoleChanged(String newRole) {
    setState(() {
      selectedRole = newRole;
      _step = 1;
    });
  }

  Widget _buildStepContent() {
    final currentUser = _auth.currentUser;
    if (selectedRole == "student") {
      switch (_step) {
        case 0:
          return StepWelcome(user: currentUser);
        case 1:
          return StepRole(selectedRole: selectedRole, onRoleChanged: _onRoleChanged);
        case 2:
          return const StepStudentFinish();
        default:
          return const SizedBox.shrink();
      }
    } else {
      switch (_step) {
        case 0:
          return StepWelcome(user: currentUser);
        case 1:
          return StepRole(selectedRole: selectedRole, onRoleChanged: _onRoleChanged);
        case 2:
          return _buildPhoneInputStep();
        case 3:
          return UniversalOtpStep(key: _otpKey, destination: fullPhoneNumber, onVerified: _stepForward);
        case 4:
          return StepTeacherPortfolio(
            controller: portfolioController,
            errorText: _portfolioError,
            onChanged: _validatePortfolio,
            onPaste: _pastePortfolio,
            selectedLanguages: _selectedLanguages,
            onLanguagesChanged: (langs) {
              setState(() {
                _selectedLanguages.clear();
                _selectedLanguages.addAll(langs);
              });
            },
          );
        case 5:
          return const StepTeacherFinish();
        default:
          return const SizedBox.shrink();
      }
    }
  }

  Widget _buildPhoneInputStep() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.verifyIdentity,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        IntlPhoneField(
          controller: phoneController,
          invalidNumberMessage: l10n.invalidMobileNumber,
          initialCountryCode: _initialCountryCode,
          style: const TextStyle(color: Colors.white),
          inputFormatters: [NumericUtils.digitFormatter],
          textAlign: TextAlign.start,
          onChanged: (phone) {
            setState(() {
              // Normalize digits AND clean spaces/dashes for the backend
              fullPhoneNumber = NumericUtils.normalize(phone.completeNumber, clean: true);
            });
          },
          decoration: InputDecoration(
            hintText: l10n.phoneNumber,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accentGold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _nextStep() async {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) return;

    if (selectedRole == "teacher" && _step == 2) {
      if (phoneController.text.length < 5) return;

      setState(() => isLoading = true);
      
      // 1. Format Check
      bool isValidFormat = false;
      try {
        isValidFormat = await _phoneUtil.validate(fullPhoneNumber, regionCode: _initialCountryCode);
      } catch (_) {
        isValidFormat = false;
      }

      if (!mounted) return;

      if (!isValidFormat) {
        setState(() => isLoading = false);
        AppMessenger.showSnackBar(context, title: l10n.error, message: l10n.invalidMobileNumber, type: MessengerType.error);
        return;
      }

      // 2. Uniqueness Check
      final isTaken = await _authService.isPhoneTaken(fullPhoneNumber);
      if (mounted) setState(() => isLoading = false);

      if (isTaken) {
        if (mounted) {
          AppMessenger.showSnackBar(context, title: l10n.unavailable, message: l10n.phoneNumberInUse, type: MessengerType.error);
        }
        return;
      }
    }

    if (selectedRole == "teacher" && _step == 3) {
      if (_otpKey.currentState == null) return;
      setState(() => isLoading = true);
      await _otpKey.currentState!.verifyAndSubmit();
      if (mounted) setState(() => isLoading = false);
      return;
    }

    if (await _validateCurrentStepInput()) {
      _isFinalStep() ? await _finishWizard() : _stepForward();
    }
  }

  void _stepForward() {
    if (mounted) {
      setState(() {
        _otpKey = GlobalKey<UniversalOtpStepState>();
        _step++;
      });
    }
  }

  void _prevStep() {
    if (_step > 0) {
      // If moving back from OTP (step 3) to Phone Input (step 2) for teachers, unlink the phone.
      if (selectedRole == "teacher" && _step == 3) {
        _authService.unlinkPhone();
      }
      setState(() {
        _otpKey = GlobalKey<UniversalOtpStepState>();
        _step--;
      });
    } else {
      // If at step 0 and go back (should be hidden in UI, but safety), handle cancel
      _handleCancel();
    }
  }

  Future<void> _handleCancel() async {
    // If they cancel, we cleanup the ghost account so they aren't "stuck"
    // especially important for Google users who signed in but didn't finish.
    setState(() => isLoading = true);
    await _authService.cleanupGhostAccount();
    if (mounted) {
      setState(() => isLoading = false);
      Navigator.of(context).pop();
    }
  }

  bool _isFinalStep() => (selectedRole == "student" && _step == 2) || (selectedRole == "teacher" && _step == 5);

  Future<bool> _validateCurrentStepInput() async {
    final l10n = AppLocalizations.of(context)!;
    if (selectedRole == "teacher" && _step == 2 && phoneController.text.isEmpty) {
      AppMessenger.showSnackBar(context, title: l10n.required, message: l10n.enterPhone, type: MessengerType.error);
      return false;
    }
    if (selectedRole == "teacher" && _step == 4) {
      _validatePortfolio(portfolioController.text);
      if (_portfolioError != null) return false;

      // ✅ Check if at least one language is selected
      if (_selectedLanguages.isEmpty) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.required,
          message: l10n.pleaseSelectAtLeastOneLanguage,
          type: MessengerType.error,
        );
        return false;
      }
    }
    if (_isFinalStep() && !_acceptedTerms) {
      AppMessenger.showSnackBar(context, title: l10n.termsRequired, message: l10n.acceptTermsToFinish, type: MessengerType.error);
      return false;
    }
    return true;
  }

  Future<void> _finishWizard() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    setState(() => isLoading = true);
    
    final result = await _authService.createGoogleUserWithRole(
      role: selectedRole,
      phone: fullPhoneNumber,
      portfolio: selectedRole == 'teacher' ? portfolioController.text : null,
      acceptedTerms: true,
      spokenLanguages: selectedRole == 'teacher' ? _selectedLanguages : null,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    // null = success, non-null string = error message
    if (result == null) {
      if (selectedRole == "student") {
        // Direct to Student Dashboard
        navigator.pushNamedAndRemoveUntil('/studentDashboard', (route) => false);
      } else {
        // Teachers are pending approval: POP FIRST so UI feels responsive
        navigator.pop(true);
        
        AppMessenger.showSnackBar(
          navigator.context,
          title: l10n.applicationReceived,
          message: l10n.teacherUnderReview,
          type: MessengerType.success,
        );

        // Route to AuthWrapper which will show the TeacherPendingPage
        navigator.pushNamedAndRemoveUntil('/', (route) => false);
      }
    } else {
      AppMessenger.showSnackBar(context, title: l10n.error, message: result, type: MessengerType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !isLoading, // Prevent pop if we are currently cleaning up
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // If already popped by something else
        
        // 👻 Cleanup if system back or swipe exits the wizard
        await _authService.cleanupGhostAccount();
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black54),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: BoxConstraints(
                  maxWidth: 450,
                  maxHeight: MediaQuery.of(context).size.height * 0.85 - MediaQuery.of(context).viewInsets.bottom,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        if (_step == 2 || _step == 5)
                          Align(
                            alignment: AlignmentDirectional.topStart,
                            child: Container(
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                                onPressed: _prevStep,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ),
                          ),
                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: _handleCancel,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      layoutBuilder: (child, list) => Stack(alignment: Alignment.center, children: [...list, if (child != null) child]),
                      child: Container(
                        key: ValueKey<int>(_step),
                        child: !_isStepsInitialized ? const CircularProgressIndicator() : _buildStepContent(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isFinalStep())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _acceptedTerms, 
                                onChanged: (v) => setState(() => _acceptedTerms = v!),
                                activeColor: AppColors.textColor,
                                checkColor: Colors.black,
                                side: const BorderSide(color: Colors.white70, width: 2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  children: [
                                    TextSpan(text: l10n.iAccept),
                                    TextSpan(
                                      text: l10n.termsAndConditions,
                                      style: const TextStyle(
                                        color: AppColors.textColor, 
                                        fontWeight: FontWeight.bold, 
                                        decoration: TextDecoration.underline
                                      ),
                                      recognizer: TapGestureRecognizer()..onTap = () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()));
                                      },
                                    ),
                                    TextSpan(text: l10n.and),
                                    TextSpan(
                                      text: l10n.privacyPolicy,
                                      style: const TextStyle(
                                        color: AppColors.textColor, 
                                        fontWeight: FontWeight.bold, 
                                        decoration: TextDecoration.underline
                                      ),
                                      recognizer: TapGestureRecognizer()..onTap = () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        const Spacer(),
                        if (!(selectedRole == "teacher" && _step == 3))
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isLoading ? null : _nextStep,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Text(
                                    _isFinalStep() ? l10n.finish : l10n.next,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                          ),
                      ],
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
