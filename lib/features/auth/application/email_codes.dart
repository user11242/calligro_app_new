import '../domain/auth_repositories.dart';
import '../domain/email_code.dart';

enum SendCodeOutcome { sent, cooldown, failed }

/// Email verification for registration and password reset. The code is
/// created, emailed and checked by the server; this layer never knows it.
class EmailCodes {
  EmailCodes({required EmailCodeGateway gateway}) : _gateway = gateway;
  final EmailCodeGateway _gateway;

  Future<SendCodeOutcome> send(String email) async {
    try {
      await _gateway.send(email.trim());
      return SendCodeOutcome.sent;
    } on EmailCodeCooldown {
      return SendCodeOutcome.cooldown;
    } catch (_) {
      return SendCodeOutcome.failed;
    }
  }

  Future<EmailCodeCheck> verify(String email, String code, {required EmailCodePurpose purpose}) async {
    if (!EmailCodeRules.looksComplete(code)) return EmailCodeCheck.wrong;
    try {
      return await _gateway.check(email.trim(), code, purpose);
    } catch (_) {
      return EmailCodeCheck.wrong;
    }
  }

  /// The reset page's last step: the code typed earlier + the new password.
  Future<void> resetPassword(String email, String code, String newPassword) =>
      _gateway.resetPassword(email.trim(), code, newPassword);
}
