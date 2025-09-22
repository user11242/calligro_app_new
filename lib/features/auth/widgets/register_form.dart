import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:device_region/device_region.dart'; // 🔹 Import the device_region package
import '../../../core/theme/colors.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../../../features/auth/data/services/auth_service.dart';
import '../pages/verification_wizard_page.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _authService = AuthService();
  final nameController = TextEditingController();
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
  String _initialCountryCode = "US"; // 🔹 Default value, will be updated

  @override
  void initState() {
    super.initState();
    _getInitialCountryCode(); // 🔹 Call the method to fetch country code
  }

  // 🔹 Asynchronous method to get the SIM's country code
  Future<void> _getInitialCountryCode() async {
    try {
      final String? countryCode = await DeviceRegion.getSIMCountryCode();
      if (countryCode != null) {
        setState(() {
          _initialCountryCode = countryCode.toUpperCase();
        });
      }
    } catch (e) {
      debugPrint("Error getting country code: $e");
    }
  }

  void _showMessage(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  bool _validateFields() {
    bool isValid = true;

    if (nameController.text.isEmpty) {
      _showMessage("Please enter your full name");
      isValid = false;
    }

    if (emailController.text.isEmpty || !RegExp(r'^[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(emailController.text)) {
      _showMessage("Please enter a valid email address");
      isValid = false;
    }

    String password = passwordController.text.trim();
    if (password.isEmpty) {
      _showMessage("Please enter a password");
      isValid = false;
    } else if (password.length < 6) {
      _showMessage("Password must be at least 6 characters long");
      isValid = false;
    } else if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[A-Z])[A-Za-z\d@$!%*?&]{6,}$').hasMatch(password)) {
      _showMessage("Password must contain at least one uppercase letter, one number, and one letter");
      isValid = false;
    }

    if (confirmController.text.trim() != password) {
      _showMessage("Passwords do not match");
      isValid = false;
    }

    if (selectedRole == "teacher") {
      if (phoneController.text.isEmpty) {
        _showMessage("Please enter your phone number");
        isValid = false;
      }

      if (portfolioController.text.isEmpty) {
        _showMessage("Please enter your portfolio link");
        isValid = false;
      }
    }

    return isValid;
  }

  Future<void> _handleRegister() async {
    if (!_validateFields()) {
      return;
    }

    setState(() => isLoading = true);

    final error = await _authService.registerWithEmail(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      confirmPassword: confirmController.text.trim(),
      role: selectedRole,
      phone: fullPhoneNumber,
      portfolio: portfolioController.text.trim(),
    );

    setState(() => isLoading = false);

    if (error != null) {
      _showMessage(error);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VerificationWizardPage(
        role: selectedRole,
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        phone: fullPhoneNumber,
        name: nameController.text.trim(),
        portfolio: portfolioController.text.trim(),
      ),
    ).then((_) {
      if (selectedRole == "teacher") {
        Navigator.pushReplacementNamed(context, "/teacherDashboard");
      } else {
        Navigator.pushReplacementNamed(context, "/");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
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
                          role[0].toUpperCase() + role.substring(1),
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
              hint: "Full Name",
              icon: Icons.person,
            ),
            const SizedBox(height: 20),
            AuthTextField(
              controller: emailController,
              hint: "Email",
              icon: Icons.email,
            ),
            const SizedBox(height: 20),
            AuthTextField(
              controller: passwordController,
              hint: "Password",
              icon: Icons.lock,
              obscure: true,
              showToggle: true,
              isObscured: isPasswordObscured,
              onToggle: () {
                setState(() {
                  isPasswordObscured = !isPasswordObscured;
                });
              },
            ),
            const SizedBox(height: 20),
            AuthTextField(
              controller: confirmController,
              hint: "Confirm Password",
              icon: Icons.lock_outline,
              obscure: true,
              showToggle: true,
              isObscured: isConfirmPasswordObscured,
              onToggle: () {
                setState(() {
                  isConfirmPasswordObscured = !isConfirmPasswordObscured;
                });
              },
            ),
            if (selectedRole == "teacher") ...[
              const SizedBox(height: 20),
              IntlPhoneField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                dropdownTextStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  hintText: "Phone Number",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                  prefixIcon: Icon(Icons.phone, color: AppColors.textColor),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.textColor, width: 2),
                  ),
                ),
                initialCountryCode: _initialCountryCode, // 🔹 Use the fetched country code
                onChanged: (phone) => fullPhoneNumber = phone.completeNumber,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                controller: portfolioController,
                hint: "Portfolio Link",
                icon: Icons.link,
              ),
            ],
            const SizedBox(height: 25),
            isLoading
                ? const CircularProgressIndicator()
                : AuthButton(text: "Register", onPressed: _handleRegister),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, "/LoginPage"),
              child: const Text("Already have an account? Login", style: TextStyle(color: AppColors.secondary),),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}