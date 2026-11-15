import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/repositories/community_repositories.dart';

/// Follows: users/{a}/following/{b} + users/{b}/followers/{a} + both counters, in one batch.
class FirestoreFollowRepository implements FollowRepository {
  FirestoreFollowRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String id) => _db.collection('users').doc(id);

  @override
  Stream<bool> watchIsFollowing({required String userId, required String targetUserId}) {
    if (userId.isEmpty) return Stream.value(false);
    return _user(userId)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((d) => d.exists)
        .handleError((Object e) => debugPrint('Follow status error: $e'));
  }

  @override
  Future<void> setFollowing({required String userId, required String targetUserId, required bool follow}) async {
    if (userId == targetUserId) throw ArgumentError('You cannot follow yourself');
    final theirFollower = _user(targetUserId).collection('followers').doc(userId);
    final myFollowing = _user(userId).collection('following').doc(targetUserId);
    final batch = _db.batch();
    if (follow) {
      final now = FieldValue.serverTimestamp();
      batch
        ..set(theirFollower, {'followerId': userId, 'timestamp': now})
        ..update(_user(targetUserId), {'followerCount': FieldValue.increment(1)})
        ..set(myFollowing, {'timestamp': now})
        ..update(_user(userId), {'followingCount': FieldValue.increment(1)});
    } else {
      batch
        ..delete(theirFollower)
        ..update(_user(targetUserId), {'followerCount': FieldValue.increment(-1)})
        ..delete(myFollowing)
        ..update(_user(userId), {'followingCount': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  @override
  Future<List<String>> getFollowingIds(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final s = await _user(userId).collection('following').get();
      return s.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('Following ids could not be loaded: $e');
      return const [];
    }
  }
}

class FirestoreCommunityUserRepository implements CommunityUserRepository {
  FirestoreCommunityUserRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static CommunityUser _user(String id, Map<String, dynamic> d) => CommunityUser(
        id: id,
        name: d['name'] is String ? d['name'] as String : '',
        photoUrl: d['photoUrl'] is String ? d['photoUrl'] as String : '',
        role: d['role'] is String ? d['role'] as String : 'student',
      );

  @override
  Future<List<CommunityUser>> getUsers(List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final docs = await Future.wait(userIds.map((id) => _db.collection('users').doc(id).get()));
    return [for (final d in docs) if (d.exists) _user(d.id, d.data()!)];
  }

  /// Prefix search on the `name_lower` index (case-insensitive).
  @override
  Future<List<CommunityUser>> searchByName(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    try {
      final s = await _db
          .collection('users')
          .orderBy('name_lower')
          .startAt([q])
          .endAt(['$q'])
          .limit(20)
          .get();
      return s.docs.map((d) => _user(d.id, d.data())).toList();
    } catch (e) {
      debugPrint('User search failed: $e');
      return const [];
    }
  }
}

/// Current user from Firebase Auth + users/{uid} (name, photo, role). Guest when signed out.
class FirebaseCommunitySessionSource implements CommunitySessionSource {
  FirebaseCommunitySessionSource({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  Future<CommunitySession> currentSession() async {
    final user = _auth.currentUser;
    if (user == null) return CommunitySession.guest;
    try {
      final d = (await _db.collection('users').doc(user.uid).get()).data() ?? const <String, dynamic>{};
      String text(Object? v, String fallback) => v is String && v.isNotEmpty ? v : fallback;
      return CommunitySession(
        userId: user.uid,
        name: text(d['name'], text(user.displayName, 'Anonymous')),
        photoUrl: text(d['photoUrl'], ''),
        role: text(d['role'], 'student'),
      );
    } catch (e) {
      debugPrint('Session profile could not be loaded: $e');
      return CommunitySession(userId: user.uid, name: user.displayName ?? 'Anonymous');
    }
  }
}
