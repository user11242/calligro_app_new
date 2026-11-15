import 'package:calligro_app/features/community/application/people_controllers.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

void main() {
  late FakeCommunityRepository repo;
  late FakeFollowRepository follows;
  late FakeUserRepository users;

  setUp(() {
    repo = FakeCommunityRepository();
    follows = FakeFollowRepository();
    users = FakeUserRepository()
      ..users['s1'] = const CommunityUser(id: 's1', name: 'Student One')
      ..users['t1'] = const CommunityUser(id: 't1', name: 'Teacher Ali', role: 'teacher')
      ..users['s2'] = const CommunityUser(id: 's2', name: 'Alia');
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('FollowController', () {
    FollowController make(CommunitySession s, String target) =>
        FollowController(follows: follows, session: s, targetUserId: target)..start();

    test('follow / unfollow, live', () async {
      final c = make(studentSession, 't1');
      await pumpEventQueue();
      expect(c.isFollowing, isFalse);
      expect(await c.toggle(), isTrue);
      await pumpEventQueue();
      expect(c.isFollowing, isTrue);
      expect(follows.following['s1'], {'t1'});
      await c.toggle();
      await pumpEventQueue();
      expect(c.isFollowing, isFalse);
      c.dispose();
    });

    test('no button for yourself or for guests', () {
      expect(make(studentSession, 's1').isVisible, isFalse);
      expect(make(guestSession, 't1').isVisible, isFalse);
      expect(make(studentSession, 't1').isVisible, isTrue);
    });

    test('failure rolls back', () async {
      final c = make(studentSession, 't1');
      await pumpEventQueue();
      follows.failing.add('setFollowing');
      expect(await c.toggle(), isFalse);
      expect(c.isFollowing, isFalse);
      expect(c.isBusy, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('UserSearchController', () {
    test('searches by name; blank clears', () async {
      final c = UserSearchController(users: users, debounce: Duration.zero);
      c.query = 'ali';
      await c.searchNow();
      expect(c.results.map((u) => u.id), ['s2']);
      c.query = '  ';
      await c.searchNow();
      expect(c.results, isEmpty);
    });

    test('a slow older search never overwrites a newer one', () async {
      users.delays['a'] = const Duration(milliseconds: 50);
      final c = UserSearchController(users: users, debounce: Duration.zero);
      c.query = 'a';
      final slow = c.searchNow();
      c.query = 'teacher';
      await c.searchNow();
      await slow;
      expect(c.results.map((u) => u.id), ['t1']);
      expect(c.isLoading, isFalse);
    });

    test('typing is debounced into one search', () async {
      final c = UserSearchController(users: users, debounce: const Duration(milliseconds: 30));
      for (final q in ['t', 'te', 'tea']) {
        c.onQueryChanged(q);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(users.searches, ['tea']);
      c.dispose();
    });

    test('a failed search shows no results and stops loading (no endless spinner)', () async {
      users.failing.add('searchByName');
      final c = UserSearchController(users: users, debounce: Duration.zero);
      c.query = 'ali';
      await c.searchNow();
      expect(c.results, isEmpty);
      expect(c.isLoading, isFalse);
    });

    test('a search finishing after dispose does not throw', () async {
      users.delays['ali'] = const Duration(milliseconds: 20);
      final c = UserSearchController(users: users, debounce: Duration.zero);
      c.query = 'ali';
      final pending = c.searchNow();
      c.dispose();
      await pending;
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('BlockedUsersController', () {
    test('lists blocked users live and unblocks', () async {
      repo.blocked['s1'] = ['t1', 's2'];
      final c = BlockedUsersController(repository: repo, users: users, session: studentSession)..start();
      await pumpEventQueue();
      expect(c.users.map((u) => u.id), ['t1', 's2']);
      expect(await c.unblock('t1'), isTrue);
      await pumpEventQueue();
      expect(c.users.map((u) => u.id), ['s2']);
      expect(repo.blocked['s1'], ['s2']);
      c.dispose();
    });

    test('a blocked user who deleted their account still shows (as unknown) so they can be unblocked', () async {
      repo.blocked['s1'] = ['gone'];
      final c = BlockedUsersController(repository: repo, users: users, session: studentSession)..start();
      await pumpEventQueue();
      expect(c.users.single.id, 'gone');
    });

    test('when the name lookup fails the ids are still listed (so they can be unblocked)', () async {
      users.failing.add('getUsers');
      repo.blocked['s1'] = ['t1'];
      final c = BlockedUsersController(repository: repo, users: users, session: studentSession)..start();
      await pumpEventQueue();
      expect(c.users.single.id, 't1');
      expect(c.isLoading, isFalse);
    });

    test('a failed unblock reports false and keeps the user listed', () async {
      repo.blocked['s1'] = ['t1'];
      repo.failing.add('unblockUser');
      final c = BlockedUsersController(repository: repo, users: users, session: studentSession)..start();
      await pumpEventQueue();
      expect(await c.unblock('t1'), isFalse);
      await pumpEventQueue();
      expect(c.users.single.id, 't1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('LikersController', () {
    test('me first, then the others; filter by name', () async {
      final c = LikersController(users: users, session: studentSession);
      await c.load({'t1', 's2', 's1'});
      expect(c.visible.first.id, 's1');
      expect(c.visible.map((u) => u.id).toSet(), {'s1', 't1', 's2'});
      c.filter = 'ALI';
      expect(c.visible.map((u) => u.id).toSet(), {'t1', 's2'});
    });

    test('a failed lookup stops loading with an empty list', () async {
      users.failing.add('getUsers');
      final c = LikersController(users: users, session: studentSession);
      await c.load({'t1'});
      expect(c.isLoading, isFalse);
      expect(c.visible, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('ProfilePostsController', () {
    setUp(() {
      repo.addPost(postBy('t1', id: 'a', day: 1, likers: {'s1'}));
      repo.addPost(postBy('t1', id: 'b', day: 2, hidden: true));
      repo.addPost(postBy('s2', id: 'c', day: 3));
    });

    test('a user\'s posts (hidden ones only for them / admins)', () async {
      final c = ProfilePostsController.byUser('t1', repository: repo, session: studentSession)..start();
      await pumpEventQueue();
      expect(c.posts.map((p) => p.id), ['a']);
      final own = ProfilePostsController.byUser('t1', repository: repo, session: teacherSession)..start();
      await pumpEventQueue();
      expect(own.posts.map((p) => p.id), ['b', 'a']);
    });

    test('posts I liked', () async {
      final c = ProfilePostsController.liked(repository: repo, session: studentSession)..start();
      await pumpEventQueue();
      expect(c.posts.map((p) => p.id), ['a']);
    });

    test('saved posts, live; saves of deleted posts are cleaned up', () async {
      repo.saved['s1'] = {'c', 'deleted'};
      final c = ProfilePostsController.saved(repository: repo, session: studentSession)..start();
      await pumpEventQueue();
      expect(c.posts.map((p) => p.id), ['c']);
      expect(repo.saved['s1'], {'c'}, reason: 'the save of the deleted post is removed');
      await repo.setSaved('a', userId: 's1', saved: true);
      await pumpEventQueue();
      expect(c.posts.map((p) => p.id).toSet(), {'a', 'c'});
      c.dispose();
    });

    test('guests have no liked / saved posts', () async {
      final c = ProfilePostsController.saved(repository: repo, session: guestSession)..start();
      await pumpEventQueue();
      expect(c.posts, isEmpty);
      expect(c.isLoading, isFalse);
    });
  });
}
