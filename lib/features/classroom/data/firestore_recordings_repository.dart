import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/classroom_repositories.dart';
import '../domain/course_recordings.dart';

class FirestoreRecordingsRepository implements RecordingsRepository {
  FirestoreRecordingsRepository({FirebaseFirestore? firestore, Future<void> Function(String courseId)? recover})
      : _injected = firestore,
        _recover = recover;
  final FirebaseFirestore? _injected;
  final Future<void> Function(String courseId)? _recover;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _recordings(String courseId) =>
      _db.collection('courses').doc(courseId).collection('recordings');

  @override
  Stream<List<CourseRecording>> watchRecordings(String courseId) => _recordings(courseId)
      .orderBy('recordedAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) CourseRecording.fromMap(d.id, d.data())]);

  @override
  Future<void> rename(String courseId, String recordingId, String? title) => _recordings(courseId)
      .doc(recordingId)
      .update({'title': (title == null || title.trim().isEmpty) ? FieldValue.delete() : title.trim()});

  @override
  Future<void> recoverMissing(String courseId) async {
    final recover = _recover;
    if (recover != null) return recover(courseId);
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('livekit-reconcileCourseRecordings')
        .call({'courseId': courseId});
  }
}
