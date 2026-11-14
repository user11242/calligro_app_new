import 'package:calligro_app/features/community/application/profile_posts_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';

void main() {
  group('ProfilePostsController Tests', () {
    late FakeCommunityRepository fakeRepo;
    late ProfilePostsController controller;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      fakeRepo.posts.addAll([
        CommunityPost(
          id: 'p1',
          authorId: 'user_target',
          authorName: 'Target User',
          caption: 'First post',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        CommunityPost(
          id: 'p2',
          authorId: 'user_target',
          authorName: 'Target User',
          caption: 'Second post',
          createdAt: DateTime.now(),
        ),
        CommunityPost(
          id: 'p3',
          authorId: 'other_user',
          authorName: 'Other',
          caption: 'Other user post',
          createdAt: DateTime.now(),
        ),
      ]);

      controller = ProfilePostsController(
        repository: fakeRepo,
        targetUserId: 'user_target',
        currentUserId: 'me',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('streams only target user posts', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);

      expect(controller.posts.length, 2);
      expect(controller.posts.every((p) => p.authorId == 'user_target'), isTrue);
    });

    test('toggling view mode switches between grid and list', () {
      expect(controller.isGridView, isTrue);
      controller.toggleViewMode();
      expect(controller.isGridView, isFalse);
      controller.toggleViewMode();
      expect(controller.isGridView, isTrue);
    });

    test('deleting post updates list immediately', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);
      expect(controller.posts.length, 2);

      await controller.deletePost(postId: 'p1', authorId: 'user_target', imageUrls: []);
      expect(controller.posts.length, 1);
      expect(controller.posts.first.id, 'p2');
    });
  });
}

