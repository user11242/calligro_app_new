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

    // 5. Notification Reference
    final String followNotificationId = "follow_$currentUserId";
    final DocumentReference notificationRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .doc(followNotificationId);

    // --- Logic ---
    if (isFollowing) {
      // --- UNFOLLOW logic ---
      batch.delete(targetUserFollowersRef); // 1. Remove from their followers
      batch.update(targetUserDocRef, {
        'followerCount': FieldValue.increment(-1),
      }); // 2. Decrement their count
      batch.delete(
        currentUserFollowingRef,
      ); // 3. Remove from our following list
      batch.update(currentUserDocRef, {
        'followingCount': FieldValue.increment(-1),
      }); // 4. Decrement our count
      
      // Remove follow notification
      batch.delete(notificationRef);
    } else {
      // --- FOLLOW logic ---
      final timestamp = FieldValue.serverTimestamp();
      batch.set(targetUserFollowersRef, {
        'timestamp': timestamp,
      }); // 1. Add to their followers
      batch.update(targetUserDocRef, {
        'followerCount': FieldValue.increment(1),
      }); // 2. Increment their count
      batch.set(currentUserFollowingRef, {
        'timestamp': timestamp,
      }); // 3. Add to our following list
      batch.update(currentUserDocRef, {
        'followingCount': FieldValue.increment(1),
      }); // 4. Increment our count

      // Add follow notification
      batch.set(notificationRef, {
        'id': followNotificationId,
        'type': 'new_follower',
        'userId': currentUserId, // The person who followed
        'targetId': targetUserId, // (Optional) for profile linking
        'createdAt': timestamp, // MUST BE createdAt
        'read': false,          // MUST BE read
        'title': 'New Follower',
        'body': 'Someone started following you.',
      });
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
