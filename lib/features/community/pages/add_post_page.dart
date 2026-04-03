// lib/features/community/pages/add_post_page.dart (Refactored)
//Done
import 'dart:io';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:flutter/material.dart';
// Import the new service
import 'package:calligro_app/features/community/services/community_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import for FirebaseAuth
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';

class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  // --- UI State ---
  final TextEditingController _captionController = TextEditingController();
  final List<File> _imageFiles = [];
  bool _isLoading = false; // For the submit button
  bool _isUserDataLoading = true; // For the header

  // --- Logic / Service ---
  final CommunityService _communityService = CommunityService();
  Map<String, dynamic> _userData = {};
  final int _maxImages = 5;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- UI-Related Logic ---

  Future<void> _loadUserData() async {
    try {
      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception(
          "User not logged in. Cannot load user data for posting.",
        );
      }
      // --- CORRECTED THIS LINE ---
      final data = await _communityService.getCurrentUserData(currentUserId);
      // --- END CORRECTION ---
      if (mounted) {
        setState(() {
          _userData = data;
          _isUserDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.errorFetchingUserData(e.toString()),
          type: MessengerType.error,
        );
        Navigator.pop(context); // Pop if we can't get user data
      }
    }
  }

  Future<void> _handlePickImage() async {
    if (_imageFiles.length >= _maxImages) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.info,
        message: AppLocalizations.of(context)!.limitPhotosReached(_maxImages),
        type: MessengerType.info,
      );
      return;
    }

    try {
      final newImages = await _communityService.pickAndCompressImages(
        context: context,
        currentImageCount: _imageFiles.length,
        maxImages: _maxImages,
        errorAlreadySelectedMax: AppLocalizations.of(context)!.alreadySelectedMax(_maxImages),
        errorCanOnlySelectUpTo: AppLocalizations.of(context)!.canOnlySelectUpTo(_maxImages),
        errorSomeImagesNotAdded: AppLocalizations.of(context)!.someImagesNotAdded(_maxImages),
      );
      if (mounted) {
        setState(() {
          _imageFiles.addAll(newImages);
        });
      }
    } on Exception catch (e) {
      // Catch exceptions from the service
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: e.toString().replaceFirst("Exception: ", ""),
        type: MessengerType.error,
      );
    }
  }

  void _clearImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _handleSubmitPost() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _communityService.createPost(
        caption: _captionController.text,
        images: _imageFiles,
        userData: _userData,
      );

      if (mounted) {
        Navigator.pop(context); // Success
      }
    } on Exception catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: e.toString().replaceFirst("Exception: ", ""),
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  // --- Build Method (UI) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textLight),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.addNewPost,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Column(
              children: [
                // 1. User Header
                _buildUserHeader(), // Extracted to a clean widget
                const SizedBox(height: 16),

                // 2. Text Field & Image Previews (Expanded)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _captionController,
                          maxLines: null,
                          autofocus: true,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.shareMasterpiece,
                            hintStyle: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_imageFiles.isNotEmpty) _buildImagePreviewList(),
                      ],
                    ),
                  ),
                ),

                // 3. Toolbar
                _buildToolbar(),
                const SizedBox(height: 20),

                // 4. Submit Button
                _buildSubmitButton(),
                const SizedBox(height: 120), // ADDED: Pushes buttons higher up
              ],
            ),
          ),
          // Loading Overlay
          if (_isLoading)
            Container(
              color: AppColors.primary.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              ),
            ),
        ],
      ),
    );
  }

  // --- UI Helper Widgets ---

  Widget _buildUserHeader() {
    if (_isUserDataLoading) {
      return Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.goldGradientEnd.withOpacity(0.5),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)!.loading,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    final String? userName = _userData['name'];
    final String? userImageUrl = _userData['photoUrl'];

    return Row(
      children: [
        ProfileAvatar(
          imageUrl: userImageUrl,
          radius: 22,
        ),
        const SizedBox(width: 12),
        Text(
          userName ?? AppLocalizations.of(context)!.anonymous,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final bool canAddMoreImages = _imageFiles.length < _maxImages;
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.add_photo_alternate_outlined,
            color: canAddMoreImages
                ? AppColors.textLight
                : AppColors.textLight.withOpacity(0.3),
            size: 28,
          ),
          onPressed: _handlePickImage,
          tooltip: canAddMoreImages
              ? AppLocalizations.of(context)!.addPhoto
              : AppLocalizations.of(context)!.limitPhotosReached(_maxImages),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmitPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, size: 20.0),
                  SizedBox(width: 8.0),
                  Text(
                    AppLocalizations.of(context)!.post,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImagePreviewList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imageFiles.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    _imageFiles[index],
                    fit: BoxFit.cover,
                    width: 100,
                    height: 120,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _clearImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
