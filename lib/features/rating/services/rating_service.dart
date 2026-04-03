// lib/features/rating/services/rating_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a rating for a teacher after course completion
  /// Updates teacher's totalStars and reviewCount atomically
  Future<void> submitRating({
    required String studentId,
    required String studentName,
    required String teacherId,
    required String courseId,
    required String courseName,
    required int rating,
    String? reviewText,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    try {
      // 1. Create review document first
      final reviewRef = _firestore.collection('reviews').doc();
      await reviewRef.set({
        'studentId': studentId,
        'studentName': studentName,
        'teacherId': teacherId,
        'courseId': courseId,
        'courseName': courseName,
        'rating': rating,
        'reviewText': reviewText ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'isPublic': true,
      });

      // 2. Update teacher stats separately
      final teacherRef = _firestore.collection('users').doc(teacherId);
      final teacherDoc = await teacherRef.get();

      if (teacherDoc.exists) {
        await teacherRef.update({
          'totalStars': FieldValue.increment(rating),
          'reviewCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  /// Check if a student has already rated a specific course
  Future<bool> hasStudentRatedCourse({
    required String studentId,
    required String courseId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('reviews')
          .where('studentId', isEqualTo: studentId)
          .where('courseId', isEqualTo: courseId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if student rated course: $e');
      return false;
    }
  }

  Stream<QuerySnapshot> getTeacherReviews(String teacherId) {
    return _firestore
        .collection('reviews')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots();
  }

  Stream<QuerySnapshot> getCourseReviews(String courseId) {
    return _firestore
        .collection('reviews')
        .where('courseId', isEqualTo: courseId)
        .snapshots();
  }
}
