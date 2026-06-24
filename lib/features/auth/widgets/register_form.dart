import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:device_region/device_region.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../../core/theme/colors.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../../../features/auth/data/services/auth_service.dart';
import 'package:phone_number/phone_number.dart' as lib_phone;
import '../../../core/utils/numeric_utils.dart';
import '../pages/verification_wizard_page.dart';
import '../../../core/message/app_messenger.dart';
import '../pages/terms_and_conditions_page.dart';

class RegisterForm extends StatefulWidget {
  final String? initialLanguage;
  const RegisterForm({super.key, this.initialLanguage});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _authService = AuthService();
  final _phoneUtil = lib_phone.PhoneNumberUtil();
  final TextEditingController nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final phoneController = TextEditingController();
  final portfolioController = TextEditingController();

  String fullPhoneNumber = "";
  String selectedRole = "student";
  bool isLoading = false;
  bool isPasswordObscured = true;
  bool isConfirmPasswordObscured = true;
  String _initialCountryCode = "US";
  bool _acceptedTerms = false;
  final List<String> selectedLanguages = [];
  final List<String> _languagesList = [
    "Arabic",
    "English",
    "Turkish",
    "Other"
  ];

  void _addCustomLanguageDialog() {
    final List<String> availableOthers = [
      "Urdu",
      "Malay",
      "Bengali",
      "Farsi",
      "French",
      "Hausa",
      "Swahili",
      "Somali",
      "Kurdish",
      "Albanian"
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          Localizations.localeOf(context).languageCode == 'ar' ? "اختر لغة أخرى" : "Select Other Language",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableOthers.map((lang) {
              String labelText = lang;
              if (lang == "Bengali") labelText = "বাংলা";
              if (lang == "Urdu") labelText = "اردو";
              if (lang == "Farsi") labelText = "فارسی";
              if (lang == "Kurdish") labelText = "کوردي";

              return InkWell(
                onTap: () {
                  setState(() {
                    final otherIdx = _languagesList.indexOf("Other");
                    if (otherIdx != -1) {
                      if (!_languagesList.contains(lang)) {
                        _languagesList.insert(otherIdx, lang);
                      }
                    } else {
                      if (!_languagesList.contains(lang)) {
                        _languagesList.add(lang);
                      }
                    }
                    if (!selectedLanguages.contains(lang)) {
                      selectedLanguages.add(lang);
                    }
                  });
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentGold.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    labelText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              Localizations.localeOf(context).languageCode == 'ar' ? "إلغاء" : "Cancel",
              style: const TextStyle(color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }


  Timer? _nameDebounce;
  Timer? _emailDebounce;
  Timer? _phoneDebounce;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmError;
  String? _portfolioError;

  bool _isCheckingName = false;
  bool _isCheckingEmail = false;
  bool _isCheckingPhone = false;

  bool _isNameValid = false;
  bool _isEmailValid = false;
  bool _isPhoneValid = false;
  
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _getInitialCountryCode();
    _preFetchFcmToken();
  }

  Future<void> _preFetchFcmToken() async {
    try {
      // Just request permission early so it's ready
      await FirebaseMessaging.instance.requestPermission();
      _fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint("Pre-fetched FCM Token: $_fcmToken");
    } catch (e) {
      debugPrint("Error pre-fetching FCM Token: $e");
    }
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _emailDebounce?.cancel();
    _phoneDebounce?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    phoneController.dispose();
    portfolioController.dispose();
    super.dispose();
  }

  Future<void> _getInitialCountryCode() async {
    try {
      // 1. Try SIM Card (Best)
      String? countryCode = await DeviceRegion.getSIMCountryCode();

      // 2. Fallback: Device System Region (Good for iPads/No SIM)
      if (countryCode == null || countryCode.isEmpty) {
        // PlatformDispatcher is the modern way to get device locale
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        countryCode = locale.countryCode;
      }

      if (!mounted) return;
      
      // 3. Update State if we found something
      if (countryCode != null && countryCode.isNotEmpty) {
        setState(() => _initialCountryCode = countryCode!.toUpperCase());
      }
    } catch (e) {
      debugPrint("Error getting country code: $e");
    }
  }

  Widget _buildValidationIcon(bool isLoading, bool isValid) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textColor),
            )
          : isValid
              ? Container(
                  key: const ValueKey('success'),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.check, color: Colors.black, size: 14),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  void _validateName(String value) {
    final l10n = AppLocalizations.of(context)!;
    if (_nameDebounce?.isActive ?? false) _nameDebounce!.cancel();

    setState(() {
      _nameError = null;
      _isNameValid = false;
      _isCheckingName = true;
    });

    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      setState(() {
        _isCheckingName = false;
        _nameError = l10n.enterFullName;
      });
      return;
    }

    // 1. Length Check (3-50)
    if (trimmedValue.length < 3 || trimmedValue.length > 50) {
      setState(() {
        _isCheckingName = false;
        _nameError = l10n.nameLengthError;
      });
      return;
    }

    // 2. Character Set Check (English, Arabic, Turkish letters and spaces)
    // \p{L} matches any letter from any language
    // \s matches whitespace
    if (!RegExp(r'^(?=.*[\p{L}])[\p{L}\p{N}\s]+$', unicode: true).hasMatch(trimmedValue)) {
      setState(() {
        _isCheckingName = false;
        _nameError = l10n.nameCharError;
      });
      return;
    }

    _nameDebounce = Timer(const Duration(milliseconds: 600), () async {
      final isTaken = await _authService.isNameTaken(trimmedValue);
      if (!mounted) return;

      setState(() {
        _isCheckingName = false;
        if (isTaken) {
          _nameError = l10n.nameTaken;
          _isNameValid = false;
        } else {
          _nameError = null;
          _isNameValid = true;
        }
      });
    });
  }

  void _validateEmail(String value) {
    final l10n = AppLocalizations.of(context)!;
    if (_emailDebounce?.isActive ?? false) _emailDebounce!.cancel();

    setState(() {
      _emailError = null;
      _isEmailValid = false;
      _isCheckingEmail = true;
    });

    if (value.trim().isEmpty) {
      setState(() {
        _isCheckingEmail = false;
        _emailError = l10n.enterEmail;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(value)) {
      setState(() {
        _isCheckingEmail = false;
        _emailError = l10n.invalidEmail;
      });
      return;
    }

    _emailDebounce = Timer(const Duration(milliseconds: 600), () async {
      final isTaken = await _authService.isEmailTaken(value);
      if (!mounted) return;

      setState(() {
        _isCheckingEmail = false;
        if (isTaken) {
          _emailError = l10n.emailRegistered;
          _isEmailValid = false;
        } else {
          _emailError = null;
          _isEmailValid = true;
        }
      });
    });
  }

  void _validatePhone(String phoneString, String isoCode) {
    final l10n = AppLocalizations.of(context)!;
    if (_phoneDebounce?.isActive ?? false) _phoneDebounce!.cancel();

    setState(() {
      fullPhoneNumber = NumericUtils.normalize(phoneString, clean: true);
      _phoneError = null;
      _isPhoneValid = false;
      _isCheckingPhone = true; 
    });

    _phoneDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final isValidFormat = await _phoneUtil.validate(phoneString, regionCode: isoCode);
        if (!mounted) return;

        if (!isValidFormat) {
          setState(() {
            _isCheckingPhone = false;
            _phoneError = l10n.invalidMobileNumber; // ✅ Set error message
            _isPhoneValid = false;
          });
          return;
        }

        final isTaken = await _authService.isPhoneTaken(phoneString);
        if (!mounted) return;

        setState(() {
          _isCheckingPhone = false;
          if (isTaken) {
            _phoneError = l10n.phoneUsed;
            _isPhoneValid = false;
          } else {
            _phoneError = null;
            _isPhoneValid = true;
          }
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingPhone = false;
            _isPhoneValid = false;
          });
        }
      }
    });
  }

  void _validatePassword(String value) {
    final l10n = AppLocalizations.of(context)!;
    if (value.isEmpty) {
      setState(() => _passwordError = l10n.enterPassword);
    } else if (value.length < 6) {
      setState(() => _passwordError = l10n.passwordLength);
    } else if (!RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,}$').hasMatch(value)) {
      setState(() => _passwordError = l10n.passwordComplexity);
    } else {
      setState(() => _passwordError = null);
    }
    if (confirmController.text.isNotEmpty) {
      _validateConfirmPassword(confirmController.text);
    }
  }

  void _validateConfirmPassword(String value) {
    final l10n = AppLocalizations.of(context)!;
    if (value != passwordController.text) {
      setState(() => _confirmError = l10n.passwordsMatch);
    } else {
      setState(() => _confirmError = null);
    }
  }

  Future<void> _pastePortfolio() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      portfolioController.text = data!.text!;
      _validatePortfolio(data.text!);
    }
  }

  void _validatePortfolio(String value) {
    final l10n = AppLocalizations.of(context)!;
    if (value.isEmpty) {
      setState(() => _portfolioError = l10n.enterPortfolio);
      return;
    }
    
    // Improved regex for URL validation:
    // Requires protocol (http/https), a domain with at least one dot, and a TLD.
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

  Future<void> _handleRegister() async {
    final l10n = AppLocalizations.of(context)!;
    bool hasEmptyFields = false;

    if (nameController.text.trim().isEmpty) {
      setState(() => _nameError = l10n.enterFullName);
      hasEmptyFields = true;
    }
    if (emailController.text.trim().isEmpty) {
      setState(() => _emailError = l10n.enterEmail);
      hasEmptyFields = true;
    }

    _validatePassword(passwordController.text);
    _validateConfirmPassword(confirmController.text);

    if (selectedRole == "teacher") {
      if (fullPhoneNumber.isEmpty) {
        setState(() => _phoneError = l10n.phoneRequired);
        hasEmptyFields = true;
      }
      _validatePortfolio(portfolioController.text);

      // ✅ Validation for Spoken Languages
      if (selectedLanguages.isEmpty) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.required,
          message: l10n.pleaseSelectAtLeastOneLanguage,
          type: MessengerType.error,
        );
        return;
      }
    }

    if (hasEmptyFields || _nameError != null || _emailError != null || _passwordError != null || _confirmError != null || (selectedRole == "teacher" && (_phoneError != null || _portfolioError != null))) {
      AppMessenger.showSnackBar(context, title: l10n.invalidInput, message: l10n.fixErrors, type: MessengerType.error);
      return;
    }

    if (!_acceptedTerms) {
      AppMessenger.showSnackBar(context, title: l10n.termsRequired, message: l10n.mustAcceptTerms, type: MessengerType.error);
      return;
    }

    if (_isCheckingName || _isCheckingEmail || (selectedRole == "teacher" && _isCheckingPhone)) {
      AppMessenger.showSnackBar(context, title: l10n.pleaseWait, message: l10n.verifyingInfo, type: MessengerType.info);
      return;
    }

    if (!_isNameValid || !_isEmailValid || (selectedRole == "teacher" && !_isPhoneValid)) {
      AppMessenger.showSnackBar(context, title: l10n.verificationIncomplete, message: l10n.waitCheckmarks, type: MessengerType.error);
      return;
    }

    final email = emailController.text.trim().toLowerCase();

    setState(() => isLoading = true);
    final preCheckError = await _authService.preRegistrationCheck(
      name: nameController.text.trim(),
      email: email,
      phone: fullPhoneNumber,
      role: selectedRole,
    );

    if (!mounted) return;
    if (preCheckError != null) {
      AppMessenger.showSnackBar(context, title: l10n.error, message: preCheckError, type: MessengerType.error);
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = false);

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VerificationWizardPage(
        role: selectedRole,
        email: email,
        password: passwordController.text.trim(),
        phone: fullPhoneNumber,
        name: nameController.text.trim(),
        portfolio: portfolioController.text.trim(),
        acceptedTerms: _acceptedTerms,
        language: widget.initialLanguage,
        fcmToken: _fcmToken,
        spokenLanguages: selectedLanguages,
      ),
    );

    if (!mounted) return;
    if (result != null) {
      if (result == "student") {
        AppMessenger.showSnackBar(context, title: l10n.welcome, message: l10n.registrationSuccessful, type: MessengerType.success);
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else if (result == "teacher" || result == "SUCCESS_CLOSE_TEACHER") {
        AppMessenger.showSnackBar(
          context,
          title: l10n.applicationReceived,
          message: l10n.teacherUnderReview,
          type: MessengerType.success,
        );
        
        // Route to AuthWrapper which will show the TeacherPendingPage
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
          Row(
            children: ["student", "teacher"].map((role) {
              final selected = selectedRole == role;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedRole = role),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.textColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        role == "student" ? l10n.student : l10n.teacher,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.black : AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: nameController,
            hint: l10n.fullName,
            icon: Icons.person,
            onChanged: _validateName,
            errorText: _nameError,
            isLoading: _isCheckingName,
            isSuccess: _isNameValid,
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: emailController,
            hint: l10n.email,
            icon: Icons.email,
            onChanged: _validateEmail,
            errorText: _emailError,
            isLoading: _isCheckingEmail,
            isSuccess: _isEmailValid,
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: passwordController,
            hint: l10n.password,
            icon: Icons.lock,
            obscure: true,
            showToggle: true,
            isObscured: isPasswordObscured,
            onToggle: () => setState(() => isPasswordObscured = !isPasswordObscured),
            onChanged: _validatePassword,
            errorText: _passwordError,
            isSuccess: _passwordError == null && passwordController.text.isNotEmpty,
            isLoading: false,
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: confirmController,
            hint: l10n.confirmPassword,
            icon: Icons.lock_outline,
            obscure: true,
            showToggle: true,
            isObscured: isConfirmPasswordObscured,
            onToggle: () => setState(() => isConfirmPasswordObscured = !isConfirmPasswordObscured),
            onChanged: _validateConfirmPassword,
            errorText: _confirmError,
            isSuccess: _confirmError == null && confirmController.text.isNotEmpty,
            isLoading: false,
          ),
          if (selectedRole == "teacher") ...[
            const SizedBox(height: 20),
            Stack(
              alignment: AlignmentDirectional.centerEnd,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntlPhoneField(
                      controller: phoneController,
                      autovalidateMode: AutovalidateMode.disabled, // ✅ Disable built-in validation to avoid double error messages
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      dropdownTextStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                      textAlign: TextAlign.start,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.07),
                        hintText: l10n.phoneNumber,
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                        prefixIcon: const Icon(Icons.phone, color: AppColors.textColor),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: _phoneError != null ? Colors.redAccent : Colors.transparent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _phoneError != null ? Colors.redAccent : AppColors.textColor,
                            width: 2,
                          ),
                        ),
                      ),
                      initialCountryCode: _initialCountryCode,
                      inputFormatters: [NumericUtils.digitFormatter],
                      onChanged: (phone) {
                        try {
                          _validatePhone(
                            phone.completeNumber,
                            phone.countryISOCode,
                          );
                        } catch (e) {
                          debugPrint("Phone validation error: $e");
                        }
                      },
                    ),
                    if (_phoneError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6, bottom: 5),
                        child: Text(
                          _phoneError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (_phoneError == null) const SizedBox(height: 15),
                  ],
                ),
                PositionedDirectional(
                  end: 16,
                  top: 20, // Centered vertically in the field (approx 18-20 for 56h field)
                  child: _buildValidationIcon(_isCheckingPhone, _isPhoneValid),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AuthTextField(
              controller: portfolioController,
              hint: l10n.portfolioHint,
              icon: Icons.link,
              onChanged: _validatePortfolio,
              errorText: _portfolioError,
              isSuccess: _portfolioError == null && portfolioController.text.isNotEmpty,
              isLoading: false,
              onPaste: _pastePortfolio,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.localeName == 'ar' ? 'اللغات المنطوقة' : 'Spoken Languages',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languagesList.map((lang) {
                final isSel = selectedLanguages.contains(lang);
                String labelText = lang;
                if (lang == "Arabic") labelText = "العربية";
                if (lang == "Turkish") labelText = "Türkçe";
                if (lang == "Bengali") labelText = "বাংলা";
                if (lang == "Urdu") labelText = "اردو";
                if (lang == "Farsi") labelText = "فارسی";
                if (lang == "Kurdish") labelText = "کوردی";
                if (lang == "Other") {
                  labelText = Localizations.localeOf(context).languageCode == 'ar' ? "+ أخرى" : "+ Other";
                }

                return InkWell(
                  onTap: () {
                    if (lang == "Other") {
                      _addCustomLanguageDialog();
                    } else {
                      setState(() {
                        if (isSel) {
                          selectedLanguages.remove(lang);
                        } else {
                          if (!selectedLanguages.contains(lang)) selectedLanguages.add(lang);
                        }
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isSel && lang != "Other") ? AppColors.accentGold : AppColors.accentGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isSel && lang != "Other") ? AppColors.accentGold : AppColors.accentGold.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      labelText,
                      style: TextStyle(
                        color: (isSel && lang != "Other") ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _acceptedTerms,
                    activeColor: AppColors.textColor,
                    checkColor: Colors.black,
                    side: const BorderSide(color: Colors.white70, width: 2),
                    onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      children: [
                        TextSpan(text: l10n.iAccept),
                        TextSpan(
                          text: l10n.termsAndConditions,
                          style: const TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()));
                          },
                        ),
                        TextSpan(text: l10n.and),
                        TextSpan(
                          text: l10n.privacyPolicy,
                          style: const TextStyle(color: AppColors.textColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
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
          const SizedBox(height: 20),
          isLoading
              ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.textColor))
              : AuthButton(text: l10n.register, onPressed: _handleRegister),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.secondary, fontSize: 14),
                children: [
                  TextSpan(text: "${l10n.alreadyHaveAccount} "),
                  TextSpan(text: l10n.login, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
    );
  }
}
