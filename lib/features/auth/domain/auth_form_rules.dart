/// Sign-up / sign-in form rules (pure, unit-tested). ONE copy for the
/// register form, the Google sign-up wizard and the password reset page —
/// they each had their own, and the copies disagreed.
enum NameProblem { empty, length, characters }

enum EmailProblem { empty, format }

enum PasswordProblem { empty, tooShort, complexity }

enum PortfolioProblem { empty, format }

class AuthFormRules {
  AuthFormRules._();

  static const minNameLength = 3;
  static const maxNameLength = 50;
  static const minPasswordLength = 6;

  /// 3-50 characters; letters (any language), digits and spaces; at least one letter.
  static NameProblem? name(String value) {
    final v = value.trim();
    if (v.isEmpty) return NameProblem.empty;
    if (v.length < minNameLength || v.length > maxNameLength) return NameProblem.length;
    if (!RegExp(r'^(?=.*[\p{L}])[\p{L}\p{N}\s]+$', unicode: true).hasMatch(v)) return NameProblem.characters;
    return null;
  }

  /// Any real address: "john_doe@gmail.com", "a-b@my-school.edu.jo", "x+y@z.academy".
  /// (The register form used to refuse "_", "-" and "+"; the reset page refused
  /// domains longer than 4 letters, like ".academy".)
  static EmailProblem? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return EmailProblem.empty;
    if (!RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)*\.[^\s@.]{2,}$').hasMatch(v)) return EmailProblem.format;
    return null;
  }

  /// At least 6 characters with one capital letter, one digit and one symbol.
  /// Any symbol counts ("#", ".", "_"…): only @$!%*?& used to, and anything
  /// else made a strong password "too weak".
  static PasswordProblem? password(String value) {
    if (value.isEmpty) return PasswordProblem.empty;
    if (value.length < minPasswordLength) return PasswordProblem.tooShort;
    // Capitals in any language (Turkish Ü, Ş…); a symbol is anything that is
    // not a letter, digit or space.
    final ok = RegExp(r'\p{Lu}', unicode: true).hasMatch(value) &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(value);
    return ok ? null : PasswordProblem.complexity;
  }

  /// http(s) link with a real domain (unchanged rule).
  static PortfolioProblem? portfolio(String value) {
    if (value.isEmpty) return PortfolioProblem.empty;
    final urlRegex = RegExp(
      r'^(http|https):\/\/(([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})(/[a-zA-Z0-9-._~:/?#\[\]@!$&' "'" r'()*+,;=%]*)?$',
      caseSensitive: false,
    );
    return urlRegex.hasMatch(value.trim()) ? null : PortfolioProblem.format;
  }
}
