import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/pages/blocked_users_page.dart';
import 'package:calligro_app/features/community/presentation/pages/search_users_page.dart';
import 'package:calligro_app/features/community/presentation/pages/single_post_page.dart';
import 'package:calligro_app/features/community/presentation/widgets/follow_button.dart';
import 'package:calligro_app/features/community/presentation/widgets/profile_posts_section.dart';
import 'package:calligro_app/features/community/presentation/widgets/user_posts_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';
import 'community_harness.dart';

/// Follow button, search, blocked users, single post and profile post lists — real widgets on fakes.
void main() {
  late CommunityHarness h;
  Finder key(String k) => find.byKey(Key(k));

  setUp(() {
    h = CommunityHarness();
    h.users
      ..users['t1'] = const CommunityUser(id: 't1', name: 'Teacher Ali', role: 'teacher')
      ..users['s2'] = const CommunityUser(id: 's2', name: 'Sara');
  });

  group('FollowButton', () {
    Future<void> show(WidgetTester tester, String me, String target) =>
        h.pump(tester, Scaffold(body: Center(child: FollowButton(currentUserId: me, targetUserId: target))));

    testWidgets('Follow → Following → Follow, stored both ways', (tester) async {
      await show(tester, 's1', 't1');
      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(key('follow-button'));
      await settle(tester);
      expect(find.text('Following'), findsOneWidget);
      expect(h.follows.following['s1'], {'t1'});
      await tester.tap(key('follow-button'));
      await settle(tester);
      expect(find.text('Follow'), findsOneWidget);
      expect(h.follows.following['s1'], isEmpty);
    });

    testWidgets('a failed follow goes back to Follow', (tester) async {
      h.follows.failing.add('setFollowing');
      await show(tester, 's1', 't1');
      await tester.tap(key('follow-button'));
      await settle(tester);
      expect(find.text('Follow'), findsOneWidget);
      await drainMessages(tester);
    });

    testWidgets('hidden on your own profile and for guests', (tester) async {
      await show(tester, 's1', 's1');
      expect(key('follow-button'), findsNothing);
      await show(tester, '', 't1');
      expect(key('follow-button'), findsNothing);
    });
  });

  group('SearchUsersPage', () {
    testWidgets('typing searches (debounced) and tapping a result opens that profile', (tester) async {
      final opened = <String>[];
      await h.pump(tester, SearchUsersPage(session: studentSession, onOpenProfile: (id, _) => opened.add(id)));
      await tester.enterText(key('user-search'), 'Sa');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(key('search-result-s2'), findsOneWidget);
      expect(key('search-result-t1'), findsNothing);
      expect(h.users.searches, ['Sa']);
      await tester.tap(key('search-result-s2'));
      expect(opened, ['s2']);
    });

    testWidgets('no match shows "no users found"', (tester) async {
      await h.pump(tester, SearchUsersPage(session: studentSession, onOpenProfile: (_, _) {}));
      await tester.enterText(key('user-search'), 'zzz');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(find.text('No users found'), findsOneWidget);
    });
  });

  group('BlockedUsersPage', () {
    testWidgets('lists blocked people; unblock removes them', (tester) async {
      h.repo.blocked['s1'] = ['t1', 's2'];
      await h.pump(tester, const BlockedUsersPage());
      expect(find.text('Teacher Ali'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      await tester.tap(key('unblock-t1'));
      await settle(tester);
      expect(h.repo.blocked['s1'], ['s2']);
      expect(key('blocked-t1'), findsNothing);
      await drainMessages(tester);
    });

    testWidgets('nobody blocked shows the empty message', (tester) async {
      await h.pump(tester, const BlockedUsersPage());
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });

  group('SinglePostPage', () {
    testWidgets('shows the linked post', (tester) async {
      h.repo.addPost(postBy('t1', id: 'p9', caption: 'Shared post'));
      await h.pump(tester, const SinglePostPage(postId: 'p9'));
      expect(find.text('Shared post'), findsOneWidget);
      expect(find.text('Teacher Ali'), findsOneWidget, reason: 'current author name');
    });

    testWidgets('a deleted / missing post shows "nothing to show"', (tester) async {
      await h.pump(tester, const SinglePostPage(postId: 'nope'));
      expect(key('post-not-found'), findsOneWidget);
    });

    testWidgets('a hidden post is not shown to another student', (tester) async {
      h.repo.addPost(postBy('t1', id: 'p9', hidden: true));
      await h.pump(tester, const SinglePostPage(postId: 'p9'));
      expect(key('post-not-found'), findsOneWidget);
    });
  });

  group('profile post lists', () {
    setUp(() {
      for (var d = 1; d <= 4; d++) {
        h.repo.addPost(postBy('t1', id: 'p$d', day: d, caption: 'post $d', likers: d.isEven ? {'s1'} : {}));
      }
    });

    testWidgets('a user\'s section: newest 3 and "See all" opens all 4', (tester) async {
      await h.pump(
          tester, const Scaffold(body: SingleChildScrollView(child: ProfilePostsSection.byUser(title: 'Posts', userId: 't1'))));
      expect(find.text('post 4'), findsOneWidget);
      expect(find.text('post 1'), findsNothing);
      await tester.tap(key('see-all'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('post 1'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('post 1'), findsOneWidget);
    });

    testWidgets('liked section shows the posts I liked', (tester) async {
      await h.pump(tester, const Scaffold(body: SingleChildScrollView(child: ProfilePostsSection.liked(title: 'Liked'))));
      expect(find.text('post 2'), findsOneWidget);
      expect(find.text('post 4'), findsOneWidget);
      expect(find.text('post 3'), findsNothing);
    });

    testWidgets('saved section shows my bookmarks, live', (tester) async {
      h.repo.saved['s1'] = {'p3'};
      await h.pump(tester, const Scaffold(body: SingleChildScrollView(child: ProfilePostsSection.saved(title: 'Saved'))));
      expect(find.text('post 3'), findsOneWidget);
      await tester.tap(key('save'));
      await settle(tester);
      expect(find.text('post 3'), findsNothing, reason: 'unsaved → leaves the Saved list');
    });

    testWidgets('UserPostsView gives the page the visible count and the list', (tester) async {
      await h.pump(
        tester,
        Scaffold(
          body: UserPostsView(
            userId: 't1',
            builder: (context, count, list) => Column(children: [Text('count=$count'), Expanded(child: list)]),
          ),
        ),
      );
      expect(find.text('count=4'), findsOneWidget);
      expect(find.text('post 4'), findsOneWidget);
    });
  });
}
