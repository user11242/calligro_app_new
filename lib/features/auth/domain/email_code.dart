/// Email verification codes (created, sent and checked by the server —
/// functions/email_codes.js). The app never sees or compares the code.
enum EmailCodePurpose { register, reset }

enum EmailCodeCheck {
  ok,
  wrong,
  expired,

  /// No code requested (or already used).
  missing,

  /// Too many wrong tries: request a new code.
  locked;

  static EmailCodeCheck fromServer(Object? value) =>
      EmailCodeCheck.values.firstWhere((v) => v.name == value, orElse: () => EmailCodeCheck.wrong);
}

class EmailCodeRules {
  EmailCodeRules._();
  static const length = 6;

  /// Typed codes may use Arabic digits; the server compares 0-9.
  static bool looksComplete(String digits) => RegExp(r'^\d{6}$').hasMatch(digits);
}

/// Asking for a new code within a minute.
class EmailCodeCooldown implements Exception {
  const EmailCodeCooldown();
}
