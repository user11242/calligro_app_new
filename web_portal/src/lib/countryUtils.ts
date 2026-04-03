/**
 * Maps common phone country codes to ISO 3166-1 alpha-2 country codes.
 */
const phoneToIso: Record<string, string> = {
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
  '1': 'US',   // USA/Canada
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

/**
 * Returns a flag emoji from a phone number string.
 */
export const getFlagFromPhoneNumber = (phoneNumber?: string): string => {
  if (!phoneNumber) return "";

  // 1. Normalize: remove all non-numeric characters
  const digits = phoneNumber.replace(/\D/g, '');
  
  // 2. Handle '00' prefix
  const cleanDigits = digits.startsWith('00') ? digits.substring(2) : digits;
  
  if (!cleanDigits) return "";

  // 3. Try to match prefixes (longest first: 3, 2, 1 digits)
  for (let len = 3; len >= 1; len--) {
    if (cleanDigits.length >= len) {
      const prefix = cleanDigits.substring(0, len);
      if (phoneToIso[prefix]) {
        return isoToEmoji(phoneToIso[prefix]);
      }
    }
  }

  return "";
};

/**
 * Converts ISO country code to Emoji flag.
 */
const isoToEmoji = (isoCode: string): string => {
  return isoCode
    .toUpperCase()
    .replace(/./g, (char) => 
      String.fromCodePoint(char.charCodeAt(0) + 127397)
    );
};
