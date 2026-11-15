import 'dart:io';

import 'package:calligro_app/features/notifications/domain/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Notifications guard-rails: every push opens something, and is sent once.
void main() {
  Iterable<File> dartIn(String dir) =>
      Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  final server = File('functions/notifications.js').readAsStringSync();

  test('every route the server sends is one the app opens (no silent taps)', () {
    final routes = RegExp(r"route:\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]").allMatches(server).map((m) => m.group(1)!).toSet();
    expect(routes, isNotEmpty);
    for (final route in routes) {
      final target = NotificationTarget.fromData({'route': route, 'postId': 'p', 'courseId': 'c', 'userId': 'u'});
      expect(target, isNot(isA<InboxTarget>()), reason: 'the server sends "$route" but the app does not know it');
    }
  });

  test('every server notification is sent once per event (keyed inbox item)', () {
    final calls = RegExp(r'sendNotification\(\{\s*\n\s*key:').allMatches(server).length;
    final all = RegExp(r'sendNotification\(\{\s*\n').allMatches(server).length;
    expect(calls, all, reason: 'a trigger calls sendNotification without key: event.id');
    expect(File('functions/notification_delivery.js').readAsStringSync().contains('.create('), isTrue);
  });

  test('domain and application are pure', () {
    for (final dir in ['lib/features/notifications/domain', 'lib/features/notifications/application']) {
      for (final f in dartIn(dir)) {
        final c = f.readAsStringSync();
        expect(c.contains('package:flutter/') || c.contains('package:firebase_') || c.contains('package:cloud_firestore'), isFalse,
            reason: f.path);
      }
    }
  });

  test('all taps go through the ONE opener; no fixed launch delay; no second copy on iOS', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect('NotificationServices.instance.opener.openData('.allMatches(main).length, greaterThanOrEqualTo(3));
    expect(main.contains('Duration(milliseconds: 800)'), isFalse);
    expect(main.contains('defaultTargetPlatform == TargetPlatform.android'), isTrue);
    for (final dash in [
      'lib/features/student/student_dashboard.dart',
      'lib/features/teacher/teacher_dashboard.dart',
      'lib/features/admin/admin_dashboard.dart',
    ]) {
      expect(File(dash).readAsStringSync().contains('NotificationTapHandler('), isTrue, reason: dash);
    }
  });

  test('the app writes no notifications for others; inbox screens use the repository', () {
    for (final f in dartIn('lib')) {
      if (f.path.contains('features/admin/')) continue; // payout status (admin only)
      final c = f.readAsStringSync();
      expect(c.contains(".collection('notifications').add(") || c.contains(".collection('notifications')\n"), isFalse,
          reason: '${f.path} writes notifications itself');
    }
    for (final p in ['lib/features/notifications/presentation/notifications_page.dart', 'lib/core/widgets/notification_bell_button.dart']) {
      expect(File(p).readAsStringSync().contains("collection('notifications')"), isFalse, reason: p);
    }
  });

  test('sign-out releases the push token; the server keeps one token per account', () {
    expect(File('lib/features/auth/data/services/auth_service.dart').readAsStringSync().contains('tokens.unregister('), isTrue);
    expect(File('functions/index.js').readAsStringSync().contains('claimPushToken'), isTrue);
  });
}
