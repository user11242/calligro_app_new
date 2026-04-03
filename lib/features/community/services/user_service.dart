import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets the role of a user (teacher/student). Defaults to 'student'.
  Future<String> getUserRole(String userId) async {
    if (userId.isEmpty) return 'student';
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['role'] ?? 'student';
      } else {
        return 'student'; // Default role if user doc doesn't exist
      }
    } catch (e) {
      print("Error fetching user role from UserService: $e");
      return 'student'; // Default role on error
    }
  }

  /// Provides a real-time stream of a specific user's document.
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  /// Searches for users by name (Supports First Name, Last Name, and partial matches).
  /// Note: This fetches a batch of users and filters them in memory to allow "Contains" search.
  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final String lowerCaseQuery = query.toLowerCase().trim();

      // 1. Efficient Server-Side Search
      // We use the name_lower index we recently added to perform a prefix search.
      // '\uf8ff' is the last character in the UTF-16 table, so this range
      // effectively matches anything starting with the query.
      final snapshot = await _firestore
          .collection('users')
          .orderBy('name_lower')
          .startAt([lowerCaseQuery])
          .endAt(['$lowerCaseQuery\uf8ff'])
          .limit(20) // Snappier results with lower data usage
          .get();

      // 2. Map results
      final List<Map<String, dynamic>> results = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return results;
    } catch (e) {
      print("Error searching users in UserService: $e");
      return [];
    }
  }
}
