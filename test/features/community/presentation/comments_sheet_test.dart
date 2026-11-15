import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/widgets/comments_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';
import 'community_harness.dart';

/// The real comments sheet on fakes. Post p1 is by t1.
void main() {
  late CommunityHarness h;
  final opened = <(String, String)>[];

  Future<void> show(WidgetTester tester, CommunitySession session) async {
    h.sessions.session = session;
    await h.pump(
      tester,
      Scaffold(
        body: CommentsBottomSheet(
          postId: 'p1',
          postAuthorId: 't1',
          session: session,
          onOpenProfile: (id, role) => opened.add((id, role)),
        ),
      ),
    );
  }

  Finder inComment(String id, Finder f) => find.descendant(of: find.byKey(ValueKey('comment-$id')), matching: f);

  setUp(() {
    opened.clear();
    h = CommunityHarness();
    h.repo.comments['p1'] = [
      const CommunityComment(id: 'c1', authorId: 's2', authorName: 'Sara', authorRole: 'student', text: 'Lovely'),
      const CommunityComment(id: 'c2', authorId: 's1', authorName: 'Student One', text: 'Mine'),
    ];
    h.repo.replies['c1'] = [
      const CommunityComment(id: 'r1', authorId: 't1', authorName: 'Teacher One', authorRole: 'teacher', text: 'Thanks Sara'),
    ];
  });

  testWidgets('shows comments with their replies', (tester) async {
    await show(tester, studentSession);
    expect(find.text('Lovely'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Thanks Sara'), findsOneWidget);
  });

  testWidgets('empty post shows the empty message', (tester) async {
    h.repo.comments.clear();
    await show(tester, studentSession);
    expect(find.byKey(const Key('no-comments')), findsOneWidget);
  });

  testWidgets('reply: banner names who is answered, the reply attaches to the ROOT comment', (tester) async {
    await show(tester, studentSession);
    // Reply to the teacher's reply inside Sara's thread.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('reply-r1')), matching: find.byKey(const Key('comment-reply'))).first);
    await settle(tester);
    expect(find.text('Teacher One'), findsWidgets);
    expect(find.byKey(const Key('cancel-reply')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('comment-field')), 'Agreed');
    await tester.tap(find.byKey(const Key('send-comment')));
    await settle(tester);
    expect(h.repo.replies['c1']!.last.text, 'Agreed');
    expect(h.repo.calls, isNot(contains('addComment')));
    expect(find.byKey(const Key('cancel-reply')), findsNothing, reason: 'back to a normal comment after sending');
  });

  testWidgets('cancel reply goes back to a top-level comment', (tester) async {
    await show(tester, studentSession);
    await tester.tap(inComment('c1', find.byKey(const Key('comment-reply'))).first);
    await settle(tester);
    await tester.tap(find.byKey(const Key('cancel-reply')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('comment-field')), 'Top level');
    await tester.tap(find.byKey(const Key('send-comment')));
    await settle(tester);
    expect(h.repo.comments['p1']!.first.text, 'Top level');
  });

  testWidgets('a failed send keeps the text so nothing is lost', (tester) async {
    h.repo.failing.add('addComment');
    await show(tester, studentSession);
    await tester.enterText(find.byKey(const Key('comment-field')), 'Keep me');
    await tester.tap(find.byKey(const Key('send-comment')));
    await settle(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('comment-field'))).controller!.text, 'Keep me');
    await drainMessages(tester);
  });

  group('who may edit / delete', () {
    testWidgets('a student: menu only on their own comment', (tester) async {
      await show(tester, studentSession);
      expect(inComment('c2', find.byKey(const Key('comment-menu'))), findsOneWidget);
      expect(inComment('c1', find.byKey(const Key('comment-menu'))), findsNothing);
    });

    testWidgets('the post author may delete (not edit) others\' comments', (tester) async {
      await show(tester, teacherSession);
      await tester.tap(inComment('c1', find.byKey(const Key('comment-menu'))).first);
      await settle(tester);
      expect(find.byKey(const Key('comment-delete')), findsOneWidget);
      expect(find.byKey(const Key('comment-edit')), findsNothing);
    });

    testWidgets('delete asks first, then removes the comment', (tester) async {
      await show(tester, studentSession);
      await tester.tap(inComment('c2', find.byKey(const Key('comment-menu'))));
      await settle(tester);
      await tester.tap(find.byKey(const Key('comment-delete')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await settle(tester);
      expect(h.repo.comments['p1']!.map((c) => c.id), ['c1']);
      expect(find.text('Mine'), findsNothing);
    });
  });

  testWidgets('guests read comments but get a sign-in button instead of the text field', (tester) async {
    await show(tester, guestSession);
    expect(find.text('Lovely'), findsOneWidget);
    expect(find.byKey(const Key('comment-field')), findsNothing);
    await tester.tap(find.byKey(const Key('login-to-interact')));
    await settle(tester);
    expect(signInPrompt, findsOneWidget);
  });

  testWidgets('guests tapping reply get the sign-in prompt', (tester) async {
    await show(tester, guestSession);
    await tester.tap(inComment('c1', find.byKey(const Key('comment-reply'))).first);
    await settle(tester);
    expect(signInPrompt, findsOneWidget);
  });

  testWidgets('tapping an avatar opens that profile', (tester) async {
    await show(tester, studentSession);
    await tester.tap(inComment('c1', find.byKey(const Key('comment-avatar'))).first);
    expect(opened, [('s2', 'student')]);
  });
}
