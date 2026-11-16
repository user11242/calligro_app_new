import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/utils/date_utils.dart';

void main() {
  group('CalligroDateUtils.toDateTime', () {
    test('returns null when input is null', () {
      expect(CalligroDateUtils.toDateTime(null), isNull);
    });

    test('converts Timestamp to DateTime correctly', () {
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      
      final result = CalligroDateUtils.toDateTime(timestamp);
      
      expect(result, isA<DateTime>());
      // Comparing milliseconds since microseconds can sometimes truncate in Firestore Timestamps
      expect(result!.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('returns the same DateTime if input is DateTime', () {
      final now = DateTime.now();
      final result = CalligroDateUtils.toDateTime(now);
      expect(result, equals(now));
    });

    test('parses valid ISO String to DateTime', () {
      const dateString = '2025-01-01T12:00:00Z';
      final result = CalligroDateUtils.toDateTime(dateString);
      
      expect(result, isNotNull);
      expect(result!.year, 2025);
      expect(result.month, 1);
      expect(result.isUtc, isTrue);
    });

    test('handles Firestore JSON map format (_seconds)', () {
      final map = {'_seconds': 1704067200, '_nanoseconds': 0}; // 2024-01-01 00:00:00 UTC
      final result = CalligroDateUtils.toDateTime(map);
      
      expect(result, isNotNull);
      expect(result!.year, 2024);
    });
  });

  group('CalligroDateUtils.toTimestamp', () {
    test('returns null when input is null', () {
      expect(CalligroDateUtils.toTimestamp(null), isNull);
    });

    test('returns the same Timestamp if input is Timestamp', () {
      final timestamp = Timestamp.now();
      final result = CalligroDateUtils.toTimestamp(timestamp);
      expect(result, equals(timestamp));
    });

    test('converts DateTime to Timestamp', () {
      final now = DateTime.now();
      final result = CalligroDateUtils.toTimestamp(now);
      
      expect(result, isA<Timestamp>());
      expect(result!.toDate().millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });
  });
}
