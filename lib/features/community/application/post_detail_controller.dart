import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/models/community_comment.dart';
import '../domain/models/community_post.dart';
import '../domain/policies/community_post_policy.dart';
import '../domain/repositories/community_repository.dart';

/// Controller managing post inspection, real-time comment streams, commenting, and reporting.
class PostDetailController extends ChangeNotifier {
  final CommunityRepository _repository;
  final String postId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPhotoUrl;
  final String currentUserRole;

  CommunityPost? _post;
  List<CommunityComment> _comments = [];
  bool _isLoading = false;
  bool _isSubmittingComment = false;
  String? _errorMessage;

  StreamSubscription<List<CommunityComment>>? _commentsSubscription;

  PostDetailController({
    required CommunityRepository repository,
    required this.postId,
    CommunityPost? initialPost,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPhotoUrl,
    required this.currentUserRole,
  })  : _repository = repository,
        _post = initialPost;

  CommunityPost? get post => _post;
  List<CommunityComment> get comments => _comments;
  bool get isLoading => _isLoading;
  bool get isSubmittingComment => _isSubmittingComment;
  String? get errorMessage => _errorMessage;

  /// Initializes the post data and real-time comment stream.
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _post ??= await _repository.getPost(postId, currentUserId: currentUserId);
      _subscribeComments();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeComments() {
    _commentsSubscription?.cancel();
    _commentsSubscription = _repository.watchComments(postId).listen((items) {
      _comments = items;
      if (_post != null && _post!.commentsCount != items.length) {
        _post = _post!.copyWith(commentsCount: items.length);
      }
      notifyListeners();
    }, onError: (e) {
      _errorMessage = e.toString();
      notifyListeners();
    });
  }

  /// Adds a new comment after validating input.
  Future<bool> addComment(String text) async {
    final validationError = CommunityPostPolicy.validateComment(text);
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    _isSubmittingComment = true;
    _errorMessage = null;
    notifyListeners();

    final newComment = CommunityComment(
      id: '',
      postId: postId,
      authorId: currentUserId,
      authorName: currentUserName,
      authorPhotoUrl: currentUserPhotoUrl,
      authorRole: currentUserRole,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _repository.addComment(postId: postId, comment: newComment);
      if (_post != null) {
        _post = _post!.copyWith(commentsCount: _post!.commentsCount + 1);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmittingComment = false;
      notifyListeners();
    }
  }

  /// Deletes a comment.
  Future<void> deleteComment(String commentId) async {
    try {
      await _repository.deleteComment(postId: postId, commentId: commentId);
      _comments.removeWhere((c) => c.id == commentId);
      if (_post != null) {
        final newCount = _post!.commentsCount - 1;
        _post = _post!.copyWith(commentsCount: newCount < 0 ? 0 : newCount);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Reports the post.
  Future<void> reportPost(String reason) async {
    await _repository.reportPost(
      postId: postId,
      reporterId: currentUserId,
      reason: reason,
    );
  }

  /// Blocks the author of this post.
  Future<void> blockAuthor() async {
    if (_post == null || currentUserId.isEmpty) return;
    await _repository.blockUser(
      currentUserId: currentUserId,
      blockedUserId: _post!.authorId,
    );
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    super.dispose();
  }
}
