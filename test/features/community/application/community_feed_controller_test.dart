import 'package:calligro_app/features/community/application/community_feed_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_filter.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';
import '../fakes/fake_follow_repository.dart';

void main() {
  group('CommunityFeedController Tests', () {
    late FakeCommunityRepository fakeRepo;
    late FakeFollowRepository fakeFollow;
    late CommunityFeedController controller;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      fakeFollow = FakeFollowRepository();

      // Seed posts
      fakeRepo.posts.addAll([
        CommunityPost(
          id: 'p1',
          authorId: 'u1',
          authorName: 'Yazan',
          authorRole: 'teacher',
          caption: 'Teacher calligraphy post',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          likesCount: 10,
          isPinned: true,
        ),
        CommunityPost(
          id: 'p2',
          authorId: 'u2',
          authorName: 'Student Ali',
          authorRole: 'student',
          caption: 'Student practice',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
          likesCount: 2,
        ),
        CommunityPost(
          id: 'p3',
          authorId: 'me',
          authorName: 'My Account',
          authorRole: 'student',
          caption: 'My artwork',
          createdAt: DateTime.now(),
          likesCount: 50,
        ),
      ]);

      controller = CommunityFeedController(
        repository: fakeRepo,
        followRepository: fakeFollow,
        currentUserId: 'me',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial load loads all feed posts and pinned posts', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);
      expect(controller.posts.length, 3);
      expect(controller.pinnedPosts.length, 1);
      expect(controller.pinnedPosts.first.id, 'p1');
      expect(controller.selectedFilter, CommunityFilter.all);
    });

    test('switching filter to myPosts filters correctly', () async {
      await controller.init();
      await controller.setFilter(CommunityFilter.myPosts);
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedFilter, CommunityFilter.myPosts);
      expect(controller.posts.length, 1);
      expect(controller.posts.first.id, 'p3');
    });

    test('switching filter to teachers filters correctly', () async {
      await controller.init();
      await controller.setFilter(CommunityFilter.teachers);
      await Future<void>.delayed(Duration.zero);

      expect(controller.posts.length, 1);
      expect(controller.posts.first.id, 'p1');
      expect(controller.posts.first.isTeacher, isTrue);
    });

    test('switching filter to popular sorts by likes descending', () async {
      await controller.init();
      await controller.setFilter(CommunityFilter.popular);
      await Future<void>.delayed(Duration.zero);

      expect(controller.posts.first.id, 'p3'); // 50 likes
      expect(controller.posts.first.likesCount, 50);
    });

    test('toggleSavePost saves and removes posts', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPostSaved('p2'), isFalse);

      await controller.toggleSave('p2');
      expect(controller.isPostSaved('p2'), isTrue);

      await controller.setFilter(CommunityFilter.saved);
      await Future<void>.delayed(Duration.zero);
      expect(controller.posts.length, 1);
      expect(controller.posts.first.id, 'p2');

      // Unsave
      await controller.toggleSave('p2');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPostSaved('p2'), isFalse);
    });

    test('deletePost removes post from feed', () async {
      await controller.init();
      await Future<void>.delayed(Duration.zero);
      expect(controller.posts.length, 3);

      await controller.deletePost(postId: 'p2', authorId: 'u2', imageUrls: []);
      await Future<void>.delayed(Duration.zero);
      expect(controller.posts.any((p) => p.id == 'p2'), isFalse);
    });

    test('pullToRefresh refreshes feed smoothly', () async {
      await controller.init();
      await controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.isLoading, isFalse);
      expect(controller.posts.length, 3);
    });
  });
}
