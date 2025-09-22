import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../widgets/register_form.dart';
import '../widgets/google_hint_dialog.dart';
import 'google_register_wizard.dart';
import '../../../features/auth/data/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🔹 Show Google Hint Dialog automatically when page loads
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => GoogleHintDialog(
          onContinue: _handleGoogleRegister,
        ),
      );
    });
  }

  /// 🔹 Handle Google register logic safely
  Future<void> _handleGoogleRegister() async {
    if (mounted) Navigator.pop(context); // close GoogleHintDialog if still open

    final result = await _authService.loginWithGoogle();

    if (!mounted) return; // ✅ prevent using dead context

    if (result == "NEEDS_ROLE") {
      // 🔹 Show Google Register Wizard
      final chosenRole = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const GoogleRegisterWizard(),
      );

      if (!mounted || chosenRole == null) return;

      if (chosenRole == "student") {
        Navigator.pushReplacementNamed(context, "/");
      } else if (chosenRole == "teacher") {
        Navigator.pushReplacementNamed(context, "/teacherDashboard");
      } else if (chosenRole == "admin") {
        Navigator.pushReplacementNamed(context, "/adminDashboard");
      }
    } else if (result == "student") {
      Navigator.pushReplacementNamed(context, "/");
    } else if (result == "teacher") {
      Navigator.pushReplacementNamed(context, "/teacherDashboard");
    } else if (result == "admin") {
      Navigator.pushReplacementNamed(context, "/adminDashboard");
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ?? "Google sign-in failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 🔹 Background
          Positioned.fill(
            child: Image.asset(
              "assets/backgrounds/main_background.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFEEE593), Color(0xFF8B4513)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Join us today and start your journey\nas a Student or Teacher.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.secondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Form Box (normal email registration)
                Expanded(
                  child: Container(
                    height: height * 0.7,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: const RegisterForm(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
