// Simple in-memory cache to avoid duplicate API calls within a session
const cache = new Map<string, string>();

const localeToLang: Record<string, string> = {
  en: "en",
  ar: "ar",
  tr: "tr",
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

  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${sourceLang}&tl=${targetLang}&dt=t&q=${encodeURIComponent(text)}`;
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
