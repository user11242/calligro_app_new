import 'package:calligro_app/features/community/domain/models/community_comment.dart';
import 'package:calligro_app/features/community/domain/models/community_filter.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:calligro_app/features/community/domain/models/community_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Community Domain Models Tests', () {
    test('CommunityPost serialization, deserialization & copyWith', () {
      final now = DateTime.now();
      final post = CommunityPost(
        id: 'p1',
        authorId: 'u1',
        authorName: 'Yazan',
        authorPhotoUrl: 'https://calligro.com/avatar.jpg',
        authorRole: 'teacher',
        caption: 'Beautiful calligraphy piece',
        imageUrls: ['https://calligro.com/img1.jpg'],
        createdAt: now,
        likesCount: 5,
        commentsCount: 2,
        isLikedByMe: true,
        isPinned: true,
        isHidden: false,
        isEdited: false,
        linkUrl: 'https://calligro.com',
        linkTitle: 'Course Link',
      );

      final map = post.toMap();
      expect(map['userId'], 'u1');
      expect(map['userName'], 'Yazan');
      expect(map['caption'], 'Beautiful calligraphy piece');
      expect(map['likesCount'], 5);
      expect(map['isPinned'], isTrue);

      final fromMap = CommunityPost.fromMap(id: 'p1', map: map, currentUserId: 'u1');
      expect(fromMap.id, 'p1');
      expect(fromMap.authorName, 'Yazan');
      expect(fromMap.isPinned, isTrue);

      final updated = post.copyWith(likesCount: 6, isLikedByMe: false);
      expect(updated.likesCount, 6);
      expect(updated.isLikedByMe, isFalse);
      expect(updated.authorName, post.authorName);
    });

    test('CommunityComment serialization, deserialization & copyWith', () {
      final now = DateTime.now();
      final comment = CommunityComment(
        id: 'c1',
        postId: 'p1',
        authorId: 'u2',
        authorName: 'Ahmad',
        authorPhotoUrl: '',
        authorRole: 'student',
        text: 'Great work!',
        createdAt: now,
      );

      final map = comment.toMap();
      expect(map['userId'], 'u2');
      expect(map['userName'], 'Ahmad');
      expect(map['text'], 'Great work!');

      final fromMap = CommunityComment.fromMap(id: 'c1', postId: 'p1', map: map);
      expect(fromMap.id, 'c1');
      expect(fromMap.text, 'Great work!');
    });

    test('CommunityUser model', () {
      const user = CommunityUser(
        id: 'u1',
        name: 'Master Calligrapher',
        photoUrl: 'photo.jpg',
        role: 'teacher',
        isFollowing: true,
      );
      expect(user.id, 'u1');
      expect(user.role, 'teacher');
      expect(user.isTeacher, isTrue);
      expect(user.isFollowing, isTrue);
    });

    test('CommunityFilter values and labels', () {
      expect(CommunityFilter.all.displayName, 'All');
      expect(CommunityFilter.popular.displayName, 'Popular');
      expect(CommunityFilter.friends.displayName, 'Friends');
      expect(CommunityFilter.teachers.displayName, 'Teachers');
      expect(CommunityFilter.myPosts.displayName, 'My Posts');
      expect(CommunityFilter.saved.displayName, 'Saved');
    });
  });
}

