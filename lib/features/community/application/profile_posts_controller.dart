import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/models/community_post.dart';
import '../domain/repositories/community_repository.dart';

/// Controller managing a specific user's posts on their public profile.
class ProfilePostsController extends ChangeNotifier {
  final CommunityRepository _repository;
  final String targetUserId;
  final String currentUserId;

  List<CommunityPost> _posts = [];
  bool _isLoading = false;
  bool _isGridView = true;
  String? _errorMessage;

  StreamSubscription<List<CommunityPost>>? _subscription;

  ProfilePostsController({
    required CommunityRepository repository,
    required this.targetUserId,
    required this.currentUserId,
  }) : _repository = repository;

  List<CommunityPost> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isGridView => _isGridView;
  String? get errorMessage => _errorMessage;

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository.watchUserPosts(targetUserId, currentUserId: currentUserId).listen((list) {
      _posts = list;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> deletePost({
    required String postId,
    required String authorId,
    required List<String> imageUrls,
  }) async {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();

    await _repository.deletePost(
      postId: postId,
      authorId: authorId,
      imageUrls: imageUrls,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

