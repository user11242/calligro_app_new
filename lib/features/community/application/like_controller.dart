import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/repositories/community_repository.dart';

/// Manages optimistic like/unlike interactions with automatic rollback on network failure.
class LikeController extends ChangeNotifier {
  final CommunityRepository _repository;
  final String currentUserId;
  final String postId;

  bool _isLiked;
  int _likesCount;
  String? _lastError;
  bool _isSyncing = false;

  LikeController({
    required CommunityRepository repository,
    required this.currentUserId,
    required this.postId,
    required int initialLikesCount,
    required bool initialIsLiked,
  })  : _repository = repository,
        _likesCount = initialLikesCount,
        _isLiked = initialIsLiked;

  bool get isLiked => _isLiked;
  int get likesCount => _likesCount;
  String? get lastError => _lastError;
  bool get isSyncing => _isSyncing;

  /// Toggles like state optimistically, reverting on failure.
  Future<void> toggleLike() async {
    if (currentUserId.isEmpty) {
      _lastError = 'Must be signed in to like';
      notifyListeners();
      return;
    }

    // Save previous state for rollback
    final previousLiked = _isLiked;
    final previousCount = _likesCount;

    // Optimistically update
    _isLiked = !previousLiked;
    _likesCount = _isLiked ? previousCount + 1 : (previousCount > 0 ? previousCount - 1 : 0);
    _lastError = null;
    notifyListeners();

    _isSyncing = true;
    try {
      await _repository.toggleLike(
        postId: postId,
        currentUserId: currentUserId,
        isLiked: previousLiked, // pass what it was so repository knows whether to add or delete
      );
    } catch (e) {
      // Rollback to original state!
      _isLiked = previousLiked;
      _likesCount = previousCount;
      _lastError = e.toString();
      debugPrint('⚠️ Like operation failed, rolled back: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Updates local state if an external sync occurs (e.g. from stream).
  void syncFromPost({required int count, required bool liked}) {
    if (_isSyncing) return; // do not overwrite while an optimistic action is pending
    if (_likesCount != count || _isLiked != liked) {
      _likesCount = count;
      _isLiked = liked;
      notifyListeners();
    }
  }
}

