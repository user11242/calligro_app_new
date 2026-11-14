import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/repositories/follow_repository.dart';

/// Concrete FollowRepository using FirebaseFirestore.
class FirestoreFollowRepository implements FollowRepository {
  final FirebaseFirestore? _firestoreMock;

  FirestoreFollowRepository({FirebaseFirestore? firestore}) : _firestoreMock = firestore;

  FirebaseFirestore get _firestore => _firestoreMock ?? FirebaseFirestore.instance;

  @override
  Stream<bool> watchIsFollowing({required String currentUserId, required String targetUserId}) {
    if (currentUserId.isEmpty || targetUserId.isEmpty) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Future<void> followUser({required String currentUserId, required String targetUserId}) async {
    if (currentUserId.isEmpty || targetUserId.isEmpty || currentUserId == targetUserId) return;

    final batch = _firestore.batch();
    final followingRef = _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
    final followerRef = _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    batch.set(followingRef, {'timestamp': FieldValue.serverTimestamp()});
    batch.set(followerRef, {'timestamp': FieldValue.serverTimestamp()});
    batch.update(currentUserRef, {'followingCount': FieldValue.increment(1)});
    batch.update(targetUserRef, {'followersCount': FieldValue.increment(1)});

    await batch.commit();
  }

  @override
  Future<void> unfollowUser({required String currentUserId, required String targetUserId}) async {
    if (currentUserId.isEmpty || targetUserId.isEmpty) return;

    final batch = _firestore.batch();
    final followingRef = _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
    final followerRef = _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    batch.delete(followingRef);
    batch.delete(followerRef);
    batch.update(currentUserRef, {'followingCount': FieldValue.increment(-1)});
    batch.update(targetUserRef, {'followersCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  @override
  Future<List<String>> getFollowingIds(String currentUserId) async {
    if (currentUserId.isEmpty) return [];
    final snap = await _firestore.collection('users').doc(currentUserId).collection('following').get();
    return snap.docs.map((d) => d.id).toList();
  }

  @override
  Future<List<String>> getFollowerIds(String currentUserId) async {
    if (currentUserId.isEmpty) return [];
    final snap = await _firestore.collection('users').doc(currentUserId).collection('followers').get();
    return snap.docs.map((d) => d.id).toList();
  }
}

