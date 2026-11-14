import 'package:calligro_app/features/community/domain/policies/community_post_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityPostPolicy Tests', () {
    test('canCreatePost rejects empty post without text, image or link', () {
      expect(
        CommunityPostPolicy.canCreatePost(caption: '', imageCount: 0, linkUrl: null),
        isFalse,
      );
      expect(
        CommunityPostPolicy.canCreatePost(caption: '   ', imageCount: 0, linkUrl: ''),
        isFalse,
      );
    });

    test('canCreatePost allows post with text only', () {
      expect(
        CommunityPostPolicy.canCreatePost(caption: 'Hello world', imageCount: 0),
        isTrue,
      );
    });

    test('canCreatePost allows post with images only', () {
      expect(
        CommunityPostPolicy.canCreatePost(caption: '', imageCount: 2),
        isTrue,
      );
    });

    test('canCreatePost rejects if image count exceeds limit', () {
      expect(
        CommunityPostPolicy.canCreatePost(
          caption: 'My artwork',
          imageCount: CommunityPostPolicy.maxImagesPerPost + 1,
        ),
        isFalse,
      );
    });

    test('canCreatePost allows valid link', () {
      expect(
        CommunityPostPolicy.canCreatePost(caption: '', imageCount: 0, linkUrl: 'https://calligro.com'),
        isTrue,
      );
    });

    test('canAttachLink only allows admins', () {
      expect(CommunityPostPolicy.canAttachLink(userRole: 'admin'), isTrue);
      expect(CommunityPostPolicy.canAttachLink(userRole: 'teacher'), isFalse);
      expect(CommunityPostPolicy.canAttachLink(userRole: 'student'), isFalse);
    });

    test('canPinPost only allows admins', () {
      expect(CommunityPostPolicy.canPinPost(userRole: 'admin'), isTrue);
      expect(CommunityPostPolicy.canPinPost(userRole: 'teacher'), isFalse);
      expect(CommunityPostPolicy.canPinPost(userRole: 'student'), isFalse);
    });

    test('canEditPost allows author or admin, rejects others', () {
      expect(CommunityPostPolicy.canEditPost(currentUserId: 'u1', authorId: 'u1', isAdmin: false), isTrue);
      expect(CommunityPostPolicy.canEditPost(currentUserId: 'u2', authorId: 'u1', isAdmin: true), isTrue);
      expect(CommunityPostPolicy.canEditPost(currentUserId: 'u2', authorId: 'u1', isAdmin: false), isFalse);
    });

    test('canDeletePost allows author or admin, rejects others', () {
      expect(CommunityPostPolicy.canDeletePost(currentUserId: 'u1', authorId: 'u1', isAdmin: false), isTrue);
      expect(CommunityPostPolicy.canDeletePost(currentUserId: 'u2', authorId: 'u1', isAdmin: true), isTrue);
      expect(CommunityPostPolicy.canDeletePost(currentUserId: 'u2', authorId: 'u1', isAdmin: false), isFalse);
    });

    test('validateCaption truncates or enforces character limits', () {
      final valid = CommunityPostPolicy.validateCaption('Short text');
      expect(valid, isNull);

      final tooLong = 'a' * (CommunityPostPolicy.maxCaptionLength + 1);
      final error = CommunityPostPolicy.validateCaption(tooLong);
      expect(error, isNotNull);
    });
  });
}

