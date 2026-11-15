import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/classroom_repositories.dart';
import '../domain/course_board.dart';

class FirestoreBoardRepository implements BoardRepository {
  FirestoreBoardRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _course(String id) => _db.collection('courses').doc(id);

  @override
  Stream<List<Announcement>> watchAnnouncements(String courseId) => _course(courseId)
      .collection('announcements')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Announcement.fromMap(d.id, d.data())]);

  @override
  Future<void> postAnnouncement(String courseId, {required String message, required String senderName}) =>
      _course(courseId).collection('announcements').add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': senderName,
        'type': 'teacher_post',
      });

  @override
  Future<void> reschedule(String courseId, SessionChange change) => _course(courseId).update({
        'rescheduledSession': {
          'originalDate': Timestamp.fromDate(change.originalDate),
          'newStartTime': Timestamp.fromDate(change.newStart),
          'newEndTime': Timestamp.fromDate(change.newEnd),
        },
      });

  @override
  Future<void> cancelReschedule(String courseId) =>
      _course(courseId).update({'rescheduledSession': FieldValue.delete()});

  @override
  Future<String> displayName(String uid) async {
    final d = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    return d['name'] is String ? d['name'] as String : '';
  }
}
