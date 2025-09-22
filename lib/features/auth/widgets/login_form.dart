import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../pages/google_register_wizard.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _authService = AuthService();
  bool isLoading = false;
  bool isObscured = true; // Added to control password visibility

  // Function to show custom SnackBar with success or error
  void _showMessage(String message, {bool success = false}) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: success ? Colors.white : Colors.white),
      ),
      backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600, // Success/Failure color
      duration: const Duration(seconds: 3),  // Duration for automatic dismissal
      behavior: SnackBarBehavior.floating,  // Floating style
      margin: const EdgeInsets.all(16.0),  // Margin from the edges
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),  // Rounded corners for a modern look
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showMessage("Email and password are required");
      return;
    }

    setState(() => isLoading = true);
    final result = await _authService.loginWithEmail(
      emailController.text.trim(),
      passwordController.text.trim(),
    );
    setState(() => isLoading = false);

    if (result == "admin") {
      await _authService.saveAdminFcmToken(FirebaseAuth.instance.currentUser!.uid);
      _showMessage("Login successful! Welcome Boss!", success: true);
      Navigator.pushReplacementNamed(context, "/adminDashboard");
    } else if (result == "teacher") {
      _showMessage("Login successful! Welcome back.", success: true);
      Navigator.pushReplacementNamed(context, "/teacherDashboard");
    } else if (result == "student") {
      _showMessage("Login successful! Welcome back.", success: true);
      Navigator.pushReplacementNamed(context, "/");
    } else {
      _showMessage(result ?? "Login failed");
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => isLoading = true);
    final result = await _authService.loginWithGoogle();
    setState(() => isLoading = false);

    if (result == "NEEDS_ROLE") {
      final chosenRole = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const GoogleRegisterWizard(),
      );
      if (chosenRole == null) return;

      final createErr = await _authService.createGoogleUserWithRole(chosenRole);
      if (createErr == null) {
        if (chosenRole == "teacher") {
          _showMessage("Teacher registration submitted. Wait for approval.", success: true);
          await _authService.signOut();
        } else {
          _showMessage("Student registered successfully. Please login.", success: true);
          Navigator.pushReplacementNamed(context, "/");
        }
      } else {
        _showMessage(createErr);
      }
    } else if (result == "admin") {
      await _authService.saveAdminFcmToken(FirebaseAuth.instance.currentUser!.uid);
      _showMessage("Login successful! Welcome Boss!", success: true);
      Navigator.pushReplacementNamed(context, "/adminDashboard");
    } else if (result == "teacher") {
      _showMessage("Login successful! Welcome back.", success: true);
      Navigator.pushReplacementNamed(context, "/teacherDashboard");
    } else if (result == "student") {
      _showMessage("Login successful! Welcome back.", success: true);
      Navigator.pushReplacementNamed(context, "/");
    } else {
      _showMessage(result ?? "Google sign-in failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        AuthTextField(controller: emailController, hint: "Email", icon: Icons.email),
        const SizedBox(height: 18),
        // Updated password field with toggle for visibility
        AuthTextField(
          controller: passwordController,
          hint: "Password",
          obscure: isObscured,
          showToggle: true, // Enable toggle button
          isObscured: isObscured,
          icon: Icons.lock,
          onToggle: () {
            setState(() {
              isObscured = !isObscured; // Toggle the password visibility
            });
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, "/forgotPassword"),
            child: const Text("Forgot Password?", style: TextStyle(color: AppColors.secondary, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 20),
        isLoading
            ? const CircularProgressIndicator()
            : AuthButton(text: "Login", onPressed: _handleLogin),
        const SizedBox(height: 40),

        // Divider
        Row(
          children: const [
            Expanded(child: Divider(color: AppColors.secondary, thickness: 0.8)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text("Or continue with",
                  style: TextStyle(color: AppColors.secondary)),
            ),
            Expanded(child: Divider(color: AppColors.secondary, thickness: 0.8)),
          ],
        ),
        const SizedBox(height: 25),

        // Google Button (circle)
        Center(
          child: SizedBox(
            height: 58,
            width: 58,
            child: ElevatedButton(
              onPressed: _handleGoogleLogin,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: ClipOval(
                child: Image.asset("assets/icons/circle_google_icon.png", fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, "/RegisterPage"),
          child: const Text("Don't have an account? Register",style: TextStyle(color: AppColors.secondary,fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
