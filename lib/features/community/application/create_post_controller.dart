import 'dart:io';
import 'package:flutter/foundation.dart';

import '../domain/models/community_post.dart';
import '../domain/policies/community_post_policy.dart';
import '../domain/repositories/community_repository.dart';

/// Controller managing post creation, image attachments, link validation, and publishing state.
class CreatePostController extends ChangeNotifier {
  final CommunityRepository _repository;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPhotoUrl;
  final String currentUserRole;

  String _caption = '';
  final List<File> _images = [];
  String? _linkUrl;
  String? _linkTitle;
  bool _isPinned = false;
  bool _isHidden = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  CreatePostController({
    required CommunityRepository repository,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPhotoUrl,
    required this.currentUserRole,
  }) : _repository = repository;

  String get caption => _caption;
  List<File> get images => List.unmodifiable(_images);
  String? get linkUrl => _linkUrl;
  String? get linkTitle => _linkTitle;
  bool get isPinned => _isPinned;
  bool get isHidden => _isHidden;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  bool get isAdmin => currentUserRole.toLowerCase() == 'admin';
  bool get canSubmit => CommunityPostPolicy.canCreatePost(
        caption: _caption,
        imageCount: _images.length,
        linkUrl: _linkUrl,
      );

  void setCaption(String text) {
    _caption = text;
    _errorMessage = null;
    notifyListeners();
  }

  void addImages(List<File> newFiles) {
    _errorMessage = null;
    final int available = CommunityPostPolicy.maxImagesPerPost - _images.length;
    if (available <= 0) {
      _errorMessage = 'Maximum of ${CommunityPostPolicy.maxImagesPerPost} images reached';
      notifyListeners();
      return;
    }

    if (newFiles.length > available) {
      _images.addAll(newFiles.take(available));
      _errorMessage = 'Only the first $available images were added';
    } else {
      _images.addAll(newFiles);
    }
    notifyListeners();
  }

  void removeImage(int index) {
    if (index >= 0 && index < _images.length) {
      _images.removeAt(index);
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setLinkUrl(String? url) {
    if (!CommunityPostPolicy.canAttachLink(userRole: currentUserRole)) return;
    _linkUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    notifyListeners();
  }

  void setLinkTitle(String? title) {
    if (!CommunityPostPolicy.canAttachLink(userRole: currentUserRole)) return;
    _linkTitle = (title != null && title.trim().isNotEmpty) ? title.trim() : null;
    notifyListeners();
  }

  void setIsPinned(bool val) {
    if (!CommunityPostPolicy.canPinPost(userRole: currentUserRole)) return;
    _isPinned = val;
    notifyListeners();
  }

  void setIsHidden(bool val) {
    if (!isAdmin) return;
    _isHidden = val;
    notifyListeners();
  }

  /// Submits the post to the repository. Returns true on success.
  Future<bool> submit() async {
    if (!canSubmit) {
      _errorMessage = 'You cannot create an empty post';
      notifyListeners();
      return false;
    }

    final validationError = CommunityPostPolicy.validateCaption(_caption);
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final post = CommunityPost(
      id: '',
      authorId: currentUserId,
      authorName: currentUserName,
      authorPhotoUrl: currentUserPhotoUrl,
      authorRole: currentUserRole,
      caption: _caption.trim(),
      imageUrls: const [],
      createdAt: DateTime.now(),
      isPinned: _isPinned,
      isHidden: _isHidden,
      linkUrl: _linkUrl,
      linkTitle: _linkTitle,
    );

    try {
      await _repository.createPost(post: post, images: _images);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}

