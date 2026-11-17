/// Teacher announcements and session changes (pure Dart).
library;

import 'package:calligro_app/features/courses/domain/course_schedule.dart' show RescheduleError;

export 'package:calligro_app/features/courses/domain/course_schedule.dart' show RescheduleError;

class Announcement {
  final String id;
  final String message;
  final String senderName;
  final DateTime? timestamp;
  const Announcement({required this.id, this.message = '', this.senderName = '', this.timestamp});

  factory Announcement.fromMap(String id, Map<String, dynamic> d) {
    DateTime? at;
    try {
      final dynamic t = d['timestamp'];
      if (t is DateTime) {
        at = t;
      } else if (t != null) {
        at = t.toDate() as DateTime;
      }
    } catch (_) {}
    return Announcement(
      id: id,
      message: d['message'] is String ? d['message'] as String : '',
      senderName: d['senderName'] is String ? d['senderName'] as String : '',
      timestamp: at,
    );
  }
}

/// The NEXT class moved to [newStart]–[newEnd], with an optional [note] to the
/// students. Checked by CourseSchedule.planMove here and again by the server
/// (functions/schedule.js), which also moves the course dates and notifies the
/// students once (functions/notifications.js).
class SessionChange {
  final DateTime newStart;
  final DateTime newEnd;
  final String note;

  const SessionChange({required this.newStart, required this.newEnd, this.note = ''});

  bool get isValid => newEnd.isAfter(newStart);
}

/// The server refused the move, for [reason].
class RescheduleRefused implements Exception {
  final RescheduleError reason;
  const RescheduleRefused(this.reason);
  @override
  String toString() => 'RescheduleRefused(${reason.name})';
}
