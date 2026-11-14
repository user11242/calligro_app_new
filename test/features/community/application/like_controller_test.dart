import 'package:calligro_app/features/community/application/like_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';

void main() {
  group('LikeController Tests (Optimistic & Rollback)', () {
    late FakeCommunityRepository fakeRepo;
    late CommunityPost testPost;
    late LikeController controller;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      testPost = CommunityPost(
        id: 'post_1',
        authorId: 'author_1',
        authorName: 'Yazan',
        caption: 'Test post',
        createdAt: DateTime.now(),
        likesCount: 10,
        isLikedByMe: false,
      );
      fakeRepo.posts.add(testPost);
      controller = LikeController(
        repository: fakeRepo,
        currentUserId: 'me_1',
        initialLikesCount: testPost.likesCount,
        initialIsLiked: testPost.isLikedByMe,
        postId: testPost.id,
      );
    });

    test('optimistic like updates state immediately before network returns', () async {
      expect(controller.isLiked, isFalse);
      expect(controller.likesCount, 10);

      final future = controller.toggleLike();
      // Right away before await completes:
      expect(controller.isLiked, isTrue);
      expect(controller.likesCount, 11);

      await future;
      expect(controller.isLiked, isTrue);
      expect(controller.likesCount, 11);
      expect(controller.lastError, isNull);
    });

    test('optimistic like ROLLS BACK when network fails', () async {
      fakeRepo.simulateNetworkErrorOnLike = true;
      expect(controller.isLiked, isFalse);
      expect(controller.likesCount, 10);

      // Trigger like
      final future = controller.toggleLike();

      // Optimistically updated
      expect(controller.isLiked, isTrue);
      expect(controller.likesCount, 11);

      // Await network failure
      await future;

      // Must roll back to original state!
      expect(controller.isLiked, isFalse);
      expect(controller.likesCount, 10);
      expect(controller.lastError, isNotNull);
    });

    test('optimistic unlike ROLLS BACK when network fails', () async {
      // Start with already liked
      controller = LikeController(
        repository: fakeRepo,
        currentUserId: 'me_1',
        initialLikesCount: 15,
        initialIsLiked: true,
        postId: testPost.id,
      );

      fakeRepo.simulateNetworkErrorOnLike = true;
      expect(controller.isLiked, isTrue);
      expect(controller.likesCount, 15);

      final future = controller.toggleLike();

      // Optimistically unliked
      expect(controller.isLiked, isFalse);
      expect(controller.likesCount, 14);

      await future;

      // Rolled back to true and 15
      expect(controller.isLiked, isTrue);
      expect(controller.likesCount, 15);
      expect(controller.lastError, isNotNull);
    });

    test('rapid double-tap is debounced: does not fire parallel conflicting requests', () async {
      expect(controller.isLiked, isFalse);
      final first = controller.toggleLike();
      final second = controller.toggleLike(); // rapid second tap

      await Future.wait([first, second]);
      // After toggling on and off, it safely returns to false
      expect(controller.isLiked, isFalse);
      expect(controller.likesCount, 10);
    });
  });
}

