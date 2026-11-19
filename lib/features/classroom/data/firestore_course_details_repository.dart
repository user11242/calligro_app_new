import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/classroom_repositories.dart';

class FirestoreCourseDetailsRepository implements CourseDetailsRepository {
  FirestoreCourseDetailsRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  /// Firestore's limit for `whereIn`.
  static const _batchSize = 10;

  @override
  Stream<Map<String, dynamic>?> watchCourse(String courseId) =>
      _db.collection('courses').doc(courseId).snapshots().map((s) => s.exists ? s.data() : null);

  @override
  Future<Map<String, dynamic>?> getCourse(String courseId) async {
    final s = await _db.collection('courses').doc(courseId).get();
    return s.exists ? s.data() : null;
  }

  @override
  Future<String?> userRole(String uid) async {
    if (uid.isEmpty) return null;
    final s = await _db.collection('users').doc(uid).get();
    final role = s.data()?['role'];
    return role is String ? role : null;
  }

  @override
  Future<List<EnrolledStudent>> students(List<String> uids) async {
    if (uids.isEmpty) return const [];
    final batches = [
      for (var i = 0; i < uids.length; i += _batchSize)
        uids.sublist(i, i + _batchSize > uids.length ? uids.length : i + _batchSize),
    ];
    final snapshots = await Future.wait([
      for (final b in batches) _db.collection('users').where(FieldPath.documentId, whereIn: b).get(),
    ]);
    return [
      for (final s in snapshots)
        for (final d in s.docs) _student(d.id, d.data()),
    ];
  }

  static EnrolledStudent _student(String uid, Map<String, dynamic> d) {
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    final created = d['createdAt'];
    return EnrolledStudent(
      uid: uid,
      name: text(d['fullName']) ?? text(d['name']),
      email: text(d['email']),
      photoUrl: text(d['photoUrl']) ?? text(d['profilePic']),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
