import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/models/community_post.dart';
import '../domain/policies/community_policy.dart';
import '../domain/repositories/community_repositories.dart';

enum FilterResult { changed, unchanged, needsAccount }

/// The community feed: tabs, pinned posts, blocked/hidden filtering and
/// up-to-date author names (one lookup per author, not one listener per card).
class CommunityFeedController extends ChangeNotifier {
  CommunityFeedController({
    required CommunityRepository repository,
    required FollowRepository follows,
    required CommunityUserRepository users,
    required this.session,
  })  : _repo = repository,
        _follows = follows,
        _users = users;

  static const tabs = [
    CommunityFilter.all,
    CommunityFilter.friends,
    CommunityFilter.popular,
    CommunityFilter.teachers,
    CommunityFilter.myPosts,
  ];

  final CommunityRepository _repo;
  final FollowRepository _follows;
  final CommunityUserRepository _users;
  final CommunitySession session;

  CommunityFilter _filter = CommunityFilter.all;
  CommunityFilter get filter => _filter;

  List<CommunityPost> _rawFeed = const [];
  List<CommunityPost> _rawPinned = const [];
  Set<String> _blocked = const {};
  final Map<String, CommunityUser> _authors = {};
  final Set<String> _authorsRequested = {};

  bool _isLoading = true;
  bool get isLoading => _isLoading;
  bool _hasError = false;
  bool get hasError => _hasError;
  bool _disposed = false;

  StreamSubscription<List<CommunityPost>>? _feedSub, _pinnedSub;

  /// Bumped on every feed (re)subscription: a slow one that was overtaken by a
  /// newer tab switch must not open a second, never-stopped listener.
  int _feedGeneration = 0;
  StreamSubscription<List<String>>? _blockedSub;

  List<CommunityPost> get posts =>
      CommunityPolicy.mainFeed(_rawFeed, session, blockedUserIds: _blocked).map(_withAuthor).toList();

  List<CommunityPost> get pinned => _rawPinned
      .where((p) => CommunityPolicy.isVisible(p, session, blockedUserIds: _blocked))
      .map(_withAuthor)
      .toList();

  Future<void> start() async {
    _pinnedSub = _repo.watchPinnedPosts().listen((p) {
      _rawPinned = p;
      _lookUpAuthors(p);
      _notify();
    }, onError: (Object _) {});
    if (!session.isGuest) {
      _blockedSub = _repo.watchBlockedUserIds(session.userId).listen((ids) {
        _blocked = ids.toSet();
        _notify();
      }, onError: (Object _) {});
    }
    await _subscribeFeed();
  }

  Future<FilterResult> setFilter(CommunityFilter f) async {
    if (f == _filter) return FilterResult.unchanged;
    if (session.isGuest && CommunityPolicy.requiresAccount(f)) return FilterResult.needsAccount;
    _filter = f;
    await _subscribeFeed();
    return FilterResult.changed;
  }

  /// Pull-to-refresh: re-read the feed and everyone's current profile.
  Future<void> refresh() async {
    _authors.clear();
    _authorsRequested.clear();
    _lookUpAuthors(_rawPinned);
    await _subscribeFeed();
  }

  Future<void> _subscribeFeed() async {
    // No await: after cancel() no more events arrive, and waiting could stall the tab switch.
    unawaited(_feedSub?.cancel());
    _feedSub = null;
    _isLoading = true;
    _hasError = false;
    _rawFeed = const [];
    _notify();
    final generation = ++_feedGeneration;
    final following =
        _filter == CommunityFilter.friends ? await _follows.getFollowingIds(session.userId) : const <String>[];
    if (_disposed || generation != _feedGeneration) return; // overtaken by a newer switch
    _feedSub = _repo.watchFeed(_filter, currentUserId: session.userId, followingIds: following).listen((p) {
      _rawFeed = p;
      _isLoading = false;
      _lookUpAuthors(p);
      _notify();
    }, onError: (Object e) {
      debugPrint('Feed error: $e');
      _isLoading = false;
      _hasError = true;
      _notify();
    });
  }

  void _lookUpAuthors(List<CommunityPost> posts) {
    final missing = posts.map((p) => p.authorId).where((id) => id.isNotEmpty && _authorsRequested.add(id)).toList();
    if (missing.isEmpty) return;
    _users.getUsers(missing).then((found) {
      for (final u in found) {
        _authors[u.id] = u;
      }
      _notify();
    }).catchError((Object e) => debugPrint('Author lookup failed: $e'));
  }

  CommunityPost _withAuthor(CommunityPost p) {
    final a = _authors[p.authorId];
    return a == null ? p : p.withAuthor(name: a.name, photoUrl: a.photoUrl, role: a.role);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _feedSub?.cancel();
    _pinnedSub?.cancel();
    _blockedSub?.cancel();
    super.dispose();
  }
}
