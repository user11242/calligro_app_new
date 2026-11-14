import 'dart:io';

import 'package:calligro_app/features/community/application/create_post_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';

void main() {
  group('CreatePostController Tests', () {
    late FakeCommunityRepository fakeRepo;
    late CreatePostController studentController;
    late CreatePostController adminController;

    setUp(() {
      fakeRepo = FakeCommunityRepository();

      studentController = CreatePostController(
        repository: fakeRepo,
        currentUserId: 's1',
        currentUserName: 'Student Name',
        currentUserPhotoUrl: 'photo.jpg',
        currentUserRole: 'student',
      );

      adminController = CreatePostController(
        repository: fakeRepo,
        currentUserId: 'a1',
        currentUserName: 'Admin Name',
        currentUserPhotoUrl: 'admin.jpg',
        currentUserRole: 'admin',
      );
    });

    test('cannot submit completely empty post', () async {
      studentController.setCaption('   ');
      final success = await studentController.submit();
      expect(success, isFalse);
      expect(studentController.errorMessage, isNotNull);
      expect(fakeRepo.posts.isEmpty, isTrue);
    });

    test('can submit post with text only', () async {
      studentController.setCaption('My calligraphy progress');
      final success = await studentController.submit();
      expect(success, isTrue);
      expect(fakeRepo.posts.length, 1);
      expect(fakeRepo.posts.first.caption, 'My calligraphy progress');
      expect(fakeRepo.posts.first.authorId, 's1');
    });

    test('managing images enforces maxImagesPerPost limit', () {
      expect(studentController.images.isEmpty, isTrue);
      final dummyFiles = List.generate(5, (i) => File('img_$i.jpg'));

      studentController.addImages(dummyFiles);
      expect(studentController.images.length, 5);

      studentController.removeImage(0);
      expect(studentController.images.length, 4);

      // Attempt adding more than limit (10)
      final moreFiles = List.generate(10, (i) => File('extra_$i.jpg'));
      studentController.addImages(moreFiles);
      expect(studentController.images.length, 10);
      expect(studentController.errorMessage, isNotNull);
    });

    test('admin can attach link and pin post; student cannot', () async {
      studentController.setLinkUrl('https://calligro.com');
      studentController.setIsPinned(true);
      expect(studentController.linkUrl, isNull);
      expect(studentController.isPinned, isFalse);

      adminController.setCaption('Official Announcement');
      adminController.setLinkUrl('https://calligro.com/event');
      adminController.setLinkTitle('Calligraphy Summit');
      adminController.setIsPinned(true);

      expect(adminController.linkUrl, 'https://calligro.com/event');
      expect(adminController.isPinned, isTrue);

      final success = await adminController.submit();
      expect(success, isTrue);
      expect(fakeRepo.posts.first.isPinned, isTrue);
      expect(fakeRepo.posts.first.linkUrl, 'https://calligro.com/event');
    });

    test('network failure during submit sets error and leaves state editable', () async {
      fakeRepo.simulateNetworkErrorOnCreate = true;
      studentController.setCaption('Will fail');

      final success = await studentController.submit();
      expect(success, isFalse);
      expect(studentController.errorMessage, isNotNull);
      expect(studentController.isSubmitting, isFalse);
      expect(studentController.caption, 'Will fail');
    });
  });
}

