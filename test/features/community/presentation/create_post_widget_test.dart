import 'package:calligro_app/features/community/application/create_post_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';

void main() {
  group('CreatePost Widget & Form Tests', () {
    late FakeCommunityRepository fakeRepo;
    late CreatePostController studentController;
    late CreatePostController adminController;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      studentController = CreatePostController(
        repository: fakeRepo,
        currentUserId: 'student_1',
        currentUserName: 'Fatima Student',
        currentUserPhotoUrl: 'https://example.com/photo.jpg',
        currentUserRole: 'student',
      );
      adminController = CreatePostController(
        repository: fakeRepo,
        currentUserId: 'admin_1',
        currentUserName: 'Master Calligrapher',
        currentUserPhotoUrl: 'https://example.com/admin.jpg',
        currentUserRole: 'admin',
      );
    });

    testWidgets('shows caption input and disables submit button when caption is empty and no images', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: studentController,
              builder: (context, _) {
                return Column(
                  children: [
                    TextField(
                      key: const Key('caption-field'),
                      onChanged: studentController.setCaption,
                    ),
                    ElevatedButton(
                      key: const Key('submit-btn'),
                      onPressed: studentController.canSubmit && !studentController.isSubmitting
                          ? () => studentController.submit()
                          : null,
                      child: studentController.isSubmitting
                          ? const CircularProgressIndicator()
                          : const Text('Post'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final submitBtn = tester.widget<ElevatedButton>(find.byKey(const Key('submit-btn')));
      expect(submitBtn.onPressed, isNull);

      // Enter caption
      await tester.enterText(find.byKey(const Key('caption-field')), 'Practicing Riqaa script today!');
      await tester.pump();

      final enabledSubmitBtn = tester.widget<ElevatedButton>(find.byKey(const Key('submit-btn')));
      expect(enabledSubmitBtn.onPressed, isNotNull);

      // Submit
      await tester.tap(find.byKey(const Key('submit-btn')));
      await tester.pump();

      expect(fakeRepo.posts.length, 1);
      expect(fakeRepo.posts.first.caption, 'Practicing Riqaa script today!');
      expect(fakeRepo.posts.first.authorName, 'Fatima Student');
    });

    testWidgets('admin can attach link and pin post, but student cannot', (tester) async {
      // Student tries to set link or pin
      studentController.setLinkUrl('https://calligroacademy.com');
      studentController.setIsPinned(true);
      expect(studentController.linkUrl, isNull);
      expect(studentController.isPinned, isFalse);

      // Admin sets link and pin
      adminController.setCaption('Official Calligro Workshop Announced');
      adminController.setLinkUrl('https://calligroacademy.com/workshop');
      adminController.setLinkTitle('Workshop Details');
      adminController.setIsPinned(true);

      expect(adminController.linkUrl, 'https://calligroacademy.com/workshop');
      expect(adminController.linkTitle, 'Workshop Details');
      expect(adminController.isPinned, isTrue);

      final success = await adminController.submit();
      expect(success, isTrue);
      expect(fakeRepo.posts.length, 1);
      expect(fakeRepo.posts.first.isPinned, isTrue);
      expect(fakeRepo.posts.first.linkUrl, 'https://calligroacademy.com/workshop');
    });
  });
}
