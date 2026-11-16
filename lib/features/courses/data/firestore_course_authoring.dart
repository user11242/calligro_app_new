import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:calligro_app/features/teacher_money/data/payout_settings_repository.dart';

import '../domain/course_draft.dart';
import '../domain/course_repositories.dart';

class FirestoreCourseAuthoring implements CourseAuthoring {
  FirestoreCourseAuthoring({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  @override
  Future<CourseAuthor?> author(String uid) async {
    if (uid.isEmpty) return null;
    final user = (await _db.collection('users').doc(uid).get(const GetOptions(source: Source.server))).data();
    if (user == null) return null;
    final rate = user['commissionRate'];
    return CourseAuthor(
      id: uid,
      name: user['name'] is String ? user['name'] as String : '',
      photoUrl: user['photoUrl'] is String ? user['photoUrl'] as String : '',
      hasPayoutInfo: await PayoutSettingsRepository(firestore: _db).hasPayoutInfo(uid),
      commissionRate: rate is num ? rate.toDouble() : null,
    );
  }

  @override
  Future<String> create(
    CourseDraft draft,
    CourseAuthor author, {
    String generatedName = '',
    String meetLink = '',
  }) async {
    final course = _db.collection('courses').doc();
    final batch = _db.batch()
      ..set(
        course,
        draft.toDocument(author,
            createdAt: FieldValue.serverTimestamp(), generatedName: generatedName, meetLink: meetLink),
      )
      ..set(course.collection('private').doc('meetingConfig'), {
        'calligroMeetLink': meetLink,
        'createdAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    return course.id;
  }
}
