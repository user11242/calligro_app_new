import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../widgets/register_form.dart';
import '../widgets/google_hint_dialog.dart';
import 'google_register_wizard.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../../../core/message/app_messenger.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => GoogleHintDialog(onContinue: _handleGoogleRegister),
      );
    });
  }

  Future<void> _handleGoogleRegister() async {
    final l10n = AppLocalizations.of(context)!;
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    final result = await _authService.loginWithGoogle();
    if (!mounted) return;

    if (result == "NEEDS_ROLE") {
      final wizardResult = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const GoogleRegisterWizard(),
      );
      
      // If wizard completed successfully (Teacher finished), close RegisterPage too
      if (wizardResult == true && mounted) {
        Navigator.pop(context);
      }
    } else if (result != null && !result.toLowerCase().contains("error")) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else if (result != null) {
      // Standard snackbar for errors (e.g., Firebase error)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const double imageRatio = 0.35;
    final headerStopPosition = screenHeight * imageRatio;
    const double borderRadiusValue = 30.0;
    const double formTopContentPadding = borderRadiusValue + 20.0;
    const double formBottomContentPadding = 20.0;

    return Stack(
      children: [
        // 🔹 Fixed Background Image
        Positioned.fill(
          child: Image.asset(
            "assets/backgrounds/main_background.jpg",
            fit: BoxFit.cover,
          ),
        ),
        // 🔹 Fixed Overlay
        Positioned.fill(
          child: Container(color: AppColors.black.withAlpha(128)),
        ),
        // 🔹 UI Layer with Keyboard Support
        Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              // 1. 🔹 Header Section
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
                          l10n.registerTitle,
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
                        l10n.registerSubtitle,
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

              // 2. 🔹 Back Button
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

              // 3. 🔹 Form Container (This will shrink when keyboard pops up)
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
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20.0,
                        formTopContentPadding,
                        20.0,
                        formBottomContentPadding + bottomPadding,
                      ),
                      child: RegisterForm(initialLanguage: ModalRoute.of(context)?.settings.arguments as String?),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
