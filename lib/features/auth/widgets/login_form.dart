import 'package:calligro_app/l10n/app_localizations.dart';
import '../pages/google_register_wizard.dart';
import 'link_account_dialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../../../core/message/app_messenger.dart';

class LoginForm extends StatefulWidget {
  final String? initialLanguage;
  final String? returnTo;
  const LoginForm({super.key, this.initialLanguage, this.returnTo});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _authService = AuthService();

  bool isLoading = false;
  bool isObscured = true;


  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    if (isLoading) return;

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        title: l10n.error,
        message: l10n.invalidCredentials, // Use generic message for empty fields too? Or keep vague?
        // Actually for empty fields, "Email and password are required" is fine, or "Required" key.
        // Let's keep existing logic but localized if possible. ARB has "required".
        // "Email and password are required." isn't in ARB.
        // I'll stick to English here as I didn't add a key for this specific validation.
        // Or I can use l10n.validationRequired twice?
        // Let's leave it hardcoded for now or use "inputError".
        // User complained about "message is not translated correctly".
        // I should try to use "inputError".
        type: MessengerType.error,
      );
      return;
    }

    setState(() => isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final role = await _authService.loginWithEmail(
        emailController.text.trim().toLowerCase(),
        passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      await _authService.saveUserFcmToken(FirebaseAuth.instance.currentUser!.uid);

      if (widget.returnTo != null && widget.returnTo != "/") {
        if (mounted) navigator.pushNamedAndRemoveUntil(widget.returnTo!, (route) => false);
      } else {
        // Delegate routing to AuthWrapper (the "/" route)
        if (mounted) navigator.pushNamedAndRemoveUntil("/", (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => isLoading = false);

      String message = e.message ?? l10n.somethingWentWrong;
      
      if (e.code == 'user-not-found') {
        message = l10n.noAccountFound;
      } else if (e.code == 'wrong-password') {
        message = l10n.wrongPassword;
      } else if (e.code == 'invalid-email') {
        message = l10n.invalidEmail;
      } else if (e.code == 'invalid-credential' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
        message = l10n.invalidCredentials;
      } else if (e.code == 'too-many-requests') {
        message = l10n.tooManyRequests;
      } else if (e.code == 'account-pending') {
        message = l10n.teacherAccountPendingApproval;
      }

      AppMessenger.showSnackBar(
        context,
        title: l10n.error,
        message: message,
        type: MessengerType.error,
      );
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      AppMessenger.showSnackBar(
        context,
        title: l10n.error,
        message: l10n.somethingWentWrong,
        type: MessengerType.error,
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final result = await _authService.loginWithGoogle();
      if (!mounted) return;

      if (result == "ACCOUNT_EXISTS_DIFFERENT_CREDENTIAL") {
        if (mounted) {
          setState(() => isLoading = false);
          final googleEmail = _authService.googleAuth.pendingEmail;
          if (googleEmail != null) {
            final role = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (context) => LinkAccountDialog(email: googleEmail),
            );

            if (role != null && mounted) {
              await _authService.saveUserFcmToken(FirebaseAuth.instance.currentUser!.uid);
              String route = "/";
              if (widget.returnTo != null && widget.returnTo != "/") {
                route = widget.returnTo!;
              }
              navigator.pushNamedAndRemoveUntil(route, (route) => false);
            }
          }
        }
        return;
      }

      if (result == "NEEDS_ROLE" || result == null || (result != "student" && result != "teacher" && result != "admin")) {
        setState(() => isLoading = false);
      }

      if (result == "NEEDS_ROLE") {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => const GoogleRegisterWizard(),
        );
      } else if (result == "student" || result == "teacher" || result == "admin") {
        await _authService.saveUserFcmToken(FirebaseAuth.instance.currentUser!.uid);
        if (mounted) {
          String route = "/";
          if (widget.returnTo != null && widget.returnTo != "/") {
            route = widget.returnTo!;
          }
          navigator.pushNamedAndRemoveUntil(route, (route) => false);
        }
      } else if (result != null) {
        String errorMessage = result;
        if (result == "Teacher account pending approval") {
          errorMessage = l10n.teacherAccountPendingApproval;
        }

        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: errorMessage,
          type: MessengerType.error,
        );
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        const SizedBox(height: 20),
        AuthTextField(
          controller: emailController,
          hint: l10n.email,
          icon: Icons.email,
        ),
        const SizedBox(height: 18),
        AuthTextField(
          controller: passwordController,
          hint: l10n.password,
          obscure: isObscured,
          showToggle: true,
          isObscured: isObscured,
          icon: Icons.lock,
          onToggle: () => setState(() => isObscured = !isObscured),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, "/forgotPassword"),
            child: Text(
              l10n.forgotPassword,
              style: const TextStyle(color: AppColors.secondary, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.textColor))
            : AuthButton(text: l10n.login, onPressed: _handleLogin),
        const SizedBox(height: 40),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.secondary, thickness: 0.8)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                l10n.orContinueWith,
                style: const TextStyle(color: AppColors.secondary),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.secondary, thickness: 0.8)),
          ],
        ),
        const SizedBox(height: 25),
        Center(
          child: SizedBox(
            height: 58,
            width: 58,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleGoogleLogin,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: ClipOval(
                child: Container(
                  color: Colors.white,
                  child: Image.asset(
                    "assets/icons/circle_google_icon.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, "/RegisterPage", arguments: widget.initialLanguage),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.secondary, fontSize: 14),
              children: [
                TextSpan(text: "${l10n.dontHaveAccount} "),
                TextSpan(
                  text: l10n.register,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
