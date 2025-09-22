import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseFirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch teacher details from Firestore
  Future<Map<String, String>> fetchTeacherDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot teacherDoc = await _firestore.collection('users').doc(user.uid).get();
        if (teacherDoc.exists) {
          return {
            'teacherId': user.uid,
            'teacherName': teacherDoc['name'],  // Assuming the 'name' field exists
          };
        }
        throw Exception('Teacher details not found');
      } catch (e) {
        throw Exception('Error fetching teacher details: $e');
      }
    }
    throw Exception('User not logged in');
  }

  // Save the course data to Firestore
  Future<void> saveCourse(Map<String, dynamic> courseData) async {
    try {
      await _firestore.collection('courses').add(courseData);
    } catch (e) {
      throw Exception('Error saving course: $e');
    }
  }

}
