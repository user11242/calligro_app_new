import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/profile_models.dart';
import '../domain/profile_policy.dart';
import '../domain/profile_repositories.dart';

/// One profile screen (own tab or public page): the live profile, its counters
/// and — through ProfilePolicy — which tabs and buttons to show.
class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.profileId,
    required this.viewer,
    required ProfileRepository profiles,
    required ProfileCountsRepository counts,
    this.publicView = false,
  })  : _profiles = profiles,
        _counts = counts;

  final String profileId;
  final ProfileViewer viewer;

  /// A public page (even when it is the viewer's own).
  final bool publicView;
  final ProfileRepository _profiles;
  final ProfileCountsRepository _counts;

  StreamSubscription<UserProfile?>? _profileSub;
  final _countSubs = <StreamSubscription<int>>[];
  bool _countsStarted = false;
  bool _disposed = false;

  UserProfile? _profile;
  UserProfile? get profile => _profile;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  bool get notFound => !_isLoading && _profile == null;
  ProfileCounts _countValues = const ProfileCounts();
  ProfileCounts get counts => _countValues;

  bool get isOwn => ProfilePolicy.isOwn(viewer, profileId);
  bool get _ownView => isOwn && !publicView;

  List<ProfileTab> get tabs =>
      _profile == null ? const [] : ProfilePolicy.tabs(_profile!, viewer, publicView: publicView);
  bool get showFollow => _profile != null && ProfilePolicy.showFollow(_profile!, viewer);
  bool get showSettings => _profile != null && !publicView && ProfilePolicy.showSettings(_profile!, viewer);
  bool get showCommission => _profile != null && !publicView && ProfilePolicy.showCommission(_profile!, viewer);
  bool get showEmail => _profile != null && !publicView && ProfilePolicy.showEmail(_profile!, viewer);

  void start() {
    _profileSub ??= _profiles.watchProfile(profileId).listen((p) {
      _profile = p;
      _isLoading = false;
      if (p != null) _startCounts(p);
      _notify();
    }, onError: (Object e) {
      debugPrint('Profile $profileId could not be loaded: $e');
      _profile = null;
      _isLoading = false;
      _notify();
    });
  }

  /// Only the counters this screen shows; someone else's saved / liked are never read.
  void _startCounts(UserProfile p) {
    if (_countsStarted) return;
    _countsStarted = true;
    void watch(Stream<int> s, ProfileCounts Function(int) apply) => _countSubs.add(s.listen((n) {
          _countValues = apply(n);
          _notify();
        }, onError: (Object e) => debugPrint('Profile counter failed: $e')));

    watch(_counts.watchPostCount(profileId), (n) => _countValues.copyWith(posts: n));
    if (_ownView) {
      watch(_counts.watchSavedCount(profileId), (n) => _countValues.copyWith(saved: n));
      watch(_counts.watchLikedCount(profileId), (n) => _countValues.copyWith(liked: n));
    }
    if (p.isTeacher && !_ownView) {
      watch(_counts.watchCourseCount(profileId), (n) => _countValues.copyWith(courses: n));
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profileSub?.cancel();
    for (final s in _countSubs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Followers / following sheet: the viewer first, filter by name.
class FollowListController extends ChangeNotifier {
  FollowListController({
    required this.userId,
    required this.kind,
    required this.viewer,
    required FollowListRepository repository,
  }) : _repo = repository;

  final String userId;
  final FollowListKind kind;
  final ProfileViewer viewer;
  final FollowListRepository _repo;
  bool _disposed = false;

  List<FollowListEntry> _all = const [];
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  String _filter = '';
  set filter(String value) {
    _filter = value.toLowerCase().trim();
    _notify();
  }

  List<FollowListEntry> get visible =>
      _filter.isEmpty ? _all : _all.where((e) => e.name.toLowerCase().contains(_filter)).toList();

  Future<void> load() async {
    try {
      final found = await _repo.load(userId, kind);
      _all = [...found.where((e) => e.id == viewer.userId), ...found.where((e) => e.id != viewer.userId)];
    } catch (e) {
      debugPrint('Follow list could not be loaded: $e');
      _all = const [];
    }
    _isLoading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A live list with loading / error state (a teacher's courses, reviews).
class LiveListController<T> extends ChangeNotifier {
  LiveListController(this._source);
  final Stream<List<T>> _source;
  StreamSubscription<List<T>>? _sub;
  bool _disposed = false;

  List<T> _items = const [];
  List<T> get items => _items;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  bool _hasError = false;
  bool get hasError => _hasError;

  void start() {
    _sub ??= _source.listen((items) {
      _items = items;
      _isLoading = false;
      _hasError = false;
      _notify();
    }, onError: (Object e) {
      debugPrint('List could not be loaded: $e');
      _isLoading = false;
      _hasError = true;
      _notify();
    });
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
