import 'package:calligro_app/features/profile/domain/profile_edit.dart';
import 'package:calligro_app/features/profile/presentation/profile_scope.dart';
import 'dart:io';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TeacherSetupPage extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;

  const TeacherSetupPage({
    super.key,
    this.auth,
    this.firestore,
    this.storage,
  });

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  late final FirebaseAuth _auth;
  
  File? _selectedImage;
  bool _isLoading = false;
  
  // Google Calendar State

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
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

      // Same upload + save as Edit Profile. Copies of the photo on courses, posts
      // and comments are refreshed by the syncProfileCopies Cloud Function.
      final services = ProfileScope.of(context);
      final profile = await services.editor.load(user.uid);
      if (profile == null) throw Exception('Profile not found');
      final downloadUrl = await services.photos.upload(user.uid, _selectedImage!.path);
      await services.editor.save(
        profile,
        ProfileDraft(name: profile.name, bio: profile.bio, phone: profile.phone),
        photoUrl: downloadUrl,
      );

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

