import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/student_user_model.dart';

class StudentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<StudentUserModel> getCurrentStudent() async {
    final user = _auth.currentUser;

    // 1. If no user, return Guest Model
    if (user == null) {
      return StudentUserModel.guest();
    }

    try {
      // 2. Fetch User Data from Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        return StudentUserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          user.uid,
        );
      }
    } catch (e) {
      debugPrint("Error fetching student service: $e");
    }

    // 3. Fallback if logged in but no data found
    return StudentUserModel(
      uid: user.uid,
      name: "Student",
      email: user.email ?? "",
      photoUrl: "",
      isGuest: false,
    );
  }

  // --- NEW: Stream of Student Data for Real-Time Updates ---
  Stream<StudentUserModel> getStudentStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(StudentUserModel.guest());
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return StudentUserModel.fromMap(
              doc.data() as Map<String, dynamic>,
              user.uid,
            );
          }
          return StudentUserModel(
            uid: user.uid,
            name: "Student",
            email: user.email ?? "",
            photoUrl: "",
            isGuest: false,
          );
        }).handleError((e) {
          debugPrint("StudentService Stream Error: $e");
          return StudentUserModel.guest();
        });
  }

  // --- NEW: Stream of Enrolled Courses ---
  Stream<List<Map<String, dynamic>>> getEnrolledCourses() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('courses')
        .where('enrolledStudents', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList())
        .handleError((e) {
          debugPrint("EnrolledCourses Stream Error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  // --- NEW: Stream of Featured / Discovery Courses ---
  Stream<List<Map<String, dynamic>>> getFeaturedCourses() {
    try {
      return _firestore
          .collection('courses')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList())
          .handleError((error) {
            debugPrint("Error fetching featured courses: $error");
            return <Map<String, dynamic>>[];
          });
    } catch (e) {
      debugPrint("Exception in getFeaturedCourses: $e");
      return Stream.value([]);
    }
  }

  // --- NEW: Stream of Teachers ---
  Stream<List<Map<String, dynamic>>> getTeachersStream() {
    try {
      return _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList())
          .handleError((error) {
            debugPrint("Error fetching teachers: $error");
            return <Map<String, dynamic>>[];
          });
    } catch (e) {
      debugPrint("Exception in getTeachersStream: $e");
      return Stream.value([]);
    }
  }
}
