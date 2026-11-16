import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Auth guard-rails: codes are the server's, keys are shared, no secrets ship.
void main() {
  Iterable<File> dartIn(String dir) =>
      Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  test('the app never creates, sends or compares an email code itself', () {
    for (final f in dartIn('lib')) {
      final c = f.readAsStringSync();
      expect(c.contains('api.brevo.com'), isFalse, reason: '${f.path} talks to Brevo');
      expect(c.contains('BREVO_API_KEY'), isFalse, reason: f.path);
    }
    final step = File('lib/features/auth/widgets/verification/universal_otp_step.dart').readAsStringSync();
    expect(step.contains('Random()'), isFalse);
    expect(step.contains('emailCodes.verify('), isTrue);
  });

  test('no .env (with Twilio/Postmark/Brevo keys) is bundled into the app', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(RegExp(r'^\s*-\s*\.env\s*$', multiLine: true).hasMatch(pubspec), isFalse);
    expect(pubspec.contains('flutter_dotenv'), isFalse);
  });

  test('password reset sends the code it verified (it used to send none)', () {
    final page = File('lib/features/auth/pages/forgot_password_page.dart').readAsStringSync();
    expect(page.contains('emailCodes.resetPassword(_userEmail!, _verifiedCode'), isTrue);
    expect(page.contains("httpsCallable(\n        'resetPasswordWithOtp'"), isFalse);
  });

  test('every reservation of username/email/phone goes through AccountLocks (one key format)', () {
    for (final f in dartIn('lib/features/auth/data/services')) {
      final c = f.readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      for (final col in ['locked_emails', 'locked_usernames', 'locked_phones']) {
        expect(c.contains("collection('$col').doc(") && c.contains('batch.set(') && c.contains("'$col').doc(user"), isFalse,
            reason: '${f.path} reserves $col itself');
      }
    }
    final keys = File('lib/features/auth/domain/account_keys.dart').readAsStringSync();
    final server = File('functions/index.js').readAsStringSync();
    expect(server.contains('const cleanPhone = phoneKey(phone);'), isTrue, reason: 'server deletion uses the same phone key');
    expect(keys.contains("'٠١٢٣٤٥٦٧٨٩' '۰۱۲۳۴۵۶۷۸۹' '०१२३४५६७८९' '০১২৩৪৫৬৭৮৯'"), isTrue);
  });

  test('the server checks codes with an attempt limit and lower-cased emails', () {
    final codes = File('functions/email_codes.js').readAsStringSync();
    expect(codes.contains('const MAX_ATTEMPTS = 5;'), isTrue);
    expect(codes.contains('toLowerCase()'), isTrue);
    expect(File('functions/index.js').readAsStringSync().contains('checkCode(admin.firestore(), email, otp, { consume: true })'), isTrue);
  });

  test('the start-up router uses the tested routing rule', () {
    expect(File('lib/screens/auth_wrapper.dart').readAsStringSync().contains('AuthRouting.destinationFor('), isTrue);
  });

  test('auth screens reach Firebase only through AuthService / AuthScope', () {
    final screens = [...dartIn('lib/features/auth/pages'), ...dartIn('lib/features/auth/widgets')];
    for (final f in screens) {
      final c = f.readAsStringSync();
      for (final banned in [
        'FirebaseFirestore.instance',
        'FirebaseFunctions.instance',
        'FirebaseMessaging.instance',
        'FirebaseAuth.instance',
        'AuthService()',
      ]) {
        expect(c.contains(banned), isFalse, reason: '${f.path} uses $banned');
      }
    }
  });

  test('ONE copy of the form rules (the screens had three that disagreed)', () {
    for (final p in [
      'lib/features/auth/widgets/register_form.dart',
      'lib/features/auth/pages/google_register_wizard.dart',
      'lib/features/auth/pages/forgot_password_page.dart',
    ]) {
      final c = File(p).readAsStringSync();
      expect(c.contains('AuthFormRules.'), isTrue, reason: p);
      expect(c.contains("(?=.*[A-Z])"), isFalse, reason: '$p has its own password regex');
      expect(c.contains('@[a-zA-Z0-9]+'), isFalse, reason: '$p has its own email regex');
    }
  });
}
