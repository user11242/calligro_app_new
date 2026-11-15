import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/rating_models.dart';
import '../domain/rating_repository.dart';

class FirestoreRatingRepository implements RatingRepository {
  FirestoreRatingRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  @override
  Future<List<RateableCourse>> enrolledCourses(String uid) async {
    final snap = await _db.collection('courses').where('enrolledStudents', arrayContains: uid).get();
    return [
      for (final d in snap.docs)
        RateableCourse(
          courseId: d.id,
          teacherId: d.data()['teacherId'] is String ? d.data()['teacherId'] as String : '',
          enrolledStudents: [for (final s in (d.data()['enrolledStudents'] as List?) ?? const []) if (s is String) s],
          endDate: _date(d.data()['endDate']),
          data: d.data(),
        ),
    ];
  }

  @override
  Future<Set<String>> reviewedCourseIds(String uid) async {
    // Also finds reviews saved by older app versions under random ids.
    final snap = await _db.collection('reviews').where('studentId', isEqualTo: uid).get();
    return {for (final d in snap.docs) if (d.data()['courseId'] is String) d.data()['courseId'] as String};
  }

  @override
  Future<void> submit(Review review) => _db.runTransaction((tx) async {
        final ref = _db.collection('reviews').doc(review.id);
        if ((await tx.get(ref)).exists) throw const AlreadyRatedException();
        tx.set(ref, review.toDocument(timestamp: FieldValue.serverTimestamp()));
      });

  CollectionReference<Map<String, dynamic>> _prompts(String uid) =>
      _db.collection('users').doc(uid).collection('rating_prompts');

  @override
  Future<Map<String, RatingPrompt>> prompts(String uid) async {
    final snap = await _prompts(uid).get();
    return {
      for (final d in snap.docs)
        d.id: RatingPrompt(
          courseId: d.id,
          timesShown: d.data()['timesShown'] is num ? (d.data()['timesShown'] as num).toInt() : 0,
          lastShownAt: _date(d.data()['lastShownAt']),
        ),
    };
  }

  @override
  Future<void> markShown(String uid, String courseId) => _prompts(uid).doc(courseId).set({
        'timesShown': FieldValue.increment(1),
        'lastShownAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<String> studentName(String uid) async {
    final d = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    return d['name'] is String ? d['name'] as String : '';
  }
}
