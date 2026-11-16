import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Admin guard-rails: actions go through AdminService + AdminRules.
void main() {
  Iterable<File> dartIn(String dir) =>
      Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  test('admin pages write nothing themselves (approve, commission, suspend, delete go through AdminService)', () {
    for (final f in [...dartIn('lib/features/admin/pages'), ...dartIn('lib/features/admin/tabs')]) {
      final c = f.readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      expect(RegExp(r"FirebaseFirestore\.instance\.collection\('users'\)\.doc\([a-zA-Z]+\)\.(delete|update)\(").hasMatch(c), isFalse,
          reason: f.path);
      expect(c.contains("batch.update(firestore.collection(\"users\")"), isFalse, reason: f.path);
      expect(c.contains("'approved':false"), isFalse, reason: '${f.path}: suspend via AdminService.suspendTeacher');
    }
  });

  test('one role-change path; reservations released with the registration keys', () {
    final s = File('lib/features/admin/data/services/admin_service.dart').readAsStringSync();
    expect(s.contains('AdminRules.changeRole('), isTrue);
    expect(s.contains("await changeUserRole(found.id, 'admin');"), isTrue);
    expect(s.contains("await changeUserRole(uid, 'student');"), isTrue);
    expect(s.contains('AdminRules.reservationsOf(data)'), isTrue);
    expect(s.contains("replaceAll(RegExp(r'[^\\d+]')"), isFalse);
    expect(s.contains("orderBy('timestamp', descending: true).limit(5)"), isTrue, reason: 'posts in recent activity');
  });

  test('settled sales stay in teacher earnings (app + server)', () {
    expect(File('lib/features/teacher_money/data/firestore_earnings_repository.dart').readAsStringSync()
        .contains('whereIn: EarningsRules.earnedStatuses'), isTrue);
    expect(File('functions/withdrawals.js').readAsStringSync().contains('"in", EARNED_STATUSES'), isTrue);
  });
}
