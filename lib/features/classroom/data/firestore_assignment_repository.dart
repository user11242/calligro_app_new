import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/classroom_models.dart';
import '../domain/classroom_repositories.dart';

class FirestoreAssignmentRepository implements AssignmentRepository {
  FirestoreAssignmentRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _assignments(String courseId) =>
      _db.collection('courses').doc(courseId).collection('assignments');
  CollectionReference<Map<String, dynamic>> _submissions(String courseId, String assignmentId) =>
      _assignments(courseId).doc(assignmentId).collection('submissions');

  @override
  Stream<List<Assignment>> watchAssignments(String courseId) => _assignments(courseId)
      .orderBy('dueDate')
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) Assignment.fromMap(d.id, d.data())]);

  @override
  Future<String> createAssignment(String courseId, AssignmentDraft draft) async {
    final ref = await _assignments(courseId).add(draft.toDocument(
      dueDate: Timestamp.fromDate(draft.dueDate!),
      createdAt: FieldValue.serverTimestamp(),
    ));
    return ref.id;
  }

  @override
  Stream<List<Submission>> watchSubmissions(String courseId, String assignmentId) =>
      _submissions(courseId, assignmentId)
          .orderBy('submittedAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => [for (final d in s.docs) Submission.fromMap(d.id, d.data())]);

  @override
  Stream<Submission?> watchSubmission(String courseId, String assignmentId, String studentId) =>
      _submissions(courseId, assignmentId).doc(studentId).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : Submission.fromMap(d.id, data);
      });

  @override
  Future<void> saveSubmission(String courseId, String assignmentId, String studentId, SubmissionInput input,
      {required bool isNew}) {
    final ref = _submissions(courseId, assignmentId).doc(studentId);
    final now = FieldValue.serverTimestamp();
    // New: create. Existing: update ONLY the student's fields, so the
    // teacher's "seen" mark (and older status/points) are untouched.
    return isNew
        ? ref.set(input.toDocument(studentId, submittedAt: now))
        : ref.update(input.toDocument(studentId, submittedAt: now, includeId: false));
  }

  @override
  Future<void> deleteSubmission(String courseId, String assignmentId, String studentId) =>
      _submissions(courseId, assignmentId).doc(studentId).delete();

  @override
  Future<void> setSeen(String courseId, String assignmentId, String studentId, bool seen) =>
      _submissions(courseId, assignmentId).doc(studentId).update({'seenByTeacher': seen});

  @override
  Future<({String name, String? photoUrl})> studentProfile(String uid) async {
    final d = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    return (
      name: d['name'] is String ? d['name'] as String : '',
      photoUrl: d['photoUrl'] is String ? d['photoUrl'] as String : null,
    );
  }
}

class StorageSubmissionFiles implements SubmissionFiles {
  StorageSubmissionFiles({FirebaseStorage? storage}) : _injected = storage;
  final FirebaseStorage? _injected;

  @override
  Future<String> upload({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String localPath,
    required String fileName,
  }) async {
    final ref = (_injected ?? FirebaseStorage.instance)
        .ref()
        .child('course_submissions')
        .child(courseId)
        .child(assignmentId)
        .child('${studentId}_$fileName'); // storage.rules: named by the uploader
    final task = await ref.putFile(File(localPath));
    return task.ref.getDownloadURL();
  }
}
