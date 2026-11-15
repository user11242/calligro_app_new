import 'dart:async';

import 'package:calligro_app/features/community/application/post_editor_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/domain/policies/community_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

void main() {
  late FakeCommunityRepository repo;
  late FakeMediaStorage media;
  late FakeImagePicker picker;

  PostEditorController create(CommunitySession s) =>
      PostEditorController.create(repository: repo, media: media, session: s);

  setUp(() {
    repo = FakeCommunityRepository();
    media = FakeMediaStorage();
    picker = FakeImagePicker();
  });

  group('new post', () {
    test('caption + images: uploads, then creates the post', () async {
      final c = create(studentSession)..caption = '  Naskh  ';
      picker.next = ['/tmp/a.jpg', '/tmp/b.jpg'];
      expect(await c.addImages(picker), 2);
      expect(await c.submit(), EditorResult.saved);
      final post = repo.posts.values.single;
      expect(post.caption, 'Naskh');
      expect(post.imageUrls, ['https://cdn/s1/a.jpg', 'https://cdn/s1/b.jpg']);
      expect(post.authorId, 's1');
    });

    test('an empty post is refused before uploading anything', () async {
      final c = create(studentSession)..caption = '   ';
      expect(await c.submit(), EditorResult.invalid);
      expect(c.error, CommunityValidationError.emptyPost);
      expect(media.uploaded, isEmpty);
      expect(repo.calls, isEmpty);
    });

    test('never more than 5 images: the picker is asked only for the free slots', () async {
      final c = create(studentSession);
      picker.next = ['/1', '/2', '/3'];
      await c.addImages(picker);
      picker.next = ['/4', '/5', '/6', '/7'];
      expect(await c.addImages(picker), 2);
      expect(picker.requests, [5, 2]);
      expect(c.imageCount, 5);
      expect(c.canAddImages, isFalse);
      expect(await c.addImages(picker), 0, reason: 'full');
      expect(picker.requests, [5, 2], reason: 'picker not even opened');
    });

    test('remove a picked image', () async {
      final c = create(studentSession);
      picker.next = ['/1', '/2'];
      await c.addImages(picker);
      c.removeNewImage(0);
      expect(c.newImagePaths, ['/2']);
    });

    test('admins can attach a link (normalised) and pin / hide; students cannot', () async {
      final a = create(adminSession)
        ..caption = 'news'
        ..linkUrl = 'calligro.app'
        ..pin = true;
      expect(a.canUseAdminOptions, isTrue);
      await a.submit();
      final adminPost = repo.posts.values.single;
      expect(adminPost.linkUrl, 'https://calligro.app');
      expect(adminPost.isPinned, isTrue);

      repo.posts.clear();
      final s = create(studentSession)
        ..caption = 'x'
        ..linkUrl = 'evil.com'
        ..pin = true;
      expect(s.canUseAdminOptions, isFalse);
      await s.submit();
      expect(repo.posts.values.single.linkUrl, isNull);
      expect(repo.posts.values.single.isPinned, isFalse);
    });

    test('a link alone is a valid post (admins)', () async {
      final a = create(adminSession)..linkUrl = 'x.io';
      expect(await a.submit(), EditorResult.saved);
    });

    test('upload failure → nothing is created', () async {
      final c = create(studentSession)..caption = 'x';
      picker.next = ['/1'];
      await c.addImages(picker);
      media.fail = true;
      expect(await c.submit(), EditorResult.failed);
      expect(repo.posts, isEmpty);
      expect(c.isSaving, isFalse);
    });

    test('double submit while saving is ignored', () async {
      final c = create(studentSession)..caption = 'x';
      repo.gate = Completer<void>();
      final first = c.submit();
      expect(c.isSaving, isTrue);
      expect(await c.submit(), EditorResult.busy);
      repo.gate!.complete();
      expect(await first, EditorResult.saved);
      expect(repo.posts, hasLength(1));
    });

    test('guests can\'t post', () async {
      final c = create(guestSession)..caption = 'x';
      expect(await c.submit(), EditorResult.needsAccount);
    });
  });

  group('editing', () {
    late PostEditorController edit;
    setUp(() {
      repo.addPost(postBy('s1', images: ['https://cdn/old1', 'https://cdn/old2']));
      edit = PostEditorController.edit(post: repo.posts['p1']!, repository: repo, media: media, session: studentSession);
    });

    test('starts from the current caption and images', () {
      expect(edit.caption, 'Naskh practice');
      expect(edit.existingImageUrls, ['https://cdn/old1', 'https://cdn/old2']);
      expect(edit.isEditing, isTrue);
    });

    test('keep some old images, add new ones, change the caption', () async {
      edit
        ..caption = 'Updated'
        ..removeExistingImage(0);
      picker.next = ['/new.jpg'];
      await edit.addImages(picker);
      expect(picker.requests, [4], reason: '5 minus the 1 kept old image');
      expect(await edit.submit(), EditorResult.saved);
      final p = repo.posts['p1']!;
      expect(p.caption, 'Updated');
      expect(p.imageUrls, ['https://cdn/old2', 'https://cdn/s1/new.jpg']);
      expect(p.isEdited, isTrue);
    });

    test('an edit can\'t empty the post', () async {
      edit
        ..caption = ''
        ..removeExistingImage(0)
        ..removeExistingImage(0);
      expect(await edit.submit(), EditorResult.invalid);
      expect(repo.calls, isEmpty);
    });

    test('only the author can edit', () async {
      final other = PostEditorController.edit(
          post: repo.posts['p1']!, repository: repo, media: media, session: teacherSession)
        ..caption = 'hijack';
      expect(await other.submit(), EditorResult.notAllowed);
      expect(repo.posts['p1']!.caption, 'Naskh practice');
    });
  });
}
