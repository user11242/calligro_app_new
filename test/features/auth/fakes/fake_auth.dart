import 'package:calligro_app/features/auth/domain/auth_repositories.dart';
import 'package:calligro_app/features/auth/domain/email_code.dart';

/// Behaves like functions/email_codes.js.
class FakeEmailCodeGateway implements EmailCodeGateway {
  final sent = <String>[];
  final codes = <String, String>{};
  final attempts = <String, int>{};
  final resets = <({String email, String code, String password})>[];
  bool cooldown = false;
  Object? failSend;

  String _k(String e) => e.trim().toLowerCase();

  @override
  Future<void> send(String email) async {
    if (cooldown) throw const EmailCodeCooldown();
    if (failSend != null) throw failSend!;
    sent.add(email);
    codes[_k(email)] = '482913';
    attempts[_k(email)] = 0;
  }

  @override
  Future<EmailCodeCheck> check(String email, String code, EmailCodePurpose purpose) async {
    final real = codes[_k(email)];
    if (real == null) return EmailCodeCheck.missing;
    if (code != real) {
      attempts[_k(email)] = (attempts[_k(email)] ?? 0) + 1;
      if (attempts[_k(email)]! >= 5) {
        codes.remove(_k(email));
        return EmailCodeCheck.locked;
      }
      return EmailCodeCheck.wrong;
    }
    if (purpose == EmailCodePurpose.register) codes.remove(_k(email));
    return EmailCodeCheck.ok;
  }

  @override
  Future<void> resetPassword(String email, String code, String newPassword) async {
    if (codes[_k(email)] != code) throw Exception('Invalid or expired verification code.');
    codes.remove(_k(email));
    resets.add((email: email, code: code, password: newPassword));
  }
}
