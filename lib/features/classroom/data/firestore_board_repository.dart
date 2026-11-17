import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/classroom_repositories.dart';
import '../domain/course_board.dart';

/// Calls a Cloud Function (tests pass a fake).
typedef BoardCallable = Future<Object?> Function(String name, Map<String, dynamic> data);

class FirestoreBoardRepository implements BoardRepository {
  FirestoreBoardRepository({FirebaseFirestore? firestore, BoardCallable? call})
      : _injected = firestore,
        _call = call ?? _callFunction;
  final FirebaseFirestore? _injected;
  final BoardCallable _call;

  static Future<Object?> _callFunction(String name, Map<String, dynamic> data) async {
    try {
      return (await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(name).call(data)).data;
    } on FirebaseFunctionsException catch (e) {
      final reason = e.details is Map ? (e.details as Map)['reason'] : null;
      final known = RescheduleError.values.where((r) => r.name == reason).firstOrNull;
      if (known != null) throw RescheduleRefused(known);
      rethrow;
    }
  }
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
  Future<void> reschedule(String courseId, SessionChange change) => _call('rescheduleNextSession', {
        'courseId': courseId,
        'newStart': change.newStart.millisecondsSinceEpoch,
        'newEnd': change.newEnd.millisecondsSinceEpoch,
        'note': change.note.trim(),
        // The teacher's time zone: used for courses that do not store theirs yet.
        'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      });

  @override
  Future<void> cancelReschedule(String courseId) => _call('cancelNextSessionReschedule', {'courseId': courseId});

  @override
  Future<String> displayName(String uid) async {
    final d = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    return d['name'] is String ? d['name'] as String : '';
  }
}
