import 'package:calligro_app/core/utils/numeric_utils.dart';
import 'package:calligro_app/features/auth/domain/account_keys.dart';
import 'package:calligro_app/features/auth/domain/auth_destination.dart';
import 'package:calligro_app/features/auth/domain/email_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('account keys (THE BUG: deleted teachers\' phones stayed "taken")', () {
    test('phone: same as registration has always used (NumericUtils clean)', () {
      for (final p in ['+962 79 123 4567', '(079) 123-4567', '+٩٦٢٧٩١٢٣٤٥٦٧', '۰۷۹۱۲۳', '+९६२', '০১২']) {
        expect(AccountKeys.phone(p), NumericUtils.normalize(p, clean: true), reason: p);
      }
      expect(AccountKeys.phone('+962 79-123'), '+96279123', reason: 'the "+" is kept (deletion used to drop it)');
    });
    test('email and username: trimmed, lower-case', () {
      expect(AccountKeys.email('  Ali@Example.COM '), 'ali@example.com');
      expect(AccountKeys.username(' Yazan Q '), 'yazan q');
    });
  });

  group('where a signed-in user lands (unchanged rules)', () {
    AuthDestination d(Map<String, dynamic>? m) => AuthRouting.destinationFor(m);
    test('no document / no role → finish sign-up', () {
      expect(d(null), AuthDestination.onboarding);
      expect(d({}), AuthDestination.onboarding);
      expect(d({'role': ''}), AuthDestination.onboarding);
    });
    test('teachers by status (missing = approved)', () {
      expect(d({'role': 'teacher', 'status': 'approved'}), AuthDestination.teacherDashboard);
      expect(d({'role': 'teacher'}), AuthDestination.teacherDashboard);
      expect(d({'role': 'teacher', 'status': 'rejected'}), AuthDestination.teacherRejected);
      expect(d({'role': 'teacher', 'status': 'pending'}), AuthDestination.teacherPending);
      expect(d({'role': 'teacher', 'status': 'anything'}), AuthDestination.teacherPending);
    });
    test('admin; student; unknown roles as students (as before)', () {
      expect(d({'role': 'admin'}), AuthDestination.adminDashboard);
      expect(d({'role': 'student'}), AuthDestination.studentDashboard);
      expect(d({'role': 'other'}), AuthDestination.studentDashboard);
    });
  });

  test('splash first route (unchanged): only approved teachers / admins / students skip ahead', () {
    expect(AuthRouting.splashRoute(null), '/');
    expect(AuthRouting.splashRoute({'role': 'teacher', 'status': 'approved'}), '/teacherDashboard');
    expect(AuthRouting.splashRoute({'role': 'teacher'}), '/teacherDashboard');
    expect(AuthRouting.splashRoute({'role': 'teacher', 'status': 'pending'}), '/');
    expect(AuthRouting.splashRoute({'role': 'admin'}), '/adminDashboard');
    expect(AuthRouting.splashRoute({'role': 'student'}), '/studentDashboard');
    expect(AuthRouting.splashRoute({}), '/studentDashboard', reason: 'missing role = student, as before');
    expect(AuthRouting.splashRoute({'role': 'other'}), '/');
  });

  group('email codes', () {
    test('server results', () {
      expect(EmailCodeCheck.fromServer('ok'), EmailCodeCheck.ok);
      expect(EmailCodeCheck.fromServer('locked'), EmailCodeCheck.locked);
      expect(EmailCodeCheck.fromServer('???'), EmailCodeCheck.wrong);
    });
    test('six digits', () {
      expect(EmailCodeRules.looksComplete('123456'), isTrue);
      expect(EmailCodeRules.looksComplete('12345'), isFalse);
      expect(EmailCodeRules.looksComplete('12a456'), isFalse);
    });
  });
}
