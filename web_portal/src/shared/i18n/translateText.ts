// Simple in-memory cache to avoid duplicate API calls within a session
const cache = new Map<string, string>();

const localeToLang: Record<string, string> = {
  en: "en",
  ar: "ar",
  tr: "tr",
};

// Prevent Google Translate from butchering calligraphy terms
const CALLIGRAPHY_TERMS: Record<string, Record<string, string>> = {
  en: {
    "النسخ": "Naskh",
    "نسخ": "Naskh",
    "الرقعة": "Ruqaa",
    "رقعة": "Ruqaa",
    "الديواني": "Diwani",
    "ديواني": "Diwani",
    "الثلث": "Thuluth",
    "ثلث": "Thuluth",
    "التعليق": "Ta'liq",
    "تعليق": "Ta'liq",
    "النستعليق": "Nasta'liq",
    "نستعليق": "Nasta'liq",
    "الإجازة": "Ijazah",
    "اجازة": "Ijazah",
    "الكوفي": "Kufic",
    "كوفي": "Kufic",
    "السنبلي": "Sunbuli",
    "سنبلي": "Sunbuli",
    "المحقق": "Muhaqqaq",
    "محقق": "Muhaqqaq",
    "الريحاني": "Rayhani",
    "ريحاني": "Rayhani"
  },
  tr: {
    "النسخ": "Nesih",
    "نسخ": "Nesih",
    "الرقعة": "Rika",
    "رقعة": "Rika",
    "الديواني": "Divani",
    "ديواني": "Divani",
    "الثلث": "Sülüs",
    "ثلث": "Sülüs",
    "التعليق": "Talik",
    "تعليق": "Talik",
    "النستعليق": "Nestalik",
    "نستعليق": "Nestalik",
    "الإجازة": "İcazet",
    "اجازة": "İcazet",
    "الكوفي": "Kufi",
    "كوفي": "Kufi",
    "السنبلي": "Sünbüli",
    "سنبلي": "Sünbüli",
    "المحقق": "Muhakkak",
    "محقق": "Muhakkak",
    "الريحاني": "Reyhani",
    "ريحاني": "Reyhani"
  }
};

/**
 * Translates text using the free Google Translate endpoint (no API key required).
 * Falls back to the original text on any error.
 */
export async function translateText(
  text: string,
  targetLocale: string,
  sourceLocale = "ar"
): Promise<string> {
  const targetLang = localeToLang[targetLocale] ?? targetLocale;
  const sourceLang = localeToLang[sourceLocale] ?? sourceLocale;

  if (!text || targetLang === sourceLang) return text;

  const cacheKey = `${sourceLang}→${targetLang}:${text}`;
  if (cache.has(cacheKey)) return cache.get(cacheKey)!;

  let textToTranslate = text;
  if (sourceLang === "ar" && CALLIGRAPHY_TERMS[targetLang]) {
    const terms = CALLIGRAPHY_TERMS[targetLang];
    for (const [arTerm, translatedTerm] of Object.entries(terms)) {
      textToTranslate = textToTranslate.replace(new RegExp(`\\b${arTerm}\\b`, 'g'), translatedTerm);
      // Fallback for Arabic words which sometimes don't trigger \b nicely in JS
      textToTranslate = textToTranslate.replace(new RegExp(`(?<=^|\\s)${arTerm}(?=\\s|$)`, 'g'), translatedTerm);
    }
  }

  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${sourceLang}&tl=${targetLang}&dt=t&q=${encodeURIComponent(textToTranslate)}`;
    const res = await fetch(url);
    if (!res.ok) return text;
    const data = await res.json();
    // The response is a nested array; join all sentence segments
    const translated: string =
      (data[0] as Array<[string]>)
        ?.map((item) => item[0])
        .join("") || text;
    cache.set(cacheKey, translated);
    return translated;
  } catch {
    return text;
  }
}
