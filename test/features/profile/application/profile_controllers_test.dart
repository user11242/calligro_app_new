import 'package:calligro_app/features/profile/application/profile_controllers.dart';
import 'package:calligro_app/features/profile/domain/profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_profile.dart';

void main() {
  late FakeProfileStore store;

  setUp(() {
    store = FakeProfileStore()
      ..put(sara)
      ..put(ali)
      ..put(boss)
      ..posts['t1'] = 4
      ..posts['s1'] = 1
      ..saved['s1'] = 3
      ..liked['s1'] = 7
      ..courses['t1'] = [const TeacherCourse(id: 'c1', raw: {})];
  });

  ProfileController make(String id, ProfileViewer viewer, {bool publicView = false}) => ProfileController(
        profileId: id,
        viewer: viewer,
        profiles: store,
        counts: store,
        publicView: publicView,
      )..start();

  group('ProfileController', () {
    test('loads the profile live', () async {
      final c = make('t1', studentViewer);
      expect(c.isLoading, isTrue);
      await pumpEventQueue();
      expect(c.isLoading, isFalse);
      expect(c.profile!.name, 'Ustadh Ali');
      store.put(const UserProfile(id: 't1', role: 'teacher', name: 'Renamed'));
      await pumpEventQueue();
      expect(c.profile!.name, 'Renamed');
      c.dispose();
    });

    test('unknown user → not found', () async {
      final c = make('ghost', studentViewer);
      await pumpEventQueue();
      expect(c.notFound, isTrue);
      expect(c.profile, isNull);
    });

    test('a load error ends loading as not found (no endless spinner)', () async {
      store.failing.add('watchProfile');
      final c = make('t1', studentViewer);
      await pumpEventQueue();
      expect(c.isLoading, isFalse);
      expect(c.notFound, isTrue);
    });

    test('own student profile: Saved/Liked tabs with live counts, settings, no follow', () async {
      final c = make('s1', studentViewer);
      await pumpEventQueue();
      expect(c.isOwn, isTrue);
      expect(c.tabs, [ProfileTab.saved, ProfileTab.liked]);
      expect(c.counts.posts, 1);
      expect(c.counts.saved, 3);
      expect(c.counts.liked, 7);
      expect(c.showSettings, isTrue);
      expect(c.showFollow, isFalse);
      store
        ..saved['s1'] = 4
        ..changed();
      await pumpEventQueue();
      expect(c.counts.saved, 4);
    });

    test('a teacher\'s public profile: courses/reviews/posts, course count, follow, no private data', () async {
      final c = make('t1', studentViewer, publicView: true);
      await pumpEventQueue();
      expect(c.tabs, [ProfileTab.courses, ProfileTab.reviews, ProfileTab.posts]);
      expect(c.counts.courses, 1);
      expect(c.counts.posts, 4);
      expect(c.showFollow, isTrue);
      expect(c.showCommission, isFalse);
      expect(c.showSettings, isFalse);
    });

    test('someone else\'s saved / liked counts are never subscribed', () async {
      make('s1', teacherViewer, publicView: true);
      await pumpEventQueue();
      expect(store.countWatches.where((w) => w.startsWith('saved') || w.startsWith('liked')), isEmpty);
    });

    test('own teacher profile shows the commission; admin profile shows email and My Posts', () async {
      final t = make('t1', teacherViewer);
      final a = make('a1', adminViewer);
      await pumpEventQueue();
      expect(t.showCommission, isTrue);
      expect(a.showEmail, isTrue);
      expect(a.tabs.first, ProfileTab.myPosts);
    });

    test('no updates after dispose', () async {
      final c = make('t1', studentViewer);
      await pumpEventQueue();
      c.dispose();
      store.put(const UserProfile(id: 't1', role: 'teacher', name: 'Later'));
      await pumpEventQueue();
    });
  });

  group('FollowListController', () {
    const omar = FollowListEntry(id: 's2', name: 'Omar');
    const me = FollowListEntry(id: 's1', name: 'Sara');
    const teacher = FollowListEntry(id: 't9', name: 'Ustadha Huda', role: 'teacher');

    setUp(() => store.followers['t1'] = [omar, teacher, me]);

    test('loads, viewer first, filter by name', () async {
      final c = FollowListController(userId: 't1', kind: FollowListKind.followers, viewer: studentViewer, repository: store);
      expect(c.isLoading, isTrue);
      await c.load();
      expect(c.isLoading, isFalse);
      expect(c.visible.map((e) => e.id), ['s1', 's2', 't9']);
      c.filter = 'HUDA';
      expect(c.visible.single.id, 't9');
      c.filter = '';
      expect(c.visible, hasLength(3));
    });

    test('a failed load shows an empty list', () async {
      store.failing.add('load');
      final c = FollowListController(userId: 't1', kind: FollowListKind.followers, viewer: studentViewer, repository: store);
      await c.load();
      expect(c.isLoading, isFalse);
      expect(c.visible, isEmpty);
    });
  });

  group('LiveListController (courses, reviews)', () {
    test('items arrive live', () async {
      final c = LiveListController<TeacherCourse>(store.watchCourses('t1'))..start();
      await pumpEventQueue();
      expect(c.items.single.id, 'c1');
      store.courses['t1'] = [...store.courses['t1']!, const TeacherCourse(id: 'c2', raw: {})];
      store.changed();
      await pumpEventQueue();
      expect(c.items, hasLength(2));
      c.dispose();
    });

    test('errors become an error state', () async {
      store.failing.add('watchCourses');
      final c = LiveListController<TeacherCourse>(store.watchCourses('t1'))..start();
      await pumpEventQueue();
      expect(c.isLoading, isFalse);
      expect(c.hasError, isTrue);
    });
  });
}
