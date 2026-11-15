import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/models/community_post.dart';
import '../domain/policies/community_policy.dart';
import '../domain/repositories/community_repositories.dart';

/// Follow / Unfollow button.
class FollowController extends ChangeNotifier {
  FollowController({required FollowRepository follows, required this.session, required this.targetUserId})
      : _follows = follows;

  final FollowRepository _follows;
  final CommunitySession session;
  final String targetUserId;
  StreamSubscription<bool>? _sub;
  bool _disposed = false;

  bool _isFollowing = false;
  bool get isFollowing => _isFollowing;
  bool _busy = false;
  bool get isBusy => _busy;

  /// No button for guests or on your own profile.
  bool get isVisible => !session.isGuest && session.userId != targetUserId;

  void start() {
    if (!isVisible) return;
    _sub ??= _follows.watchIsFollowing(userId: session.userId, targetUserId: targetUserId).listen((v) {
      if (_busy) return;
      _isFollowing = v;
      _notify();
    });
  }

  Future<bool> toggle() async {
    if (!isVisible || _busy) return false;
    final follow = !_isFollowing;
    _busy = true;
    _isFollowing = follow;
    _notify();
    try {
      await _follows.setFollowing(userId: session.userId, targetUserId: targetUserId, follow: follow);
      return true;
    } catch (e) {
      _isFollowing = !follow;
      return false;
    } finally {
      _busy = false;
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

/// "Search users" screen: debounced name search; stale responses are dropped.
class UserSearchController extends ChangeNotifier {
  UserSearchController({required CommunityUserRepository users, this.debounce = const Duration(milliseconds: 500)})
      : _users = users;

  final CommunityUserRepository _users;
  final Duration debounce;
  Timer? _timer;
  int _generation = 0;

  String query = '';
  List<CommunityUser> _results = const [];
  List<CommunityUser> get results => _results;
  bool _loading = false;
  bool get isLoading => _loading;

  void onQueryChanged(String q) {
    query = q;
    _timer?.cancel();
    _timer = Timer(debounce, searchNow);
  }

  Future<void> searchNow() async {
    final generation = ++_generation;
    final q = query.trim();
    if (q.isEmpty) {
      _results = const [];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    List<CommunityUser> found;
    try {
      found = await _users.searchByName(q);
    } catch (e) {
      debugPrint('User search failed: $e');
      found = const [];
    }
    if (_disposed || generation != _generation) return; // disposed, or a newer search started meanwhile
    _results = found;
    _loading = false;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Settings → Blocked users.
class BlockedUsersController extends ChangeNotifier {
  BlockedUsersController({
    required CommunityRepository repository,
    required CommunityUserRepository users,
    required this.session,
  })  : _repo = repository,
        _users = users;

  final CommunityRepository _repo;
  final CommunityUserRepository _users;
  final CommunitySession session;
  StreamSubscription<List<String>>? _sub;
  bool _disposed = false;

  List<CommunityUser> _list = const [];
  List<CommunityUser> get users => _list;
  bool _loading = true;
  bool get isLoading => _loading;

  void start() {
    _sub ??= _repo.watchBlockedUserIds(session.userId).listen((ids) async {
      var found = <String, CommunityUser>{};
      try {
        found = {for (final u in await _users.getUsers(ids)) u.id: u};
      } catch (e) {
        debugPrint('Blocked users lookup failed: $e');
      }
      // Keep accounts that no longer exist (or failed to load) so they can still be unblocked.
      _list = [for (final id in ids) found[id] ?? CommunityUser(id: id)];
      _loading = false;
      if (!_disposed) notifyListeners();
    }, onError: (Object e) {
      _loading = false;
      if (!_disposed) notifyListeners();
    });
  }

  Future<bool> unblock(String userId) async {
    try {
      await _repo.unblockUser(session.userId, blockedUserId: userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

/// "Who liked this" sheet: me first, filter by name.
class LikersController extends ChangeNotifier {
  LikersController({required CommunityUserRepository users, required this.session}) : _users = users;
  final CommunityUserRepository _users;
  final CommunitySession session;

  List<CommunityUser> _all = const [];
  bool _loading = true;
  bool get isLoading => _loading;
  String _filter = '';
  set filter(String value) {
    _filter = value.toLowerCase().trim();
    notifyListeners();
  }

  List<CommunityUser> get visible =>
      _filter.isEmpty ? _all : _all.where((u) => u.name.toLowerCase().contains(_filter)).toList();

  Future<void> load(Set<String> likerIds) async {
    try {
      final found = await _users.getUsers(likerIds.toList());
      _all = [...found.where((u) => u.id == session.userId), ...found.where((u) => u.id != session.userId)];
    } catch (e) {
      debugPrint('Likers could not be loaded: $e');
      _all = const [];
    }
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Posts shown on profiles: a user's posts, my liked posts, my saved posts.
class ProfilePostsController extends ChangeNotifier {
  ProfilePostsController._(this._source, {required CommunityRepository repository, required this.session})
      : _repo = repository;

  factory ProfilePostsController.byUser(String userId,
          {required CommunityRepository repository, required CommunitySession session}) =>
      ProfilePostsController._(_Source.user(userId), repository: repository, session: session);
  factory ProfilePostsController.liked({required CommunityRepository repository, required CommunitySession session}) =>
      ProfilePostsController._(const _Source.liked(), repository: repository, session: session);
  factory ProfilePostsController.saved({required CommunityRepository repository, required CommunitySession session}) =>
      ProfilePostsController._(const _Source.saved(), repository: repository, session: session);

  final _Source _source;
  final CommunityRepository _repo;
  final CommunitySession session;
  final _subs = <StreamSubscription<dynamic>>[];
  StreamSubscription<List<CommunityPost>>? _savedPostsSub;
  bool _disposed = false;

  List<CommunityPost> _posts = const [];
  List<CommunityPost> get posts => _posts.where((p) => CommunityPolicy.isVisible(p, session)).toList();
  bool _loading = true;
  bool get isLoading => _loading;

  void start() {
    switch (_source.kind) {
      case _Kind.user:
        _listen(_repo.watchUserPosts(_source.userId!));
      case _Kind.liked:
        if (session.isGuest) return _empty();
        _listen(_repo.watchLikedPosts(session.userId));
      case _Kind.saved:
        if (session.isGuest) return _empty();
        _subs.add(_repo.watchSavedPostIds(session.userId).listen((ids) {
          _savedPostsSub?.cancel();
          _savedPostsSub = _repo.watchPostsByIds(ids).listen((found) {
            _set(found);
            _cleanUpDeletedSaves(ids.take(CommunityPolicy.maxWhereInIds), found);
          });
        }));
    }
  }

  /// A saved post that no longer exists → remove the dangling save.
  void _cleanUpDeletedSaves(Iterable<String> requested, List<CommunityPost> found) {
    final existing = found.map((p) => p.id).toSet();
    for (final id in requested.where((id) => !existing.contains(id))) {
      _repo.setSaved(id, userId: session.userId, saved: false).catchError((Object _) {});
    }
  }

  void _listen(Stream<List<CommunityPost>> s) => _subs.add(s.listen(_set, onError: (Object _) => _set(const [])));

  void _empty() => _set(const []);

  void _set(List<CommunityPost> p) {
    _posts = p;
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _savedPostsSub?.cancel();
    super.dispose();
  }
}

enum _Kind { user, liked, saved }

class _Source {
  final _Kind kind;
  final String? userId;
  const _Source.user(String this.userId) : kind = _Kind.user;
  const _Source.liked()
      : kind = _Kind.liked,
        userId = null;
  const _Source.saved()
      : kind = _Kind.saved,
        userId = null;
}
