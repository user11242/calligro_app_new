import 'package:flutter/services.dart';

class NumericUtils {
  /// Converts non-English digits from various languages to standard English digits.
  /// If [clean] is true, it also removes spaces, dashes, and brackets.
  static String normalize(String input, {bool clean = false}) {
    if (input.isEmpty) return input;
    
    // Mapping of various Unicode digit sets to '0123456789'
    const String nonEnglishDigits = 
      '٠١٢٣٤٥٦٧٨٩' // Arabic-Indic
      '۰۱۲۳۴۵۶۷۸۹' // Eastern Arabic-Indic (Persian/Urdu)
      '०१२३४५६७८९' // Devanagari (Hindi)
      '০১২৩৪৫৬৭৮৯'; // Bengali
    
    const String englishDigits = 
      '0123456789'
      '0123456789'
      '0123456789'
      '0123456789';

    String result = "";
    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      int index = nonEnglishDigits.indexOf(char);
      if (index != -1) {
        result += englishDigits[index];
      } else {
        if (clean) {
          // If cleaning, only keep standard digits or the '+' prefix
          if (RegExp(r'[0-9+]').hasMatch(char)) {
            result += char;
          }
        } else {
          result += char;
        }
      }
    }
    
    return result;
  }

  /// A TextInputFormatter that converts international digits to English in real-time.
  static TextInputFormatter get digitFormatter => TextInputFormatter.withFunction(
    (oldValue, newValue) {
      final normalized = normalize(newValue.text);
      return newValue.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    },
  );
}
