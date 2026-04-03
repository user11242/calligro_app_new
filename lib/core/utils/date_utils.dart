import 'package:cloud_firestore/cloud_firestore.dart';

class CalligroDateUtils {
  /// Safely converts various date formats (Timestamp, String, DateTime) to DateTime
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    // Handle cases where it might be a Map (Firestore JSON representation sometimes)
    if (value is Map && value.containsKey('_seconds')) {
      return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0).toDate();
    }
    return null;
  }

  /// Safely converts a value to a Timestamp for Firestore saving
  static Timestamp? toTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return null;
  }
}
