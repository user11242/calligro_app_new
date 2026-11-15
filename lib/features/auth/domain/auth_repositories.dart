import 'email_code.dart';

/// The server's email codes (functions/email_codes.js + resetPasswordWithOtp).
abstract interface class EmailCodeGateway {
  /// Throws [EmailCodeCooldown] when asked again within a minute.
  Future<void> send(String email);
  Future<EmailCodeCheck> check(String email, String code, EmailCodePurpose purpose);

  /// Verifies [code] (uses it up) and sets the new password. Throws with the
  /// server's message when refused.
  Future<void> resetPassword(String email, String code, String newPassword);
}
