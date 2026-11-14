import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/community_user.dart';
import '../domain/repositories/user_repository.dart';

/// Concrete UserRepository using FirebaseFirestore.
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore? _firestoreMock;

  FirestoreUserRepository({FirebaseFirestore? firestore}) : _firestoreMock = firestore;

  FirebaseFirestore get _firestore => _firestoreMock ?? FirebaseFirestore.instance;

  @override
  Future<CommunityUser> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      throw Exception('User data not found for ID: $userId');
    }
    return CommunityUser.fromMap(doc.id, doc.data() ?? {});
  }

  @override
  Future<List<CommunityUser>> getUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final List<Future<DocumentSnapshot>> futures = userIds
        .map((id) => _firestore.collection('users').doc(id).get())
        .toList();

    final docs = await Future.wait(futures);
    return docs
        .where((d) => d.exists && d.data() != null)
        .map((d) => CommunityUser.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CommunityUser>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final lower = query.toLowerCase().trim();

    final snap = await _firestore
        .collection('users')
        .where('name_lowercase', isGreaterThanOrEqualTo: lower)
        .where('name_lowercase', isLessThanOrEqualTo: '$lower\uf8ff')
        .limit(limit)
        .get();

    return snap.docs
        .map((d) => CommunityUser.fromMap(d.id, d.data()))
        .toList();
  }
}

