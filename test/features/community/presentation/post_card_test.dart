import 'package:calligro_app/features/community/application/saved_posts_store.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';
import 'community_harness.dart';

/// The real PostCard (the widget in every feed and profile) on fakes.
void main() {
  late CommunityHarness h;
  late SavedPostsStore saved;

  Future<void> show(WidgetTester tester, {CommunitySession session = studentSession, String postId = 'p1'}) async {
    h.sessions.session = session;
    saved = h.savedStore();
    addTearDown(saved.dispose);
    await h.pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: StreamBuilder(
            stream: h.repo.watchPost(postId),
            builder: (context, snap) => snap.data == null
                ? const SizedBox(key: Key('gone'))
                : PostCard(post: snap.data!, session: session, saved: saved),
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('post-menu')));
    await settle(tester);
  }

  setUp(() {
    h = CommunityHarness();
    h.repo.addPost(postBy('t1', id: 'p1', role: 'teacher', caption: 'My first Thuluth', likes: 2, likers: {'x', 'y'}));
  });

  testWidgets('shows the author, teacher badge, caption and counts', (tester) async {
    await show(tester);
    expect(find.text('Author t1'), findsOneWidget);
    expect(find.byKey(const Key('teacher-badge')), findsOneWidget);
    expect(find.text('My first Thuluth'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('likes-count'))).data, '2');
    expect(find.byKey(const Key('admin-badge')), findsNothing);
  });

  group('like', () {
    testWidgets('tap likes (count +1, saved to the repository); tap again unlikes', (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const Key('like')));
      await settle(tester);
      expect(tester.widget<Text>(find.byKey(const Key('likes-count'))).data, '3');
      expect(h.repo.posts['p1']!.likerIds, contains('s1'));

      await tester.tap(find.byKey(const Key('like')));
      await settle(tester);
      expect(tester.widget<Text>(find.byKey(const Key('likes-count'))).data, '2');
      expect(h.repo.posts['p1']!.likerIds, isNot(contains('s1')));
    });

    testWidgets('a failed like goes back to the old count', (tester) async {
      h.repo.failing.add('setLiked');
      await show(tester);
      await tester.tap(find.byKey(const Key('like')));
      await settle(tester);
      expect(tester.widget<Text>(find.byKey(const Key('likes-count'))).data, '2');
    });

    testWidgets('guests get the sign-in prompt and nothing is written', (tester) async {
      await show(tester, session: guestSession);
      await tester.tap(find.byKey(const Key('like')));
      await settle(tester);
      expect(signInPrompt, findsOneWidget);
      expect(h.repo.calls, isNot(contains('setLiked')));
    });
  });

  group('save', () {
    testWidgets('bookmark toggles and is stored for the viewer', (tester) async {
      await show(tester);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      await tester.tap(find.byKey(const Key('save')));
      await settle(tester);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(h.repo.saved['s1'], {'p1'});
    });

    testWidgets('guests get the sign-in prompt', (tester) async {
      await show(tester, session: guestSession);
      await tester.tap(find.byKey(const Key('save')));
      await settle(tester);
      expect(signInPrompt, findsOneWidget);
      expect(h.repo.calls, isNot(contains('setSaved')));
    });
  });

  group('menu shows only what the viewer may do', () {
    testWidgets('another student: report and block only', (tester) async {
      await show(tester);
      await openMenu(tester);
      expect(find.byKey(const Key('menu-report')), findsOneWidget);
      expect(find.byKey(const Key('menu-block')), findsOneWidget);
      for (final a in ['edit', 'delete', 'pin', 'hide']) {
        expect(find.byKey(Key('menu-$a')), findsNothing, reason: a);
      }
    });

    testWidgets('the author: edit and delete, no report/block', (tester) async {
      await show(tester, session: teacherSession);
      await openMenu(tester);
      expect(find.byKey(const Key('menu-edit')), findsOneWidget);
      expect(find.byKey(const Key('menu-delete')), findsOneWidget);
      expect(find.byKey(const Key('menu-report')), findsNothing);
      expect(find.byKey(const Key('menu-pin')), findsNothing);
    });

    testWidgets('an admin: pin, hide and delete (not edit someone else\'s post)', (tester) async {
      await show(tester, session: adminSession);
      await openMenu(tester);
      expect(find.byKey(const Key('menu-pin')), findsOneWidget);
      expect(find.byKey(const Key('menu-hide')), findsOneWidget);
      expect(find.byKey(const Key('menu-delete')), findsOneWidget);
      expect(find.byKey(const Key('menu-edit')), findsNothing);
    });

    testWidgets('guests see no menu', (tester) async {
      await show(tester, session: guestSession);
      expect(find.byKey(const Key('post-menu')), findsNothing);
    });
  });

  group('menu actions', () {
    testWidgets('delete asks first; cancel keeps the post', (tester) async {
      await show(tester, session: teacherSession);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-delete')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('dialog-cancel')));
      await settle(tester);
      expect(h.repo.posts, contains('p1'));
      expect(h.repo.calls, isNot(contains('deletePost')));
    });

    testWidgets('delete confirmed removes the post', (tester) async {
      await show(tester, session: teacherSession);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-delete')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await settle(tester);
      expect(h.repo.posts, isNot(contains('p1')));
      expect(find.byKey(const Key('gone')), findsOneWidget);
    });

    testWidgets('admin pin / hide write to the post', (tester) async {
      await show(tester, session: adminSession);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-pin')));
      await settle(tester);
      expect(h.repo.posts['p1']!.isPinned, isTrue);
      expect(find.text('PINNED POST'), findsOneWidget);
      await drainMessages(tester);

      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-hide')));
      await settle(tester);
      expect(h.repo.posts['p1']!.isHidden, isTrue);
      await drainMessages(tester);
    });

    testWidgets('report files a report by the viewer', (tester) async {
      await show(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-report')));
      await settle(tester);
      expect(h.repo.reports.single, (postId: 'p1', reporterId: 's1'));
      await drainMessages(tester);
    });

    testWidgets('block asks first, then blocks the author', (tester) async {
      await show(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-block')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await settle(tester);
      expect(h.repo.blocked['s1'], ['t1']);
      await drainMessages(tester);
    });

    testWidgets('edit opens the editor with the caption; saving updates the post', (tester) async {
      await show(tester, session: teacherSession);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-edit')));
      await settle(tester);
      final field = find.byKey(const Key('caption-field'));
      expect(tester.widget<TextField>(field).controller!.text, 'My first Thuluth');
      await tester.enterText(field, 'Edited caption');
      await tester.tap(find.byKey(const Key('submit-post')));
      await settle(tester);
      expect(h.repo.posts['p1']!.caption, 'Edited caption');
      expect(find.text('Edited caption'), findsOneWidget, reason: 'card updates live');
      await drainMessages(tester);
    });
  });

  group('sheets', () {
    testWidgets('likers sheet lists who liked, by name', (tester) async {
      h.users
        ..users['x'] = const CommunityUser(id: 'x', name: 'Xena')
        ..users['y'] = const CommunityUser(id: 'y', name: 'Yusuf', role: 'teacher');
      await show(tester);
      await tester.tap(find.byKey(const Key('likers')));
      await settle(tester);
      expect(find.byKey(const Key('liker-x')), findsOneWidget);
      expect(find.byKey(const Key('liker-y')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('likers-search')), 'yus');
      await settle(tester);
      expect(find.byKey(const Key('liker-x')), findsNothing);
      expect(find.byKey(const Key('liker-y')), findsOneWidget);
    });

    testWidgets('comments sheet: read and write a comment', (tester) async {
      h.repo.comments['p1'] = [
        const CommunityComment(id: 'c0', authorId: 'y', authorName: 'Yusuf', text: 'Beautiful!'),
      ];
      await show(tester);
      await tester.tap(find.byKey(const Key('comments')));
      await settle(tester);
      expect(find.text('Beautiful!'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('comment-field')), 'Thank you');
      await tester.tap(find.byKey(const Key('send-comment')));
      await settle(tester);
      expect(h.repo.comments['p1']!.first.text, 'Thank you');
      expect(h.repo.comments['p1']!.first.authorId, 's1');
      expect(find.text('Thank you'), findsOneWidget);
    });
  });
}
