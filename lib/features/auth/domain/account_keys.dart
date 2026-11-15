/// The ids of the "taken" registries (locked_usernames / locked_emails /
/// locked_phones). EVERY place that reserves or releases one uses these, so a
/// reservation is always found again (account deletion used to strip the
/// phone's "+" while registration kept it, so phones stayed "taken" forever).
/// functions/index.js deleteOwnAccount uses the same phone rule.
class AccountKeys {
  AccountKeys._();

  static String username(String name) => name.trim().toLowerCase();

  static String email(String email) => email.trim().toLowerCase();

  // Same digit sets as NumericUtils.normalize (registration has always used it).
  static const _foreignDigits = '٠١٢٣٤٥٦٧٨٩' '۰۱۲۳۴۵۶۷۸۹' '०१२३४५६७८९' '০১২৩৪৫৬৭৮৯';

  /// Foreign digits → 0-9; only digits and "+" kept
  /// (= NumericUtils.normalize(phone, clean: true)).
  static String phone(String phone) {
    final out = StringBuffer();
    for (final ch in phone.split('')) {
      final i = _foreignDigits.indexOf(ch);
      if (i != -1) {
        out.write(i % 10);
      } else if (RegExp(r'[0-9+]').hasMatch(ch)) {
        out.write(ch);
      }
    }
    return out.toString();
  }
}
