import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/features/auth/widgets/login_form.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dynamic args = ModalRoute.of(context)?.settings.arguments;
    final String? language = args is String ? args : (args is Map ? args['language'] as String? : null);
    final String? returnTo = args is Map ? args['returnTo'] as String? : null;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // ... (rest of the proportions stay the same)
    const double imageRatio = 0.35;
    final headerStopPosition = screenHeight * imageRatio;
    const double borderRadiusValue = 30.0;
    const double formTopContentPadding = borderRadiusValue + 20.0;
    const double formBottomContentPadding = 20.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/backgrounds/main_background.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: AppColors.black.withAlpha(128)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerStopPosition,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 20.0,
                right: 20.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: AppColors.titleGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      l10n.loginTitle,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.secondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. 🔹 Top Left Back Button (Now RTL Aware)
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 10,
            start: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 4. 🔹 Form Container Layer (Bottom of Screen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: headerStopPosition - borderRadiusValue,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(borderRadiusValue),
                ),
              ),
              // SingleChildScrollView handles the content scrolling when the keyboard is up.
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20.0, // Left
                    formTopContentPadding, // Top compensation + internal spacing
                    20.0, // Right
                    formBottomContentPadding +
                        bottomPadding, // Bottom spacing + safe area
                  ),
                  child: LoginForm(
                    initialLanguage: language,
                    returnTo: returnTo,
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
