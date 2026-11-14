import 'package:calligro_app/features/community/application/post_detail_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_comment.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';

void main() {
  group('PostDetailController Tests', () {
    late FakeCommunityRepository fakeRepo;
    late CommunityPost post;
    late PostDetailController controller;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      post = CommunityPost(
        id: 'p1',
        authorId: 'u1',
        authorName: 'Yazan',
        caption: 'Detailed discussion post',
        createdAt: DateTime.now(),
        commentsCount: 1,
      );
      fakeRepo.posts.add(post);
      fakeRepo.commentsByPost['p1'] = [
        CommunityComment(
          id: 'c1',
          postId: 'p1',
          authorId: 'u2',
          authorName: 'Ahmad',
          text: 'Initial comment',
          createdAt: DateTime.now(),
        ),
      ];

      controller = PostDetailController(
        repository: fakeRepo,
        postId: 'p1',
        initialPost: post,
        currentUserId: 'me',
        currentUserName: 'My Name',
        currentUserPhotoUrl: 'photo.jpg',
        currentUserRole: 'student',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes and streams comments', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);
      expect(controller.comments.length, 1);
      expect(controller.comments.first.text, 'Initial comment');
    });

    test('addComment adds comment and clears comment text', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);

      final success = await controller.addComment('New awesome calligraphy comment!');
      expect(success, isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(controller.comments.length, 2);
      expect(controller.comments.last.text, 'New awesome calligraphy comment!');
      expect(controller.post?.commentsCount, 2);
    });

    test('addComment rejects empty text with error', () async {
      await controller.init();
      final success = await controller.addComment('    ');
      expect(success, isFalse);
      expect(controller.errorMessage, isNotNull);
    });

    test('deleteComment removes comment from list', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);

      await controller.deleteComment('c1');
      await Future<void>.delayed(Duration.zero);

      expect(controller.comments.isEmpty, isTrue);
    });

    test('reportPost and blockAuthor succeed', () async {
      await controller.reportPost('Inappropriate content');
      expect(fakeRepo.reports.length, 1);
      expect(fakeRepo.reports.first['reason'], 'Inappropriate content');

      await controller.blockAuthor();
      expect(fakeRepo.blockedUsers.contains('u1'), isTrue);
    });
  });
}

