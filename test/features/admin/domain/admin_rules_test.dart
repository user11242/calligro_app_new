import 'package:calligro_app/features/admin/domain/admin_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('changing a role (one path for change role, promote and revoke)', () {
    test('student → teacher: approved, teachers entry created, students entry removed', () {
      final p = AdminRules.changeRole({'role': 'student', 'name': 'Sara'}, 'teacher');
      expect(p.userUpdate, {'role': 'teacher', 'approved': true, 'status': 'approved'});
      expect([p.setCollection, p.setData['name'], p.setData['role'], p.deleteCollections], ['teachers', 'Sara', 'teacher', ['students']]);
    });
    test('teacher → admin (promote): leaves NO teacher/student entry behind', () {
      final p = AdminRules.changeRole({'role': 'teacher'}, 'admin');
      expect([p.setCollection, p.deleteCollections], [null, ['students', 'teachers']]);
    });
    test('admin → student (revoke): a students entry is created', () {
      final p = AdminRules.changeRole({'role': 'admin', 'name': 'Omar'}, 'student');
      expect([p.setCollection, p.deleteCollections, p.setData['role']], ['students', ['teachers'], 'student']);
    });
    test('same role: nothing to do', () => expect(AdminRules.changeRole({'role': 'admin'}, 'admin').isNoChange, isTrue));
  });

  group('suspending (THE BUG: suspend blocked nothing)', () {
    test('back to pending, not approved, dated — what routing and the rules actually check', () {
      expect(AdminRules.suspend('NOW'), {'status': 'pending', 'approved': false, 'suspendedAt': 'NOW'});
    });
    test('restored by approving', () => expect(AdminRules.approve, {'status': 'approved'}));
  });

  test('commission between 0 and 100 %', () {
    expect([0.0, 70.0, 100.0].every(AdminRules.isValidCommissionPercent), isTrue);
    expect([-1.0, 100.5].any(AdminRules.isValidCommissionPercent), isFalse);
  });

  test('reservations released on delete use the registration keys (Arabic-digit phones were left reserved)', () {
    expect(AdminRules.reservationsOf({'email': ' Ali@X.com', 'name': 'Ali Q', 'phone': '+٩٦٢ 79 1'}), {
      'locked_emails': 'ali@x.com',
      'locked_usernames': 'ali q',
      'locked_phones': '+962791',
    });
    expect(AdminRules.reservationsOf({}), isEmpty);
  });
}
