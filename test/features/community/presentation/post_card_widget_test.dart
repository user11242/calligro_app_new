import 'package:calligro_app/features/community/application/like_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';

void main() {
  group('PostCard Widget & Action Tests', () {
    late FakeCommunityRepository fakeRepo;
    late CommunityPost testPost;
    late LikeController likeController;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      testPost = CommunityPost(
        id: 'p_100',
        authorId: 'u_100',
        authorName: 'Ustadha Fatima',
        authorRole: 'teacher',
        caption: 'Thuluth script composition practice',
        createdAt: DateTime.now(),
        likesCount: 25,
        commentsCount: 4,
        isLikedByMe: false,
      );
      fakeRepo.posts.add(testPost);

      likeController = LikeController(
        repository: fakeRepo,
        currentUserId: 'student_1',
        postId: testPost.id,
        initialLikesCount: testPost.likesCount,
        initialIsLiked: testPost.isLikedByMe,
      );
    });

    testWidgets('renders post author, badge, caption and stats correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: likeController,
              builder: (context, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(testPost.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              key: const Key('teacher-badge'),
                              child: Text(testPost.authorRole),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(testPost.caption),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              key: const Key('like-btn'),
                              icon: Icon(likeController.isLiked ? Icons.favorite : Icons.favorite_border),
                              onPressed: () => likeController.toggleLike(),
                            ),
                            Text('${likeController.likesCount}', key: const Key('likes-count')),
                            const SizedBox(width: 16),
                            IconButton(
                              key: const Key('comment-btn'),
                              icon: const Icon(Icons.mode_comment_outlined),
                              onPressed: () {},
                            ),
                            Text('${testPost.commentsCount}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Ustadha Fatima'), findsOneWidget);
      expect(find.byKey(const Key('teacher-badge')), findsOneWidget);
      expect(find.text('Thuluth script composition practice'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Tap like button
      await tester.tap(find.byKey(const Key('like-btn')));
      await tester.pump();

      // Optimistically shows 26 and filled heart!
      expect(find.text('26'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('optimistic like rollback on network failure reflects in UI', (tester) async {
      fakeRepo.simulateNetworkErrorOnLike = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: likeController,
              builder: (context, _) {
                return Column(
                  children: [
                    IconButton(
                      key: const Key('like-btn'),
                      icon: Icon(likeController.isLiked ? Icons.favorite : Icons.favorite_border),
                      onPressed: () => likeController.toggleLike(),
                    ),
                    Text('${likeController.likesCount}', key: const Key('likes-count')),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('25'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Tap like
      await tester.tap(find.byKey(const Key('like-btn')));
      await tester.pump(); // immediate frame

      // Optimistically liked
      expect(find.text('26'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Await the simulated error
      await tester.pumpAndSettle();

      // UI rolled back to 25 and hollow heart!
      expect(find.text('25'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}

