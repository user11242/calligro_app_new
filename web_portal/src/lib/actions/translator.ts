"use server";

const CALLIGRAPHY_TERMS: Record<string, Record<string, string>> = {
  en: {
    "النسخ": "Naskh", "نسخ": "Naskh",
    "الرقعة": "Ruqaa", "رقعة": "Ruqaa",
    "الديواني": "Diwani", "ديواني": "Diwani",
    "الثلث": "Thuluth", "ثلث": "Thuluth",
    "التعليق": "Ta'liq", "تعليق": "Ta'liq",
    "النستعليق": "Nasta'liq", "نستعليق": "Nasta'liq",
    "الإجازة": "Ijazah", "اجازة": "Ijazah",
    "الكوفي": "Kufic", "كوفي": "Kufic",
    "السنبلي": "Sunbuli", "سنبلي": "Sunbuli",
    "المحقق": "Muhaqqaq", "محقق": "Muhaqqaq",
    "الريحاني": "Rayhani", "ريحاني": "Rayhani"
  },
  tr: {
    "النسخ": "Nesih", "نسخ": "Nesih",
    "الرقعة": "Rika", "رقعة": "Rika",
    "الديواني": "Divani", "ديواني": "Divani",
    "الثلث": "Sülüs", "ثلث": "Sülüs",
    "التعليق": "Talik", "تعليق": "Talik",
    "النستعليق": "Nestalik", "نستعليق": "Nestalik",
    "الإجازة": "İcazet", "اجازة": "İcazet",
    "الكوفي": "Kufi", "كوفي": "Kufi",
    "السنبلي": "Sünbüli", "سنبلي": "Sünbüli",
    "المحقق": "Muhakkak", "محقق": "Muhakkak",
    "الريحاني": "Reyhani", "ريحاني": "Reyhani"
  }
};

/**
 * Server Action to translate text using the Google Translate API (matching Flutter app logic).
 * This prevents CORS issues and keeps API calls server-side.
 */
export async function translateText(text: string, target: string) {
  if (!text || text === "Untitled" || text === "Untitled Course") return text;
  
  let textToTranslate = text;
  if (CALLIGRAPHY_TERMS[target]) {
    const terms = CALLIGRAPHY_TERMS[target];
    for (const [arTerm, translatedTerm] of Object.entries(terms)) {
      textToTranslate = textToTranslate.replace(new RegExp(`\\b${arTerm}\\b`, 'g'), translatedTerm);
      textToTranslate = textToTranslate.replace(new RegExp(`(?<=^|\\s)${arTerm}(?=\\s|$)`, 'g'), translatedTerm);
    }
  }
  
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${target}&dt=t&q=${encodeURIComponent(textToTranslate)}`;
    const response = await fetch(url);
    if (!response.ok) throw new Error("Translation failed");
    
    const data = await response.json();
    // Google Translate API V1 returns an array of segments
    const translated = data[0].map((segment: any) => segment[0]).join("");
    return translated;
  } catch (error) {
    console.error("Translation Error:", error);
    return text; // Fallback to original text
  }
}
