import 'dart:async';

import 'package:calligro_app/features/profile/domain/profile_models.dart';
import 'package:calligro_app/features/profile/domain/profile_repositories.dart';

/// Emits [read]() on listen and after every [changes] event.
Stream<T> _live<T>(Stream<void> changes, T Function() read) {
  StreamSubscription<void>? sub;
  late final StreamController<T> c;
  c = StreamController<T>(
    onListen: () {
      c.add(read());
      sub = changes.listen((_) => c.add(read()));
    },
    onCancel: () => sub?.cancel(),
  );
  return c.stream;
}

/// In-memory profiles, counters, follow lists, courses and reviews.
class FakeProfileStore
    implements
        ProfileRepository,
        ProfileCountsRepository,
        FollowListRepository,
        TeacherCoursesRepository,
        TeacherReviewsRepository {
  final profiles = <String, UserProfile>{};
  final posts = <String, int>{};
  final saved = <String, int>{};
  final liked = <String, int>{};
  final courses = <String, List<TeacherCourse>>{};
  final reviews = <String, List<TeacherReview>>{};
  final followers = <String, List<FollowListEntry>>{};
  final following = <String, List<FollowListEntry>>{};
  final countWatches = <String>[];
  final failing = <String>{};

  final _changes = StreamController<void>.broadcast(sync: true);
  void changed() => _changes.add(null);
  Stream<T> _watch<T>(T Function() read) => _live(_changes.stream, read);

  void put(UserProfile p) {
    profiles[p.id] = p;
    changed();
  }

  @override
  Stream<UserProfile?> watchProfile(String userId) =>
      failing.contains('watchProfile') ? Stream.error(Exception('profile failed')) : _watch(() => profiles[userId]);

  @override
  Stream<int> watchPostCount(String userId) {
    countWatches.add('posts:$userId');
    return _watch(() => posts[userId] ?? 0);
  }

  @override
  Stream<int> watchSavedCount(String userId) {
    countWatches.add('saved:$userId');
    return _watch(() => saved[userId] ?? 0);
  }

  @override
  Stream<int> watchLikedCount(String userId) {
    countWatches.add('liked:$userId');
    return _watch(() => liked[userId] ?? 0);
  }

  @override
  Stream<int> watchCourseCount(String teacherId) {
    countWatches.add('courses:$teacherId');
    return _watch(() => courses[teacherId]?.length ?? 0);
  }

  @override
  Future<List<FollowListEntry>> load(String userId, FollowListKind kind) async {
    if (failing.contains('load')) throw Exception('follow list failed');
    return List.of((kind == FollowListKind.followers ? followers : following)[userId] ?? const []);
  }

  @override
  Stream<List<TeacherCourse>> watchCourses(String teacherId) =>
      failing.contains('watchCourses') ? Stream.error(Exception('courses failed')) : _watch(() => List.of(courses[teacherId] ?? const []));

  @override
  Stream<List<TeacherReview>> watchReviews(String teacherId) => _watch(() => List.of(reviews[teacherId] ?? const []));
}

class FakeViewerSource implements ProfileViewerSource {
  FakeViewerSource(this.viewer);
  ProfileViewer viewer;
  @override
  Future<ProfileViewer> currentViewer() async => viewer;
}

const studentViewer = ProfileViewer(userId: 's1', role: 'student');
const teacherViewer = ProfileViewer(userId: 't1', role: 'teacher');
const adminViewer = ProfileViewer(userId: 'a1', role: 'admin');
const guestViewer = ProfileViewer.guest;

const sara = UserProfile(id: 's1', role: 'student', name: 'Sara', bio: 'Learning Naskh', followerCount: 2, followingCount: 5);
const ali = UserProfile(
  id: 't1',
  role: 'teacher',
  name: 'Ustadh Ali',
  bio: 'Thuluth teacher',
  followerCount: 12,
  followingCount: 3,
  spokenLanguages: ['Arabic', 'English'],
  totalStars: 9,
  reviewCount: 2,
  countryFlag: '🇯🇴',
  commissionRate: 0.6,
);
const boss = UserProfile(id: 'a1', role: 'admin', name: 'Admin', email: 'admin@calligro.com');
