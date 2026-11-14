import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/models/community_filter.dart';
import '../domain/models/community_post.dart';
import '../domain/repositories/community_repository.dart';
import '../domain/repositories/follow_repository.dart';

/// Application controller orchestrating feed subscriptions, filters, pinned posts, and saved posts.
class CommunityFeedController extends ChangeNotifier {
  final CommunityRepository _repository;
  final FollowRepository _followRepository;
  final String currentUserId;

  CommunityFilter _selectedFilter = CommunityFilter.all;
  List<CommunityPost> _posts = [];
  List<CommunityPost> _pinnedPosts = [];
  Set<String> _savedPostIds = {};
  List<String> _followingIds = [];

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<CommunityPost>>? _feedSubscription;
  StreamSubscription<List<CommunityPost>>? _pinnedSubscription;

  CommunityFeedController({
    required CommunityRepository repository,
    required FollowRepository followRepository,
    required this.currentUserId,
  })  : _repository = repository,
        _followRepository = followRepository;

  CommunityFilter get selectedFilter => _selectedFilter;
  List<CommunityPost> get posts => _posts;
  List<CommunityPost> get pinnedPosts => _pinnedPosts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isPostSaved(String postId) => _savedPostIds.contains(postId);

  /// Initializes feed and subscriptions.
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (currentUserId.isNotEmpty) {
        final results = await Future.wait([
          _repository.getSavedPostIds(currentUserId),
          _followRepository.getFollowingIds(currentUserId),
        ]);
        _savedPostIds = Set.of(results[0]);
        _followingIds = results[1];
      }

      _watchPinned();
      _watchFeed();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _watchPinned() {
    _pinnedSubscription?.cancel();
    _pinnedSubscription = _repository.watchPinnedPosts().listen((list) {
      _pinnedPosts = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ Pinned posts error: $e');
    });
  }

  void _watchFeed() {
    _feedSubscription?.cancel();
    _feedSubscription = _repository.watchFeed(
      filter: _selectedFilter,
      currentUserId: currentUserId,
      followingIds: _followingIds,
      savedPostIds: _savedPostIds.toList(),
    ).listen((list) {
      _posts = list;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Changes the active feed filter and re-subscribes.
  Future<void> setFilter(CommunityFilter filter) async {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    _isLoading = true;
    notifyListeners();

    if (filter == CommunityFilter.friends && currentUserId.isNotEmpty) {
      _followingIds = await _followRepository.getFollowingIds(currentUserId);
    } else if (filter == CommunityFilter.saved && currentUserId.isNotEmpty) {
      final saved = await _repository.getSavedPostIds(currentUserId);
      _savedPostIds = Set.of(saved);
    }

    _watchFeed();
  }

  /// Refreshes feed data.
  Future<void> refresh() async {
    await init();
  }

  /// Toggles saved status of a post.
  Future<void> toggleSave(String postId) async {
    if (currentUserId.isEmpty) return;

    final currentlySaved = isPostSaved(postId);
    if (currentlySaved) {
      _savedPostIds.remove(postId);
    } else {
      _savedPostIds.add(postId);
    }
    notifyListeners();

    try {
      await _repository.toggleSavePost(
        currentUserId: currentUserId,
        postId: postId,
        isSaved: currentlySaved,
      );
    } catch (e) {
      // Rollback on error
      if (currentlySaved) {
        _savedPostIds.add(postId);
      } else {
        _savedPostIds.remove(postId);
      }
      notifyListeners();
      debugPrint('⚠️ Toggle save post failed: $e');
    }
  }

  /// Deletes a post.
  Future<void> deletePost({
    required String postId,
    required String authorId,
    required List<String> imageUrls,
  }) async {
    _posts.removeWhere((p) => p.id == postId);
    _pinnedPosts.removeWhere((p) => p.id == postId);
    notifyListeners();

    await _repository.deletePost(
      postId: postId,
      authorId: authorId,
      imageUrls: imageUrls,
    );
  }

  @override
  void dispose() {
    _feedSubscription?.cancel();
    _pinnedSubscription?.cancel();
    super.dispose();
  }
}

