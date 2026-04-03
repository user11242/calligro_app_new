import 'dart:io';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/features/community/services/community_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';

class EditPostPage extends StatefulWidget {
  final String postId;
  final String initialCaption;
  final List<String> initialImageUrls;

  const EditPostPage({
    super.key,
    required this.postId,
    required this.initialCaption,
    required this.initialImageUrls,
  });

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  // --- UI State ---
  late final TextEditingController _captionController;
  final List<File> _newImageFiles = [];
  late List<String> _existingImageUrls;
  bool _isLoading = false;
  bool _isUserDataLoading = true;

  // --- Logic / Service ---
  final CommunityService _communityService = CommunityService();
  Map<String, dynamic> _userData = {};
  final int _maxImages = 5;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
    _existingImageUrls = List.from(widget.initialImageUrls);
    _loadUserData();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      
      final data = await _communityService.getCurrentUserData(currentUserId);
      if (mounted) {
        setState(() {
          _userData = data;
          _isUserDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUserDataLoading = false;
        });
      }
    }
  }

  Future<void> _handlePickImage() async {
    final int totalImages = _newImageFiles.length + _existingImageUrls.length;
    if (totalImages >= _maxImages) {
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
        currentImageCount: totalImages,
        maxImages: _maxImages,
        errorAlreadySelectedMax: AppLocalizations.of(context)!.alreadySelectedMax(_maxImages),
        errorCanOnlySelectUpTo: AppLocalizations.of(context)!.canOnlySelectUpTo(_maxImages),
        errorSomeImagesNotAdded: AppLocalizations.of(context)!.someImagesNotAdded(_maxImages),
      );
      if (mounted) {
        setState(() {
          _newImageFiles.addAll(newImages);
        });
      }
    } on Exception catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: e.toString().replaceFirst("Exception: ", ""),
        type: MessengerType.error,
      );
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
    });
  }

  Future<void> _handleSubmitUpdate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _communityService.updatePost(
        postId: widget.postId,
        newCaption: _captionController.text,
        newImages: _newImageFiles,
        keepImageUrls: _existingImageUrls,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );

      if (mounted) {
        Navigator.pop(context, true); // Success
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
          AppLocalizations.of(context)!.editPost,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Column(
              children: [
                _buildUserHeader(),
                const SizedBox(height: 16),
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
                            hintText: AppLocalizations.of(context)!.updateCaptionHint,
                            hintStyle: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildImagePreviewList(),
                      ],
                    ),
                  ),
                ),
                _buildToolbar(),
                const SizedBox(height: 20),
                _buildSubmitButton(),
              ],
            ),
          ),
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
    final int totalImages = _newImageFiles.length + _existingImageUrls.length;
    final bool canAddMoreImages = totalImages < _maxImages;
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
        onPressed: _isLoading ? null : _handleSubmitUpdate,
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
                  const Icon(Icons.check, size: 20.0),
                  const SizedBox(width: 8.0),
                  Text(
                    AppLocalizations.of(context)!.save,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImagePreviewList() {
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing Images
          ..._existingImageUrls.asMap().entries.map((entry) {
            final int index = entry.key;
            final String url = entry.value;
            return _buildPreviewCard(
              child: Image.network(url, fit: BoxFit.cover, width: 100, height: 120),
              onRemove: () => _removeExistingImage(index),
            );
          }),
          // New Images
          ..._newImageFiles.asMap().entries.map((entry) {
            final int index = entry.key;
            final File file = entry.value;
            return _buildPreviewCard(
              child: Image.file(file, fit: BoxFit.cover, width: 100, height: 120),
              onRemove: () => _removeNewImage(index),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPreviewCard({required Widget child, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: child,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
