import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/models/community_post.dart';
import '../domain/policies/community_policy.dart';
import '../domain/repositories/community_repositories.dart';

/// One post opened by link (notification, share link): live, with the
/// author's current profile, and hidden posts kept from other viewers.
class SinglePostController extends ChangeNotifier {
  SinglePostController({
    required CommunityRepository repository,
    required CommunityUserRepository users,
    required this.session,
    required this.postId,
  })  : _repo = repository,
        _users = users;

  final CommunityRepository _repo;
  final CommunityUserRepository _users;
  final CommunitySession session;
  final String postId;

  StreamSubscription<CommunityPost?>? _sub;
  bool _disposed = false;
  CommunityPost? _raw;
  CommunityUser? _author;
  bool _authorRequested = false;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// Null when the post doesn't exist, was deleted, or may not be seen.
  CommunityPost? get post {
    final p = _raw;
    if (p == null || !CommunityPolicy.isVisible(p, session)) return null;
    final a = _author;
    return a == null ? p : p.withAuthor(name: a.name, photoUrl: a.photoUrl, role: a.role);
  }

  void start() {
    _sub ??= _repo.watchPost(postId).listen((p) {
      _raw = p;
      _isLoading = false;
      if (p != null) _lookUpAuthor(p.authorId);
      _notify();
    }, onError: (Object e) {
      debugPrint('Post could not be loaded: $e');
      _raw = null;
      _isLoading = false;
      _notify();
    });
  }

  Future<void> _lookUpAuthor(String authorId) async {
    if (_authorRequested || authorId.isEmpty) return;
    _authorRequested = true;
    try {
      final found = await _users.getUsers([authorId]);
      if (found.isNotEmpty) {
        _author = found.first;
        _notify();
      }
    } catch (e) {
      debugPrint('Author lookup failed: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
