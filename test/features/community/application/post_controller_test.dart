import 'dart:async';

import 'package:calligro_app/features/community/application/post_controller.dart';
import 'package:calligro_app/features/community/application/saved_posts_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

void main() {
  late FakeCommunityRepository repo;
  late FakeMediaStorage media;

  PostController make(dynamic session, {String authorId = 't1', Set<String> likers = const {}, int likes = 0, bool pinned = false, bool hidden = false, List<String> images = const []}) {
    final post = postBy(authorId, likers: likers, likes: likes, pinned: pinned, hidden: hidden, images: images);
    repo.addPost(post);
    return PostController(post: post, session: session, repository: repo, media: media);
  }

  setUp(() {
    repo = FakeCommunityRepository();
    media = FakeMediaStorage();
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('likes', () {
    test('like: shows immediately (+1, liked) and is saved', () async {
      final c = make(studentSession, likes: 4);
      final future = c.toggleLike();
      expect(c.isLiked, isTrue, reason: 'optimistic');
      expect(c.likesCount, 5);
      expect(await future, LikeResult.done);
      expect(repo.posts['p1']!.likerIds, {'s1'});
    });

    test('unlike when already liked', () async {
      final c = make(studentSession, likes: 1, likers: {'s1'});
      expect(c.isLiked, isTrue);
      await c.toggleLike();
      expect(c.isLiked, isFalse);
      expect(c.likesCount, 0);
      expect(repo.posts['p1']!.likerIds, isEmpty);
    });

    test('server failure rolls back to the previous state', () async {
      final c = make(studentSession, likes: 4);
      repo.failing.add('setLiked');
      expect(await c.toggleLike(), LikeResult.failed);
      expect(c.isLiked, isFalse);
      expect(c.likesCount, 4);
    });

    test('taps while a like is in flight are ignored (no double counting)', () async {
      final c = make(studentSession, likes: 0);
      repo.gate = Completer<void>();
      final first = c.toggleLike();
      expect(await c.toggleLike(), LikeResult.ignored);
      repo.gate!.complete();
      await first;
      expect(repo.calls.where((x) => x == 'setLiked'), hasLength(1));
      expect(c.likesCount, 1);
    });

    test('guests can\'t like (the UI asks them to sign in)', () async {
      final c = make(guestSession);
      expect(await c.toggleLike(), LikeResult.needsAccount);
      expect(repo.calls, isEmpty);
    });

    test('the likers list includes my own fresh like', () async {
      final c = make(studentSession, likers: {'x'}, likes: 1);
      await c.toggleLike();
      expect(c.likerIds, {'x', 's1'});
    });

    test('server updates are applied — but not over a like in flight', () async {
      final c = make(studentSession, likes: 0);
      c.syncPost(postBy('t1', likes: 7, likers: {'a', 'b'}));
      expect(c.likesCount, 7);
      repo.gate = Completer<void>();
      final f = c.toggleLike();
      c.syncPost(postBy('t1', likes: 7, likers: {'a', 'b'}));
      expect(c.likesCount, 8, reason: 'keep the optimistic value');
      repo.gate!.complete();
      await f;
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('menu permissions', () {
    test('author', () {
      final c = make(studentSession, authorId: 's1');
      expect([c.canEdit, c.canDelete, c.canPinOrHide, c.canReportOrBlock], [true, true, false, false]);
    });
    test('admin', () {
      final c = make(adminSession);
      expect([c.canEdit, c.canDelete, c.canPinOrHide, c.canReportOrBlock], [false, true, true, false]);
    });
    test('another student', () {
      final c = make(studentSession);
      expect([c.canEdit, c.canDelete, c.canPinOrHide, c.canReportOrBlock], [false, false, false, true]);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('actions', () {
    test('delete: removes the post and its images from storage', () async {
      final c = make(studentSession, authorId: 's1', images: ['https://img/1', 'https://img/2']);
      final f = c.delete();
      expect(c.isDeleting, isTrue);
      expect(await f, isTrue);
      expect(repo.posts, isEmpty);
      expect(media.deleted, ['https://img/1', 'https://img/2']);
      expect(c.isDeleting, isFalse);
    });

    test('delete is refused for someone who may not delete', () async {
      final c = make(studentSession);
      expect(await c.delete(), isFalse);
      expect(repo.calls, isEmpty);
    });

    test('delete failure keeps the post and the images', () async {
      final c = make(adminSession, images: ['https://img/1']);
      repo.failing.add('deletePost');
      expect(await c.delete(), isFalse);
      expect(media.deleted, isEmpty);
      expect(c.lastError, contains('deletePost failed'));
    });

    test('pin / hide (admin) flip the flags', () async {
      final c = make(adminSession);
      expect(await c.togglePinned(), isTrue);
      expect(c.post.isPinned, isTrue);
      expect(repo.posts['p1']!.isPinned, isTrue);
      expect(await c.toggleHidden(), isTrue);
      expect(c.post.isHidden, isTrue);
      expect(await c.toggleHidden(), isTrue);
      expect(repo.posts['p1']!.isHidden, isFalse);
    });

    test('non-admins cannot pin or hide', () async {
      final c = make(teacherSession);
      expect(await c.togglePinned(), isFalse);
      expect(await c.toggleHidden(), isFalse);
      expect(repo.calls, isEmpty);
    });

    test('report and block the author', () async {
      final c = make(studentSession);
      expect(await c.report(), isTrue);
      expect(repo.reports.single, (postId: 'p1', reporterId: 's1'));
      expect(await c.blockAuthor(), isTrue);
      expect(repo.blocked['s1'], ['t1']);
    });

    test('my own post can\'t be reported or its author blocked', () async {
      final c = make(studentSession, authorId: 's1');
      expect(await c.report(), isFalse);
      expect(await c.blockAuthor(), isFalse);
      expect(repo.calls, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('saved posts (shared across screens)', () {
    test('reflects the server, toggles optimistically, rolls back on failure', () async {
      repo.saved['s1'] = {'p9'};
      final store = SavedPostsStore(repository: repo, userId: 's1')..start();
      await pumpEventQueue();
      expect(store.isSaved('p9'), isTrue);

      expect(await store.toggle('p1'), isTrue);
      expect(store.isSaved('p1'), isTrue);
      expect(repo.saved['s1'], contains('p1'));

      repo.failing.add('setSaved');
      expect(await store.toggle('p1'), isFalse);
      expect(store.isSaved('p1'), isTrue, reason: 'rolled back to saved');
      store.dispose();
    });

    test('guests have nothing saved and can\'t save', () async {
      final store = SavedPostsStore(repository: repo, userId: '')..start();
      expect(await store.toggle('p1'), isFalse);
      expect(store.isSaved('p1'), isFalse);
      store.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('caption translation', () {
    late FakeTranslator translator;
    setUp(() => translator = FakeTranslator());

    test('offers the other languages (detected once, then cached)', () async {
      final t = CaptionTranslationController(text: 'مرحبا', translator: translator);
      expect(await t.targetLanguages(), ['en', 'tr']);
      expect(await t.targetLanguages(), ['en', 'tr']);
      expect(translator.identifyCalls, 1);
    });

    test('unknown language → all three are offered', () async {
      translator.language = 'und';
      final t = CaptionTranslationController(text: '??', translator: translator);
      expect(await t.targetLanguages(), ['en', 'ar', 'tr']);
    });

    test('translate, then show the original again', () async {
      final t = CaptionTranslationController(text: 'hello', translator: translator);
      final f = t.translateTo('tr');
      expect(t.isTranslating, isTrue);
      await f;
      expect(t.isShowingTranslation, isTrue);
      expect(t.displayText, '[tr] hello');
      t.showOriginal();
      expect(t.displayText, 'hello');
    });

    test('a failed translation keeps the original', () async {
      translator.fail = true;
      final t = CaptionTranslationController(text: 'hello', translator: translator);
      await t.translateTo('ar');
      expect(t.isShowingTranslation, isFalse);
      expect(t.isTranslating, isFalse);
      expect(t.displayText, 'hello');
    });
  });
}
