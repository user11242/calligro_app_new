import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:calligro_app/features/community/services/community_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Layer 2: CommunityService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockFirebaseStorage mockStorage;
    late CommunityService communityService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(signedIn: false);
      mockStorage = MockFirebaseStorage();
      
      communityService = CommunityService(
        auth: mockAuth,
        firestore: fakeFirestore,
        storage: mockStorage,
      );
    });

    test('getCurrentUserData() retrieves user data', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'name': 'John',
        'photoUrl': 'url',
        'role': 'teacher',
      });

      final data = await communityService.getCurrentUserData('u1');
      expect(data['name'], 'John');
      expect(data['role'], 'teacher');
    });

    test('getCurrentUserData() throws if user not found', () async {
      expect(communityService.getCurrentUserData('unknown'), throwsException);
    });

    test('getCommunityPostsStream() returns stream of posts', () {
      final stream = communityService.getCommunityPostsStream();
      expect(stream, isA<Stream>());
    });

    test('getCommunityPostsStream(My Posts) returns stream of user posts', () {
      final stream = communityService.getCommunityPostsStream(filter: 'My Posts', currentUserId: 'u1');
      expect(stream, isA<Stream>());
    });

    test('toggleLike() adds like', () async {
      await fakeFirestore.collection('community_posts').doc('p1').set({
        'likes': {'dummy': true},
        'likesCount': 0,
      });

      await communityService.toggleLike(postId: 'p1', currentUserId: 'u1', isLiked: false);
      
      final doc = await fakeFirestore.collection('community_posts').doc('p1').get();
      final data = doc.data()!;
      expect(data['likes']['u1'], true);
      expect(data['likesCount'], 1);
    });

    test('toggleLike() removes like if already liked', () async {
      await fakeFirestore.collection('community_posts').doc('p1').set({
        'likes': {'u1': true},
        'likesCount': 1,
      });

      await communityService.toggleLike(postId: 'p1', currentUserId: 'u1', isLiked: true);
      
      final doc = await fakeFirestore.collection('community_posts').doc('p1').get();
      final data = doc.data()!;
      expect(data['likes']['u1'], null);
      expect(data['likesCount'], 0);
    });

    test('createPost() creates a text post', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'name': 'John',
        'photoUrl': 'url',
        'role': 'teacher',
        'postCount': 0,
      });
      await fakeFirestore.collection('teachers').doc('u1').set({
        'postCount': 0,
      });

      await communityService.createPost(
        caption: 'Hello world',
        images: [],
        userData: {
          'id': 'u1',
          'name': 'John',
          'photoUrl': 'url',
          'role': 'teacher'
        },
      );

      final posts = await fakeFirestore.collection('community_posts').get();
      expect(posts.docs.length, 1);
      final postData = posts.docs.first.data();
      expect(postData['caption'], 'Hello world');
      expect(postData['userId'], 'u1');

      final userDoc = await fakeFirestore.collection('users').doc('u1').get();
      expect(userDoc.data()?['postCount'], 1);
    });

    test('deletePost() deletes post and updates counts', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'postCount': 1,
        'role': 'teacher',
      });
      await fakeFirestore.collection('teachers').doc('u1').set({
        'postCount': 1,
      });
      await fakeFirestore.collection('community_posts').doc('p1').set({
        'authorId': 'u1',
        'commentCount': 0,
      });

      await communityService.deletePost(postId: 'p1', postAuthorId: 'u1', imageUrls: []);

      final posts = await fakeFirestore.collection('community_posts').get();
      expect(posts.docs.isEmpty, true);

      final userDoc = await fakeFirestore.collection('users').doc('u1').get();
      expect(userDoc.data()?['postCount'], 0);
    });

    test('addComment() adds comment and increments count', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'name': 'John',
        'photoUrl': 'url',
        'role': 'teacher',
      });
      await fakeFirestore.collection('community_posts').doc('p1').set({
        'commentsCount': 0,
      });

      await communityService.addComment(
        postId: 'p1',
        userId: 'u1',
        userName: 'John',
        userPhotoUrl: 'url',
        userRole: 'teacher',
        text: 'A comment',
      );

      final comments = await fakeFirestore.collection('community_posts').doc('p1').collection('comments').get();
      expect(comments.docs.length, 1);
      expect(comments.docs.first.data()['text'], 'A comment');

      final post = await fakeFirestore.collection('community_posts').doc('p1').get();
      expect(post.data()?['commentsCount'], 1);
    });
    
    test('getCommentsStream() returns stream', () {
      final stream = communityService.getCommentsStream('p1');
      expect(stream, isA<Stream>());
    });

    test('reportPost() adds report', () async {
      await communityService.reportPost(
        postId: 'p1',
        reportedUserId: 'u2',
        currentUserId: 'u1',
      );

      final reports = await fakeFirestore.collection('reports').get();
      expect(reports.docs.length, 1);
      final data = reports.docs.first.data();
      expect(data['postId'], 'p1');
      expect(data['reportedByUserId'], 'u1');
      expect(data['reportedUserId'], 'u2');
    });

    test('blockUser() adds to blocked Users', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'blockedUsers': [],
      });
      
      await communityService.blockUser(
        currentUserId: 'u1',
        blockedUserId: 'u2',
      );

      final blockDoc = await fakeFirestore.collection('users').doc('u1').get();
      expect(blockDoc.data()?['blockedUsers'], contains('u2'));
    });
  });
}
