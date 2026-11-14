import 'package:calligro_app/features/community/data/firestore_community_repository.dart';
import 'package:calligro_app/features/community/domain/models/community_comment.dart';
import 'package:calligro_app/features/community/domain/models/community_filter.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_media_uploader.dart';

void main() {
  group('FirestoreCommunityRepository Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeMediaUploader fakeUploader;
    late FirestoreCommunityRepository repo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeUploader = FakeMediaUploader();
      repo = FirestoreCommunityRepository(
        firestore: fakeFirestore,
        uploader: fakeUploader,
      );
    });

    test('createPost adds document and increments user postCount', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'name': 'Yazan',
        'role': 'teacher',
        'postCount': 0,
      });

      final post = CommunityPost(
        id: '',
        authorId: 'u1',
        authorName: 'Yazan',
        authorRole: 'teacher',
        caption: 'Hello community',
        createdAt: DateTime.now(),
      );

      await repo.createPost(post: post);

      final posts = await fakeFirestore.collection('community_posts').get();
      expect(posts.docs.length, 1);
      expect(posts.docs.first.data()['caption'], 'Hello community');

      final user = await fakeFirestore.collection('users').doc('u1').get();
      expect(user.data()?['postCount'], 1);
    });

    test('toggleLike increments and decrements likes count correctly', () async {
      final docRef = await fakeFirestore.collection('community_posts').add({
        'caption': 'Liked post',
        'likesCount': 0,
        'likes': <String, dynamic>{},
      });

      // Like
      await repo.toggleLike(postId: docRef.id, currentUserId: 'u1', isLiked: false);
      var snapshot = await docRef.get();
      expect(snapshot.data()?['likesCount'], 1);
      expect(snapshot.data()?['likes']['u1'], isTrue);

      // Unlike
      await repo.toggleLike(postId: docRef.id, currentUserId: 'u1', isLiked: true);
      snapshot = await docRef.get();
      expect(snapshot.data()?['likesCount'], 0);
      expect(snapshot.data()?['likes']['u1'], isNull);
    });

    test('addComment and deleteComment update commentsCount atomically', () async {
      final docRef = await fakeFirestore.collection('community_posts').add({
        'caption': 'Discussion post',
        'commentsCount': 0,
      });

      final comment = CommunityComment(
        id: 'c1',
        postId: docRef.id,
        authorId: 'u2',
        authorName: 'Ali',
        text: 'Awesome calligraphy!',
        createdAt: DateTime.now(),
      );

      await repo.addComment(postId: docRef.id, comment: comment);
      var postSnap = await docRef.get();
      expect(postSnap.data()?['commentsCount'], 1);

      final commentsSnap = await docRef.collection('comments').get();
      expect(commentsSnap.docs.length, 1);
      final commentId = commentsSnap.docs.first.id;

      await repo.deleteComment(postId: docRef.id, commentId: commentId);
      postSnap = await docRef.get();
      expect(postSnap.data()?['commentsCount'], 0);
    });

    test('deletePost removes post and decrements user postCount', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'name': 'Yazan',
        'postCount': 1,
      });

      final docRef = await fakeFirestore.collection('community_posts').add({
        'userId': 'u1',
        'caption': 'To be deleted',
      });

      await repo.deletePost(
        postId: docRef.id,
        authorId: 'u1',
        imageUrls: ['https://storage.calligro.com/img1.jpg'],
      );

      final postSnap = await docRef.get();
      expect(postSnap.exists, isFalse);

      final userSnap = await fakeFirestore.collection('users').doc('u1').get();
      expect(userSnap.data()?['postCount'], 0);
      expect(fakeUploader.deletedUrls, contains('https://storage.calligro.com/img1.jpg'));
    });

    test('reportPost and blockUser record records', () async {
      await repo.reportPost(postId: 'p1', reporterId: 'u1', reason: 'Spam');
      final reports = await fakeFirestore.collection('community_reports').get();
      expect(reports.docs.length, 1);
      expect(reports.docs.first.data()['reason'], 'Spam');

      await repo.blockUser(currentUserId: 'u1', blockedUserId: 'u2');
      final blocked = await fakeFirestore.collection('users').doc('u1').collection('blocked_users').doc('u2').get();
      expect(blocked.exists, isTrue);
    });

    test('toggleSavePost and getSavedPostIds', () async {
      await repo.toggleSavePost(currentUserId: 'u1', postId: 'p100', isSaved: false);
      var saved = await repo.getSavedPostIds('u1');
      expect(saved, contains('p100'));

      await repo.toggleSavePost(currentUserId: 'u1', postId: 'p100', isSaved: true);
      saved = await repo.getSavedPostIds('u1');
      expect(saved, isNot(contains('p100')));
    });

    test('watchFeed returns Stream of CommunityPost', () async {
      await fakeFirestore.collection('community_posts').add({
        'userId': 'u1',
        'userName': 'Yazan',
        'caption': 'Live stream item',
        'timestamp': DateTime.now(),
        'likesCount': 10,
        'commentsCount': 2,
      });

      final stream = repo.watchFeed(filter: CommunityFilter.all, currentUserId: 'u1');
      final posts = await stream.first;
      expect(posts.length, 1);
      expect(posts.first.caption, 'Live stream item');
    });
  });
}
