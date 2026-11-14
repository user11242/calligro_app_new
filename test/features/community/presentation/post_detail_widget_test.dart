import 'package:calligro_app/features/community/application/post_detail_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_comment.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';

void main() {
  group('PostDetail & Comments Widget Tests', () {
    late FakeCommunityRepository fakeRepo;
    late CommunityPost testPost;
    late PostDetailController controller;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      testPost = CommunityPost(
        id: 'post_abc',
        authorId: 'author_1',
        authorName: 'Master Hassan',
        authorRole: 'teacher',
        caption: 'Detailed critique of Naskh proportions',
        createdAt: DateTime.now(),
        likesCount: 15,
        commentsCount: 2,
      );
      fakeRepo.posts.add(testPost);

      fakeRepo.commentsByPost['post_abc'] = [
        CommunityComment(
          id: 'c_1',
          postId: 'post_abc',
          authorId: 'student_1',
          authorName: 'Zayd',
          authorRole: 'student',
          text: 'SubhanAllah, very helpful explanation!',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

      controller = PostDetailController(
        repository: fakeRepo,
        postId: testPost.id,
        initialPost: testPost,
        currentUserId: 'student_2',
        currentUserName: 'Maryam',
        currentUserPhotoUrl: 'https://example.com/maryam.jpg',
        currentUserRole: 'student',
      );
    });

    testWidgets('renders comments and adds a new comment in real-time', (tester) async {
      await controller.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: controller.comments.length,
                        itemBuilder: (context, index) {
                          final comment = controller.comments[index];
                          return ListTile(
                            title: Text(comment.authorName),
                            subtitle: Text(comment.text),
                          );
                        },
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('add-comment-btn'),
                      onPressed: () => controller.addComment('Wonderful work!'),
                      child: const Text('Add Comment'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Zayd'), findsOneWidget);
      expect(find.text('SubhanAllah, very helpful explanation!'), findsOneWidget);

      // Add comment
      await tester.tap(find.byKey(const Key('add-comment-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Maryam'), findsOneWidget);
      expect(find.text('Wonderful work!'), findsOneWidget);
      expect(fakeRepo.posts.first.commentsCount, 3); // 2 initial + 1 new comment
    });

    testWidgets('author can report post and block author', (tester) async {
      await controller.init();

      await controller.reportPost('Inappropriate content');
      expect(fakeRepo.reports.length, 1);
      expect(fakeRepo.reports.first['postId'], 'post_abc');

      await controller.blockAuthor();
      expect(fakeRepo.blockedUsers.contains('author_1'), isTrue);
    });
  });
}
