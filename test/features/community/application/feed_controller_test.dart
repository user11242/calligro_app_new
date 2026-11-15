import 'package:calligro_app/features/community/application/feed_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

void main() {
  late FakeCommunityRepository repo;
  late FakeFollowRepository follows;
  late FakeUserRepository users;

  Future<CommunityFeedController> started(CommunitySession session) async {
    final c = CommunityFeedController(repository: repo, follows: follows, users: users, session: session);
    await c.start();
    await pumpEventQueue();
    return c;
  }

  List<String> ids(List<dynamic> posts) => posts.map((p) => p.id as String).toList();

  setUp(() {
    repo = FakeCommunityRepository();
    follows = FakeFollowRepository();
    users = FakeUserRepository();
    repo.addPost(postBy('s2', id: 'a', day: 1, likes: 9));
    repo.addPost(postBy('t1', id: 'b', role: 'teacher', day: 2, likes: 1));
    repo.addPost(postBy('s1', id: 'c', day: 3));
  });

  test('tabs offered (Saved is not a feed tab)', () {
    expect(CommunityFeedController.tabs,
        [CommunityFilter.all, CommunityFilter.friends, CommunityFilter.popular, CommunityFilter.teachers, CommunityFilter.myPosts]);
  });

  test('starts on All, newest first, live', () async {
    final c = await started(studentSession);
    expect(c.filter, CommunityFilter.all);
    expect(c.isLoading, isFalse);
    expect(ids(c.posts), ['c', 'b', 'a']);
    repo.addPost(postBy('s3', id: 'd', day: 4));
    await pumpEventQueue();
    expect(ids(c.posts).first, 'd');
    c.dispose();
  });

  test('switching tabs', () async {
    final c = await started(studentSession);
    await c.setFilter(CommunityFilter.teachers);
    await pumpEventQueue();
    expect(ids(c.posts), ['b']);
    await c.setFilter(CommunityFilter.popular);
    await pumpEventQueue();
    expect(ids(c.posts), ['a', 'b', 'c']);
    await c.setFilter(CommunityFilter.myPosts);
    await pumpEventQueue();
    expect(ids(c.posts), ['c']);
  });

  test('Friends loads who I follow first', () async {
    follows.following['s1'] = {'t1'};
    final c = await started(studentSession);
    expect(await c.setFilter(CommunityFilter.friends), FilterResult.changed);
    await pumpEventQueue();
    expect(ids(c.posts), ['b']);
  });

  test('guests can\'t open Friends / My Posts (sign-in prompt instead)', () async {
    final c = await started(guestSession);
    expect(await c.setFilter(CommunityFilter.friends), FilterResult.needsAccount);
    expect(await c.setFilter(CommunityFilter.myPosts), FilterResult.needsAccount);
    expect(c.filter, CommunityFilter.all);
    expect(await c.setFilter(CommunityFilter.teachers), FilterResult.changed);
  });

  test('re-selecting the current tab does nothing', () async {
    final c = await started(studentSession);
    repo.calls.clear();
    expect(await c.setFilter(CommunityFilter.all), FilterResult.unchanged);
    expect(repo.calls, isEmpty);
  });

  test('pinned posts sit on top and are not repeated in the feed', () async {
    repo.addPost(postBy('a1', id: 'pin', pinned: true, day: 9, role: 'admin'));
    final c = await started(studentSession);
    expect(ids(c.pinned), ['pin']);
    expect(ids(c.posts), isNot(contains('pin')));
  });

  test('blocked authors disappear everywhere, live', () async {
    repo.addPost(postBy('t1', id: 'pin', pinned: true, role: 'teacher'));
    final c = await started(studentSession);
    await repo.blockUser('s1', blockedUserId: 't1');
    await pumpEventQueue();
    expect(ids(c.posts), ['c', 'a']);
    expect(c.pinned, isEmpty);
  });

  test('hidden posts: gone for students, visible to admins and the author', () async {
    repo.addPost(postBy('t1', id: 'h', hidden: true, day: 5));
    expect(ids((await started(studentSession)).posts), isNot(contains('h')));
    expect(ids((await started(adminSession)).posts), contains('h'));
    expect(ids((await started(teacherSession)).posts), contains('h'));
  });

  test('authors show their CURRENT name/photo/role, looked up once per author', () async {
    users.users['t1'] = const CommunityUser(id: 't1', name: 'Renamed Teacher', photoUrl: 'new.png', role: 'teacher');
    final c = await started(studentSession);
    await pumpEventQueue();
    final b = c.posts.firstWhere((p) => p.id == 'b');
    expect(b.authorName, 'Renamed Teacher');
    expect(b.authorPhotoUrl, 'new.png');
    final lookedUp = users.lookups.expand((l) => l).toList();
    expect(lookedUp.where((id) => id == 't1'), hasLength(1));
    await c.setFilter(CommunityFilter.teachers);
    await pumpEventQueue();
    expect(users.lookups.expand((l) => l).where((id) => id == 't1'), hasLength(1), reason: 'cached');
  });

  test('a feed error is shown as an error state', () async {
    repo.failing.add('watchFeed');
    final c = await started(studentSession);
    expect(c.hasError, isTrue);
    expect(c.isLoading, isFalse);
  });

  test('refresh re-reads the feed and the authors', () async {
    final c = await started(studentSession);
    final before = users.lookups.length;
    await c.refresh();
    await pumpEventQueue();
    expect(users.lookups.length, greaterThan(before));
    expect(ids(c.posts), ['c', 'b', 'a']);
  });
}
