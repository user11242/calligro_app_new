import 'dart:io';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/utils/image_utils.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:calligro_app/features/auth/data/services/google_auth_service.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  File? _selectedImage;
  bool _isLoading = false;
  
  // Google Calendar State
  bool _isGoogleConnected = false;
  bool _isConnectingGoogle = false;
  bool _isLoadingConnection = true;

  @override
  void initState() {
    super.initState();
    _checkGoogleConnection();
  }

  Future<void> _checkGoogleConnection() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('google_auth')
          .get();

      if (mounted) {
        setState(() {
          _isGoogleConnected = doc.exists && doc.data()?['refreshToken'] != null;
          _isLoadingConnection = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingConnection = false);
    }
  }

  Future<void> _connectGoogleCalendar() async {
    try {
      setState(() => _isConnectingGoogle = true);

      // Using GoogleAuthService to manage the instance and initialization
      final googleAuthService = GoogleAuthService.instance;
      await googleAuthService.initialize();
      
      final GoogleSignIn googleSignIn = googleAuthService.googleSignIn;
      debugPrint("DEBUG: GoogleSignIn runtimeType: ${googleSignIn.runtimeType}");
      
      await googleSignIn.signOut();
      debugPrint("DEBUG: Signed out of previous session");
      
      final scopes = [
        'https://www.googleapis.com/auth/calendar.events',
        'https://www.googleapis.com/auth/meetings.space.settings',
      ];
      debugPrint("DEBUG: Calling authenticate()...");
      final GoogleSignInAccount account = await googleSignIn.authenticate(
        scopeHint: scopes,
      );
      debugPrint("DEBUG: authenticate() returned: $account");

      // Check for email mismatch (Strict Requirement)
      final String? userEmail = _auth.currentUser?.email;
      if (userEmail != null && account.email.toLowerCase() != userEmail.toLowerCase()) {
        await _showEmailMismatchDialog(account.email, userEmail);
        await googleSignIn.signOut();
        setState(() => _isConnectingGoogle = false);
        return;
      }

      // 3. Request Server Auth Code (google_sign_in ^7.0.0+)
      debugPrint("DEBUG: Calling authorizeServer...");
      final serverAuth = await account.authorizationClient.authorizeServer(scopes);
      final String? authCode = serverAuth?.serverAuthCode;
      
      if (authCode == null) {
        throw Exception(AppLocalizations.of(context)!.offlineAccessRequired);
      }
      
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('exchangeGoogleCode');
      
      await callable.call({
        'code': authCode,
        'refreshToken': "dummy_token_needs_server_exchange",
      });

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.calendarConnected,
          type: MessengerType.success,
        );
        _checkGoogleConnection();
      }
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint("❌ FIREBASE FUNCTION ERROR: code=${e.code}, message=${e.message}, details=${e.details}");
      debugPrint("❌ STACKTRACE: $stack");
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: "Function Error: ${e.message}",
          type: MessengerType.error,
        );
      }
    } catch (e, stack) {
      debugPrint("❌ ERROR CONNECTION CALENDAR: $e");
      debugPrint("❌ STACKTRACE: $stack");
      
      // Specifically handle cancellation without showing an error popup
      final errorStr = e.toString().toLowerCase();
      if ((e is GoogleSignInException && (e.code == 'sign_in_canceled' || e.code == 'canceled')) ||
          errorStr.contains('canceled') || 
          errorStr.contains('cancelled')) {
        debugPrint("Google Sign-In was cancelled by user - suppressing error.");
        return;
      }

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: "Failed to connect calendar: $e",
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isConnectingGoogle = false);
    }
  }

  Future<void> _showEmailMismatchDialog(String googleEmail, String appEmail) async {
    final l10n = AppLocalizations.of(context)!;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_circle_outlined, color: Colors.redAccent, size: 40),
                  ),
                  const SizedBox(height: 18),
                  
                  // Title
                  Text(
                    l10n.emailMismatchTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Description
                  Text(
                    l10n.emailMismatchDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Email Comparison Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _emailComparisonRow(
                          label: l10n.requiredEmail,
                          email: appEmail,
                          icon: Icons.check_circle_outline,
                          color: AppColors.textColor,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Colors.white10, height: 1),
                        ),
                        _emailComparisonRow(
                          label: l10n.connectedEmail,
                          email: googleEmail,
                          icon: Icons.cancel_outlined,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        l10n.tryAnotherAccount,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailComparisonRow({
    required String label,
    required String email,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 75,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfilePhoto() async {
    if (_selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 1. Upload Image with EXIF correction
      final File correctedImage = await fixExifRotation(_selectedImage!);
      String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage
          .ref()
          .child('user_profile_images')
          .child(user.uid)
          .child(fileName);

      await ref.putFile(correctedImage);
      final String downloadUrl = await ref.getDownloadURL();

      // 2. Batch Update (Same logic as EditProfilePage)
      final batch = _firestore.batch();
      
      // Update Users
      batch.update(_firestore.collection('users').doc(user.uid), {
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Teachers
      batch.update(_firestore.collection('teachers').doc(user.uid), {
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Sync to Courses
      final coursesQuery = await _firestore
          .collection('courses')
          .where('teacherId', isEqualTo: user.uid)
          .get();
      for (var doc in coursesQuery.docs) {
        batch.update(doc.reference, {'teacherProfilePic': downloadUrl});
      }

      // Sync to Posts
      final postsQuery = await _firestore
          .collection('community_posts')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (var doc in postsQuery.docs) {
        batch.update(doc.reference, {'userImageUrl': downloadUrl});
      }

      // Sync to Comments
      final commentsQuery = await _firestore
          .collectionGroup('comments')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (var doc in commentsQuery.docs) {
        batch.update(doc.reference, {'userPhotoUrl': downloadUrl});
      }

      await batch.commit();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/teacherDashboard');
      }

    } catch (e) {
      if (mounted) {
        debugPrint("TeacherSetupPage Error: $e");
        AppMessenger.showSnackBar(
          context,
          title: "Error",
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.setupTitle;
    final subtitle = l10n.setupSubtitle;
    final btnText = l10n.submitForApproval;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user, size: 60, color: AppColors.secondary),
                const SizedBox(height: 24),
                
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Step 1: Image Picker
                Text(
                  l10n.step1UploadPhoto,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardBackground,
                          border: Border.all(color: AppColors.secondary, width: 2),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? const Icon(Icons.camera_alt, color: Colors.white54, size: 40)
                            : null,
                      ),
                      if (_selectedImage != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: AppColors.black, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),


                const SizedBox(height: 50),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_selectedImage != null && !_isLoading) ? _saveProfilePhoto : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.black)
                        : Text(
                            btnText,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: (_selectedImage != null) 
                                ? AppColors.black 
                                : Colors.white24,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

