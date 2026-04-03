
class CountryUtils {
  /// Maps common phone country codes to ISO 3166-1 alpha-2 country codes.
  static final Map<String, String> _phoneToIso = {
    '966': 'SA', // Saudi Arabia
    '962': 'JO', // Jordan
    '971': 'AE', // UAE
    '965': 'KW', // Kuwait
    '974': 'QA', // Qatar
    '973': 'BH', // Bahrain
    '968': 'OM', // Oman
    '20': 'EG',  // Egypt
    '90': 'TR',  // Turkey
    '98': 'IR',  // Iran
    '964': 'IQ', // Iraq
    '961': 'LB', // Lebanon
    '963': 'SY', // Syria
    '212': 'MA', // Morocco
    '213': 'DZ', // Algeria
    '216': 'TN', // Tunisia
    '218': 'LY', // Libya
    '249': 'SD', // Sudan
    '967': 'YE', // Yemen
    '970': 'PS', // Palestine
    '1': 'US',   // USA/Canada (Defaults to US)
    '44': 'GB',  // UK
    '33': 'FR',  // France
    '49': 'DE',  // Germany
    '34': 'ES',  // Spain
    '39': 'IT',  // Italy
    '7': 'RU',   // Russia
    '86': 'CN',  // China
    '81': 'JP',  // Japan
    '82': 'KR',  // Korea
    '92': 'PK',  // Pakistan
    '91': 'IN',  // India
    '62': 'ID',  // Indonesia
    '60': 'MY',  // Malaysia
    '234': 'NG', // Nigeria
    '27': 'ZA',  // South Africa
    '55': 'BR',  // Brazil
    '52': 'MX',  // Mexico
    '61': 'AU',  // Australia
  };

  /// Returns a flag emoji from a phone number string (e.g., "+96650...", "00966...", "966...").
  static String getFlagFromPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return "";

    // 1. Normalize: remove all non-numeric characters
    String digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // 2. Handle '00' prefix (standard international prefix)
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    
    if (digits.isEmpty) return "";

    // 3. Try to match prefixes (longest first: 3, 2, 1 digits)
    // We check common country code lengths
    for (int len = 3; len >= 1; len--) {
      if (digits.length >= len) {
        String prefix = digits.substring(0, len);
        if (_phoneToIso.containsKey(prefix)) {
          return _isoToEmoji(_phoneToIso[prefix]!);
        }
      }
    }

    return "";
  }

  /// Converts ISO country code to Emoji flag.
  static String _isoToEmoji(String isoCode) {
    return isoCode.toUpperCase().replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397),
    );
  }
}
