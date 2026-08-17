import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CertificateModel {
  final String id;
  final String studentId;
  final String studentName;
  final String courseId;
  final String courseName;
  final String teacherId;
  final DateTime issueDate;

  CertificateModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.teacherId,
    required this.issueDate,
  });

  factory CertificateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CertificateModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Student',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? 'Course',
      teacherId: data['teacherId'] ?? '',
      issueDate: (data['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'courseId': courseId,
      'courseName': courseName,
      'teacherId': teacherId,
      'issueDate': Timestamp.fromDate(issueDate),
    };
  }
}

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates a certificate if it doesn't already exist for this student and course
  Future<void> generateCertificateIfMissing({
    required String courseId,
    required String courseName,
    required String teacherId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Check if certificate already exists
      final existingQuery = await _firestore
          .collection('certificates')
          .where('studentId', isEqualTo: user.uid)
          .where('courseId', isEqualTo: courseId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return; // Already has a certificate for this course
      }

      // 2. Fetch student name
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final studentName = userDoc.data()?['name'] ?? 'Student';

      // 3. Create certificate
      final certRef = _firestore.collection('certificates').doc();
      final certificate = CertificateModel(
        id: certRef.id,
        studentId: user.uid,
        studentName: studentName,
        courseId: courseId,
        courseName: courseName,
        teacherId: teacherId,
        issueDate: DateTime.now(),
      );

      await certRef.set(certificate.toMap());
      debugPrint("Certificate generated: ${certRef.id}");
    } catch (e) {
      debugPrint("Error generating certificate: $e");
    }
  }

  /// Get stream of certificates for the current user
  Stream<List<CertificateModel>> getStudentCertificates() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('certificates')
        .where('studentId', isEqualTo: user.uid)
        // Removed .orderBy to prevent missing composite index errors!
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CertificateModel.fromFirestore(doc))
              .toList();
          // Sort locally by issueDate descending
          list.sort((a, b) => b.issueDate.compareTo(a.issueDate));
          return list;
        })
        .handleError((e) {
          debugPrint("Error fetching certificates: $e");
          return <CertificateModel>[];
        });
  }
}
