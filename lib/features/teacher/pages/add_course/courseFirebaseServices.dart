import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseFirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch teacher details from Firestore
  Future<Map<String, dynamic>> fetchTeacherDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot teacherDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));
        if (teacherDoc.exists) {
          // Cast the data to a Map to safely access fields
          final data = teacherDoc.data() as Map<String, dynamic>;

          return {
            'teacherId': user.uid,
            'teacherName': data['name'] ?? 'Unknown Teacher',
            // FIXED: Fetches 'photoUrl' (Teacher Identity) from your database
            'teacherProfilePic': data['photoUrl'] ?? '',
            'hasPayoutInfo': data.containsKey('payoutSettings'),
            'earningPercentage': ((data['commissionRate'] ?? 0.60) * 100).toDouble(),
          };
        }
        throw Exception('Teacher details not found');
      } catch (e) {
        throw Exception('Error fetching teacher details: $e');
      }
    }
    throw Exception('User not logged in');
  }

  // Save the course data to Firestore and return the generated course ID
  Future<String> saveCourse(Map<String, dynamic> courseData) async {
    try {
      final docRef = await _firestore.collection('courses').add(courseData);
      return docRef.id;
    } catch (e) {
      throw Exception('Error saving course: $e');
    }
  }
}
