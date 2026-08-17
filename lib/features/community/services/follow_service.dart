// lib/features/user/services/follow_service.dart
//Done

import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // This is the 4-step batch write function
  Future<void> toggleFollow({
    required String currentUserId,
    required String targetUserId,
    required bool isFollowing, // Are we currently following this user?
  }) async {
    WriteBatch batch = _firestore.batch();

    // --- References ---
    // 1. The document of the person we are following (to add to their followers)
    final DocumentReference targetUserFollowersRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    // 2. The main document of the person we are following (to update their count)
    final DocumentReference targetUserDocRef = _firestore
        .collection('users')
        .doc(targetUserId);

    // 3. Our own following document (to add the person to our list)
    final DocumentReference currentUserFollowingRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    // 4. Our own main document (to update our count)
    final DocumentReference currentUserDocRef = _firestore
        .collection('users')
        .doc(currentUserId);

    // --- Fetch Roles ---
    final targetDocSnapshot = await targetUserDocRef.get();
    final currentDocSnapshot = await currentUserDocRef.get();
    
    final targetRole = (targetDocSnapshot.data() as Map<String, dynamic>?)?['role'] as String? ?? 'student';
    final currentRole = (currentDocSnapshot.data() as Map<String, dynamic>?)?['role'] as String? ?? 'student';

    final DocumentReference targetRoleDocRef = _firestore
        .collection(targetRole == 'teacher' ? 'teachers' : 'students')
        .doc(targetUserId);

    final DocumentReference currentRoleDocRef = _firestore
        .collection(currentRole == 'teacher' ? 'teachers' : 'students')
        .doc(currentUserId);


    // --- Logic ---
    if (isFollowing) {
      // --- UNFOLLOW logic ---
      batch.delete(targetUserFollowersRef); // 1. Remove from their followers
      batch.update(targetUserDocRef, {
        'followerCount': FieldValue.increment(-1),
      }); // 2. Decrement their count
      batch.update(targetRoleDocRef, {
        'followerCount': FieldValue.increment(-1),
      }); // Decrement their count in role collection

      batch.delete(
        currentUserFollowingRef,
      ); // 3. Remove from our following list
      batch.update(currentUserDocRef, {
        'followingCount': FieldValue.increment(-1),
      }); // 4. Decrement our count
      batch.update(currentRoleDocRef, {
        'followingCount': FieldValue.increment(-1),
      }); // Decrement our count in role collection
    } else {
      // --- FOLLOW logic ---
      final timestamp = FieldValue.serverTimestamp();
      batch.set(targetUserFollowersRef, {
        'followerId': currentUserId,
        'timestamp': timestamp,
      }); // 1. Add to their followers — Cloud Function watches this to send push + in-app notification
      batch.update(targetUserDocRef, {
        'followerCount': FieldValue.increment(1),
      }); // 2. Increment their count
      batch.update(targetRoleDocRef, {
        'followerCount': FieldValue.increment(1),
      }); // Increment their count in role collection

      batch.set(currentUserFollowingRef, {
        'timestamp': timestamp,
      }); // 3. Add to our following list
      batch.update(currentUserDocRef, {
        'followingCount': FieldValue.increment(1),
      }); // 4. Increment our count
      batch.update(currentRoleDocRef, {
        'followingCount': FieldValue.increment(1),
      }); // Increment our count in role collection
    }

    // Commit all operations at once
    await batch.commit();
  }

  // NEW METHOD: Get a stream to check if current user is following target user
  /// Provides a real-time stream of the following status between two users.
  Stream<DocumentSnapshot> getFollowingStatusStream({
    required String currentUserId,
    required String targetUserId,
  }) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .snapshots();
  }


  // NEW METHOD: Get list of user IDs that the current user is following
  Future<List<String>> getFollowingIds(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error fetching following IDs: $e");
      return [];
    }
  }
}
