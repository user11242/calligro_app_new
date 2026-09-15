import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/community/services/follow_service.dart';

void main() {
  group('Layer 2: FollowService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FollowService followService;
    const currentUserId = 'user_1';
    const targetUserId = 'user_2';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      followService = FollowService(firestore: fakeFirestore);
    });

    test('toggleFollow() adds follow when isFollowing=false', () async {
      await fakeFirestore.collection('users').doc(currentUserId).set({'followingCount': 0});
      await fakeFirestore.collection('users').doc(targetUserId).set({'followerCount': 0});

      await followService.toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        isFollowing: false,
      );

      // Verify currentUser following list/count
      final currentDoc = await fakeFirestore.collection('users').doc(currentUserId).get();
      expect(currentDoc.data()?['followingCount'], 1);
      final followingDoc = await fakeFirestore
          .collection('users').doc(currentUserId).collection('following').doc(targetUserId).get();
      expect(followingDoc.exists, true);

      // Verify targetUser follower list/count
      final targetDoc = await fakeFirestore.collection('users').doc(targetUserId).get();
      expect(targetDoc.data()?['followerCount'], 1);
      final followerDoc = await fakeFirestore
          .collection('users').doc(targetUserId).collection('followers').doc(currentUserId).get();
      expect(followerDoc.exists, true);
    });

    test('toggleFollow() removes follow when isFollowing=true', () async {
      await fakeFirestore.collection('users').doc(currentUserId).set({'followingCount': 1});
      await fakeFirestore.collection('users').doc(targetUserId).set({'followerCount': 1});
      await fakeFirestore
          .collection('users').doc(currentUserId).collection('following').doc(targetUserId).set({'time': 'now'});
      await fakeFirestore
          .collection('users').doc(targetUserId).collection('followers').doc(currentUserId).set({'time': 'now'});

      await followService.toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
        isFollowing: true,
      );

      // Verify counts decreased
      final currentDoc = await fakeFirestore.collection('users').doc(currentUserId).get();
      expect(currentDoc.data()?['followingCount'], 0);
      final targetDoc = await fakeFirestore.collection('users').doc(targetUserId).get();
      expect(targetDoc.data()?['followerCount'], 0);

      // Verify docs removed
      final followingDoc = await fakeFirestore
          .collection('users').doc(currentUserId).collection('following').doc(targetUserId).get();
      expect(followingDoc.exists, false);
      final followerDoc = await fakeFirestore
          .collection('users').doc(targetUserId).collection('followers').doc(currentUserId).get();
      expect(followerDoc.exists, false);
    });

    test('getFollowingStatusStream() returns a Stream', () {
      final stream = followService.getFollowingStatusStream(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );
      expect(stream, isA<Stream>());
    });

    test('getFollowingIds() returns list of user IDs', () async {
      await fakeFirestore
          .collection('users').doc(currentUserId).collection('following').doc('user_a').set({'time': 'now'});
      await fakeFirestore
          .collection('users').doc(currentUserId).collection('following').doc('user_b').set({'time': 'now'});

      final ids = await followService.getFollowingIds(currentUserId);
      expect(ids, containsAll(['user_a', 'user_b']));
    });

    test('getFollowingIds() returns empty list when no followings', () async {
      final ids = await followService.getFollowingIds('nobody');
      expect(ids, isEmpty);
    });
  });
}
