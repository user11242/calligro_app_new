import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';

// Step widgets
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_role.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_welcome.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_student_finish.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_teacher_phone.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_teacher_portfolio.dart';
import 'package:calligro_app/features/auth/widgets/google_register_widgets/step_teacher_finish.dart';

// Verification widgets
import 'package:calligro_app/features/auth/widgets/verification/phone_otp_step.dart';

class GoogleRegisterWizard extends StatefulWidget {
  const GoogleRegisterWizard({super.key});

  @override
  State<GoogleRegisterWizard> createState() => _GoogleRegisterWizardState();
}

class _GoogleRegisterWizardState extends State<GoogleRegisterWizard> {
  int _step = 0;
  String selectedRole = "student";

  final phoneController = TextEditingController();
  final portfolioController = TextEditingController();

  bool isLoading = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // GlobalKey to access the public state of the OTP step
  final GlobalKey<PhoneOtpStepState> _otpKey = GlobalKey<PhoneOtpStepState>();

  late List<Widget> steps;
  
  // State variables to store the original Google profile data (Name, Email, Photo)
  String _initialName = '';
  String _initialEmail = '';
  String _initialPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _loadInitialUserData(); // Load data from Google profile
    _buildSteps();
  }

  // Function to capture the user's original Google profile data
  void _loadInitialUserData() {
    final user = _auth.currentUser;
    if (user != null) {
      _initialName = user.displayName ?? '';
      _initialEmail = user.email ?? '';
      _initialPhotoUrl = user.photoURL ?? '';
    }
  }

  void _buildSteps() {
    steps = [
      StepWelcome(user: _auth.currentUser),
      StepRole(
        selectedRole: selectedRole,
        onRoleChanged: (r) => setState(() {
          selectedRole = r;
          _buildSteps();
        }),
      ),
      if (selectedRole == "student") const StepStudentFinish(),
      if (selectedRole == "teacher")
        StepTeacherPhone(controller: phoneController),
      if (selectedRole == "teacher")
        PhoneOtpStep(
          // Attach the key to the OTP step
          key: _otpKey,
          phone: phoneController.text.trim(),
          onVerified: _nextStep,
          showNextButton: false, 
        ),
      if (selectedRole == "teacher")
        StepTeacherPortfolio(controller: portfolioController),
      if (selectedRole == "teacher") const StepTeacherFinish(),
    ];
  }

  Future<bool> _validateStep(int step) async {
    if (selectedRole == "teacher") {
      // Step 3 (index 2) is the phone number input
      if (step == 2 && phoneController.text.trim().isEmpty) {
        _showError("Phone number required");
        return false;
      }
      // Step 5 (index 4) is the portfolio link
      if (step == 4 && !_isValidUrl(portfolioController.text.trim())) {
        _showError("Enter a valid portfolio link (must start with http:// or https://)");
        return false;
      }
    }
    return true;
  }

  bool _isValidUrl(String url) {
    // Basic regex check for URL format
    final regex = RegExp(r"^https?:\/\/.+"); 
    return regex.hasMatch(url);
  }

  Future<void> _nextStep() async {
    // Intercept and handle OTP validation here
    if (_isOtpStep) {
      if (_otpKey.currentState == null) {
         _showError("OTP validation state is not ready.");
         return;
      }
      
      setState(() => isLoading = true); // Show loading while validating OTP
      
      // Call the public method on the OTP step's state
      final isOtpValid = await _otpKey.currentState!.verifyAndSubmit();
      
      setState(() => isLoading = false); // Hide loading

      if (isOtpValid) {
        // Since verifyAndSubmit() handles the Firebase sign-in, we just move the step.
        // We rely on the internal logic of PhoneOtpStep to handle the transition.
        setState(() => _step++);
      }
      return; // Stop further execution for this step
    }

    final ok = await _validateStep(_step);
    if (!ok) return;

    setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _finish() async {
    setState(() => isLoading = true);
    
    // 1. Force focus out to ensure the portfolio controller has the latest text
    if (FocusScope.of(context).hasFocus) {
      FocusScope.of(context).unfocus(); 
    }
    
    User? user = _auth.currentUser;
    if (user == null) {
        if (mounted) setState(() => isLoading = false);
        _showError("User not logged in.");
        return;
    }

    // ⭐️ CRITICAL STEP: Explicitly reload the user to guarantee the latest profile data
    try {
        await user.reload();
        // Get the reloaded user object reference
        user = _auth.currentUser; 
        if (user == null) throw Exception("User disappeared after reload.");
    } catch (e) {
        debugPrint("Failed to reload user data: $e");
    }
    
    // Read the (reloaded) user properties
    String finalName = user!.displayName ?? '';
    String finalEmail = user!.email ?? '';
    // Store the Photo URL separately for defensive saving
    String photoUrlToSave = user!.photoURL ?? '';

    // Track the source of the data for debugging
    String nameSource = "Google Auth";
    String emailSource = "Google Auth";

    // 1. Fallback to initial state variables
    if (finalName.isEmpty) {
      finalName = _initialName;
      if (finalName.isNotEmpty) nameSource = "Initial State";
    }
    if (finalEmail.isEmpty) {
      finalEmail = _initialEmail;
      if (finalEmail.isNotEmpty) emailSource = "Initial State";
    }
    
    // 2. 🚨 ULTIMATE FALLBACK: If still empty, use the UID/Placeholder.
    if (finalName.isEmpty) {
        finalName = "User ${user!.uid.substring(0, 8)}";
        nameSource = "UID Placeholder"; // Indicate that the placeholder was used
    }
    if (finalEmail.isEmpty) {
        finalEmail = "${user!.uid}@calligro.temp";
        emailSource = "UID Placeholder"; // Indicate that the placeholder was used
    }
    
    // Get the portfolio value and handle empty values
    String portfolio = portfolioController.text.trim();
    if (portfolio.isEmpty) {
      portfolio = "No Portfolio";  // Provide fallback value
    }

    // ⭐️ DEBUGGING: Print the values we are about to save, including their source
    debugPrint("--- Saving to Firestore ---");
    debugPrint("UID: ${user!.uid}");
    debugPrint("Name: $finalName (Source: $nameSource)");
    debugPrint("Email: $finalEmail (Source: $emailSource)");
    debugPrint("Photo URL: $photoUrlToSave (Saving separately)");
    debugPrint("Role: $selectedRole");
    if (selectedRole == "teacher") {
        debugPrint("Phone: ${phoneController.text.trim()}");
        debugPrint("Portfolio: $portfolio");
    }
    debugPrint("---------------------------");

    // Primary data map (excluding the potentially problematic photoUrl for the first write)
    final primaryData = {
      "uid": user!.uid, 
      "name": finalName, // Will be real name or UID placeholder
      "email": finalEmail, // Will be real email or UID placeholder
      "role": selectedRole,
      "status": selectedRole == "teacher" ? "pending" : "approved",
      "createdAt": FieldValue.serverTimestamp(),
      if (selectedRole == "teacher") ...{
        "phone": phoneController.text.trim(),
        "portfolio": portfolio,
      },
    };

    try {
      // 1. Attempt to save primary data (Name, Email, Role)
      await _firestore.collection("users").doc(user!.uid).set(
        primaryData, 
        SetOptions(merge: true)
      );
      debugPrint("Primary data (Name/Email/Role) saved successfully.");

      // 2. Attempt to save Photo URL separately only if it's available
      if (photoUrlToSave.isNotEmpty) {
        await _firestore.collection("users").doc(user!.uid).set(
          {"photoUrl": photoUrlToSave}, 
          SetOptions(merge: true)
        );
        debugPrint("Photo URL saved successfully.");
      } else {
        // Ensure photoUrl is written as an empty string if it was missing
        await _firestore.collection("users").doc(user!.uid).set(
          {"photoUrl": ""}, 
          SetOptions(merge: true)
        );
        debugPrint("Photo URL field initialized as empty.");
      }

    } catch (e) {
      // 🚨 Enhanced Error Logging
      debugPrint("FATAL FIREBASE WRITE ERROR: $e");
      _showError("Failed to save user data to Firestore. Check console for details.");
      if (mounted) setState(() => isLoading = false);
      return;
    }


    if (!mounted) return;
    setState(() => isLoading = false);
    // Return the selected role upon successful registration
    Navigator.pop(context, selectedRole); 
  }

  bool _isFinalStep() {
    if (selectedRole == "student") return _step == 2;
    if (selectedRole == "teacher") return _step == 5;
    return false;
  }

  // Teacher steps: 0=Welcome, 1=Role, 2=Phone, 3=OTP, 4=Portfolio, 5=Finish
  bool get _isOtpStep => selectedRole == "teacher" && _step == 3;

  @override
  Widget build(BuildContext context) {
    _buildSteps();

    return WillPopScope(
      onWillPop: () async {
        if (isLoading) return false;
        return true;
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.438,
                    ),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.25,
                            ),
                            child: steps[_step],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (_step > 0)
                                TextButton(
                                  onPressed: _prevStep,
                                  child: const Text(
                                    "Back",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : (_isFinalStep() ? _finish : _nextStep),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade400,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                child: isLoading
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      )
                                    : Text(_isFinalStep() ? "Finish" : "Next"),
                              ),
                            ],
                          ),
                        ],
                      ),
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