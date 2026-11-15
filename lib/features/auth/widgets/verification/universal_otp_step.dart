import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../application/email_codes.dart';
import '../../domain/email_code.dart';
import '../../presentation/auth_scope.dart';
import '../../../../core/message/app_messenger.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/numeric_utils.dart';

class UniversalOtpStep extends StatefulWidget {
  final String destination;
  final VoidCallback onVerified;

  /// Email codes only: registration uses the code up; password reset keeps it
  /// for the final step ([UniversalOtpStepState.verifiedCode]).
  final EmailCodePurpose emailPurpose;

  const UniversalOtpStep({
    super.key,
    required this.destination,
    required this.onVerified,
    this.emailPurpose = EmailCodePurpose.register,
  });

  @override
  UniversalOtpStepState createState() => UniversalOtpStepState();
}

class UniversalOtpStepState extends State<UniversalOtpStep> {
  final AuthService _authService = AuthService();
  late TextEditingController otpController;

  String? _verificationId;
  int? _resendToken;
  /// The email code the server accepted (password reset sends it again with the new password).
  String? verifiedCode;
  int _resendCooldown = 0;
  Timer? _timer;
  bool isLoading = false;

  bool get _isEmail => widget.destination.contains('@');

  @override
  void initState() {
    super.initState();
    otpController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtp();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    if (_timer?.isActive ?? false) return;
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.destination.isEmpty || isLoading) return;
    setState(() => isLoading = true);
    try {
      if (_isEmail) {
        // The SERVER creates, emails and checks the code (functions/email_codes.js).
        final outcome = await AuthScope.of(context).emailCodes.send(widget.destination);
        if (!mounted) return;
        switch (outcome) {
          case SendCodeOutcome.sent:
            _startCooldown();
            AppMessenger.showSnackBar(context, title: l10n.otpSent, message: l10n.checkInbox, type: MessengerType.success);
          case SendCodeOutcome.cooldown:
            _startCooldown();
            AppMessenger.showSnackBar(context, title: l10n.error, message: l10n.tooManyRequests, type: MessengerType.error);
          case SendCodeOutcome.failed:
            AppMessenger.showSnackBar(context, title: l10n.error, message: l10n.verificationFailed, type: MessengerType.error);
        }
      } else {
        await _authService.startPhoneVerification(
          phone: widget.destination,
          codeSent: (id, token) {
            if (mounted) {
              setState(() {
                _verificationId = id;
                _resendToken = token;
                isLoading = false;
              });
              _startCooldown();
              AppMessenger.showSnackBar(context, title: l10n.smsSent, message: l10n.checkMessages, type: MessengerType.success);
            }
          },
          forceResendingToken: _resendToken,
          onError: (err) {
            AppMessenger.showSnackBar(context, title: l10n.smsError, message: err, type: MessengerType.error);
            if (mounted) setState(() => isLoading = false);
          },
        );
      }
    } catch (e) {
      AppMessenger.showSnackBar(context, title: l10n.error, message: e.toString(), type: MessengerType.error);
    } finally {
      if (_isEmail && mounted) setState(() => isLoading = false);
    }
  }

   Future<bool> verifyAndSubmit() async {
    if (isLoading) return false;
    final l10n = AppLocalizations.of(context)!;
    final rawCode = otpController.text.trim();
    final smsCode = NumericUtils.normalize(rawCode);
    

    if (smsCode.length != 6) {
      AppMessenger.showSnackBar(context, title: l10n.inputError, message: l10n.enter6Digits, type: MessengerType.error);
      return false;
    }

    setState(() => isLoading = true);
    try {
      bool success = false;
      if (_isEmail) {
        final check = await AuthScope.of(context).emailCodes.verify(widget.destination, smsCode, purpose: widget.emailPurpose);
        success = check == EmailCodeCheck.ok;
        if (success) verifiedCode = smsCode;
        if (check == EmailCodeCheck.locked && mounted) {
          // Five wrong tries: this code no longer works; a new one is needed.
          AppMessenger.showSnackBar(context, title: l10n.incorrectCode, message: l10n.tooManyRequests, type: MessengerType.error);
          return false;
        }
      } else {
        if (_verificationId == null) {
          AppMessenger.showSnackBar(context, title: l10n.error, message: l10n.idMissing, type: MessengerType.error);
          return false;
        }
        final cred = await _authService.verifySmsCode(verificationId: _verificationId!, smsCode: smsCode);
        success = (cred != null);
      }

      if (success) {
        widget.onVerified();
        return true;
      } else {
        AppMessenger.showSnackBar(context, title: l10n.incorrectCode, message: l10n.pleaseTryAgain, type: MessengerType.error);
        return false;
      }
    } catch (e) {
      AppMessenger.showSnackBar(context, title: l10n.error, message: l10n.verificationFailed, type: MessengerType.error);
      return false;
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.enterCodeSentTo(NumericUtils.normalize(widget.destination)),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 30),
        Directionality(
          textDirection: TextDirection.ltr,
          child: PinCodeTextField(
            appContext: context,
            length: 6,
            controller: otpController,
            keyboardType: TextInputType.number,
            autoDisposeControllers: false,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(10),
              fieldHeight: 50,
              fieldWidth: 40,
              activeFillColor: AppColors.accentGold.withOpacity(0.1),
              inactiveFillColor: Colors.white.withOpacity(0.05),
              selectedFillColor: AppColors.accentGold.withOpacity(0.2),
              activeColor: AppColors.accentGold,
              selectedColor: AppColors.accentGold,
              inactiveColor: Colors.white.withOpacity(0.3),
            ),
            textStyle: const TextStyle(color: Colors.white),
            inputFormatters: [NumericUtils.digitFormatter],
            onChanged: (v) {
              if (v.length == 6) verifyAndSubmit();
            },
          ),
        ),
        TextButton(
          onPressed: (isLoading || _resendCooldown > 0) ? null : _sendOtp,
          child: Text(
            _resendCooldown > 0 ? l10n.resendIn(_resendCooldown) : l10n.resendCode,
            style: TextStyle(color: _resendCooldown > 0 ? Colors.grey : AppColors.secondary),
          ),
        ),
      ],
    );
  }
}
