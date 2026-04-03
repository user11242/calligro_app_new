"use server";

/**
 * Server Action to translate text using the Google Translate API (matching Flutter app logic).
 * This prevents CORS issues and keeps API calls server-side.
 */
export async function translateText(text: string, target: string) {
  if (!text || text === "Untitled" || text === "Untitled Course") return text;
  
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${target}&dt=t&q=${encodeURIComponent(text)}`;
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
