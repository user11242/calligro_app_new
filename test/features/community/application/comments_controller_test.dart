import 'dart:async';

import 'package:calligro_app/features/community/application/comments_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

void main() {
  late FakeCommunityRepository repo;

  CommentsController make(CommunitySession session, {String postAuthorId = 't1'}) =>
      CommentsController(repository: repo, session: session, postId: 'p1', postAuthorId: postAuthorId)..start();

  setUp(() => repo = FakeCommunityRepository());

  test('shows the post\'s comments live', () async {
    final c = make(studentSession);
    expect(c.isLoading, isTrue);
    await pumpEventQueue();
    expect(c.isLoading, isFalse);
    expect(c.comments, isEmpty);
    await repo.addComment('p1', author: teacherSession, text: 'Welcome');
    await pumpEventQueue();
    expect(c.comments.single.text, 'Welcome');
    c.dispose();
  });

  group('sending', () {
    test('a comment, trimmed', () async {
      final c = make(studentSession);
      expect(await c.send('  Beautiful  '), SendResult.sent);
      expect(repo.comments['p1']!.single.text, 'Beautiful');
      expect(repo.comments['p1']!.single.authorId, 's1');
    });

    test('blank text is refused', () async {
      final c = make(studentSession);
      expect(await c.send('   '), SendResult.invalid);
      expect(repo.calls, isEmpty);
    });

    test('guests must sign in', () async {
      final c = make(guestSession);
      expect(c.canWrite, isFalse);
      expect(await c.send('hi'), SendResult.needsAccount);
      expect(repo.calls, isEmpty);
    });

    test('a reply goes under the TOP-LEVEL comment, even when replying to a reply', () async {
      final c = make(studentSession);
      const root = CommunityComment(id: 'c1', authorId: 't1', authorName: 'Teacher');
      c.replyTo(root, toName: 'Someone in the thread');
      expect(c.replyingToName, 'Someone in the thread');
      expect(await c.send('thanks'), SendResult.sent);
      expect(repo.replies['c1']!.single.text, 'thanks');
      expect(c.replyingToName, isNull, reason: 'reply mode ends after sending');
    });

    test('guests can\'t enter reply mode; cancel leaves it', () {
      final g = make(guestSession);
      expect(g.replyTo(const CommunityComment(id: 'c1', authorId: 't1'), toName: 'T'), isFalse);
      final c = make(studentSession);
      c.replyTo(const CommunityComment(id: 'c1', authorId: 't1'), toName: 'T');
      c.cancelReply();
      expect(c.replyingToName, isNull);
    });

    test('double send while sending is ignored', () async {
      final c = make(studentSession);
      repo.gate = Completer<void>();
      final first = c.send('one');
      expect(c.isSending, isTrue);
      expect(await c.send('two'), SendResult.busy);
      repo.gate!.complete();
      await first;
      expect(repo.calls.where((x) => x == 'addComment'), hasLength(1));
    });

    test('failure is reported and the reply target is kept', () async {
      final c = make(studentSession);
      c.replyTo(const CommunityComment(id: 'c1', authorId: 't1'), toName: 'T');
      repo.failing.add('addReply');
      expect(await c.send('x'), SendResult.failed);
      expect(c.replyingToName, 'T');
      expect(c.isSending, isFalse);
    });
  });

  group('edit / delete permissions', () {
    const mine = CommunityComment(id: 'c1', authorId: 's1');
    const theirs = CommunityComment(id: 'c2', authorId: 's2');

    test('edit: only my own comment, and not to blank', () async {
      final c = make(studentSession);
      repo.comments['p1'] = [mine, theirs];
      expect(c.canEdit(mine), isTrue);
      expect(c.canEdit(theirs), isFalse);
      expect(await c.editComment(theirs, 'x'), isFalse);
      expect(await c.editComment(mine, '  '), isFalse);
      expect(await c.editComment(mine, ' fixed '), isTrue);
      expect(repo.comments['p1']!.first.text, 'fixed');
    });

    test('delete comment: mine, or anything on my post, or as admin', () async {
      expect(make(studentSession).canDelete(theirs), isFalse);
      expect(make(studentSession).canDelete(mine), isTrue);
      expect(make(studentSession, postAuthorId: 's1').canDelete(theirs), isTrue);
      expect(make(adminSession).canDelete(theirs), isTrue);
      final c = make(studentSession);
      repo.comments['p1'] = [mine, theirs];
      expect(await c.deleteComment(theirs), isFalse);
      expect(await c.deleteComment(mine), isTrue);
      expect(repo.comments['p1']!.map((x) => x.id), ['c2']);
    });

    test('replies: edit mine; delete mine or as the parent comment author or admin', () async {
      const root = CommunityComment(id: 'c1', authorId: 's1');
      const reply = CommunityComment(id: 'r1', authorId: 's2');
      final c = make(studentSession);
      expect(c.canDeleteReply(reply, parent: root), isTrue, reason: 'I wrote the parent comment');
      expect(c.canEditReply(reply), isFalse);
      repo.replies['c1'] = [reply];
      expect(await c.deleteReply(reply, parent: root), isTrue);
      expect(repo.replies['c1'], isEmpty);
      expect(make(teacherSession).canDeleteReply(reply, parent: root), isFalse,
          reason: 'the post author can\'t (firestore.rules)');
    });

    test('server failures return false', () async {
      final c = make(studentSession);
      repo.failing.addAll(['deleteComment', 'editComment']);
      expect(await c.deleteComment(mine), isFalse);
      expect(await c.editComment(mine, 'x'), isFalse);
    });
  });

  test('replies of a comment are live', () async {
    final c = make(studentSession);
    final replies = <int>[];
    final sub = c.watchReplies('c1').listen((r) => replies.add(r.length));
    await pumpEventQueue();
    await repo.addReply('p1', 'c1', author: teacherSession, text: 'r');
    await pumpEventQueue();
    expect(replies, [0, 1]);
    await sub.cancel();
  });
}
