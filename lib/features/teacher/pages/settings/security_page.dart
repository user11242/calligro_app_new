import 'package:calligro_app/core/theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../core/message/app_messenger.dart';
import '../../../auth/data/services/auth_service.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  // --- 1. IN-APP CHANGE PASSWORD (NEW) ---
  void _showChangePasswordDialog() {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.changePassword,
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  // Old Password
                  TextFormField(
                    controller: oldPassController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.currentPassword,
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                    validator: (val) =>
                        val!.isEmpty ? AppLocalizations.of(context)!.enterCurrentPassword : null,
                  ),
                  const SizedBox(height: 10),

                  // New Password
                  TextFormField(
                    controller: newPassController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.newPassword,
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return AppLocalizations.of(context)!.min6Characters;
                      }
                      if (val.length < 6) {
                        return AppLocalizations.of(context)!.min6Characters;
                      }
                      // Apply same English-only & Complexity regex as RegisterForm
                      final regex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,}$');
                      if (!regex.hasMatch(val)) {
                        return AppLocalizations.of(context)!.passwordComplexity;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Confirm Password
                  TextFormField(
                    controller: confirmPassController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.confirmNewPassword,
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                    validator: (val) {
                      if (val != newPassController.text) {
                        return AppLocalizations.of(context)!.passwordsMatch;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
          actions: [
            TextButton(
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: const TextStyle(color: Colors.white54),
                ),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
              ),
                child: Text(
                  AppLocalizations.of(context)!.update,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Close dialog first
                  Navigator.pop(ctx);
                  // Run update logic
                  await _updatePassword(
                    oldPassController.text,
                    newPassController.text,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- LOGIC TO RE-AUTHENTICATE & UPDATE ---
  Future<void> _updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final cred = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );

      // 1. Re-authenticate user (Security Check)
      await user!.reauthenticateWithCredential(cred);

      // 2. Update Password
      await user!.updatePassword(newPassword);

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.success,
          message: l10n.passwordUpdatedSuccessfully,
          type: MessengerType.success,
        );
      }
    } on FirebaseAuthException catch (e) {
      String error = l10n.error;
      if (e.code == 'wrong-password') error = l10n.currentPasswordIncorrect;
      if (e.code == 'weak-password') error = l10n.newPasswordWeak;

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: error,
          type: MessengerType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: "${l10n.error}: $e",
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. RE-AUTHENTICATE & DELETE ACCOUNT ---
  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          AppLocalizations.of(context)!.deleteAccountQuestion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(context)!.deleteAccountWarning,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(
              AppLocalizations.of(context)!.deleteCaps,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    // Check if user has a password provider
    bool hasPassword = user?.providerData.any((info) => info.providerId == 'password') ?? false;

    if (hasPassword) {
      // Prompt for password
      final TextEditingController passController = TextEditingController();
      bool passwordConfirmed = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            AppLocalizations.of(context)!.security,
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.enterCurrentPassword,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.password,
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: const TextStyle(color: Colors.white54),
              ),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(
                AppLocalizations.of(context)!.deleteCaps,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                if (passController.text.isEmpty) return;
                Navigator.pop(ctx, true);
                await _processDeletion(password: passController.text);
              },
            ),
          ],
        ),
      ) ?? false;

      if (!passwordConfirmed) return;

    } else {
      // It's a Google-only account. We need them to re-authenticate with Google.
      // But for UX simplicity, let's just try the deletion. If it fails due to 
      // recent-login-required, we catch it. 
      // (Ideally, we trigger Google Sign In again here, but let's try direct first)
      await _processDeletion();
    }
  }

  Future<void> _processDeletion({String? password}) async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    
    try {
      // 1. Re-authenticate if password provided
      if (password != null && user?.email != null) {
        final cred = EmailAuthProvider.credential(email: user!.email!, password: password);
        await user!.reauthenticateWithCredential(cred);
      }

      // 2. Call AuthService to handle the database cleanup & Account deletion
      // We need to import AuthService at the top of the file
      // Actually, since this is a UI file, let's just call it directly.
      await AuthService().deleteAccount();

      // 3. Navigate away
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/onBoarding', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = l10n.error;
      if (e.code == 'wrong-password') {
        errorMsg = l10n.currentPasswordIncorrect;
      } else if (e.code == 'requires-recent-login') {
        errorMsg = l10n.reloginToDelete;
      }
      
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.security,
          message: errorMsg,
          type: MessengerType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: "${l10n.error}: $e",
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check provider (Hide change pass for Google users)
    bool hasPassword =
        user?.providerData.any(
          (userInfo) => userInfo.providerId == 'password',
        ) ??
        false;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.security,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ONLY SHOW FOR EMAIL USERS
                  if (hasPassword) ...[
                    Text(
                      AppLocalizations.of(context)!.loginSecurityCaps,
                      style: const TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSecurityOption(
                      icon: Icons.lock_outline,
                      title: AppLocalizations.of(context)!.changePassword,
                      subtitle: AppLocalizations.of(context)!.updateCurrentPasswordSubtitle,
                      onTap:
                          _showChangePasswordDialog, // <--- Calls the new Dialog
                  ),
                    const SizedBox(height: 40),
                  ],

                  // DELETE ACCOUNT
                  Text(
                    AppLocalizations.of(context)!.dangerZoneCaps,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.deleteAccount,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        AppLocalizations.of(context)!.deleteAccountSubtitle,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      onTap: _deleteAccount,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.3),
          size: 14,
        ),
        onTap: onTap,
      ),
    );
  }
}
