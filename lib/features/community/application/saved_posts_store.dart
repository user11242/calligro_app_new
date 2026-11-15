import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/repositories/community_repositories.dart';

/// The signed-in user's saved posts, live, shared by every screen
/// (feed, single post, profiles) so a bookmark looks the same everywhere.
class SavedPostsStore extends ChangeNotifier {
  SavedPostsStore({required CommunityRepository repository, required this.userId}) : _repo = repository;

  final CommunityRepository _repo;
  final String userId;
  final Set<String> _ids = {};
  final Set<String> _pending = {};
  StreamSubscription<List<String>>? _sub;
  bool _disposed = false;

  bool isSaved(String postId) => _ids.contains(postId);

  void start() {
    if (userId.isEmpty) return;
    _sub ??= _repo.watchSavedPostIds(userId).listen((ids) {
      // Keep optimistic values for toggles still in flight.
      final keep = {for (final id in _pending) id: _ids.contains(id)};
      _ids
        ..clear()
        ..addAll(ids);
      keep.forEach((id, saved) => saved ? _ids.add(id) : _ids.remove(id));
      _notify();
    }, onError: (Object e) => debugPrint('Saved posts stream failed: $e'));
  }

  /// Optimistic save/unsave; rolls back on failure. False for guests or on failure.
  Future<bool> toggle(String postId) async {
    if (userId.isEmpty || _pending.contains(postId)) return false;
    final save = !_ids.contains(postId);
    _pending.add(postId);
    save ? _ids.add(postId) : _ids.remove(postId);
    _notify();
    try {
      await _repo.setSaved(postId, userId: userId, saved: save);
      return true;
    } catch (e) {
      save ? _ids.remove(postId) : _ids.add(postId);
      return false;
    } finally {
      _pending.remove(postId);
      _notify();
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
