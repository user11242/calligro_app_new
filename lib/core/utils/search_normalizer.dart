/// Search normalization for English + Arabic (pure Dart; no Flutter).
class SearchNormalizer {
  SearchNormalizer._();

  static const _digits = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4', '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };

  /// Arabic-Indic / Persian digits → 0-9.
  static String numerics(String input) {
    var result = input;
    _digits.forEach((k, v) => result = result.replaceAll(k, v));
    return result;
  }

  /// No harakat; أ إ آ → ا; ة → ه; ى → ي.
  static String arabic(String text) => text
      .replaceAll(RegExp(r'[ً-ْ]'), '')
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');

  static String prepare(String text) => arabic(numerics(text.toLowerCase().trim()));
}
