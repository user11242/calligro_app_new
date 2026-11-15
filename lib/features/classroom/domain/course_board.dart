/// Teacher announcements and session changes (pure Dart).
library;

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

/// Today's session moved to another time. Students are notified by the server
/// (functions/notifications.js notifyStudentsOnReschedule) — the app used to
/// write its own notice too, so every student got two.
class SessionChange {
  final DateTime originalDate;
  final DateTime newStart;
  final DateTime newEnd;

  const SessionChange({required this.originalDate, required this.newStart, required this.newEnd});

  bool get isValid => newEnd.isAfter(newStart);
}
